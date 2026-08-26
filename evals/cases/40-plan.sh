#!/usr/bin/env bash
# Caso: plan-install.sh. Read-only, decide o modo, lê os módulos do projeto
# (nunca do template) e reprova o repositório que não merece harness.

echo "→ install / plano (read-only)"
$I/plan-install.sh $F/legado-com-ciclos > "$W/plan-legado.json" 2>/dev/null
$I/plan-install.sh $F/repo-vazio        > "$W/plan-vazio.json" 2>/dev/null
$I/plan-install.sh $F/nao-merece-harness > "$W/plan-nao.json" 2>/dev/null
t "repo vazio → modo scaffold"            "jq -e '.modo==\"scaffold\"' $W/plan-vazio.json"
t "repo com código → modo retrofit"       "jq -e '.modo==\"retrofit\"' $W/plan-legado.json"
t "módulos vêm do projeto, não do template (C6)" \
  "jq -e '(.modulos | index(\"src/faturamento\")) and (.modulos | index(\"src/cobranca\"))' $W/plan-legado.json"
t "nunca inventa nome de módulo do template" \
  "! jq -r '.modulos[]' $W/plan-legado.json | grep -qxE '(modules/)?(domain|data)'"
t "lint verde entra no gate"              "jq -e '.gates_hoje.lint.estado==\"verde\"' $W/plan-legado.json"
t "typecheck vermelho fica fora do gate"  "jq -e '.gates_hoje.typecheck.estado==\"vermelho\"' $W/plan-legado.json"
t "typecheck vermelho vira pendência declarada" \
  "jq -e '[.pendencias[] | select(test(\"typecheck reprova\"))] | length == 1' $W/plan-legado.json"
t "plano não escreve no repositório" \
  "[ -z \"\$(find $F/legado-com-ciclos -newermt '-2 seconds' -type f)\" ]"

echo "→ install / eval negativo: repo que não deveria receber harness"
t "script de uso único é reprovado"       "jq -e '.merece_harness.veredito==false' $W/plan-nao.json"
t "e a razão é dita, não só o veredito"   "jq -e '.merece_harness.razoes | length > 0' $W/plan-nao.json"
t "legado de verdade é aprovado"          "jq -e '.merece_harness.veredito==true' $W/plan-legado.json"

echo "→ install / o plano mede o mesmo que o gate (bug do .next/)"
# O plano acusava 4 god files num repositório onde nenhum arquivo de código passa
# do teto: todos eram artefato de build em `.next/`, sequer versionado. Duas
# causas independentes — a lista de poda do plano não tinha `.next`, `coverage`,
# `out` nem `target`, e ele varria a raiz em vez dos `size.targets` que ele mesmo
# emite. O gate media certo, então quem lia o plano e quem rodava o gate tinham
# respostas diferentes sobre o mesmo repositório.
#
# O artefato é gerado aqui, e não versionado: um build de 903 linhas dentro de
# fixtures/ é ruído, e 70-catraca-tamanho já usa esse mesmo caminho.
BLD=$W/com-build
mkdir -p "$BLD/src" "$BLD/.next/server/chunks/ssr" "$BLD/coverage/lcov-report" "$BLD/out" "$BLD/target"
printf '{"name":"com-build","private":true,"scripts":{}}' > "$BLD/package.json"
# `ferramentas/legado.js` é o que separa as DUAS causas: não está em diretório
# podado, e não está em `size.targets` (["src"]). Só a poda não o esconde — quem
# varre a raiz o acusa, quem varre os alvos não. Sem ele o fixture passaria mesmo
# com a metade do defeito presente.
mkdir -p "$BLD/ferramentas"
python3 -c "
open('$BLD/src/ok.ts','w').write(chr(10).join(f'const a{i} = {i};' for i in range(1,327))+chr(10))
open('$BLD/ferramentas/legado.js','w').write(chr(10).join(['y']*700)+chr(10))
for p in ['.next/server/chunks/ssr/[turbopack]_runtime.js','coverage/lcov-report/x.js','out/b.js','target/c.js']:
    open('$BLD/'+p,'w').write(chr(10).join(['x']*903)+chr(10))"
$I/plan-install.sh "$BLD" > "$W/plan-build.json" 2>/dev/null
t "artefato de build não conta como god file" "jq -e '.size.acima_do_teto == 0' $W/plan-build.json"
t "arquivo grande FORA dos targets também não conta" \
  "jq -e '.size.targets == [\"src\"] and .size.acima_do_teto == 0' $W/plan-build.json"
t "e não nomeia nenhum na saída"              "jq -e '.size.maior == null' $W/plan-build.json"
t "sem pendência V10 inventada"               "jq -e '[.pendencias[] | select(test(\"V10\"))] | length == 0' $W/plan-build.json"
t "artefato de build não conta como código-fonte" \
  "jq -e '.repo.arquivos_de_codigo == 2' $W/plan-build.json"
t "o arquivo real de 326 linhas passa, e é medido" \
  "[ \$($I/../assets/gate/size.sh --measure --root $BLD --targets src | cut -f1) -eq 326 ]"

# A guarda durável não é a lista de poda: é os três consumidores concordarem.
# Enquanto cada um reimplementava o find, o desvio voltava na primeira correção
# aplicada a só um lado.
gate_n=$($I/../assets/gate/size.sh --measure --root "$BLD" | wc -l)
audit_n=$($A/size-status.sh "$BLD" | jq '.arquivos')
plano_n=$(jq '.repo.arquivos_de_codigo' "$W/plan-build.json")
t "plano, gate e audit contam o mesmo" "[ '$gate_n' = '$audit_n' ] && [ '$audit_n' = '$plano_n' ]"
t "o teto canônico vem de um lugar só" \
  "[ \$($I/../assets/gate/size.sh --defaults | jq .ceiling) = \$(jq .size.ceiling $W/plan-build.json) ]"
