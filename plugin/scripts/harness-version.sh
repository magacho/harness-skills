#!/usr/bin/env bash
# Versões do harness: a da skill que está rodando e a que instalou o harness
# deste repositório. As duas divergem com o tempo, e a diferença é a única
# informação acionável — arquivo gerado carrega marca de versão justamente para
# que a próxima instalação saiba o que é dela (D3 → R10).
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
plugin_root="${CLAUDE_PLUGIN_ROOT:-$here/..}"
repo="${1:-.}"
[[ -d "$repo" ]] || { echo "raiz inexistente: $repo" >&2; exit 64; }
repo="$(cd "$repo" && pwd)"

jqr() { jq -r "$1" "$2" 2>/dev/null || echo ""; }

# printf conta bytes; rótulo acentuado desalinharia a coluna. ${#s} conta
# caracteres em locale UTF-8, então o preenchimento é calculado à mão.
row() {
  local l="$1" v="$2" pad
  pad=$(( 20 - ${#l} )); (( pad < 1 )) && pad=1
  printf '  %s%*s%s\n' "$l" "$pad" "" "$v"
}

exec_v=$(jqr '.version // ""' "$plugin_root/.claude-plugin/plugin.json")
[[ -n "$exec_v" ]] || exec_v="desconhecida"

echo "harness — versões"
echo
row "skill em execução" "$exec_v"

# Marketplace de diretório aponta para a árvore de trabalho: se a fonte já está
# à frente do que está em execução, o cache está velho e um reinstall resolve.
mk="$HOME/.claude/plugins/known_marketplaces.json"
if [[ -f "$mk" ]]; then
  while IFS= read -r src; do
    [[ -n "$src" && -f "$src/plugin/.claude-plugin/plugin.json" ]] || continue
    sv=$(jqr '.version // ""' "$src/plugin/.claude-plugin/plugin.json")
    if [[ -n "$sv" && "$sv" != "$exec_v" ]]; then
      row "fonte local" "$sv  ← a fonte está à frente; reinstale para ativar"
    fi
  done < <(jq -r 'to_entries[] | select(.value.source.source == "directory") | .value.installLocation // .value.source.path' "$mk" 2>/dev/null)
fi

echo
hj="$repo/.harness/harness.json"
if [[ ! -f "$hj" ]]; then
  row "neste repositório" "nenhum harness instalado"
  echo
  echo "  Rode harness:audit para diagnosticar, ou harness:install para instalar."
  exit 0
fi

rv=$(jqr '.harness_version // ""' "$hj"); [[ -n "$rv" ]] || rv="desconhecida"
if [[ "$rv" != "$exec_v" && "$exec_v" != "desconhecida" && "$rv" != "desconhecida" ]]; then
  row "neste repositório" "$rv  ← instalado por outra versão"
else
  row "neste repositório" "$rv"
fi
row "dono" "$(jqr '.owner // "NÃO REGISTRADO (D6)"' "$hj")"
row "teto de autonomia" "$(jqr '.autonomy_ceiling // "não declarado"' "$hj")"

ad=$(jqr '.boundary.adapter // ""' "$hj")
if [[ -n "$ad" && "$ad" != "null" ]]; then
  gate="ausente"; [[ -x "$repo/.harness/gate-boundaries.sh" ]] && gate="presente"
  row "gate de fronteira" "$gate ($ad)"
else
  row "gate de fronteira" "indisponível: $(jqr '.boundary.reason // "sem adaptador"' "$hj")"
fi

if [[ -f "$repo/.harness/baseline.json" ]]; then
  row "catraca fronteira" "$(jq 'length' "$repo/.harness/baseline.json" 2>/dev/null || echo '?') violação(ões) congelada(s)"
else
  row "catraca fronteira" "sem baseline — a fase 2 não rodou"
fi

teto=$(jqr '.size.ceiling // ""' "$hj")
if [[ -n "$teto" && "$teto" != "null" ]]; then
  gate="ausente"; [[ -x "$repo/.harness/gate-size.sh" ]] && gate="presente"
  row "gate de tamanho" "$gate (teto $teto linhas)"
  if [[ -f "$repo/.harness/baseline-size.json" ]]; then
    row "catraca tamanho" "$(jq 'length' "$repo/.harness/baseline-size.json" 2>/dev/null || echo '?') arquivo(s) congelado(s)"
  else
    row "catraca tamanho" "sem baseline — a fase 2 não rodou"
  fi
else
  row "gate de tamanho" "não configurado"
fi

# Telemetria desligada é exatamente a coisa que fica invisível: o /stats existiria
# e não teria o que ler. Uma linha aqui evita isso. `// true` não serve — em jq
# ele devolve true para false.
if [[ "$(jq -r 'if .telemetry.enabled == false then "off" else "on" end' "$hj" 2>/dev/null)" == off ]]; then
  row "trilha" "DESLIGADA (telemetry.enabled: false)"
else
  n=$(cat "$repo"/.harness/log/events-*.jsonl 2>/dev/null | wc -l | tr -d ' ')
  if [[ "${n:-0}" -gt 0 ]]; then
    row "trilha" "$n evento(s) — leia com ./.harness/stats.sh"
  else
    row "trilha" "ligada, ainda sem evento"
  fi
fi

if [[ "$rv" != "$exec_v" && "$exec_v" != "desconhecida" && "$rv" != "desconhecida" ]]; then
  echo
  echo "  A instalação deste repositório é de outra versão da skill. Rodar"
  echo "  harness:install de novo é seguro: é idempotente e não sobrescreve"
  echo "  o que você editou à mão — o que for pulado é relatado (D3 → R10)."
fi
