#!/usr/bin/env bash
# Evals das skills. Skill que modifica repositório alheio sem eval é risco não
# medido — e a instalação escreve.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
A=plugin/skills/audit/scripts
I=plugin/skills/install/scripts
T=plugin/skills/install/assets/template
F=evals/fixtures
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

pass=0; fail=0; skip=0
t() { if eval "$2" >/dev/null 2>&1; then echo "  ok   $1"; pass=$((pass+1)); else echo "  FAIL $1"; fail=$((fail+1)); fi; }
s() { echo "  skip $1 — $2"; skip=$((skip+1)); }

# A cadeia de fronteira precisa do dependency-cruiser. Sem rede, os evals que
# dependem dela são PULADOS COM MOTIVO, nunca silenciados (mesma regra D4 que a
# skill cobra dos outros).
rede=0
if timeout 120 npx --yes --package dependency-cruiser depcruise --version >/dev/null 2>&1; then rede=1; fi

# ===========================================================================
echo "→ audit / detect-stack"
t "identifica node-ts no template"        "$A/detect-stack.sh $T | grep -q '\"stack\": \"node-ts\"'"
t "identifica harness existente"          "$A/detect-stack.sh $T | grep -q '\"settings\": true'"
t "conta CLAUDE.md de módulo"             "[ \$($A/detect-stack.sh $T | grep -o '\"claude_md_module_count\": [0-9]*' | awk '{print \$2}') -ge 5 ]"
t "declara stack sem adaptador"           "$A/detect-stack.sh $F/python-sem-adaptador | grep -q 'unsupported'"

echo "→ audit / check-claims (regra C4)"
t "template não tem instrução falsa"      "$A/check-claims.sh $T"
t "detecta instrução falsa no fixture"    "! $A/check-claims.sh $F/legado-com-instrucao-falsa"
t "aponta exatamente 2 falsas"            "{ $A/check-claims.sh $F/legado-com-instrucao-falsa || true; } | grep -q 'falsas=2'"
t "repo sem CLAUDE.md não quebra"         "$A/check-claims.sh $F/sem-harness | grep -q SEM_CLAUDE_MD"

echo "→ audit / read-only"
before=$(find $T $F -type f -newermt '-1 second' 2>/dev/null | wc -l)
$A/detect-stack.sh $T >/dev/null; $A/check-claims.sh $T >/dev/null
after=$(find $T $F -type f -newermt '-1 second' 2>/dev/null | wc -l)
t "auditoria não escreve arquivo"         "[ $before -eq $after ]"

# ===========================================================================
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

# ===========================================================================
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

# ===========================================================================
echo "→ install / modo A em legado com violações"
cp -a $F/legado-com-ciclos "$W/legado"
$I/plan-install.sh "$W/legado" > "$W/plan.json" 2>/dev/null
$I/gen-config.sh "$W/legado" --plan "$W/plan.json" --owner "Dona Eval <eval@exemplo>" --fase 1 > "$W/f1.json" 2>/dev/null
t "fase 1 instala os quatro hooks" \
  "[ \$(ls $W/legado/.claude/hooks/*.sh 2>/dev/null | wc -l) -eq 4 ]"
t "hooks saem executáveis"                "[ -x $W/legado/.claude/hooks/verify.sh ]"
t "shebang continua na primeira linha"    "head -1 $W/legado/.claude/hooks/verify.sh | grep -q '^#!'"
t "gate é comando invocável à mão (D5)"   "[ -x $W/legado/.harness/gate-boundaries.sh ]"
t "adaptador vai para o repositório (R8)" "[ -x $W/legado/.harness/adapters/node.sh ]"
t "dono registrado (D6)"                  "jq -e '.owner==\"Dona Eval <eval@exemplo>\"' $W/legado/.harness/harness.json"
t "teto default é supervisionado (A6)"    "jq -e '.autonomy_ceiling==\"supervisionado\"' $W/legado/.harness/harness.json"
t "typecheck vermelho não virou gate"     "jq -e '.gates.typecheck==null' $W/legado/.harness/harness.json"
t "lint verde virou gate"                 "jq -e '.gates.lint!=null' $W/legado/.harness/harness.json"
t "produção negada em permissão (A2)"     "jq -e '[.permissions.deny[] | select(test(\"prd|prod\"))] | length > 0' $W/legado/.claude/settings.json"
t "leitura de .env negada (A5)"           "jq -e '[.permissions.deny[] | select(test(\"env\"))] | length > 0' $W/legado/.claude/settings.json"
t "produção negada também em hook (A2)"   "grep -q 'deny' $W/legado/.claude/hooks/guard-prod.sh"
t "guarda anti-loop presente (V5)"        "jq -e '.anti_loop_tries==3' $W/legado/.harness/harness.json"
t "/ship só cita comando que existe (C4)" "! grep -q 'npm run typecheck' $W/legado/.claude/commands/ship.md"
t "nenhum arquivo-fonte foi tocado" \
  "diff -r --exclude=.claude --exclude=.harness --exclude='*.cjs' $F/legado-com-ciclos $W/legado"

