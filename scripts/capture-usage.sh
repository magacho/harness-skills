#!/usr/bin/env bash
# Recaptura as saídas que docs/USAGE.md publica como reais.
#
# A página afirma que nenhuma saída dela é ilustrativa — é a regra C4 aplicada à
# própria documentação. Uma vez a afirmação ficou falsa: os blocos da catraca de
# tamanho traziam sete god files e um arquivo de 1840 linhas que nenhuma fixture
# tinha. Este script existe para que recapturar seja mais barato que inventar.
#
#   ./scripts/capture-usage.sh            imprime todos os blocos
#   ./scripts/capture-usage.sh 5.0        imprime um bloco
#
# Os nomes de seção são os do USAGE.md. Cole a saída no lugar do bloco.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

filtro="${1:-}"
F=$PWD/evals/fixtures
A=$PWD/plugin/skills/audit/scripts
I=$PWD/plugin/skills/install/scripts
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

quer() { [[ -z "$filtro" || "$1" == "$filtro"* ]]; }
bloco() { echo; echo "########## USAGE.md §$1 — $2"; }

# O legado da página é `legado-com-ciclos`. Para os blocos de tamanho ele ganha o
# mesmo god file de 450 linhas que o eval 70 planta: fixture sem arquivo grande
# não tem o que congelar, e foi essa lacuna que a prosa preencheu com número
# inventado.
legado() {
  local d="$W/$1"
  cp -a "$F/legado-com-ciclos" "$d"
  [[ "${2:-}" == --god ]] && python3 -c \
    "open('$d/src/cobranca/gigante.js','w').write(chr(10).join(f'const l{i} = {i};' for i in range(1,451))+chr(10))"
  echo "$d"
}

if quer 3.1; then
  bloco 3.1 "detect-stack.sh"
  "$A/detect-stack.sh" "$F/legado-com-instrucao-falsa"
fi

if quer 3.2; then
  bloco 3.2 "check-claims.sh"
  "$A/check-claims.sh" "$F/legado-com-instrucao-falsa"; echo "(exit $?)"
fi

if quer 3.3; then
  bloco 3.3 "boundary-status.sh"
  "$A/boundary-status.sh" "$F/legado-com-ciclos"
  bloco 3.3 "boundary-status.sh sem alvo reconhecido"
  "$A/boundary-status.sh" "$F/sem-harness"; echo "(exit $?)"
fi

if quer 4; then
  bloco 4 "plan-install.sh — merece_harness falso"
  "$I/plan-install.sh" "$F/nao-merece-harness" | jq '{modo, merece_harness}'
fi

if quer 5.0; then
  d=$(legado plan --god)
  bloco 5.0 "plan-install.sh"
  "$I/plan-install.sh" "$d" | jq '{modo, modulos, boundary, gates_hoje,
    size: (.size | {ceiling, acima_do_teto, maior}), pendencias}'
fi

if quer 5.1; then
  d=$(legado f1 --god)
  bloco 5.1 "gen-config.sh --fase 1"
  "$I/plan-install.sh" "$d" > "$W/f1.plan.json" 2>/dev/null
  "$I/gen-config.sh" "$d" --plan "$W/f1.plan.json" \
    --owner "Flavio Magacho" --ceiling supervisionado --fase 1
fi

if quer 5.2; then
  d=$(legado bl --god)
  "$I/plan-install.sh" "$d" > "$W/bl.plan.json" 2>/dev/null
  "$I/gen-config.sh" "$d" --plan "$W/bl.plan.json" --owner "X" --fase 1 >/dev/null 2>&1
  bloco 5.2 "gen-baseline.sh"
  "$I/gen-baseline.sh" "$d"
  bloco 5.2 "baseline.json — fronteira, presença"
  cat "$d/.harness/baseline.json"
  bloco 5.2 "baseline-size.json — tamanho, grandeza"
  cat "$d/.harness/baseline-size.json"
fi

if quer 5.3; then
  d=$(legado f3)
  "$I/plan-install.sh" "$d" > "$W/f3.plan.json" 2>/dev/null
  "$I/gen-config.sh" "$d" --plan "$W/f3.plan.json" --owner "X" --fase 1 >/dev/null 2>&1
  bloco 5.3 "gen-config.sh --fase 3"
  "$I/gen-config.sh" "$d" --plan "$W/f3.plan.json" --owner "Flavio Magacho" --fase 3
  bloco 5.3 "CLAUDE.md de módulo gerado"
  cat "$d/src/cobranca/CLAUDE.md"
fi

if quer 5.4; then
  d=$(legado sm --god)
  "$I/plan-install.sh" "$d" > "$W/sm.plan.json" 2>/dev/null
  "$I/gen-config.sh" "$d" --plan "$W/sm.plan.json" --owner "X" --fase 1 >/dev/null 2>&1
  "$I/gen-baseline.sh" "$d" >/dev/null 2>&1
  bloco 5.4 "smoke-test.sh"
  "$I/smoke-test.sh" "$d"; echo "(exit $?)"
fi

if quer 6; then
  mkdir -p "$W/novo"
  bloco 6 "scaffold.sh"
  "$I/scaffold.sh" "$W/novo" --owner "Flavio Magacho" \
    --modules "shared=comum,domain=cobranca,data=persistencia,api=http,web=ui"
