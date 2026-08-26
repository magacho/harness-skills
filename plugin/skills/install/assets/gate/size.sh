#!/usr/bin/env bash
# Catraca de tamanho — gerado por harness:install.
# harness-generated: __VERSION__
#
# Mede linhas por arquivo e reprova apenas o que é NOVO ou o que CRESCEU
# (V10 → R4,R7). O god file existente entra no baseline e para de crescer; a
# decadência para antes de qualquer refactor.
#
# Semântica diferente da catraca de fronteira, de propósito: fronteira é
# presença (existe ou não existe), tamanho é grandeza (o número não pode subir).
# Por isso o baseline aqui é {caminho: linhas}, e não uma lista de violações.
#
# Não depende de ferramenta externa: vale em qualquer linguagem, inclusive nas
# que não têm adaptador de fronteira (V8 → R12).
#
#   .harness/gate-size.sh                    verifica
#   .harness/gate-size.sh --scope f.txt      só arquivos da sessão
#   .harness/gate-size.sh --json             saída de máquina
#   .harness/gate-size.sh --tighten          baixa o baseline para o tamanho atual
#   .harness/gate-size.sh --init [--force]   grava o baseline inicial (fase 2)
#   .harness/gate-size.sh --rename a b       move a entrada de um arquivo renomeado
#
# E dois modos sem estado, para quem precisa medir ANTES de haver instalação —
# o plano da instalação e o relatório do audit:
#
#   .harness/gate-size.sh --defaults                    teto, extensões e exclusões canônicos
#   .harness/gate-size.sh --measure --root D [opções]   "linhas<TAB>caminho" de todo arquivo-fonte
#
# Estes dois existem porque a varredura estava reimplementada em três lugares —
# aqui, no plan-install.sh e no size-status.sh — com listas de poda diferentes.
# O plano acusava god file em `.next/` e `coverage/`, que o gate podava: o mesmo
# repositório tinha duas respostas, e a errada era a que a pessoa lia antes de
# decidir. Um scanner, três consumidores.
#
# Saída: 0 nada novo · 1 arquivo novo ou que cresceu · 3 gate não configurado
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
cfgfile="$here/harness.json"
baseline="$here/baseline-size.json"

# Diretório de artefato de build nunca é código-fonte. Esta lista é a canônica:
# divergir dela foi o defeito. .next/.nuxt/.svelte-kit/out são de framework web,
# target de Rust/Java, coverage de relatório de teste.
PODAR=(node_modules .git dist build out vendor .venv __pycache__ .next .nuxt
       .svelte-kit target coverage .turbo .cache .parcel-cache)
EXT_PADRAO=(ts tsx mts cts js jsx mjs cjs py go java kt rb rs php cs sh)
EXCL_PADRAO=('*.d.ts' '*.generated.*' '*.min.js' '*.pb.go' '*_pb2.py' '*.snap' '*-lock.json')
TETO_PADRAO=400

scope=""; as_json=0; tighten=0; init=0; force=0; ren_de=""; ren_para=""
measure=0; defaults=0; opt_root=""; opt_targets=""; opt_ext=""; opt_excl=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) scope="${2:-}"; shift 2 ;;
    --json) as_json=1; shift ;;
    --tighten) tighten=1; shift ;;
    --init) init=1; shift ;;
    --force) force=1; shift ;;
    --rename) ren_de="${2:-}"; ren_para="${3:-}"; shift 3 ;;
    --measure) measure=1; shift ;;
    --defaults) defaults=1; shift ;;
    --root) opt_root="${2:-}"; shift 2 ;;
    --targets) opt_targets="${2:-}"; shift 2 ;;
    --ext) opt_ext="${2:-}"; shift 2 ;;
    --exclude) opt_excl="${2:-}"; shift 2 ;;
    *) echo "argumento desconhecido: $1" >&2; exit 64 ;;
  esac
done

# Enumeração de arquivo-fonte. Único lugar do harness que decide o que é código
# e o que é artefato.
e_fonte() {
  local rel="$1" base="${rel##*/}" e p achou=1
  for e in "${exts[@]}"; do [[ "$base" == *."$e" ]] && { achou=0; break; }; done
  [[ $achou -eq 0 ]] || return 1
  for p in ${excl[@]+"${excl[@]}"}; do
    # shellcheck disable=SC2053
    [[ "$base" == $p || "$rel" == $p ]] && return 1
  done
  return 0
}

# Linha física contada com awk e não com `wc -l`: arquivo sem newline final tem
# uma linha a menos no wc, e o gate ficaria devendo uma linha justo no arquivo
# que alguém acabou de tocar.
medir() {  # medir <raiz> <alvo...> → "linhas<TAB>caminho"
  local r="$1"; shift
  local t f rel n poda=()
  for p in "${PODAR[@]}"; do poda+=(-name "$p" -o); done
  unset "poda[${#poda[@]}-1]"
  for t in "$@"; do
    [[ -e "$r/$t" ]] || continue
    while IFS= read -r f; do
      rel="${f#"$r"/}"; rel="${rel#./}"
      e_fonte "$rel" || continue
      n=$(awk 'END{print NR+0}' "$f" 2>/dev/null) || continue
      printf '%s\t%s\n' "$n" "$rel"
    done < <(find "$r/$t" \( "${poda[@]}" \) -prune -o -type f -print 2>/dev/null)
  done
}

