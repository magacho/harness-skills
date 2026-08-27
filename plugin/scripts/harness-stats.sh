#!/usr/bin/env bash
# A trilha do harness, como ela está NESTA MÁQUINA. Read-only.
#
#   harness-stats.sh                 este repositório; sem trilha aqui, varre a máquina
#   harness-stats.sh <repo>          um repositório
#   harness-stats.sh --all           todo repositório com trilha, em uma tabela
#   harness-stats.sh --json          a mesma coisa, legível por máquina
#
# Complementa o `/stats` que a instalação escreve dentro do repositório: aquele
# lê a trilha deste repositório e INTERPRETA; este mostra o que está gravado no
# JSON, aqui e nos outros repositórios da máquina, sem julgar.
#
# NÃO reimplementa a leitura. Chama o leitor único (`stats.sh --root`), que é o
# mesmo que o repositório instalado usa — e é por isso que ele funciona até em
# repositório cujo harness é de uma versão anterior à telemetria: o que falta lá
# é o emissor, não o leitor.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
plugin_root="${CLAUDE_PLUGIN_ROOT:-$here/..}"
leitor="$plugin_root/skills/install/assets/telemetry/stats.sh"

alvo=""; todos=0; as_json=0; since="all"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) todos=1; shift ;;
    --json) as_json=1; shift ;;
    --since) since="${2:-all}"; shift 2 ;;
    -*) echo "argumento desconhecido: $1" >&2; exit 64 ;;
    *) alvo="$1"; shift ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "harness:stats — jq é necessário." >&2; exit 3; }
[[ -x "$leitor" ]] || { echo "harness:stats — leitor ausente: $leitor" >&2; exit 3; }

# Descoberta: todo diretório .harness com harness.json debaixo de $HOME. Profun-
# didade limitada e node_modules podado — sem isso, uma máquina de trabalho leva
# minutos para responder a uma pergunta de dez segundos.
descobrir() {
  find "$HOME" -maxdepth 6 \
    \( -name node_modules -o -name .git -o -name .cache -o -name Trash \) -prune -o \
    -type f -path '*/.harness/harness.json' -print 2>/dev/null \
    | while IFS= read -r f; do dirname "$(dirname "$f")"; done | sort -u
}

# Uma linha de dados por repositório, sempre pelo leitor.
linha() {  # <repo> → JSON
  local d="$1" s
  s=$("$leitor" --root "$d" --since "$since" --json 2>/dev/null) || s=""
  local ver emissor
  ver=$(jq -r '.harness_version // "?"' "$d/.harness/harness.json" 2>/dev/null || echo '?')
  emissor=false; [[ -f "$d/.harness/log.sh" ]] && emissor=true
  if [[ -z "$s" ]]; then
    jq -n --arg r "$d" --arg v "$ver" \
      '{repo: $r, versao: $v, estado: "ilegivel", eventos: 0, bloqueios: 0, desde: null}'
    return
  fi
  jq -n --argjson s "$s" --arg r "$d" --arg v "$ver" --argjson e "$emissor" '
    { repo: $r, versao: $v,
      estado: (if ($e | not) then "sem-emissor"
               elif ($s.telemetria.enabled | not) then "desligada"
               elif ($s.telemetria.trilha_desde == null) then "vazia"
               else "medindo" end),
      eventos: ($s.guard.deny + $s.guard.allow + $s.verify.execucoes + $s.atividade.edits),
      bloqueios: $s.guard.deny,
      por_motivo: $s.guard.por_motivo,
      reprovacoes: $s.verify.fail,
      edicoes: $s.atividade.edits,
      desde: $s.telemetria.trilha_desde,
      modo_de_permissao: $s.permissao.modo_predominante }'
}

# --- alvo único ------------------------------------------------------------
# Sem argumento e com trilha aqui, o relatório completo é a resposta certa: é o
# que a pessoa quer ver, e o leitor já sabe imprimi-lo.
if [[ $todos -eq 0 ]]; then
  d="${alvo:-$PWD}"
  d="$(cd "$d" 2>/dev/null && pwd)" || { echo "raiz inexistente: $d" >&2; exit 64; }
  if [[ -f "$d/.harness/harness.json" ]]; then
    if [[ $as_json -eq 1 ]]; then "$leitor" --root "$d" --since "$since" --json
    else "$leitor" --root "$d" --since "$since"; fi
    exit $?
  fi
  [[ -n "$alvo" ]] && { echo "não há harness em $d." >&2; exit 3; }
  # Sem harness aqui: em vez de dizer só "não tem", mostre onde tem.
  echo "Nenhum harness neste diretório. Trilhas encontradas na máquina:"
  echo
  todos=1
fi

# --- a máquina inteira -----------------------------------------------------
mapfile -t repos < <(descobrir)
if [[ ${#repos[@]} -eq 0 ]]; then
  [[ $as_json -eq 1 ]] && { echo '{"repos": []}'; exit 3; }
  echo "nenhum repositório com harness encontrado em $HOME (profundidade 6)." >&2
  echo "harness:install instala; a trilha nasce junto a partir da 0.3.0." >&2
  exit 3
fi

dados=$(for d in "${repos[@]}"; do linha "$d"; done | jq -s 'sort_by(-.eventos)')

if [[ $as_json -eq 1 ]]; then
  jq -n --argjson r "$dados" --arg j "$since" '{janela: $j, repos: $r}'
  exit 0
fi

# Alinhamento por caractere, não por byte: printf conta byte e o acento
# desalinharia a coluna.
pad() { local s="$1" n="$2"; printf '%s' "$s"; local i=$(( n - ${#s} )); ((i > 0)) && printf '%*s' "$i" ''; }
pad "repositório" 42; pad "versão" 9; pad "trilha" 12; pad "eventos" 9; echo "bloqueios"
printf '%s\n' "$(printf '─%.0s' $(seq 1 80))"
jq -r '.[] | [.repo, .versao, .estado, (.eventos|tostring), (.bloqueios|tostring)] | @tsv' <<<"$dados" \
  | while IFS=$'\t' read -r r v e n b; do
      # O caminho longo é cortado pela ESQUERDA: o fim identifica o repositório,
      # o começo é sempre o mesmo /home/fulano/.
      [[ ${#r} -gt 41 ]] && r="…${r: -40}"
      pad "$r" 42; pad "$v" 9; pad "$e" 12; pad "$n" 9; echo "$b"
    done
echo
# A distinção que o relatório inteiro existe para fazer: zero medido não é zero
# desconhecido, e `sem-emissor` é a forma mais silenciosa de zero desconhecido.
n_sem=$(jq '[.[] | select(.estado == "sem-emissor")] | length' <<<"$dados")
if [[ "$n_sem" -gt 0 ]]; then
  echo "  $n_sem repositório(s) com harness anterior à telemetria: nenhum hook"
  echo "  registra nada ali, e 0 evento não quer dizer que nada aconteceu."
  echo "  harness:install de novo liga a trilha sem sobrescrever edição manual."
fi
n_off=$(jq '[.[] | select(.estado == "desligada")] | length' <<<"$dados")
[[ "$n_off" -gt 0 ]] && echo "  $n_off com telemetry.enabled: false — desligada por decisão do projeto."
echo
echo "  Relatório completo de um deles: harness-stats.sh <caminho>"
exit 0
