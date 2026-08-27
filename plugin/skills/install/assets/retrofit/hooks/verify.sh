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

# V12 → R6: trilha. Sem ela ninguém sabe se este gate reprova alguma coisa ou
# se está passando reto — que é como um gate desligado por engano se parece.
HARNESS_ROOT="$root" HARNESS_SID="$sid"
export HARNESS_ROOT HARNESS_SID
# shellcheck source=/dev/null
source "$root/.harness/log.sh" 2>/dev/null || true
if ! type harness_log >/dev/null 2>&1; then harness_log() { :; }; harness_ms() { echo 0; }; fi
t0=$(harness_ms)
decorrido() { echo $(( $(harness_ms) - t0 )); }

cat /tmp/cc-touched-"$sid"-*.txt 2>/dev/null | sort -u \
  | while read -r f; do [[ -f "$root/$f" || -f "$f" ]] && echo "$f"; done > "$scope"
if [[ ! -s "$scope" ]]; then
  harness_log verify verdict=skip reason=escopo-vazio ms="$(decorrido)"
  exit 0
fi
n_arq=$(wc -l < "$scope" | tr -d ' ')

# V5 → R2: guarda anti-loop. Depois de N tentativas sem passar, libera com aviso.
max=$(jq -r '.anti_loop_tries // 3' "$cfg")
n=$(( $(cat "$tries" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$tries"
if [[ $n -gt $max ]]; then
  # O evento mais importante da trilha: aqui o harness DEIXOU passar código que
  # não passou no gate. Se isso é rotina neste repositório, algum gate está
  # reprovando trabalho legítimo — o modo de fracasso nº 1.
  harness_log verify verdict=released reason=anti-loop try="$n" files="$n_arq" ms="$(decorrido)"
  echo "verify: $max tentativas sem passar. Liberando — revise à mão antes do PR." >&2
  exit 0
fi

fail() {  # fail <gate> <saída>
  harness_log verify verdict=fail gate="$1" try="$n" files="$n_arq" ms="$(decorrido)"
  printf '%s\n' "$2" | head -40 >&2
  exit 2
}

# V6 → R2: em lote o gate é read-only. Correção automática só no hook por
# edição, no arquivo recém-tocado — outra sessão pode estar editando.

# 1. Fronteira, com catraca. Sai 3 quando não há adaptador: declara e segue (D4).
if [[ -x "$root/.harness/gate-boundaries.sh" ]]; then
  bnd=$("$root/.harness/gate-boundaries.sh" --scope "$scope" 2>&1); rc=$?
  [[ $rc -eq 1 ]] && fail boundaries "$bnd"
fi

# 2. Tamanho, com catraca. Não depende de adaptador: é o único gate estrutural
# que existe em toda stack. Sai 3 quando não está configurado (D4).
if [[ -x "$root/.harness/gate-size.sh" ]]; then
  sz=$("$root/.harness/gate-size.sh" --scope "$scope" 2>&1); rc=$?
  [[ $rc -eq 1 ]] && fail size "$sz"
fi

# 3. Lint e 4. typecheck: só os que já passavam no dia da instalação. Ligar um
# gate que reprova trabalho legítimo é o modo de fracasso nº 1 do INTENT.
# Projeto inteiro roda inteiro; o filtro é na saída (V4).
for g in lint typecheck; do
  cmd=$(jq -r --arg g "$g" '.gates[$g] // empty' "$cfg")
  [[ -n "$cmd" ]] || continue
  out=$(cd "$root" && eval "$cmd" 2>&1) || {
    mine=$(grep -F -f "$scope" <<<"$out")
    [[ -n "$mine" ]] && fail "$g" "$mine"
  }
done

harness_log verify verdict=pass files="$n_arq" ms="$(decorrido)"
: > "$tries"
exit 0