fi

if quer 7; then
  d=$(legado hj --god)
  "$I/plan-install.sh" "$d" > "$W/hj.plan.json" 2>/dev/null
  "$I/gen-config.sh" "$d" --plan "$W/hj.plan.json" --owner "Flavio Magacho" --fase 1 >/dev/null 2>&1
  # A árvore da §7 é o que fica no repositório DEPOIS da fase 2: sem gerar o
  # baseline aqui, os dois arquivos de catraca não apareceriam — foi assim que o
  # gate de tamanho sumiu da lista.
  "$I/gen-baseline.sh" "$d" >/dev/null 2>&1
  bloco 7 "harness.json"
  cat "$d/.harness/harness.json"
  bloco 7 "árvore de .harness e .claude"
  (cd "$d" && find .harness .claude -type f | sort)
fi

if quer 8; then
  d=$(legado dps --god)
  "$I/plan-install.sh" "$d" > "$W/dps.plan.json" 2>/dev/null
  "$I/gen-config.sh" "$d" --plan "$W/dps.plan.json" --owner "X" --fase 1 >/dev/null 2>&1
  "$I/gen-baseline.sh" "$d" >/dev/null 2>&1
  bloco 8 "gate-boundaries.sh com o baseline congelado"
  (cd "$d" && ./.harness/gate-boundaries.sh); echo "(exit $?)"
  # Ciclo novo: `moeda.js` já existe e não importa ninguém, então basta fechar o
  # laço com um arquivo novo para que a violação seja de verdade NOVA.
  printf 'import { fmt } from "./moeda.js";\nexport const usa = fmt;\n' > "$d/src/comum/ciclo-novo.js"
  printf 'import { usa } from "./ciclo-novo.js";\nexport const eco = usa;\n' >> "$d/src/comum/moeda.js"
  bloco 8 "gate-boundaries.sh com violação nova"
  (cd "$d" && ./.harness/gate-boundaries.sh); echo "(exit $?)"
  bloco 8 "gate-boundaries.sh --tighten"
  (cd "$d" && ./.harness/gate-boundaries.sh --tighten); echo "(exit $?)"
fi

if quer 8.1; then
  d=$(legado tel --god)
  "$I/plan-install.sh" "$d" > "$W/tel.plan.json" 2>/dev/null
  "$I/gen-config.sh" "$d" --plan "$W/tel.plan.json" --owner "Flavio Magacho" --fase 1 >/dev/null 2>&1
  "$I/gen-baseline.sh" "$d" >/dev/null 2>&1
  # Eventos vindos dos hooks de verdade, não escritos à mão: a página afirma que
  # nenhuma saída dela é ilustrativa, e trilha inventada seria a mesma classe de
  # defeito que a 0.2.9 corrigiu.
  g() { echo "{\"session_id\":\"s1\",\"tool_input\":{\"command\":$(jq -Rn --arg c "$1" '$c')}}" \
        | CLAUDE_PROJECT_DIR="$d" "$d/.claude/hooks/guard-prod.sh" >/dev/null 2>&1; }
  g 'git tag -a v1.4.0 -m "release"'
  g './ops/deploy.sh --env prd'
  g 'psql -h db -c "TRUNCATE faturas"'
  g 'pnpm run build'; g 'git status'; g 'git diff'
  printf '%s\n' "$d/src/comum/moeda.js" > "/tmp/cc-touched-s1-main.txt"
  echo '{"session_id":"s1"}' | CLAUDE_PROJECT_DIR="$d" "$d/.claude/hooks/verify.sh" >/dev/null 2>&1
  for f in src/comum/moeda.js src/comum/moeda.js src/cobranca/cobrar.js; do
    echo "{\"session_id\":\"s1\",\"tool_input\":{\"file_path\":\"$d/$f\"}}" \
      | CLAUDE_PROJECT_DIR="$d" "$d/.claude/hooks/on-edit.sh" >/dev/null 2>&1
  done
  rm -f /tmp/cc-touched-s1-main.txt
  bloco 8.1 "uma linha da trilha, como o hook a escreve"
  find "$d/.harness/log" -name 'events-*.jsonl' -exec head -1 {} +
  bloco 8.1 "stats.sh"
  (cd "$d" && ./.harness/stats.sh)
  bloco 8.1 "stats.sh --denies"
  (cd "$d" && ./.harness/stats.sh --denies)
fi

if quer 9; then
  bloco 9 "plan-install.sh — stack sem adaptador"
  "$I/plan-install.sh" "$F/python-sem-adaptador" | jq '{boundary, pendencias}'
fi

if quer 10; then
  d=$(legado idem)
  "$I/plan-install.sh" "$d" > "$W/idem.plan.json" 2>/dev/null
  "$I/gen-config.sh" "$d" --plan "$W/idem.plan.json" --owner "Flavio Magacho" --fase 1 >/dev/null 2>&1
  bloco 10 "gen-config.sh --fase 1, segunda rodada"
  "$I/gen-config.sh" "$d" --plan "$W/idem.plan.json" --owner "Outra Pessoa" --fase 1
fi
