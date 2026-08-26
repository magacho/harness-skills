#!/usr/bin/env bash
# Regra C4: executa as afirmações do CLAUDE.md. Instrução falsa é o achado mais
# comum e o mais barato de corrigir. Read-only: consulta manifesto e disco.
set -uo pipefail
root="${1:-.}"; cd "$root" || exit 1
[[ -f CLAUDE.md ]] || { echo "SEM_CLAUDE_MD"; exit 0; }

# 1. Scripts de pacote citados em crase.
mapfile -t claims < <(grep -oE '`(pnpm|npm run|yarn|bun run|npm|make) [a-zA-Z0-9:_-]+`' CLAUDE.md \
  | tr -d '`' | sort -u)

# 2. Caminhos executáveis citados em crase — `./ops/deploy.sh`,
#    `./.harness/gate-boundaries.sh --tighten`. O CLAUDE.md que o próprio
#    harness gera cita o gate; sem esta checagem, apagar o gate não aparecia
#    como instrução falsa e o audit reportava "falsas=0".
mapfile -t paths < <(grep -oE '`\./[^`]+`' CLAUDE.md | tr -d '`' | awk '{print $1}' | sort -u)

if [[ ${#claims[@]} -eq 0 && ${#paths[@]} -eq 0 ]]; then
  echo "SEM_AFIRMACOES"; exit 0
fi

ok=0; bad=0
for c in "${claims[@]}"; do
  script=$(awk '{print $NF}' <<<"$c")
  case "$c" in
    make\ *) if [[ -f Makefile ]] && grep -qE "^${script}:" Makefile; then
               echo "OK    $c"; ok=$((ok+1)); else echo "FALSA $c  (alvo ausente no Makefile)"; bad=$((bad+1)); fi ;;
    *)       if [[ -f package.json ]] && grep -qE "\"${script}\"[[:space:]]*:" package.json; then
               echo "OK    $c"; ok=$((ok+1)); else echo "FALSA $c  (script ausente no package.json)"; bad=$((bad+1)); fi ;;
  esac
done

for p in "${paths[@]}"; do
  if [[ ! -e "$p" ]]; then
    echo "FALSA $p  (caminho não existe)"; bad=$((bad+1))
  elif [[ -d "$p" ]]; then
    echo "OK    $p"; ok=$((ok+1))
  elif [[ ! -x "$p" ]]; then
    echo "FALSA $p  (existe mas não é executável)"; bad=$((bad+1))
  else
    echo "OK    $p"; ok=$((ok+1))
  fi
done

echo "---"
echo "verificadas=$((ok+bad)) ok=$ok falsas=$bad"
[[ $bad -eq 0 ]] || exit 3
