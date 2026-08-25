#!/usr/bin/env bash
# Catraca de fronteira — gerado por harness:install.
# harness-generated: __VERSION__
#
# Roda o adaptador, normaliza a saída e compara com o baseline: reprova apenas
# o que é NOVO (V7 → R7). A comparação vive aqui, no harness, e não no
# mecanismo nativo da ferramenta (V8 → R7,R12).
#
# É comando invocável à mão (D5 → R12). O hook apenas o chama; nenhuma decisão
# mora dentro do hook (P8).
#
#   .harness/gate-boundaries.sh                 verifica
#   .harness/gate-boundaries.sh --scope f.txt   só violações que tocam a sessão
#   .harness/gate-boundaries.sh --json          saída de máquina
#   .harness/gate-boundaries.sh --tighten       remove do baseline o que já foi resolvido
#
# Saída: 0 nada novo · 1 violação nova · 3 adaptador indisponível (não bloqueia)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
cfgfile="$here/harness.json"
baseline="$here/baseline.json"

scope=""; as_json=0; tighten=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) scope="${2:-}"; shift 2 ;;
    --json) as_json=1; shift ;;
    --tighten) tighten=1; shift ;;
    *) echo "argumento desconhecido: $1" >&2; exit 64 ;;
  esac
done

[[ -f "$cfgfile" ]] || { echo "gate: $cfgfile ausente — o harness não está instalado." >&2; exit 3; }

adapter=$(jq -r '.boundary.adapter // empty' "$cfgfile")
if [[ -z "$adapter" ]]; then
  # D4 → R10: a ausência é declarada em voz alta, nunca silenciada, e nunca aborta.
  reason=$(jq -r '.boundary.reason // "sem adaptador para esta stack"' "$cfgfile")
  echo "gate de fronteira INDISPONÍVEL: $reason" >&2
  echo "O resto do harness está instalado e ativo. Ver docs/adapters/README.md." >&2
  exit 3
fi

adapter_sh="$here/adapters/$adapter.sh"
[[ -x "$adapter_sh" ]] || { echo "gate: adaptador $adapter_sh ausente ou sem bit de execução." >&2; exit 3; }

bcfg=$(jq -r '.boundary.config' "$cfgfile")
mapfile -t targets < <(jq -r '.boundary.targets[]' "$cfgfile")

raw=$("$adapter_sh" run "$root" "$bcfg" "${targets[@]}") || exit 3
current=$(printf '%s' "$raw" | "$adapter_sh" normalize -) || exit 3

[[ -f "$baseline" ]] || echo '[]' > "$baseline"

novas=$(jq -n --argjson c "$current" --slurpfile b "$baseline" '$c - $b[0]')
resolvidas=$(jq -n --argjson c "$current" --slurpfile b "$baseline" '$b[0] - $c')

# V4 → R2: escopo estreito. Reporta apenas o que toca arquivo da sessão —
# origem OU destino, porque um ciclo novo pode ser relatado a partir da ponta
# que a sessão não editou.
if [[ -n "$scope" && -f "$scope" ]]; then
  novas=$(jq -n --argjson v "$novas" --rawfile s "$scope" '
    ($s | split("\n") | map(select(length > 0))) as $files
    | $v | map(select(
        (.origem as $o | $files | any(. == $o or endswith("/" + $o)))
        or (.destino as $d | $files | any(. == $d or endswith("/" + $d)))
      ))')
fi

if [[ $tighten -eq 1 ]]; then
  # V7: o baseline só encolhe. Este é o único caminho para reduzi-lo.
  n=$(jq 'length' <<<"$resolvidas")
  jq -n --slurpfile b "$baseline" --argjson r "$resolvidas" '$b[0] - $r' > "$baseline.tmp" \
    && mv "$baseline.tmp" "$baseline"
  echo "baseline apertado: $n violação(ões) resolvida(s) removida(s)."
  exit 0
fi

n_novas=$(jq 'length' <<<"$novas")
n_resolv=$(jq 'length' <<<"$resolvidas")

if [[ $as_json -eq 1 ]]; then
  jq -n --argjson novas "$novas" --argjson resolvidas "$resolvidas" \
    '{novas: $novas, resolvidas: $resolvidas}'
  [[ "$n_novas" -eq 0 ]]
  exit $?
fi

if [[ "$n_novas" -gt 0 ]]; then
  echo "FRONTEIRA: $n_novas violação(ões) NOVA(S) — fora do baseline." >&2
  jq -r '.[] | "  \(.regra): \(.origem) → \(.destino)"' <<<"$novas" >&2
  echo >&2
  echo "Não adicione ao baseline para passar: o baseline só encolhe (V7)." >&2
  echo "Se a regra está errada, discuta antes — alterar fronteira exige ADR." >&2
  exit 1
fi

[[ "$n_resolv" -gt 0 ]] && \
  echo "fronteira ok — $n_resolv violação(ões) do baseline já não existe(m). Rode --tighten." >&2
exit 0
