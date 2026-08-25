#!/usr/bin/env bash
# PreToolUse — última linha de defesa contra escrita em produção.
# harness-generated: __VERSION__
#
# A2 → R5: dupla trava. A permissão em .claude/settings.json cobre o padrão
# óbvio; este hook cobre a variação criativa. Nenhum dos dois sozinho basta —
# e o teto de autonomia nunca depende deste arquivo (P2/A8), porque uma flag de
# execução desliga hook.
input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")

# A4 → R1: recusa que ensina. Diga o que fazer em vez disso.
deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",
    permissionDecision:"deny", permissionDecisionReason:$r}}'
  exit 0
}

grep -qE '(deploy|release|publish)[^|;&]*\b(prd|prod|production)\b' <<<"$cmd" \
  && deny "Deploy em produção é operação humana. Escreva o plano de release — o que muda, blast radius, rollback, migrations — e entregue ao responsável."

if grep -qE '(--profile[[:space:]]+(prd|prod)|PRD_|prod-cluster|\.prd\.|--context[[:space:]]+[^ ]*prod)' <<<"$cmd"; then
  grep -qE '\b(describe|get|list|logs|tail|head|status|show|cat|filter-log-events)\b' <<<"$cmd" \
    || deny "Comando toca produção e não é leitura. Produção é read-only para você: investigue à vontade, altere nada."
fi

grep -qiE '\b(drop|truncate)[[:space:]]+(table|database|schema)' <<<"$cmd" \
  && deny "DROP/TRUNCATE bloqueado em qualquer ambiente. Crie uma migration."

exit 0
