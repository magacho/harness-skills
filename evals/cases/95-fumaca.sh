#!/usr/bin/env bash
# Caso: V9 → R3 de ponta a ponta, com a ferramenta de verdade. Gate que nunca
# reprovou não é gate.

echo "→ install / catraca e V9 de ponta a ponta"
if [[ $rede -eq 1 ]]; then
  cp -a $F/legado-com-ciclos "$W/e2e"
  $I/plan-install.sh "$W/e2e" > "$W/plan-e2e.json" 2>/dev/null
  $I/gen-config.sh "$W/e2e" --plan "$W/plan-e2e.json" --owner "Dona Eval" --fase 1 >/dev/null 2>&1
  $I/gen-baseline.sh "$W/e2e" >/dev/null 2>&1
  t "gate passa com o baseline congelado"   "$W/e2e/.harness/gate-boundaries.sh"
  t "violação plantada reprova (V9 → R3)"   "$I/smoke-test.sh $W/e2e"
  t "e a violação plantada foi removida"    "[ -z \"\$(find $W/e2e -name __harness_smoke__)\" ]"
  t "gate recusa cruzar zero módulo"        "! $I/adapters/node.sh run $W/e2e .dependency-cruiser.cjs nao-existe"
else
  s "gate passa com o baseline congelado"   "dependency-cruiser indisponível (sem rede)"
  s "violação plantada reprova (V9 → R3)"   "dependency-cruiser indisponível (sem rede)"
  s "e a violação plantada foi removida"    "dependency-cruiser indisponível (sem rede)"
  s "gate recusa cruzar zero módulo"        "dependency-cruiser indisponível (sem rede)"
fi

echo
