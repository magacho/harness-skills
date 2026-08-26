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

EXCL=('*.d.ts' '*.generated.*' '*.min.js' '*.pb.go' '*_pb2.py' '*.snap' '*-lock.json')

medidas=$(find "$root" \( -name node_modules -o -name .git -o -name vendor -o -name dist \
    -o -name build -o -name .venv -o -name __pycache__ -o -name .next -o -name target \
    -o -name coverage \) -prune -o -type f \
    \( -name '*.ts' -o -name '*.tsx' -o -name '*.mts' -o -name '*.cts' \
       -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' \
       -o -name '*.py' -o -name '*.go' -o -name '*.java' -o -name '*.kt' \
       -o -name '*.rb' -o -name '*.rs' -o -name '*.php' -o -name '*.cs' \
       -o -name '*.sh' \) -print 2>/dev/null \
  | while IFS= read -r f; do
      base="${f##*/}"; pula=0
      for p in "${EXCL[@]}"; do [[ "$base" == $p ]] && { pula=1; break; }; done
      [[ $pula -eq 1 ]] && continue
      printf '%s\t%s\n' "$(awk 'END{print NR+0}' "$f" 2>/dev/null)" "${f#"$root"/}"
    done)

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