echo "→ install / fase 2: a catraca"
$I/gen-baseline.sh "$W/legado" --from-raw "$F/depcruise-bruto.json" > "$W/f2.json" 2>/dev/null
t "baseline não vazio em legado (V7)"     "jq -e '.violacoes_congeladas==2' $W/f2.json"
t "baseline no formato do harness (V8)" \
  "jq -e 'all(has(\"origem\") and has(\"destino\") and has(\"regra\"))' $W/legado/.harness/baseline.json"
t "congela o ciclo que já existia"        "jq -e '[.[] | select(.regra==\"sem-ciclos\")] | length==1' $W/legado/.harness/baseline.json"
t "catraca declarada como ligada"         "jq -e '.catraca | test(\"ligada\")' $W/f2.json"

echo "→ install / o baseline só encolhe (V7)"
jq '[.[0]]' "$W/legado/.harness/baseline.json" > "$W/menor.json" && mv "$W/menor.json" "$W/legado/.harness/baseline.json"
t "recusa regerar baseline que cresceria" \
  "! $I/gen-baseline.sh $W/legado --from-raw $F/depcruise-bruto.json"
t "e diz por quê" \
  "{ $I/gen-baseline.sh $W/legado --from-raw $F/depcruise-bruto.json 2>&1 || true; } | grep -q 'só encolhe'"
t "--force existe, mas é explícito" \
  "$I/gen-baseline.sh $W/legado --from-raw $F/depcruise-bruto.json --force"

echo "→ install / fase 3: contexto"
$I/gen-config.sh "$W/legado" --plan "$W/plan.json" --owner "Dona Eval" --fase 3 > "$W/f3.json" 2>/dev/null
t "um CLAUDE.md por módulo existente (C3)" \
  "[ -f $W/legado/src/faturamento/CLAUDE.md ] && [ -f $W/legado/src/cobranca/CLAUDE.md ]"
t "módulo declara o que possui e o que nunca importa" \
  "grep -q 'Possui:' $W/legado/src/comum/CLAUDE.md && grep -q 'Nunca importa:' $W/legado/src/comum/CLAUDE.md"
t "módulo de módulo cabe em ~15 linhas (C5)" \
  "[ \$(wc -l < $W/legado/src/comum/CLAUDE.md) -le 15 ]"
t "não sobrescreve CLAUDE.md alheio (D3)" \
  "grep -q 'pnpm build' $W/legado/CLAUDE.md"
t "e deixa a proposta ao lado para merge" \
  "[ -f $W/legado/.harness/CLAUDE.md.proposto ]"
t "a proposta cabe em ~60 linhas (C5)"    "[ \$(wc -l < $W/legado/.harness/CLAUDE.md.proposto) -le 60 ]"
t "a proposta não cita comando inexistente (C4)" \
  "! grep -q 'pnpm build' $W/legado/.harness/CLAUDE.md.proposto"

echo "→ install / idempotência (D3)"
h1=$(find "$W/legado" -type f -exec sha256sum {} \; | sort -k2 | sha256sum)
$I/gen-config.sh "$W/legado" --plan "$W/plan.json" --owner "Outro Dono" --fase 1 >/dev/null 2>&1
$I/gen-config.sh "$W/legado" --plan "$W/plan.json" --owner "Outro Dono" --fase 3 >/dev/null 2>&1
h2=$(find "$W/legado" -type f -exec sha256sum {} \; | sort -k2 | sha256sum)
t "rodar duas vezes não altera nada"      "[ '$h1' = '$h2' ]"
t "e não troca o dono já registrado"      "jq -e '.owner==\"Dona Eval <eval@exemplo>\"' $W/legado/.harness/harness.json"
echo "# nota do time" >> "$W/legado/src/comum/CLAUDE.md"
$I/gen-config.sh "$W/legado" --plan "$W/plan.json" --owner "Dona Eval" --fase 3 > "$W/f3b.json" 2>/dev/null
t "customização manual é preservada"      "grep -q 'nota do time' $W/legado/src/comum/CLAUDE.md"
t "e o pulo é relatado, não silenciado" \
  "jq -e '[.pulados[] | select(test(\"src/comum\"))] | length==1' $W/f3b.json"

echo "→ install / dono é obrigatório (D6)"
t "gen-config recusa sem dono" \
  "! $I/gen-config.sh $W/legado --plan $W/plan.json --fase 1"
t "scaffold recusa sem dono" \
  "! $I/scaffold.sh $F/repo-vazio"

# ===========================================================================
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
t "fumaça sai 3 e explica por quê" \
  "{ $I/smoke-test.sh $W/py 2>&1 || true; } | grep -q 'SEM TESTE DE FUMAÇA'"
t "gate instalado também se declara indisponível" \
  "{ $W/py/.harness/gate-boundaries.sh 2>&1 || true; } | grep -q 'INDISPONÍVEL'"

# ===========================================================================
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
echo 'const x = 1;' > "$W/novo/intruso.js"
t "recusa scaffold onde já há código-fonte" \
  "! $I/scaffold.sh $W/novo --owner 'Dona Eval'"
rm -f "$W/novo/intruso.js"

# ===========================================================================
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
echo "pass=$pass fail=$fail skip=$skip"
[[ $skip -gt 0 ]] && echo "($skip eval(s) pulado(s) por dependência externa — declarado, não silenciado)"
[[ $fail -eq 0 ]]
