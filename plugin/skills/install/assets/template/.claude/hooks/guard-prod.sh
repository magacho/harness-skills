#!/bin/bash
# PreToolUse — última linha de defesa contra escrita em produção.
# Permissões já negam o óbvio; isto pega a variação criativa.
input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",
    permissionDecision:"deny", permissionDecisionReason:$r}}'
  exit 0
}

# deploy em prd
grep -qE 'deploy\.sh[[:space:]]+(prd|prod|production)' <<<"$cmd" \
  && deny "Deploy em produção é operação humana. Use ./ops/deploy.sh stg."

# qualquer coisa com credencial/host de prod que não seja leitura
if grep -qE '(--profile[[:space:]]+prd|PRD_|prod-cluster|\.prd\.)' <<<"$cmd"; then
  grep -qE '\b(describe|get|list|logs|tail|head|status|filter-log-events)\b' <<<"$cmd" \
    || deny "Comando toca produção e não é leitura. Prod é read-only: use ./ops/investigate.sh prd."
fi

# DDL/DML destrutivo em qualquer ambiente
grep -qiE '\b(drop|truncate)[[:space:]]+(table|database|schema)' <<<"$cmd" \
  && deny "DROP/TRUNCATE bloqueado. Crie uma migration."

exit 0
