#!/usr/bin/env bash
# Caso: a catraca de TAMANHO. Pergunta de grandeza — o número não pode subir —,
# comparada arquivo por arquivo (V10 → R4,R7). O god file é plantado no fixture
# de propósito: sem ele o eval mediria o caso fácil.
Z=$W/sz
legado_instalado sz --god
$I/gen-baseline.sh "$Z" --from-raw "$F/depcruise-bruto.json" > "$W/sz.f2.json" 2>/dev/null
G="$Z/.harness/gate-size.sh"

echo "→ install / catraca de tamanho (V10 → R4,R7)"
G="$Z/.harness/gate-size.sh"
t "o plano mede o god file antes de escrever" \
  "jq -e '.size.acima_do_teto==1 and (.size.maior.arquivo|test(\"gigante\"))' $W/sz.plan.json"
t "e vira pendência declarada, não rodapé" \
  "jq -e '[.pendencias[] | select(test(\"V10\"))] | length==1' $W/sz.plan.json"
t "gate é comando invocável à mão (D5)"   "[ -x $G ]"
t "config de tamanho no harness.json"     "jq -e '.size.ceiling==400 and .gates.size==true' $Z/.harness/harness.json"
t "fase 2 congela o god file existente"   "jq -e '.tamanho.arquivos_congelados==1' $W/sz.f2.json"
t "baseline guarda grandeza, não presença" \
  "jq -e '.[\"src/cobranca/gigante.js\"]==450' $Z/.harness/baseline-size.json"
t "gate passa com o god file congelado"   "$G"
echo "const cresceu = 1;" >> "$Z/src/cobranca/gigante.js"
t "e reprova quando o god file cresce"    "! $G"
t "a recusa diz quanto era e quanto ficou" \
  "{ $G 2>&1 || true; } | grep -q 'era 450'"
t "e ensina a saída certa, não só nega (A4)" \
  "{ $G 2>&1 || true; } | grep -q 'parte 1 / parte 2'"
sed -i '$d' "$Z/src/cobranca/gigante.js"
t "arquivo NOVO acima do teto reprova" \
  "python3 -c \"open('$Z/src/comum/novo.js','w').write(chr(10).join(['x']*401)+chr(10))\"; ! $G"
t "mas não quando está fora do raio da sessão (V4)" \
  "echo src/comum/data.js > $W/sz.scope.txt; $G --scope $W/sz.scope.txt"
rm -f "$Z/src/comum/novo.js"
t "extensão fora da lista não é medida" \
  "python3 -c \"open('$Z/src/comum/doc.md','w').write(chr(10).join(['x']*900))\"; $G"
t "arquivo excluído por padrão não é medido" \
  "python3 -c \"open('$Z/src/comum/api.generated.js','w').write(chr(10).join(['x']*900))\"; $G"
rm -f "$Z/src/comum/doc.md" "$Z/src/comum/api.generated.js"

echo "→ install / o baseline de tamanho só encolhe (V7)"
python3 -c "open('$Z/src/cobranca/gigante.js','w').write(chr(10).join(f'const l{i} = {i};' for i in range(1,421))+chr(10))"
t "gate avisa que há folga a devolver"    "{ $G 2>&1 || true; } | grep -q 'tighten'"
t "--tighten baixa o teto individual"     "$G --tighten && jq -e '.[\"src/cobranca/gigante.js\"]==420' $Z/.harness/baseline-size.json"
t "e depois de apertar, crescer reprova"  "echo 'const x = 1;' >> $Z/src/cobranca/gigante.js; ! $G"
sed -i '$d' "$Z/src/cobranca/gigante.js"
t "--init recusa afrouxar o baseline"     "echo 'const x = 1;' >> $Z/src/cobranca/gigante.js; ! $G --init"
t "e diz que o baseline só encolhe"       "{ $G --init 2>&1 || true; } | grep -q 'só encolhe'"
t "--force existe, mas é explícito"       "$G --init --force"
sed -i '$d' "$Z/src/cobranca/gigante.js"; $G --tighten >/dev/null 2>&1
t "renomear não reprova nem afrouxa" \
  "mv $Z/src/cobranca/gigante.js $Z/src/cobranca/renomeado.js; ! $G \
   && $G --rename src/cobranca/gigante.js src/cobranca/renomeado.js && $G"
t "--rename recusa destino já no baseline" \
  "! $G --rename src/cobranca/renomeado.js src/cobranca/renomeado.js"
t "V9: fumaça prova o gate de tamanho" \
  "o=\$($I/smoke-test.sh $Z 2>&1 || true); grep -q 'V9 OK (tamanho)' <<<\"\$o\""
t "e não deixa a violação plantada para trás" \
  "[ -z \"\$(find $Z -name '__harness_smoke_size__')\" ]"
mv "$Z/src/cobranca/renomeado.js" "$Z/src/cobranca/gigante.js"
$G --rename src/cobranca/renomeado.js src/cobranca/gigante.js >/dev/null 2>&1
