#!/usr/bin/env bash
# Caso: a catraca de FRONTEIRA. Pergunta de presença — a violação existe ou
# não —, comparada por diferença de conjunto, e o baseline só encolhe (V7 → R7).
B=$W/bnd
legado_instalado bnd

echo "→ install / fase 2: as duas catracas"
$I/gen-baseline.sh "$B" --from-raw "$F/depcruise-bruto.json" > "$W/bnd.f2.json" 2>/dev/null
t "baseline de fronteira não vazio (V7)"  "jq -e '.fronteira.violacoes_congeladas==2' $W/bnd.f2.json"
t "baseline no formato do harness (V8)" \
  "jq -e 'all(has(\"origem\") and has(\"destino\") and has(\"regra\"))' $B/.harness/baseline.json"
t "congela o ciclo que já existia"        "jq -e '[.[] | select(.regra==\"sem-ciclos\")] | length==1' $B/.harness/baseline.json"
t "catraca de fronteira declarada ligada" "jq -e '.fronteira.catraca | test(\"ligada\")' $W/bnd.f2.json"

echo "→ install / o baseline de fronteira só encolhe (V7)"
jq '[.[0]]' "$B/.harness/baseline.json" > "$W/menor.json" && mv "$W/menor.json" "$B/.harness/baseline.json"
t "recusa regerar baseline que cresceria" \
  "! $I/gen-baseline.sh $B --from-raw $F/depcruise-bruto.json"
t "e diz por quê" \
  "{ $I/gen-baseline.sh $B --from-raw $F/depcruise-bruto.json 2>&1 || true; } | grep -q 'só encolhe'"
t "--force existe, mas é explícito" \
  "$I/gen-baseline.sh $B --from-raw $F/depcruise-bruto.json --force"
