#!/usr/bin/env bash
# Fase 2 — a catraca. Congela as violações que já existem e liga o gate em
# "falha só no que é novo" (V7 → R7).
#
# É onde o valor chega: transforma "40 erros, gate inútil" em "40 erros
# parados". A decadência para antes de qualquer refactor.
#
#   gen-baseline.sh <repo> [--from-raw <arquivo>] [--force]
#
# --from-raw pula o verbo `run` e usa uma saída de ferramenta já gravada.
# Serve para eval offline e para stack cuja ferramenta não roda aqui.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

repo=""; from_raw=""; force=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-raw) from_raw="$2"; shift 2 ;;
    --force) force=1; shift ;;
    -*) echo "argumento desconhecido: $1" >&2; exit 64 ;;
    *) repo="$1"; shift ;;
  esac
done
root="$(cd "${repo:?uso: gen-baseline.sh <repo>}" && pwd)"
cfg="$root/.harness/harness.json"
[[ -f "$cfg" ]] || { echo "gen-baseline: fase 1 ainda não rodou ($cfg ausente)." >&2; exit 1; }

adapter=$(jq -r '.boundary.adapter // empty' "$cfg")
if [[ -z "$adapter" ]]; then
  # D4 → R10: a lacuna é dita em voz alta, e não aborta o resto da instalação.
  echo "SEM CATRACA: $(jq -r '.boundary.reason // "esta stack não tem adaptador de fronteira"' "$cfg")" >&2
  echo "O harness fica instalado e ativo; o gate de fronteira, não." >&2
  exit 3
fi

adapter_sh="$root/.harness/adapters/$adapter.sh"
[[ -x "$adapter_sh" ]] || { echo "gen-baseline: adaptador ausente em $adapter_sh." >&2; exit 1; }
bcfg=$(jq -r '.boundary.config' "$cfg")
mapfile -t targets < <(jq -r '.boundary.targets[]' "$cfg")

if [[ -n "$from_raw" ]]; then
  raw=$(cat "$from_raw")
else
  raw=$("$adapter_sh" run "$root" "$bcfg" "${targets[@]}") || exit 3
fi
novo=$(printf '%s' "$raw" | "$adapter_sh" normalize -) || exit 3

baseline="$root/.harness/baseline.json"
if [[ -f "$baseline" ]] && [[ $force -eq 0 ]]; then
  # V7: o baseline SÓ ENCOLHE. Regerar por cima seria o caminho silencioso para
  # congelar as violações que a instalação deveria ter pego.
  cresce=$(jq -n --argjson n "$novo" --slurpfile b "$baseline" '$n - $b[0] | length')
  if [[ "$cresce" -gt 0 ]]; then
    echo "RECUSADO: regerar acrescentaria $cresce violação(ões) ao baseline." >&2
    echo "O baseline só encolhe (V7 → R7). Corrija as novas, ou use --force e" >&2
    echo "explique por escrito por que o baseline cresceu." >&2
    exit 1
  fi
  encolhe=$(jq -n --argjson n "$novo" --slurpfile b "$baseline" '$b[0] - $n | length')
  echo "baseline já existe e não cresceu ($encolhe resolvida(s)). Use --tighten no gate." >&2
fi

printf '%s\n' "$novo" > "$baseline"
n=$(jq 'length' <<<"$novo")

jq -n --argjson n "$n" --argjson v "$novo" --arg p ".harness/baseline.json" '
  { baseline: $p, violacoes_congeladas: $n,
    catraca: (if $n > 0 then "ligada: o gate falha só no que é novo"
              else "ligada: repositório limpo, qualquer violação é nova" end),
    por_regra: ($v | group_by(.regra) | map({(.[0].regra): length}) | add // {}) }'
