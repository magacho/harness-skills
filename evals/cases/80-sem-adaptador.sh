#!/usr/bin/env bash
# Caso: stack sem adaptador de fronteira (D4 → R10). A lacuna é dita em voz
# alta, o resto instala, e a catraca de tamanho — que não depende de ferramenta
# — continua valendo e é provada.

echo "→ install / stack sem adaptador (D4)"
cp -a $F/python-sem-adaptador "$W/py"; mkdir -p "$W/py/src/cobrancas"
echo 'def cobrar(): pass' > "$W/py/src/cobrancas/cobrar.py"
$I/plan-install.sh "$W/py" > "$W/plan-py.json" 2>/dev/null
$I/gen-config.sh "$W/py" --plan "$W/plan-py.json" --owner "Dona Eval" --fase 1 >/dev/null 2>&1
t "instala todo o resto mesmo assim"      "[ -x $W/py/.claude/hooks/verify.sh ] && [ -f $W/py/.claude/settings.json ]"
t "não instala adaptador que não existe"  "[ ! -e $W/py/.harness/adapters ]"
t "registra a lacuna no harness.json"     "jq -e '.boundary.adapter==null and (.boundary.reason|length>0)' $W/py/.harness/harness.json"
t "a lacuna aparece nas pendências do plano" \
  "jq -e '[.pendencias[] | select(test(\"D4\"))] | length==1' $W/plan-py.json"
t "catraca sai 3 e declara, não aborta" \
  "$I/gen-baseline.sh $W/py; [ \$? -eq 3 ]"
t "e diz em voz alta o que falta" \
  "{ $I/gen-baseline.sh $W/py 2>&1 || true; } | grep -q 'SEM CATRACA'"
t "e diz que a de TAMANHO não depende de adaptador" \
  "{ $I/gen-baseline.sh $W/py 2>&1 || true; } | grep -q 'TAMANHO'"
t "gate instalado também se declara indisponível" \
  "{ $W/py/.harness/gate-boundaries.sh 2>&1 || true; } | grep -q 'INDISPONÍVEL'"
# O ganho concreto da catraca de tamanho: numa stack sem adaptador, onde antes
# não havia gate estrutural nenhum, existe um — e ele é provado (V9), não só
# instalado. É por isso que ela não tem adaptador (V10 → R12).
t "instala catraca de tamanho mesmo sem adaptador" \
  "[ -x $W/py/.harness/gate-size.sh ] && jq -e '.gates.size==true' $W/py/.harness/harness.json"
t "e a fumaça prova o único gate que existe" \
  "o=\$($I/smoke-test.sh $W/py 2>&1); grep -q 'V9 OK (tamanho)' <<<\"\$o\""
t "declarando em voz alta a prova que falta (D4)" \
  "o=\$($I/smoke-test.sh $W/py 2>&1 || true); grep -q 'SEM TESTE DE FUMAÇA DE FRONTEIRA' <<<\"\$o\""
t "python acima do teto reprova (V10 vale em qualquer stack)" \
  "python3 -c \"open('$W/py/src/cobrancas/god.py','w').write(chr(10).join(['x = 1']*401)+chr(10))\"; ! $W/py/.harness/gate-size.sh"
rm -f "$W/py/src/cobrancas/god.py"
