#!/usr/bin/env bash
# Leitor da trilha de telemetria. READ-ONLY: não escreve um byte, em lugar
# nenhum. Gerado por harness:install.
# harness-generated: __VERSION__
#
# Responde "o harness está funcionando?" sem arqueologia. A ordem das seções é
# a ordem das perguntas do dono do repositório, e a primeira é sempre a mesma:
# o que ele impediu?
#
#   ./.harness/stats.sh                 resumo humano dos últimos 30 dias
#   ./.harness/stats.sh --since 7d      janela: 7d, 30d, all, ou YYYY-MM-DD
#   ./.harness/stats.sh --json          o mesmo conteúdo, legível por máquina
#   ./.harness/stats.sh --denies        só os bloqueios, um por linha
#   ./.harness/stats.sh --root <dir>    lê a trilha de OUTRO repositório
#
# `--root` existe para que ninguém reimplemente esta leitura. O relatório do
# harness:audit e o comando /harness:stats precisam ler a trilha de um
# repositório qualquer, e a alternativa seria uma segunda implementação do mesmo
# jq — que divergiria da primeira na primeira correção. Mesma razão pela qual o
# gate de tamanho expõe `--measure --root`.
#
# REGRA DE HONESTIDADE, que vale para toda a saída: zero nunca é impresso sem
# o tamanho da trilha ao lado. `0 bloqueios` com 30 dias de trilha é um fato
# sobre o repositório; `0 bloqueios` com trilha de ontem é ausência de dado, e
# confundir os dois é como um gate desligado passa por gate que nunca precisou
# reprovar.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"

since="30d"; as_json=0; only_denies=0; opt_root=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) since="${2:-30d}"; shift 2 ;;
    --json) as_json=1; shift ;;
    --denies) only_denies=1; shift ;;
    --root) opt_root="${2:-}"; shift 2 ;;
    # O cabeçalho inteiro, lido pelo conteúdo e não por número de linha: a marca
    # de versão que a instalação insere desloca as linhas, e o --help passava a
    # imprimir uma linha de código no fim. O padrão é escrito partido de
    # propósito — o gerador REMOVE toda linha que contenha a marca literal, e
    # este arquivo sairia da instalação com o awk pela metade.
    -h|--help) awk 'NR > 1 && /^#/ { if (!/harness-gen/) { sub(/^# ?/, ""); print } next }
                    NR > 1 { exit }' "$0"; exit 0 ;;
    *) echo "argumento desconhecido: $1" >&2; exit 64 ;;
  esac
done

if [[ -n "$opt_root" ]]; then
  root="$(cd "$opt_root" 2>/dev/null && pwd)" \
    || { echo "stats: raiz inexistente: $opt_root" >&2; exit 64; }
fi
cfg="$root/.harness/harness.json"
logdir="$root/.harness/log"

command -v jq >/dev/null 2>&1 || { echo "stats: jq é necessário." >&2; exit 3; }
[[ -f "$cfg" ]] || { echo "stats: $cfg ausente — o harness não está instalado aqui." >&2; exit 3; }

# --- janela ----------------------------------------------------------------
dias_atras() {
  date -u -d "$1 days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -v-"$1"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null
}
janela_dias=0
case "$since" in
  all) corte=""; rotulo="toda a trilha" ;;
  *d)  janela_dias="${since%d}"
       [[ "$janela_dias" =~ ^[0-9]+$ ]] || { echo "stats: janela inválida: $since" >&2; exit 64; }
       corte=$(dias_atras "$janela_dias"); rotulo="últimos $janela_dias dias" ;;
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
       corte="${since}T00:00:00Z"; rotulo="desde $since"
       # A janela em dias também é calculada aqui: é ela que decide se a trilha
       # cobre o período pedido, e sem isso uma data virava janela de tamanho
       # zero — que "cobre" qualquer trilha, inclusive a criada há um minuto.
       ini_janela=$(date -u -d "$corte" +%s 2>/dev/null \
         || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$corte" +%s 2>/dev/null || echo 0)
       [[ "$ini_janela" -gt 0 ]] \
         && janela_dias=$(( ( $(date -u +%s) - ini_janela ) / 86400 )) ;;
  *) echo "stats: janela inválida: $since (use 7d, 30d, all ou YYYY-MM-DD)" >&2; exit 64 ;;
