#!/usr/bin/env bash
# Instrumentação CIRÚRGICA de hook editado à mão.
#
#   instrument-hook.sh <repo> <guard-prod|verify|on-edit>  → JSON
#
# Quando o sha do cabeçalho `harness-generated:` bate, o gen-config reescreve o
# hook inteiro e este script não é chamado. Quando NÃO bate, o arquivo foi
# editado depois de gerado — e é comum: `guard-prod.sh` é onde as regras
# específicas do projeto são acrescentadas ao fim. Sobrescrever para ganhar
# estatística seria trocar uma regra `deny` escrita à mão por um número, que é
# um péssimo negócio (D3 → R10).
#
# Então aqui a telemetria é ENXERTADA, e a técnica é a mesma nos três hooks:
# inserir um bloco logo depois da definição da função que interessa, e
# REDEFINIR essa função capturando a original com `declare -f`. O bloco não
# conhece o corpo da função, não conhece as regras locais, e não move uma linha
# do que já estava lá — é a única forma de instrumentar sem ler a intenção de
# quem editou.
#
# Saída: {hook, acao, detalhe}. `acao` ∈ instrumentado · ja-instrumentado ·
# nao-instrumentado (com o motivo em `detalhe` — declarado, nunca silenciado).
set -uo pipefail

root="$(cd "${1:?uso: instrument-hook.sh <repo> <hook>}" && pwd)"
hook="${2:?uso: instrument-hook.sh <repo> <guard-prod|verify|on-edit>}"
alvo="$root/.claude/hooks/$hook.sh"
MARCA='# harness-telemetry:'

relata() { jq -n --arg h "$hook" --arg a "$1" --arg d "${2:-}" \
  '{hook: ("\($h).sh"), acao: $a, detalhe: $d}'; exit 0; }

[[ -f "$alvo" ]] || relata nao-instrumentado "o hook não existe neste repositório"
# A guarda é por `harness_log`, não pela marca do enxerto. Um hook GERADO por uma
# versão recente já emite eventos por dentro, e depois pode ter sido editado à
# mão — chegando aqui pelo caminho do sha divergente. Procurar só a marca do
# enxerto enxertaria uma segunda camada sobre a primeira, e cada deny entraria
# duas vezes na trilha: a estatística ficaria com o dobro do que aconteceu.
grep -q 'harness_log' "$alvo" \
  && relata ja-instrumentado "o hook já emite eventos; nada a enxertar"

# O preâmbulo comum: raiz, sessão e o source tolerante. Sem `harness_log`
# definido, tudo o que vem depois vira no-op — o hook editado à mão continua
# funcionando idêntico se `.harness/log.sh` sumir.
preambulo() {
  cat <<'P'
# harness-telemetry: enxertado por harness:install em hook editado à mão.
# O bloco não altera nenhuma regra deste arquivo: captura a função original com
# `declare -f` e a chama. Remover este bloco desliga a trilha e nada mais.
HARNESS_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
HARNESS_SID=$(jq -r '.session_id // "sem-sessao"' <<<"${input:-}" 2>/dev/null || echo sem-sessao)
export HARNESS_ROOT HARNESS_SID
# shellcheck source=/dev/null
source "$HARNESS_ROOT/.harness/log.sh" 2>/dev/null || true
if ! type harness_log >/dev/null 2>&1; then harness_log() { :; }; harness_bin() { :; }; harness_ms() { echo 0; }; fi
P
}

# Insere um bloco DEPOIS da linha que fecha a definição de <func>. A função tem
# de estar definida antes: `declare -f` lê o que já existe no shell.
inserir_apos_funcao() {  # <func> <arquivo-com-o-bloco>
  local func="$1" bloco="$2"
  awk -v f="$func" -v b="$bloco" '
    function despejar(   linha) {
      while ((getline linha < b) > 0) print linha
      close(b)
    }
    BEGIN { dentro = 0; feito = 0 }
    { print }
    !feito && dentro == 0 && $0 ~ ("^" f "\\(\\) *\\{") {
      # Definição em uma linha só — `fail() { ...; exit 2; }` — é forma comum em
      # hook editado à mão, e sem este ramo ela não casava com nada e a
      # instrumentação era recusada por um motivo que soava como defeito.
      if ($0 ~ /\}[[:space:]]*$/) { feito = 1; despejar(); next }
      dentro = 1; next
    }
    dentro == 1 && $0 ~ /^\}[[:space:]]*$/ { dentro = 0; feito = 1; despejar() }
    END { exit(feito ? 0 : 1) }' "$alvo" > "$alvo.tmp"
}

tmp_bloco=$(mktemp); tmp_out=""
trap 'rm -f "$tmp_bloco" "$alvo.tmp"' EXIT

