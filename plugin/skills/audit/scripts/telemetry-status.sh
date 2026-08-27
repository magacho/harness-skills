#!/usr/bin/env bash
# Estado da trilha de telemetria de um repositório. Read-only.
#
#   telemetry-status.sh <repo>  → JSON
#
# NÃO reimplementa a leitura: chama o leitor único (`stats.sh --root`), que é o
# mesmo que o repositório instalado usa. Uma segunda implementação do mesmo `jq`
# divergiria da primeira na primeira correção — foi assim que a varredura de
# arquivo-fonte acabou em três cópias com listas de poda diferentes, e o plano
# passou a acusar god file em `.next/`.
#
# Saída: 0 há trilha com evento · 3 não há o que medir (harness ausente,
# telemetria desligada, ou trilha vazia). Como nos demais scripts do audit,
# **exit 3 é dimensão desconhecida, nunca "nada aconteceu"** (D4 → R10).
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
leitor="$here/../../install/assets/telemetry/stats.sh"
root="${1:-.}"
root="$(cd "$root" 2>/dev/null && pwd)" || { echo "raiz inexistente: ${1:-.}" >&2; exit 64; }

resposta() {  # <estado> <recado>
  jq -n --arg e "$1" --arg r "$2" '{instalada: false, estado: $e, recado: $r}'
}

[[ -x "$leitor" ]] || { resposta sem-leitor "o leitor da trilha não está no plugin"; exit 3; }
[[ -f "$root/.harness/harness.json" ]] && { : ; } || {
  resposta sem-harness "não há harness instalado: telemetria não se aplica"; exit 3; }

bruto=$("$leitor" --root "$root" --since all --json 2>/dev/null) || bruto=""
[[ -n "$bruto" ]] || { resposta erro-de-leitura "a trilha existe mas não pôde ser lida"; exit 3; }

# A versão que instalou o harness decide se a trilha DEVERIA existir. Repositório
# em 0.2.x não tem emissor nenhum, e reportar isso como "trilha vazia" culparia o
# repositório por uma lacuna que é da versão instalada.
inst=$(jq -r '.harness_version // "desconhecida"' "$root/.harness/harness.json")
tem_emissor=false
[[ -f "$root/.harness/log.sh" ]] && tem_emissor=true

saida=$(jq -n --argjson s "$bruto" --arg inst "$inst" --argjson emissor "$tem_emissor" '
  ($s.telemetria) as $t
  | { instalada: $emissor,
      versao_instalada: $inst,
      habilitada: $t.enabled,
      retention_months: $t.retention_months,
      eventos: ($s.guard.deny + $s.guard.allow + $s.verify.execucoes + $s.atividade.edits),
      desde: $t.trilha_desde,
      dias_de_trilha: $t.dias_de_trilha,
      bloqueios: $s.guard.deny,
      bloqueios_por_motivo: $s.guard.por_motivo,
      gate_reprovou: $s.verify.fail,
      gate_por_gate: $s.verify.por_gate,
      anti_loop_liberou: $s.verify.released,
      modo_de_permissao: $s.permissao.modo_predominante,
      allow_efetivo: $s.permissao.allow_efetivo,
      estado: (if $emissor | not then "sem-emissor"
               elif ($t.enabled | not) then "desligada"
               elif ($t.trilha_desde == null) then "vazia"
               else "medindo" end),
      recado: (if $emissor | not
               then "o harness deste repositório foi instalado por uma versão sem telemetria (\($inst)): nenhum hook registra nada, e não há como saber o que os gates pegaram"
               elif ($t.enabled | not)
               then "telemetry.enabled: false — os hooks não emitem. O relatório vazio é configuração, não inatividade"
               elif ($t.trilha_desde == null)
               then "trilha instalada e ligada, ainda sem evento: nada foi medido ainda. Isto NÃO é \"nada foi bloqueado\""
               else "trilha ativa há \($t.dias_de_trilha) dia(s)" end) }')

printf '%s\n' "$saida"

# O código de saída lê o MESMO campo que a saída publica. Recalculá-lo em bash
# daria duas respostas para a mesma pergunta, e elas divergiriam na primeira
# correção — só "medindo" é dimensão conhecida.
[[ "$(jq -r '.estado' <<<"$saida")" == medindo ]] || exit 3
exit 0