esac
agora=$(date -u +%s)

telemetria=$(jq -c '{enabled: (.telemetry.enabled != false),
                     retention_months: (.telemetry.retention_months // 6)}' "$cfg")

# --- a trilha --------------------------------------------------------------
# Linha malformada é PULADA, não fatal: o arquivo é append de vários processos
# e uma escrita interrompida não pode cegar o relatório inteiro.
eventos='{"eventos":0}'
arquivos=$(find "$logdir" -maxdepth 1 -name 'events-*.jsonl' 2>/dev/null | sort)
if [[ -n "$arquivos" ]]; then
  # shellcheck disable=SC2086
  eventos=$(jq -R -n --arg cut "$corte" '
    [inputs | fromjson? | select(type == "object" and (.ts | type) == "string")] as $todos
    | (if $cut == "" then $todos else ($todos | map(select(.ts >= $cut))) end) as $e
    | ($e | map(select(.ev == "guard" and .verdict == "deny"))) as $deny
    | ($e | map(select(.ev == "guard" and .verdict == "allow"))) as $allow
    | ($e | map(select(.ev == "verify"))) as $v
    | ($e | map(select(.ev == "edit"))) as $ed
    | ($v | map(select(.verdict == "pass" or .verdict == "fail"))
          | map(.ms) | map(numbers) | sort) as $ms
    | { eventos: ($e | length),
        trilha_toda: ($todos | length),
        primeiro: ($e | map(.ts) | min),
        ultimo: ($e | map(.ts) | max),
        primeiro_absoluto: ($todos | map(.ts) | min),
        guard: {
          deny: ($deny | length),
          por_motivo: ($deny | group_by(.reason // "sem-rotulo")
                       | map({key: (.[0].reason // "sem-rotulo"), value: length})
                       | from_entries),
          lista: ($deny | sort_by(.ts) | reverse
                  | map({ts, reason: (.reason // "sem-rotulo"), subject: (.subject // "")})),
          allow: ($allow | length),
          binarios: ($allow | map(select(.subject != null)) | group_by(.subject)
                     | map({bin: .[0].subject, n: length}) | sort_by(-.n) | .[0:5]) },
        verify: {
          execucoes: ($v | length),
          pass: ($v | map(select(.verdict == "pass")) | length),
          fail: ($v | map(select(.verdict == "fail")) | length),
          skip: ($v | map(select(.verdict == "skip")) | length),
          released: ($v | map(select(.verdict == "released")) | length),
          por_gate: ($v | map(select(.verdict == "fail")) | group_by(.gate // "sem-nome")
                     | map({key: (.[0].gate // "sem-nome"), value: length}) | from_entries),
          ms_mediana: (if ($ms | length) == 0 then null
                       else $ms[(($ms | length) / 2 | floor)] end) },
        atividade: {
          edits: ($ed | length),
          distintos: ($ed | map(.path) | unique | length),
          sessoes: ($e | map(.sid) | unique | length),
          arquivos: ($ed | map(select(.path != null)) | group_by(.path)
                     | map({path: .[0].path, n: length}) | sort_by(-.n) | .[0:5]) } }' \
    $arquivos 2>/dev/null) || eventos='{"eventos":0}'
fi
[[ -n "$eventos" ]] || eventos='{"eventos":0}'

trilha_desde=$(jq -r '.primeiro_absoluto // empty' <<<"$eventos")
dias_de_trilha=null
if [[ -n "$trilha_desde" ]]; then
  ini=$(date -u -d "$trilha_desde" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$trilha_desde" +%s 2>/dev/null || echo "$agora")
  dias_de_trilha=$(( (agora - ini) / 86400 ))
fi
# A trilha cobre a janela pedida? É o que separa "nunca disparou" de "não há
# dado", e o que decide se a fonte secundária entra.
cobre=true
[[ -z "$trilha_desde" ]] && cobre=false
[[ "$dias_de_trilha" != null && $janela_dias -gt 0 && $dias_de_trilha -lt $((janela_dias - 1)) ]] && cobre=false
[[ "$since" == all && -z "$trilha_desde" ]] && cobre=false

# --- estado da catraca -----------------------------------------------------
# Catraca que não encolhe há muito tempo é dívida parada — o número congelado
# fez o seu trabalho (a decadência parou) e ninguém voltou para pagá-la.
peso() { jq -c 'if type == "array" then [length, length]
                else [length, ([.[] | numbers] | add // 0)] end' 2>/dev/null; }

catraca() {  # <caminho relativo>
  local rel="$1" abs="$root/$1" n=null dias=null desde="" versionado=false rev ats a b
  [[ -f "$abs" ]] || { jq -n --arg f "$rel" '{arquivo: $f, existe: false}'; return; }
  n=$(jq 'length' "$abs" 2>/dev/null || echo null)
  if git -C "$root" rev-parse --show-toplevel >/dev/null 2>&1 \
     && [[ -n "$(git -C "$root" log -1 --format=%H -- "$rel" 2>/dev/null)" ]]; then
    versionado=true
    while read -r rev ats; do
      a=$(git -C "$root" show "$rev:$rel" 2>/dev/null | peso)
      b=$(git -C "$root" show "$rev^:$rel" 2>/dev/null | peso)
      [[ -n "$a" && -n "$b" ]] || continue
      if jq -n -e --argjson a "$a" --argjson b "$b" '$a < $b' >/dev/null 2>&1; then
        desde="encolheu"; dias=$(( (agora - ats) / 86400 )); break
      fi
    done < <(git -C "$root" log -n 50 --format='%H %at' -- "$rel" 2>/dev/null)
    if [[ -z "$desde" ]]; then
      # Nunca encolheu na janela de histórico lida: a idade que importa passa a
      # ser desde quando o arquivo existe. Dizer "0 dias" aqui seria mentir na
      # direção confortável.
      desde="nunca"
      ats=$(git -C "$root" log --format=%at --reverse -- "$rel" 2>/dev/null | head -1)
      [[ -n "$ats" ]] && dias=$(( (agora - ats) / 86400 ))
    fi
  fi
  jq -n --arg f "$rel" --argjson n "${n:-null}" --argjson d "${dias:-null}" \
        --arg desde "$desde" --argjson ver "$versionado" \
    '{arquivo: $f, existe: true, entradas: $n, dias: $d,
      encolhimento: (if $desde == "" then "sem-historico" else $desde end), versionado: $ver}'
}
catracas=$(jq -n --argjson b "$(catraca .harness/baseline.json)" \
                 --argjson s "$(catraca .harness/baseline-size.json)" \
                 '{fronteira: $b, tamanho: $s}')

# --- cobertura -------------------------------------------------------------
# Gate ausente aparece como LACUNA, não como silêncio. Um `formatter: null` ou
# um `lint` que nunca foi ligado é informação; a ausência dele no relatório é
# como o gate desligado por engano fica invisível por mais um trimestre.
cobertura=$(jq -c '
  def estado($g; $k): if ($g | has($k) | not) then "ausente"
                      elif ($g[$k] == null or $g[$k] == false) then "desligado"
                      else "ligado" end;
  (.gates // {}) as $g
  | ([ "boundaries", "size", "lint", "typecheck" ] | map({nome: ., estado: estado($g; .)}))
    + [{nome: "formatter", estado: (if (.formatter // null) == null then "desligado" else "ligado" end)}]
  | {ligados: [.[] | select(.estado == "ligado") | .nome],
     lacunas: [.[] | select(.estado != "ligado") | "\(.nome) (\(.estado))"]}' "$cfg")

# --- fonte secundária: os transcripts do Claude Code -----------------------
# Só o hook Stop deixa registro lá, e nada do guard-prod. Serve para dar
# histórico no dia zero — e é rotulada como RECONSTRUÍDA, nunca como medida.
# É também a única fonte do modo de permissão, que não passa por hook nenhum.
slug=$(printf '%s' "$root" | sed 's/[^A-Za-z0-9]/-/g')
tdir="$HOME/.claude/projects/$slug"
transcripts='{"disponivel":false}'
if [[ -d "$tdir" ]]; then
  tfiles=$(find "$tdir" -maxdepth 1 -name '*.jsonl' 2>/dev/null | sort)
  if [[ -n "$tfiles" ]]; then
    # shellcheck disable=SC2086
    transcripts=$(jq -R -n --arg cut "$corte" '
      [inputs | fromjson? | select(type == "object")] as $r
      | ($r | map(select(.subtype == "stop_hook_summary"))
            | (if $cut == "" then . else map(select((.timestamp // "") >= $cut)) end)) as $s
      | ($s | map((.hookInfos // [])[] | .durationMs) | map(numbers) | sort) as $ms
      | ($r | map(select(.type == "permission-mode" and .permissionMode != null))) as $p
      | { disponivel: true,
          stop_hooks: ($s | length),
          bloqueios: ($s | map(select(.preventedContinuation == true)) | length),
          erros: ($s | map((.hookErrors // []) | length) | add // 0),
          ms_mediana: (if ($ms | length) == 0 then null
                       else $ms[(($ms | length) / 2 | floor)] end),
          modos: ($p | group_by(.permissionMode)
                  | map({key: .[0].permissionMode,
                         value: (map(.sessionId // .session_id // "?") | unique | length)})
                  | from_entries) }' $tfiles 2>/dev/null) || transcripts='{"disponivel":false}'
  fi
fi
[[ -n "$transcripts" ]] || transcripts='{"disponivel":false}'

modo_predominante=$(jq -r '.modos // {} | to_entries | sort_by(-.value) | .[0].key // empty' <<<"$transcripts")

# --- consolidação ----------------------------------------------------------
saida=$(jq -n \
  --arg repo "$(basename "$root")" --arg rotulo "$rotulo" --arg desde "$corte" \
  --argjson janela_dias "$janela_dias" \
  --argjson tel "$telemetria" --argjson ev "$eventos" --argjson cat "$catracas" \
  --argjson cob "$cobertura" --argjson tr "$transcripts" \
  --arg trilha_desde "$trilha_desde" --argjson dias_de_trilha "${dias_de_trilha:-null}" \
  --argjson cobre "$cobre" --arg modo "$modo_predominante" '
  { repo: $repo,
    janela: {rotulo: $rotulo, desde: (if $desde == "" then null else $desde end), dias: $janela_dias},
    telemetria: ($tel + {trilha_desde: (if $trilha_desde == "" then null else $trilha_desde end),
                         dias_de_trilha: $dias_de_trilha,
                         cobre_a_janela: $cobre}),
    guard: ($ev.guard // {deny: 0, por_motivo: {}, lista: [], allow: 0, binarios: []}),
    verify: ($ev.verify // {execucoes: 0, pass: 0, fail: 0, skip: 0, released: 0, por_gate: {}, ms_mediana: null}),
    catraca: $cat,
    cobertura: $cob,
    atividade: ($ev.atividade // {edits: 0, distintos: 0, sessoes: 0, arquivos: []}),
    permissao: {modo_predominante: (if $modo == "" then null else $modo end),
                modos: ($tr.modos // {}),
                # null, não true: sem transcript não se sabe, e "o allow vale"
                # é justamente a afirmação que não pode ser assumida.
                allow_efetivo: (if $modo == "" then null else ($modo != "bypassPermissions") end)},
    reconstruido: ($tr + {usado: (($cobre | not) and ($tr.disponivel == true))}) }')

# --- saídas de máquina -----------------------------------------------------
if [[ $only_denies -eq 1 ]]; then
  n=$(jq '.guard.deny' <<<"$saida")
  if [[ "$n" -eq 0 ]]; then
    echo "nenhum bloqueio na janela ($rotulo)." >&2
    jq -r '.telemetria | if .trilha_desde == null then "não há trilha: nenhum evento registrado ainda."
           else "trilha desde \(.trilha_desde) (\(.dias_de_trilha) dia(s))." end' <<<"$saida" >&2
    exit 0
  fi
  jq -r '.guard.lista[] | "\(.ts)  \(.reason)  \(.subject)"' <<<"$saida"
  exit 0
fi
if [[ $as_json -eq 1 ]]; then jq . <<<"$saida"; exit 0; fi

# --- relatório humano ------------------------------------------------------
if [[ "$(jq -r '.telemetria.enabled' <<<"$saida")" == false ]]; then
  echo "TELEMETRIA DESLIGADA neste repositório (.harness/harness.json →"
  echo "telemetry.enabled: false). Os hooks não emitem evento algum, e este"
  echo "relatório seria vazio por configuração, não por inatividade."
  echo "Para ligar: mude a chave para true. Nada mais precisa ser reinstalado."
  exit 0
fi

sec() { printf '\n%s %s\n' "$1" "$(printf '─%.0s' $(seq 1 $((66 - ${#1}))))"; }
dur() { # ms → texto
  local ms="$1"
  [[ "$ms" == null || -z "$ms" ]] && { printf 'sem medição'; return; }
  if [[ "$ms" -ge 1000 ]]; then printf '%d,%d s' $((ms / 1000)) $(((ms % 1000) / 100))
  else printf '%d ms' "$ms"; fi
}

printf 'harness:stats — %s · janela: %s\n' \
  "$(jq -r .repo <<<"$saida")" "$(jq -r .janela.rotulo <<<"$saida")"
jq -r '.telemetria | if .trilha_desde == null
  then "trilha: VAZIA — nenhum evento registrado em .harness/log/ ainda."
  else "trilha: \(.dias_de_trilha) dia(s), desde \(.trilha_desde)"
       + (if .cobre_a_janela then "" else " — MAIS CURTA que a janela pedida" end)
  end' <<<"$saida"

sec "1. BLOQUEIOS DO guard-prod"
n_deny=$(jq -r '.guard.deny' <<<"$saida")
if [[ "$n_deny" -gt 0 ]]; then
  echo "   $n_deny bloqueio(s). Por motivo:"
  jq -r '.guard.por_motivo | to_entries | sort_by(-.value)[] | "     \(.key)  \(.value)"' <<<"$saida"
  echo "   Os mais recentes:"
  jq -r '.guard.lista[0:5][] | "     \(.ts[0:16] | sub("T"; " "))  \(.reason)  \(.subject)"' <<<"$saida"
else
  jq -r '.telemetria | if .trilha_desde == null
    then "   sem dado: a trilha está vazia. Isto NÃO é \"nada foi bloqueado\"."
    elif .cobre_a_janela then "   0 bloqueios — e a trilha cobre a janela inteira. É um fato sobre\n   o repositório, não ausência de dado."
    else "   0 bloqueios, mas a trilha tem só \(.dias_de_trilha) dia(s): não há dado sobre o\n   resto da janela. Zero aqui ainda não quer dizer nada." end' <<<"$saida"
fi

sec "2. GATE DE TURNO"
jq -r '.verify | if .execucoes == 0 then "   nenhuma execução registrada na janela."
  else "   \(.execucoes) execução(ões): \(.pass) passaram, \(.fail) reprovaram, "
       + "\(.skip) saíram cedo (escopo vazio), \(.released) liberada(s) pelo anti-loop."
  end' <<<"$saida"
[[ "$(jq -r '.verify.fail' <<<"$saida")" -gt 0 ]] && {
  echo "   Reprovaram por gate:"
  jq -r '.verify.por_gate | to_entries | sort_by(-.value)[] | "     \(.key)  \(.value)"' <<<"$saida"; }
[[ "$(jq -r '.verify.execucoes' <<<"$saida")" -gt 0 ]] && \
  echo "   Duração mediana das execuções completas: $(dur "$(jq -r '.verify.ms_mediana' <<<"$saida")")"
[[ "$(jq -r '.verify.released' <<<"$saida")" -gt 0 ]] && {
  echo "   O anti-loop liberou código que não passou no gate. Se isso é rotina"
  echo "   aqui, algum gate está reprovando trabalho legítimo — modo de fracasso nº 1."; }
if [[ "$(jq -r '.reconstruido.usado' <<<"$saida")" == true ]]; then
  jq -r '.reconstruido | "   RECONSTRUÍDO dos transcripts, não medido: \(.stop_hooks) execução(ões) do\n   hook Stop, \(.bloqueios) bloqueio(s), \(.erros) erro(s) de hook."' <<<"$saida"
  echo "   Fonte: ~/.claude/projects/$slug/*.jsonl"
  echo "   Só o hook Stop deixa rastro lá — guard-prod e on-edit são invisíveis"
  echo "   nessa fonte. A partir de agora a trilha mede em vez de reconstruir."
fi

sec "3. ESTADO DA CATRACA"
jq -r '.catraca | to_entries[] | .key as $k | .value |
  if .existe | not then "   \($k): baseline ausente — a catraca não foi gerada (fase 2)."
  else "   \($k): \(.entradas) entrada(s)"
       + (if .entradas == 0 then " — tolerância zero: qualquer violação nova reprova" else "" end)
       + (if .versionado | not then "; não versionado, sem histórico de encolhimento"
          elif .encolhimento == "nunca" then "; NUNCA encolheu em \(.dias) dia(s) — dívida parada"
          elif .dias == null then ""
          else "; encolheu pela última vez há \(.dias) dia(s)" end)
  end' <<<"$saida"

sec "4. COBERTURA"
jq -r '.cobertura | "   ligados: " + (if (.ligados | length) == 0 then "nenhum" else (.ligados | join(", ")) end)' <<<"$saida"
jq -r '.cobertura | "   lacunas: " + (if (.lacunas | length) == 0 then "nenhuma" else (.lacunas | join(", ")) end)' <<<"$saida"

sec "5. ATIVIDADE"
jq -r '.atividade | if .edits == 0 then "   nenhuma edição registrada na janela."
  else "   \(.edits) edição(ões) em \(.distintos) arquivo(s), \(.sessoes) sessão(ões)." end' <<<"$saida"
jq -r '.atividade.arquivos[]? | "     \(.n)×  \(.path)"' <<<"$saida"

sec "6. MODO DE PERMISSÃO"
if [[ "$(jq -r '.reconstruido.disponivel' <<<"$saida")" != true ]]; then
  echo "   sem dado: não há transcripts para este repositório em ~/.claude/projects/."
else
  jq -r '.permissao.modos | to_entries | sort_by(-.value)[] | "     \(.key)  \(.value) sessão(ões)"' <<<"$saida"
  if [[ "$(jq -r '.permissao.allow_efetivo' <<<"$saida")" == false ]]; then
    echo
    echo "   ATENÇÃO: o modo predominante é bypassPermissions. Nele o bloco"
    echo "   permissions.allow do .claude/settings.json não tem efeito algum —"
    echo "   só as negações são honradas. Metade da configuração de permissão"
    echo "   que a instalação escreveu é decoração enquanto isso durar, e a"
    echo "   dupla trava de produção passa a depender só do hook (A2 → R5)."
  fi
fi
echo
exit 0
