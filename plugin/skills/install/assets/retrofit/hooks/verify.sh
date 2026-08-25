#!/usr/bin/env bash
# Stop — o critério de aceitação. Gerado por harness:install (modo retrofit).
# harness-generated: __VERSION__
#
# O hook é só o gatilho (P8): toda decisão está nos gates, que rodam à mão.
# Escopo estreito (V4 → R2): reporta apenas o que está no raio da sessão.
input=$(cat)
sid=$(jq -r '.session_id // "sem-sessao"' <<<"$input")
root="${CLAUDE_PROJECT_DIR:-$PWD}"
cfg="$root/.harness/harness.json"
tries="/tmp/cc-tries-$sid"
scope="/tmp/cc-scope-$sid.txt"

[[ -f "$cfg" ]] || exit 0

cat /tmp/cc-touched-"$sid"-*.txt 2>/dev/null | sort -u \
  | while read -r f; do [[ -f "$root/$f" || -f "$f" ]] && echo "$f"; done > "$scope"
[[ -s "$scope" ]] || exit 0

# V5 → R2: guarda anti-loop. Depois de N tentativas sem passar, libera com aviso.
max=$(jq -r '.anti_loop_tries // 3' "$cfg")
n=$(( $(cat "$tries" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$tries"
if [[ $n -gt $max ]]; then
  echo "verify: $max tentativas sem passar. Liberando — revise à mão antes do PR." >&2
  exit 0
fi

fail() { printf '%s\n' "$1" | head -40 >&2; exit 2; }

# V6 → R2: em lote o gate é read-only. Correção automática só no hook por
# edição, no arquivo recém-tocado — outra sessão pode estar editando.

# 1. Fronteira, com catraca. Sai 3 quando não há adaptador: declara e segue (D4).
if [[ -x "$root/.harness/gate-boundaries.sh" ]]; then
  bnd=$("$root/.harness/gate-boundaries.sh" --scope "$scope" 2>&1); rc=$?
  [[ $rc -eq 1 ]] && fail "$bnd"
fi

# 2. Lint e 3. typecheck: só os que já passavam no dia da instalação. Ligar um
# gate que reprova trabalho legítimo é o modo de fracasso nº 1 do INTENT.
# Projeto inteiro roda inteiro; o filtro é na saída (V4).
for g in lint typecheck; do
  cmd=$(jq -r --arg g "$g" '.gates[$g] // empty' "$cfg")
  [[ -n "$cmd" ]] || continue
  out=$(cd "$root" && eval "$cmd" 2>&1) || {
    mine=$(grep -F -f "$scope" <<<"$out")
    [[ -n "$mine" ]] && fail "$mine"
  }
done

: > "$tries"
exit 0
