#!/bin/bash
# PostToolUse — roda em toda edição: nunca fala, nunca bloqueia.
input=$(cat)
sid=$(jq -r '.session_id' <<<"$input")
aid=$(jq -r '.agent_id // "main"' <<<"$input")
path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
[[ -n "$path" && -f "$path" ]] || exit 0

echo "$path" >> "/tmp/cc-touched-$sid-$aid.txt"

case "$path" in
  *.ts|*.tsx|*.js|*.jsx|*.json|*.md)
    npx prettier --write "$path" >/dev/null 2>&1 ;;
esac
exit 0
