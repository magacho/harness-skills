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

root="${CLAUDE_PROJECT_DIR:-$PWD}"

# V12 → R6: a trilha persistente, ao lado do rastro de sessão que o cleanup.sh
# apaga. O caminho vai relativo à raiz — caminho absoluto vaza o layout da
# máquina de quem editou e não agrega ao "quais arquivos mais são tocados".
HARNESS_ROOT="$root" HARNESS_SID="$sid"
export HARNESS_ROOT HARNESS_SID
# shellcheck source=/dev/null
source "$root/.harness/log.sh" 2>/dev/null || true
if ! type harness_log >/dev/null 2>&1; then harness_log() { :; }; fi
harness_log edit path="${path#"$root"/}"

# Formata só com o formatador que o repositório JÁ tem. Baixar ferramenta que o
# projeto não escolheu reformataria o repo inteiro no primeiro turno.
fmt=$(jq -r '.formatter // empty' "$root/.harness/harness.json" 2>/dev/null)
[[ -n "$fmt" ]] && (cd "$root" && eval "$fmt \"\$1\"" _ "$path" >/dev/null 2>&1)
exit 0
