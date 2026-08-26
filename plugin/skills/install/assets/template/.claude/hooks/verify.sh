#!/bin/bash
# Stop — o critério de aceitação. Escopo estreito: só o que a sessão tocou.
input=$(cat)
sid=$(jq -r '.session_id' <<<"$input")
tries="/tmp/cc-tries-$sid"

mapfile -t files < <(cat /tmp/cc-touched-"$sid"-*.txt 2>/dev/null | sort -u \
  | while read -r f; do [[ -f "$f" ]] && case "$f" in *.ts|*.tsx) echo "$f";; esac; done)
[[ ${#files[@]} -gt 0 ]] || exit 0

n=$(( $(cat "$tries" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$tries"
if [[ $n -gt 3 ]]; then
  echo "verify: 3 tentativas sem passar. Liberando — revise manualmente antes do PR." >&2
  exit 0
fi

fail() { printf '%s\n' "$1" | head -40 >&2; exit 2; }

# 1. lint na coleção, read-only (não escreve: outra janela pode estar editando)
lint=$(npx eslint --max-warnings=0 "${files[@]}" 2>&1) || fail "$lint"

# 2. fronteiras de módulo — o gate arquitetural, com catraca
bnd=$(./.harness/gate-boundaries.sh 2>&1); [[ $? -eq 1 ]] && fail "$bnd"

# 3. tamanho — arquivo acima do teto não cresce (V10 → R4)
sz=$(./.harness/gate-size.sh 2>&1); [[ $? -eq 1 ]] && fail "$sz"

# 4. typecheck do projeto, output filtrado pela coleção
if ! tsc_out=$(pnpm typecheck 2>&1); then
  rel=$(printf '%s\n' "${files[@]}" | sed "s|^$PWD/||")
  mine=$(grep -F -f <(printf '%s\n' "$rel") <<<"$tsc_out")
  [[ -n "$mine" ]] && fail "$mine"
fi

: > "$tries"
exit 0
