#!/usr/bin/env bash
# Regra C4: executa as afirmações do CLAUDE.md. Instrução falsa é o achado
# mais comum e o mais barato de corrigir. Read-only: só consulta package.json.
set -uo pipefail
root="${1:-.}"; cd "$root" || exit 1
[[ -f CLAUDE.md ]] || { echo "SEM_CLAUDE_MD"; exit 0; }

# comandos citados em crase que invocam script de pacote
mapfile -t claims < <(grep -oE '`(pnpm|npm run|yarn|bun run|npm|make) [a-zA-Z0-9:_-]+`' CLAUDE.md \
  | tr -d '`' | sort -u)

[[ ${#claims[@]} -gt 0 ]] || { echo "SEM_AFIRMACOES"; exit 0; }

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
echo "---"
echo "verificadas=$((ok+bad)) ok=$ok falsas=$bad"
[[ $bad -eq 0 ]] || exit 3