csv_para_array() {  # csv_para_array <csv> <nome-do-array>
  local IFS=','; read -r -a "$2" <<<"$1"
}

if [[ $defaults -eq 1 ]]; then
  jq -n --argjson teto "$TETO_PADRAO" \
    --argjson ext "$(printf '%s\n' "${EXT_PADRAO[@]}" | jq -R . | jq -s .)" \
    --argjson exc "$(printf '%s\n' "${EXCL_PADRAO[@]}" | jq -R . | jq -s .)" \
    --argjson pod "$(printf '%s\n' "${PODAR[@]}" | jq -R . | jq -s .)" \
    '{ceiling: $teto, extensions: $ext, exclude: $exc, prune: $pod}'
  exit 0
fi

if [[ $measure -eq 1 ]]; then
  # Sem config e sem estado: mede a raiz que mandarem. É o que o plano da
  # instalação e o relatório do audit chamam, para que ninguém reimplemente find.
  [[ -n "$opt_root" ]] || { echo "--measure exige --root <dir>" >&2; exit 64; }
  [[ -d "$opt_root" ]] || { echo "--measure: raiz inexistente: $opt_root" >&2; exit 64; }
  mroot="$(cd "$opt_root" && pwd)"
  if [[ -n "$opt_ext" ]]; then csv_para_array "$opt_ext" exts; else exts=("${EXT_PADRAO[@]}"); fi
  if [[ -n "$opt_excl" ]]; then csv_para_array "$opt_excl" excl; else excl=("${EXCL_PADRAO[@]}"); fi
  if [[ -n "$opt_targets" ]]; then csv_para_array "$opt_targets" mtargets; else mtargets=("."); fi
  medir "$mroot" "${mtargets[@]}"
  exit 0
fi

[[ -f "$cfgfile" ]] || { echo "gate: $cfgfile ausente — o harness não está instalado." >&2; exit 3; }

teto=$(jq -r '.size.ceiling // empty' "$cfgfile")
if [[ -z "$teto" ]]; then
  # D4 → R10: a ausência é dita em voz alta, nunca silenciada, e nunca aborta.
  echo "gate de tamanho INDISPONÍVEL: não há .size em $cfgfile." >&2
  echo "O resto do harness está instalado e ativo." >&2
  exit 3
fi