case "$hook" in
  guard-prod)
    grep -qE '^deny\(\) *\{' "$alvo" \
      || relata nao-instrumentado "não há função deny() reconhecível; as regras locais foram preservadas e a trilha do guard não foi ligada"
    { preambulo
      cat <<'B'
if type harness_log >/dev/null 2>&1; then
  # Captura a deny() deste repositório, com as regras locais que ela serve, e a
  # chama depois de registrar. O rótulo do motivo não existe em hook editado à
  # mão (a assinatura antiga tem um argumento só): fica `nao-rotulado`, e é
  # melhor que inventar categoria a partir do texto da recusa.
  eval "_harness_deny_original() $(declare -f deny | tail -n +2)"
  deny() {
    _harness_negou=1
    if [[ $# -ge 2 ]]; then harness_log guard verdict=deny subject="${cmd:-}" reason="$1"
    else harness_log guard verdict=deny subject="${cmd:-}" reason=nao-rotulado; fi
    _harness_deny_original "$@"
  }
  # O allow é o caminho em que o hook simplesmente termina — e ele termina em
  # muitos lugares num arquivo editado à mão. O trap pega todos de uma vez, e a
  # trava `_harness_negou` evita registrar allow logo depois de um deny.
  trap '[[ ${_harness_negou:-0} -eq 1 ]] || harness_log guard verdict=allow subject="$(harness_bin "${cmd:-}")"' EXIT
fi
B
    } > "$tmp_bloco"
    inserir_apos_funcao deny "$tmp_bloco" \
      || relata nao-instrumentado "a função deny() não fecha em uma linha '}' isolada; nada foi alterado"
    tmp_out="$alvo.tmp"
    detalhe="deny() envolvida e allow registrado na saída; regras locais intactas. Sem rótulo de motivo: a assinatura antiga não o carrega"
    ;;

  verify)
    grep -qE '^fail\(\) *\{' "$alvo" \
      || relata nao-instrumentado "não há função fail() reconhecível; o gate continua igual e a trilha do turno não foi ligada"
    { preambulo
      cat <<'B'
if type harness_log >/dev/null 2>&1; then
  _harness_t0=$(harness_ms)
  _harness_arquivos=$(wc -l < "${scope:-/dev/null}" 2>/dev/null | tr -d ' ')
  eval "_harness_fail_original() $(declare -f fail | tail -n +2)"
  fail() {
    _harness_reprovou=1
    harness_log verify verdict=fail gate="$([[ $# -ge 2 ]] && echo "$1" || echo sem-nome)" \
      files="${_harness_arquivos:-0}" ms=$(( $(harness_ms) - _harness_t0 ))
    _harness_fail_original "$@"
  }
  # Em hook editado à mão o veredito de saída é pass ou fail e nada mais: skip
  # (escopo vazio) e released (anti-loop) nascem de linhas espalhadas que este
  # bloco não pode identificar sem ler a intenção de quem editou. A trilha diz
  # `sem-granularidade` em vez de chutar — contar um skip como pass inflaria
  # justamente o número que o dono usa para dizer que o gate está funcionando.
  trap '[[ ${_harness_reprovou:-0} -eq 1 ]] || harness_log verify verdict=pass \
     reason=sem-granularidade files="${_harness_arquivos:-0}" ms=$(( $(harness_ms) - _harness_t0 ))' EXIT
fi
B
    } > "$tmp_bloco"
    inserir_apos_funcao fail "$tmp_bloco" \
      || relata nao-instrumentado "a função fail() não fecha em uma linha '}' isolada; nada foi alterado"
    tmp_out="$alvo.tmp"
    detalhe="fail() envolvida e pass registrado na saída. skip e released não são distinguidos: a trilha os marca sem-granularidade em vez de chutar"
    ;;

  on-edit)
    linha=$(grep -nE 'cc-touched-' "$alvo" | grep -c '>>' || true)
    [[ "$linha" -gt 0 ]] \
      || relata nao-instrumentado "não há o append em /tmp/cc-touched-*; o hook não segue mais o formato instrumentável"
    { echo
      preambulo
      echo 'harness_log edit path="${path#"${CLAUDE_PROJECT_DIR:-$PWD}"/}"'
    } > "$tmp_bloco"
    # Aqui não há função a envolver: o evento é o próprio append, e o bloco
    # entra logo depois dele.
    awk -v b="$tmp_bloco" '
      { print }
      !feito && /cc-touched-/ && />>/ {
        feito = 1
        while ((getline linha < b) > 0) print linha
        close(b)
      }
      END { exit(feito ? 0 : 1) }' "$alvo" > "$alvo.tmp" \
      || relata nao-instrumentado "o append em /tmp/cc-touched-* não pôde ser localizado"
    tmp_out="$alvo.tmp"
    detalhe="evento de edição registrado junto do append que já existia"
    ;;

  *) relata nao-instrumentado "hook desconhecido: $hook" ;;
esac

# Só troca o arquivo se o resultado ainda for bash válido. Hook quebrado é pior
# que hook sem telemetria: o PreToolUse que não parseia deixa de decidir.
bash -n "$tmp_out" 2>/dev/null \
  || relata nao-instrumentado "o enxerto não produziu bash válido; o arquivo original foi mantido intacto"
cat "$tmp_out" > "$alvo"
relata instrumentado "$detalhe"
