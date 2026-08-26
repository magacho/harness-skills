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