mapfile -t targets < <(jq -r '.size.targets[]?' "$cfgfile")
mapfile -t exts    < <(jq -r '.size.extensions[]?' "$cfgfile")
mapfile -t excl    < <(jq -r '.size.exclude[]?' "$cfgfile")
[[ ${#targets[@]} -gt 0 ]] || targets=(".")
[[ ${#exts[@]} -gt 0 ]] || { echo "gate: .size.extensions vazio — nada a medir." >&2; exit 3; }

[[ -f "$baseline" ]] || echo '{}' > "$baseline"

# --- renomeação ------------------------------------------------------------
# Um arquivo renomeado apareceria como "novo acima do teto" e reprovaria um
# commit legítimo. Mover a entrada é explícito e NUNCA aumenta o número — é a
# única forma de mexer no baseline sem afrouxá-lo.
if [[ -n "$ren_de" ]]; then
  [[ -n "$ren_para" ]] || { echo "uso: --rename <antigo> <novo>" >&2; exit 64; }
  jq -e --arg d "$ren_de" 'has($d)' "$baseline" >/dev/null 2>&1 \
    || { echo "--rename: '$ren_de' não está no baseline." >&2; exit 1; }
  jq -e --arg p "$ren_para" 'has($p)' "$baseline" >/dev/null 2>&1 \
    && { echo "--rename: '$ren_para' já está no baseline. Aperte antes (--tighten)." >&2; exit 1; }
  jq --arg d "$ren_de" --arg p "$ren_para" '. + {($p): .[$d]} | del(.[$d])' \
    "$baseline" > "$baseline.tmp" && mv "$baseline.tmp" "$baseline"
  echo "baseline: $ren_de → $ren_para (mesmo teto individual, sem folga nova)."
  exit 0
fi

# --- medição ---------------------------------------------------------------
atual=$(medir "$root" "${targets[@]}" \
        | awk -F'\t' -v c="$teto" '$1 > c {printf "%s\t%s\n", $2, $1}' \
        | jq -R -s 'split("\n") | map(select(length > 0) | split("\t"))
                    | map({(.[0]): (.[1] | tonumber)}) | add // {}')

# --- --init: a fase 2 ------------------------------------------------------
if [[ $init -eq 1 ]]; then
  if [[ $force -eq 0 ]] && [[ "$(jq 'length' "$baseline" 2>/dev/null || echo 0)" -gt 0 ]]; then
    # V7: o baseline só encolhe. Regerar por cima é o caminho silencioso para
    # congelar o crescimento que a fase 2 deveria ter pego.
    cresce=$(jq -n --argjson a "$atual" --slurpfile b "$baseline" '
      [ $a | to_entries[] | select((($b[0][.key]) // -1) < .value) ] | length')
    if [[ "$cresce" -gt 0 ]]; then
      echo "RECUSADO: regerar afrouxaria o baseline em $cresce arquivo(s)." >&2
      echo "O baseline só encolhe (V7 → R7). Reduza os arquivos, ou use --force" >&2
      echo "e explique por escrito por que a folga aumentou." >&2
      exit 1
    fi
  fi
  printf '%s\n' "$atual" > "$baseline"
  jq -n --argjson a "$atual" --argjson teto "$teto" '
    { baseline: ".harness/baseline-size.json", teto: $teto,
      arquivos_congelados: ($a | length),
      maior: (($a | to_entries | sort_by(-.value) | first) // null),
      catraca: (if ($a | length) > 0
                then "ligada: os \($a | length) arquivo(s) acima do teto não podem crescer"
                else "ligada: nenhum arquivo acima do teto, qualquer um que passe reprova" end) }'
  exit 0
fi

# --- comparação ------------------------------------------------------------
falhas=$(jq -n --argjson a "$atual" --slurpfile b "$baseline" '
  ($b[0]) as $base
  | [ $a | to_entries[] | . as $e
      | if ($base | has($e.key))
        then (if $e.value > $base[$e.key]
              then {arquivo: $e.key, linhas: $e.value, era: $base[$e.key], motivo: "cresceu"}
              else empty end)
        else {arquivo: $e.key, linhas: $e.value, era: null, motivo: "novo acima do teto"}
        end ]
  | sort_by(-.linhas)')

folgas=$(jq -n --argjson a "$atual" --slurpfile b "$baseline" '
  [ $b[0] | to_entries[] | (($a[.key]) // 0) as $agora
    | select($agora < .value)
    | {arquivo: .key, era: .value, agora: $agora} ]')

# V4 → R2: escopo estreito. Só reporta arquivo que a sessão tocou — erro fora
# do raio da mudança faz o agente adotar trabalho que não é dele.
if [[ -n "$scope" && -f "$scope" ]]; then
  falhas=$(jq -n --argjson f "$falhas" --rawfile s "$scope" '
    ($s | split("\n") | map(select(length > 0))) as $files
    | $f | map(select(.arquivo as $a | $files | any(. == $a or endswith("/" + $a) or ($a | endswith("/" + .)))))')
fi

if [[ $tighten -eq 1 ]]; then
  # V7: único caminho para reduzir o baseline. Nunca aumenta um número, nunca
  # acrescenta chave: entrada que já não passa do teto simplesmente sai.
  n=$(jq 'length' <<<"$folgas")
  jq -n --argjson a "$atual" --slurpfile b "$baseline" '
    [ $b[0] | to_entries[] | (($a[.key]) // null) as $agora
      | if $agora == null then empty
        elif $agora < .value then {key: .key, value: $agora}
        else . end ] | from_entries' > "$baseline.tmp" \
    && mv "$baseline.tmp" "$baseline"
  echo "baseline apertado: $n arquivo(s) encolheram e o teto individual acompanhou."
  exit 0
fi

n_falhas=$(jq 'length' <<<"$falhas")
n_folgas=$(jq 'length' <<<"$folgas")

if [[ $as_json -eq 1 ]]; then
  jq -n --argjson falhas "$falhas" --argjson folgas "$folgas" --argjson teto "$teto" \
    '{teto: $teto, falhas: $falhas, folgas: $folgas}'
  [[ "$n_falhas" -eq 0 ]]
  exit $?
fi

if [[ "$n_falhas" -gt 0 ]]; then
  echo "TAMANHO: $n_falhas arquivo(s) acima do teto de $teto linhas." >&2
  jq -r '.[] | "  \(.arquivo): \(.linhas) linhas (\(if .era then "era \(.era) — cresceu" else .motivo end))"' \
    <<<"$falhas" >&2
  echo >&2
  # A4 → R1: a recusa ensina. Dizer só "negado" produz a saída errada — partir
  # o arquivo em "parte 1 / parte 2" satisfaz o número e piora o código.
  echo "Parta por responsabilidade, não pelo número. O gate mede linha, mas o que" >&2
  echo "ele protege é a mudança que cabe num contexto pequeno (R4): dividir em" >&2
  echo "'parte 1 / parte 2' passa no gate, piora o código, e normalmente cai no" >&2
  echo "gate de ciclo logo depois." >&2
  echo "Não edite o baseline para passar: ele só encolhe (V7). Se o arquivo foi" >&2
  echo "renomeado, use --rename <antigo> <novo>." >&2
  exit 1
fi

[[ "$n_folgas" -gt 0 ]] && \
  echo "tamanho ok — $n_folgas arquivo(s) do baseline encolheram. Rode --tighten." >&2
exit 0
