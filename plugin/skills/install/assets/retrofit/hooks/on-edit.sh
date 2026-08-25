#!/usr/bin/env bash
# PostToolUse — roda em toda edição. Gerado por harness:install (modo retrofit).
# harness-generated: __VERSION__
#
# V1 → R2,R9: nunca fala, nunca bloqueia, roda assíncrono. O registro é o
# produto; formatar é bônus.
# V2 → R2: shard por sessão E por agente, para subagentes em paralelo.
input=$(cat)
sid=$(jq -r '.session_id // "sem-sessao"' <<<"$input")
aid=$(jq -r '.agent_id // "main"' <<<"$input")
path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
[[ -n "$path" && -f "$path" ]] || exit 0

echo "$path" >> "/tmp/cc-touched-$sid-$aid.txt"

# Formata só com o formatador que o repositório JÁ tem. Baixar ferramenta que o
# projeto não escolheu reformataria o repo inteiro no primeiro turno.
root="${CLAUDE_PROJECT_DIR:-$PWD}"
fmt=$(jq -r '.formatter // empty' "$root/.harness/harness.json" 2>/dev/null)
[[ -n "$fmt" ]] && (cd "$root" && eval "$fmt \"\$1\"" _ "$path" >/dev/null 2>&1)
exit 0
