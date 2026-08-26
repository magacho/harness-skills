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

echo "→ install / modo B: os hooks vêm da fonte única e carregam marca"
t "os quatro hooks são instalados"        "[ \$(ls $W/novo/.claude/hooks/*.sh | wc -l) -eq 4 ]"
t "e nenhum vem do template (uma cópia só)" \
  "[ ! -d plugin/skills/install/assets/template/.claude/hooks ]"
# O guard-prod do template casava `deploy.sh prd` literal: `--env prd` passava, e
# o modo B recebia trava mais fraca que o modo A. Política duplicada divergiu.
t "o guard-prod do modo B nega o que o do template deixava passar" \
  "for c in './ops/deploy.sh --env prd' 'git tag -a v1.2.3 -m rel' 'PRD=1 ./ops/deploy.sh'; do
     printf '{\"tool_input\":{\"command\":\"%s\"}}' \"\$c\" | bash $W/novo/.claude/hooks/guard-prod.sh \
       | jq -e '.hookSpecificOutput.permissionDecision == \"deny\"' >/dev/null || exit 1
   done"
# Sem marca, o gen-config de uma versão futura classifica como "não é nosso" e
# manda para `pulados`: repositório do modo B nunca receberia atualização.
t "arquivo copiado carrega marca de versão (D3 → R10)" \
  "for f in .claude/hooks/guard-prod.sh .harness/gate-size.sh .harness/adapters/node.sh; do
     grep -q 'harness-generated' $W/novo/\$f || exit 1; done"
t "e o hash gravado bate com o do corpo, como o gen-config calcula" \
  "f=$W/novo/.claude/hooks/guard-prod.sh
   [ \"\$(grep -o 'sha=[0-9a-f]*' \$f | cut -d= -f2)\" = \"\$(grep -v 'harness-generated:' \$f | sha256sum | cut -c1-16)\" ]"
t "shebang continua na primeira linha"    "head -1 $W/novo/.claude/hooks/verify.sh | grep -q '^#!'"
