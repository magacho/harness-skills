#!/usr/bin/env bash
# Detecta stack, layout e ferramentas do repositório. Read-only.
# Saída: JSON em stdout.
set -uo pipefail
root="${1:-.}"; cd "$root" || exit 1

j() { printf '%s' "$1" | sed 's/"/\\"/g'; }
has() { [[ -e "$1" ]] && echo true || echo false; }
has_any() { for f in "$@"; do [[ -e "$f" ]] && { echo true; return; }; done; echo false; }

stack="unknown"; adapter="none"
if [[ -f package.json ]]; then
  stack="node"
  grep -qE '"typescript"' package.json 2>/dev/null && stack="node-ts"
  adapter="dependency-cruiser"
elif [[ -f pyproject.toml || -f requirements.txt || -f setup.py ]]; then
  stack="python"; adapter="unsupported:import-linter"
elif [[ -f go.mod ]]; then
  stack="go"; adapter="unsupported:go-arch-lint"
elif [[ -f pom.xml || -f build.gradle || -f build.gradle.kts ]]; then
  stack="jvm"; adapter="unsupported:archunit"
fi

layout="single"
if [[ -f pnpm-workspace.yaml ]]; then layout="monorepo-pnpm"
elif [[ -f lerna.json || -f turbo.json ]]; then layout="monorepo-js"
elif [[ -f package.json ]] && grep -q '"workspaces"' package.json 2>/dev/null; then layout="monorepo-npm"
fi

pm="unknown"
[[ -f pnpm-lock.yaml ]] && pm="pnpm"
[[ -f yarn.lock ]] && pm="yarn"
[[ -f package-lock.json ]] && pm="npm"
[[ -f bun.lockb ]] && pm="bun"

# A config de fronteira tem quatro extensões possíveis: o instalador escreve
# .cjs, o template traz .js. Procurar só uma deixava o audit cego para a própria
# instalação — reportava boundary_config=false em repo que tinha a config.
bcfg=$(has_any .dependency-cruiser.js .dependency-cruiser.cjs \
               .dependency-cruiser.mjs .dependency-cruiser.json)

# O baseline da catraca é do harness, não da ferramenta (V8 → R7,R12).
# .dependency-cruiser-known-violations.json é o baseline NATIVO: encontrá-lo não
# é a catraca instalada, é um achado — catraca delegada ao mecanismo da
# ferramenta, que existe em duas linguagens de quatro.
hv=null; how=null; hc=null
if [[ -f .harness/harness.json ]] && command -v jq >/dev/null 2>&1; then
  hv=$(jq -c '.harness_version // null' .harness/harness.json 2>/dev/null || echo null)
  how=$(jq -c '.owner // null' .harness/harness.json 2>/dev/null || echo null)
  hc=$(jq -c '.autonomy_ceiling // null' .harness/harness.json 2>/dev/null || echo null)
fi

cat <<JSON
{
  "stack": "$(j "$stack")",
  "layout": "$(j "$layout")",
  "package_manager": "$(j "$pm")",
  "boundary_adapter": "$(j "$adapter")",
  "harness": {
    "claude_md_root": $(has CLAUDE.md),
    "claude_dir": $(has .claude),
    "settings": $(has .claude/settings.json),
    "hooks": $(has .claude/hooks),
    "agents": $(has .claude/agents),
    "commands": $(has .claude/commands),
    "boundary_config": $bcfg,
    "harness_dir": $(has .harness),
    "gate": $(has .harness/gate-boundaries.sh),
    "adapters": $(has .harness/adapters),
    "baseline": $(has .harness/baseline.json),
    "baseline_nativo": $(has .dependency-cruiser-known-violations.json),
    "versao": $hv,
    "dono": $how,
    "teto_de_autonomia": $hc,
    "adr_dir": $(has docs/adr),
    "other_agent_configs": $( { [[ -e .cursorrules || -e AGENTS.md || -e .windsurfrules ]] && echo true || echo false; } )
  },
  "ci": $(has .github/workflows),
  "claude_md_module_count": $(find . -mindepth 2 -name CLAUDE.md -not -path './node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
}
JSON
