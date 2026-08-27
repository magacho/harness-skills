#!/usr/bin/env bash
# Emissor da trilha de telemetria — SOURCEADO pelos hooks, nunca executado.
# harness-generated: __VERSION__
#
# O harness instala quatro hooks e dois gates. Sem isto, nenhum deixa rastro: o
# dono do repositório não consegue responder "o harness está funcionando?" sem
# arqueologia nos transcripts. Um harness que protege sem registrar não é
# auditável — e um gate desligado por engano fica invisível.
#
# Três regras inegociáveis, e todas as três valem mais que qualquer evento:
#
#   1. NUNCA FALHA E NUNCA BLOQUEIA. Todo caminho é `>/dev/null 2>&1 || true`.
#      Disco cheio, jq ausente, diretório sem permissão — nada disso pode
#      derrubar um hook, muito menos o PreToolUse, que decide permissão. Perder
#      uma linha de log é barato; perder a trava de produção não é.
#   2. NUNCA VAZA SEGREDO. No veredito `allow` grava-se só o primeiro token do
#      comando (o binário), nunca os argumentos, que carregam `API_KEY=...`. Só
#      no `deny` o comando inteiro é gravado, truncado. Conteúdo de arquivo,
#      diff e saída de gate não entram aqui em hipótese alguma.
#   3. NUNCA FALA. Nada em stdout: o PostToolUse é async e o PreToolUse usa
#      stdout como protocolo de decisão. Uma linha solta ali vira erro de parse.
#
# Mora em um arquivo só, sourceado pelos três hooks, para que o schema não
# divergir entre eles seja uma propriedade do desenho e não da disciplina.
#
#   harness_log <ev> [chave=valor ...]
#
# Campos numéricos por convenção do schema: files, ms, try. Os demais são texto.
# Chave com valor vazio é omitida — campo ausente é mais honesto que campo "".

# Milissegundos desde a época. Onde `date` não tem %N (BSD), degrada para
# resolução de segundo em vez de quebrar: o gate de turno leva segundos, e uma
# duração grosseira ainda responde "isto está lento?".
harness_ms() {
  local n
  n=$(date +%s%N 2>/dev/null) || n=""
  case "$n" in
    ''|*[!0-9]*) n=$(( $(date +%s 2>/dev/null || echo 0) * 1000000000 )) ;;
  esac
  echo $(( n / 1000000 ))
}

# Binário do comando: primeiro token, sem argumentos. É o que separa registrar
# atividade de vazar credencial — `psql "postgres://user:senha@host"` vira
# `psql`. Prefixo de ambiente (`FOO=1 cmd`) é pulado justamente porque é onde
# a variável de ambiente com segredo apareceria.
harness_bin() {
  local tok
  for tok in $1; do
    case "$tok" in
      *=*) continue ;;
      *) printf '%s' "${tok##*/}"; return 0 ;;
    esac
  done
  printf ''
}

_harness_log_purga() {  # <dir> <YYYY-MM atual> <meses de retenção>
  local dir="$1" mes="$2" ret="$3" f base y m corte
  [[ "$ret" =~ ^[0-9]+$ ]] && [[ "$ret" -gt 0 ]] || return 0
  corte=$(( (10#${mes%%-*} * 12 + 10#${mes##*-}) - ret + 1 ))
  for f in "$dir"/events-*.jsonl; do
    [[ -e "$f" ]] || continue
    base="${f##*/events-}"; base="${base%.jsonl}"
    y="${base%%-*}"; m="${base##*-}"
    [[ "$y$m" =~ ^[0-9]+$ ]] || continue
    [[ $(( 10#$y * 12 + 10#$m )) -lt $corte ]] && rm -f "$f"
  done
  return 0
}

_harness_log_emit() {
  local ev="${1:-}"; shift 2>/dev/null || true
  [[ -n "$ev" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  local raiz="${HARNESS_ROOT:-${CLAUDE_PROJECT_DIR:-$PWD}}"
  local cfg="$raiz/.harness/harness.json"
  # Sem harness instalado não há trilha: o emissor não cria estado em
  # repositório que não pediu por ele.
  [[ -f "$cfg" ]] || return 0
  # Default explícito: ausente é LIGADO. `telemetry.enabled: false` faz este
  # emissor virar no-op imediato — e o stats.sh diz isso em voz alta em vez de
  # imprimir relatório vazio.
  #
  # `// true` NÃO serve aqui: em jq o `//` trata `false` como vazio, então
  # `false // true` devolve `true` e a chave que desliga a telemetria seria lida
  # como se a ligasse. O teste tem de ser de igualdade contra `false`.
  [[ "$(jq -r 'if .telemetry.enabled == false then "off" else "on" end' "$cfg" 2>/dev/null)" == off ]] && return 0

  local dir="$raiz/.harness/log" mes arq
  mes=$(date -u +%Y-%m) || return 0
  arq="$dir/events-$mes.jsonl"
  # mkdir no emissor, não na instalação: repositório clonado não traz diretório
  # vazio, e o primeiro hook a rodar não pode depender de ter havido instalação
  # nesta máquina. A rotação é pelo nome do arquivo, e a retenção é aplicada só
  # quando o mês vira — uma vez por mês, não a cada evento.
  if [[ ! -e "$arq" ]]; then
    mkdir -p "$dir" || return 0
    _harness_log_purga "$dir" "$mes" "$(jq -r '.telemetry.retention_months // 6' "$cfg" 2>/dev/null)"
  fi

  local args=() filtro='{ts: $ts, sid: $sid, ev: $ev}' kv k v
  args+=(-c -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
         --arg sid "${HARNESS_SID:-sem-sessao}" --arg ev "$ev")
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    [[ "$k" == "$kv" || -z "$k" || -z "$v" ]] && continue
    case "$k" in
      files|ms|try)
        [[ "$v" =~ ^-?[0-9]+$ ]] || continue
        args+=(--argjson "$k" "$v") ;;
      subject)
        # Truncagem no emissor, não no chamador: é a regra nº 2, e regra de
        # vazamento que depende de cada call site lembrar já vazou.
        args+=(--arg "$k" "${v:0:200}") ;;
      *) args+=(--arg "$k" "$v") ;;
    esac
    filtro="$filtro + {$k: \$$k}"
  done
  jq "${args[@]}" "$filtro" >> "$arq"
}

# A casca que torna a regra nº 1 estrutural: o corpo inteiro é silenciado e o
# status é sempre 0. Nenhum hook precisa lembrar de proteger a chamada.
harness_log() { { _harness_log_emit "$@"; } >/dev/null 2>&1 || true; return 0; }
