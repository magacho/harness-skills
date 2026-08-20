#!/usr/bin/env bash
# Detecta stack, layout e ferramentas do repositório. Read-only.
# Saída: JSON em stdout.
set -uo pipefail
root="${1:-.}"; cd "$root" || exit 1

j() { printf '%s' "$1" | sed 's/"/\\"/g'; }
has() { [[ -e "$1" ]] && echo true || echo false; }

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
    "boundary_config": $(has .dependency-cruiser.js),
    "baseline": $(has .dependency-cruiser-known-violations.json),
    "adr_dir": $(has docs/adr),
    "other_agent_configs": $( { [[ -e .cursorrules || -e AGENTS.md || -e .windsurfrules ]] && echo true || echo false; } )
  },
  "ci": $(has .github/workflows),
  "claude_md_module_count": $(find . -mindepth 2 -name CLAUDE.md -not -path './node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
}
JSON
