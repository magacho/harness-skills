#!/usr/bin/env bash
# Dimensão do problema de tamanho. Read-only.
#
# Mede o que a catraca de tamanho vai congelar ANTES de instalar nada. Não
# depende de ferramenta nem de adaptador: a contagem de linha é o único oráculo
# estrutural que existe em toda linguagem (V10 → R12).
#
# Serve para a decisão que o relatório do audit tem de sustentar: 3 arquivos
# acima do teto é uma tarde; 300 é decisão de roadmap. Nos dois casos a catraca
# congela hoje — o que muda é o que se promete depois dela.
#
#   size-status.sh <repo> [--ceiling N]
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="${1:-.}"; shift 2>/dev/null || true
teto=400
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ceiling) teto="${2:?}"; shift 2 ;;
    *) echo "argumento desconhecido: $1" >&2; exit 64 ;;
  esac
done
[[ -d "$root" ]] || { echo "raiz inexistente: $root" >&2; exit 64; }
root="$(cd "$root" && pwd)"

# A varredura é do gate de tamanho — o único lugar do harness que decide o que é
# código e o que é artefato de build. Havia aqui uma terceira cópia da lista de
# poda, e cópia de política divergiu na primeira correção aplicada a só um lado.
GATE_SIZE="$here/../../install/assets/gate/size.sh"
[[ -x "$GATE_SIZE" ]] || { echo "size-status: $GATE_SIZE ausente — a medição é dele." >&2; exit 3; }
medidas=$("$GATE_SIZE" --measure --root "$root")

if [[ -z "$medidas" ]]; then
  echo "SEM_FONTE: nenhum arquivo de código reconhecido em $root." >&2
  echo "Isto NÃO é 'nenhum god file': a dimensão não foi medida." >&2
  exit 3
fi

jq -n --arg m "$medidas" --argjson teto "$teto" '
  ($m | split("\n") | map(select(length > 0) | split("\t"))
      | map({arquivo: .[1], linhas: (.[0] | tonumber)})) as $f
  | ($f | map(.linhas) | sort) as $ls
  | { teto: $teto,
      arquivos: ($f | length),
      linhas_totais: ($ls | add),
      mediana: ($ls[($ls | length) / 2 | floor]),
      p95: ($ls[($ls | length) * 0.95 | floor]),
      acima_do_teto: ($f | map(select(.linhas > $teto)) | length),
      linhas_acima_do_teto: ($f | map(select(.linhas > $teto) | .linhas) | add // 0),
      piores: ($f | sort_by(-.linhas) | .[0:10]),
      catraca_obrigatoria: (($f | map(select(.linhas > $teto)) | length) > 0) }'
