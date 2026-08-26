#!/usr/bin/env bash
# Caso: o adaptador de fronteira e o contrato de quatro verbos
# (docs/adapters/README.md). Inclui a regressão do alvo nu, que deixava todo
# projeto TypeScript com um gate que nunca verificava nada.

echo "→ install / adaptador de fronteira (contrato de quatro verbos)"
t "detect reconhece stack node"           "$I/adapters/node.sh detect $F/legado-com-ciclos"
t "detect recusa stack alheia"            "! $I/adapters/node.sh detect $F/python-sem-adaptador"
t "generate-config só proíbe ciclo e órfão" \
  "$I/adapters/node.sh generate-config $F/legado-com-ciclos src | grep -q 'sem-ciclos' && ! $I/adapters/node.sh generate-config $F/legado-com-ciclos src | grep -qE 'from: \{ path: \"\^(modules|src)/[a-z]'"
t "normalize devolve origem/destino/regra" \
  "$I/adapters/node.sh normalize $F/depcruise-bruto.json | jq -e 'length==2 and all(has(\"origem\") and has(\"destino\") and has(\"regra\"))'"
t "normalize é estável entre execuções" \
  "diff <($I/adapters/node.sh normalize $F/depcruise-bruto.json) <($I/adapters/node.sh normalize $F/depcruise-bruto.json)"
t "catraca não usa knownViolations da ferramenta (V8)" \
  "! $I/adapters/node.sh generate-config $F/legado-com-ciclos src | grep -qE '^\s*knownViolations'"

echo "→ install / grafo TypeScript (regressão do alvo nu)"
# O dependency-cruiser 18 não expande diretório nu para .ts/.tsx: devolvia zero
# módulo cruzado e "sem violações". Todo projeto TS recebia um gate que nunca
# verificou nada. Todo fixture com grafo era JavaScript — onde o diretório nu
# funciona — e por isso a suíte inteira ficava verde com o defeito presente.
#
# Estes evals afirmam totalCruised > 0 E a contagem esperada: um eval que só
# checasse "saiu 0" continuaria passando com o bug.
if [[ $rede -eq 1 ]]; then
  TSF=$F/ts-com-ciclo
  TSCFG=$W/dc-ts.cjs
  $I/adapters/node.sh generate-config $TSF src > $TSCFG 2>/dev/null
  TSOUT=$W/ts-run.json
  $I/adapters/node.sh run $TSF $TSCFG src > $TSOUT 2>/dev/null
  t "cruza módulo em projeto TypeScript"  "[ \$(jq '.summary.totalCruised' $TSOUT) -gt 0 ]"
  t "cruza exatamente os 3 do fixture"    "jq -e '.summary.totalCruised == 3' $TSOUT"
  t "acha o ciclo e o órfão (2 violações)" \
    "[ \$($I/adapters/node.sh normalize $TSOUT | jq 'length') -eq 2 ]"
  t "o ciclo em .ts é reportado"          "$I/adapters/node.sh normalize $TSOUT | jq -e 'any(.regra == \"sem-ciclos\")'"
  # Import TS sem extensão ("./faturar"): a v18 registrava o especificador cru,
  # a regra de direção não casava e virava violação fantasma.
  t "import sem extensão é resolvido"     "$I/adapters/node.sh normalize $TSOUT | jq -e 'all(.[].destino; startswith(\".\") | not)'"
  t "e resolve para o caminho real"       "$I/adapters/node.sh normalize $TSOUT | jq -e 'any(.destino == \"src/cobranca/faturar.ts\")'"
  # A prova de que a transformação de alvo é o que salva: entregando o
  # diretório nu direto à ferramenta, o mesmo fixture cruza zero.
  nu=$(cd $TSF && npx --yes --package dependency-cruiser depcruise --config $TSCFG --output-type json src 2>/dev/null | jq '.summary.totalCruised')
  t "diretório nu cruzaria zero (o defeito)" "[ \"${nu:-0}\" -eq 0 ]"
  t "audit mede baseline em projeto TS"   "$A/boundary-status.sh $TSF | jq -e '.violacoes == 2'"
  t "e não sai 3 num projeto TS"          "$A/boundary-status.sh $TSF >/dev/null"
else
  for n in "cruza módulo em projeto TypeScript" "cruza exatamente os 3 do fixture" \
           "acha o ciclo e o órfão (2 violações)" "o ciclo em .ts é reportado" \
           "import sem extensão é resolvido" "e resolve para o caminho real" \
           "diretório nu cruzaria zero (o defeito)" "audit mede baseline em projeto TS" \
           "e não sai 3 num projeto TS"; do
    s "$n" "dependency-cruiser indisponível (sem rede)"
  done
fi
