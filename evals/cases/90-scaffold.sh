#!/usr/bin/env bash
# Caso: modo B (projeto novo). Nomes vêm do domínio real (C6 → R7), os dois
# baselines nascem vazios, e aí o teto de tamanho age como limite absoluto.

echo "→ install / modo B: repositório vazio"
mkdir -p "$W/novo"
$I/scaffold.sh "$W/novo" --owner "Dona Eval <eval@exemplo>" \
  --modules "shared=comum,domain=faturamento,data=persistencia,api=http,web=painel" > "$W/scaf.json" 2>/dev/null
t "copia o template inteiro"              "jq -e '.copiados >= 30' $W/scaf.json"
t "renomeia os cinco módulos"             "jq -e '.renomeados | length == 5' $W/scaf.json"
t "os diretórios têm os nomes pedidos"    "[ -d $W/novo/modules/faturamento ] && [ ! -d $W/novo/modules/domain ]"
t "imports acompanham a renomeação"       "grep -q 'faturamento/src/invoice' $W/novo/modules/http/src/pay-invoice.handler.ts"
t "paths da config acompanham junto"      "grep -q 'modules/faturamento' $W/novo/.dependency-cruiser.js"
t "alternação de regex também é renomeada" \
  "! grep -qE '\\^modules/\\((domain|data|api|web)' $W/novo/.dependency-cruiser.js"
t "nenhuma regra sobra apontando para módulo inexistente" \
  "! grep -oE 'modules/[a-z]+' $W/novo/.dependency-cruiser.js | sort -u | grep -vxE 'modules/(comum|faturamento|persistencia|http|painel)' | grep -q ."
t "CLAUDE.md não fica com nome velho (C4)" "! grep -qE '\\b(domain|shared)\\b' $W/novo/CLAUDE.md"
t "dono registrado no modo B (D6)"        "jq -e '.owner==\"Dona Eval <eval@exemplo>\"' $W/novo/.harness/harness.json"
t "um só mecanismo de gate nos dois modos" \
  "grep -q 'gate-boundaries.sh' $W/novo/.claude/hooks/verify.sh"
t "gate e adaptador vão para o repositório" \
  "[ -x $W/novo/.harness/gate-boundaries.sh ] && [ -x $W/novo/.harness/adapters/node.sh ]"
t "baseline nasce vazio em projeto novo"  "jq -e 'length==0' $W/novo/.harness/baseline.json"
t "os DOIS gates vão para o repositório"  "[ -x $W/novo/.harness/gate-size.sh ]"
t "baseline de tamanho vazio = teto absoluto" \
  "jq -e 'length==0' $W/novo/.harness/baseline-size.json"
t "e aí qualquer arquivo acima do teto reprova" \
  "python3 -c \"open('$W/novo/modules/comum/src/god.ts','w').write(chr(10).join(['export const x = 1;']*401)+chr(10))\"; ! $W/novo/.harness/gate-size.sh"
t "o linter do template limita função, não arquivo (V11)" \
  "grep -q 'max-lines-per-function' $W/novo/eslint.config.js && ! grep -qE '^\s*\"?max-lines\"?:' $W/novo/eslint.config.js"
t "e a dependência do linter está declarada (C4)" \
  "jq -e '.devDependencies[\"typescript-eslint\"]' $W/novo/package.json"
t "CLAUDE.md diz os três números (R1)" \
  "grep -q '400 linhas' $W/novo/CLAUDE.md && grep -q 'função até 60' $W/novo/CLAUDE.md"
rm -f "$W/novo/modules/comum/src/god.ts"
echo 'const x = 1;' > "$W/novo/intruso.js"
t "recusa scaffold onde já há código-fonte" \
  "! $I/scaffold.sh $W/novo --owner 'Dona Eval'"
rm -f "$W/novo/intruso.js"
