#!/usr/bin/env bash
# Caso: modo A (retrofit) — fase 1, fase 3 e idempotência, num repositório só
# deste caso. As catracas têm arquivo próprio: aqui a fase 2 não roda, e é de
# propósito — a fase 3 não depende de baseline, e provar isso separado impede
# que a ordem dos casos volte a ser carregada.
R=$W/retro; RP=$W/retro.plan.json
legado_instalado retro

echo "→ install / modo A em legado com violações"
t "fase 1 instala os quatro hooks" \
  "[ \$(ls $R/.claude/hooks/*.sh 2>/dev/null | wc -l) -eq 4 ]"
t "hooks saem executáveis"                "[ -x $R/.claude/hooks/verify.sh ]"
t "shebang continua na primeira linha"    "head -1 $R/.claude/hooks/verify.sh | grep -q '^#!'"
t "gate é comando invocável à mão (D5)"   "[ -x $R/.harness/gate-boundaries.sh ]"
t "adaptador vai para o repositório (R8)" "[ -x $R/.harness/adapters/node.sh ]"
t "dono registrado (D6)"                  "jq -e '.owner==\"Dona Eval <eval@exemplo>\"' $R/.harness/harness.json"
t "teto default é supervisionado (A6)"    "jq -e '.autonomy_ceiling==\"supervisionado\"' $R/.harness/harness.json"
t "typecheck vermelho não virou gate"     "jq -e '.gates.typecheck==null' $R/.harness/harness.json"
t "lint verde virou gate"                 "jq -e '.gates.lint!=null' $R/.harness/harness.json"
t "produção negada em permissão (A2)"     "jq -e '[.permissions.deny[] | select(test(\"prd|prod\"))] | length > 0' $R/.claude/settings.json"
t "leitura de .env negada (A5)"           "jq -e '[.permissions.deny[] | select(test(\"env\"))] | length > 0' $R/.claude/settings.json"
t "produção negada também em hook (A2)"   "grep -q 'deny' $R/.claude/hooks/guard-prod.sh"
t "guarda anti-loop presente (V5)"        "jq -e '.anti_loop_tries==3' $R/.harness/harness.json"
t "/ship só cita comando que existe (C4)" "! grep -q 'npm run typecheck' $R/.claude/commands/ship.md"
t "nenhum arquivo-fonte foi tocado" \
  "diff -r --exclude=.claude --exclude=.harness --exclude='*.cjs' $F/legado-com-ciclos $R"

echo "→ install / fase 3: contexto"
$I/gen-config.sh "$R" --plan "$RP" --owner "Dona Eval" --fase 3 > "$W/retro.f3.json" 2>/dev/null
t "um CLAUDE.md por módulo existente (C3)" \
  "[ -f $R/src/faturamento/CLAUDE.md ] && [ -f $R/src/cobranca/CLAUDE.md ]"
t "módulo declara o que possui e o que nunca importa" \
  "grep -q 'Possui:' $R/src/comum/CLAUDE.md && grep -q 'Nunca importa:' $R/src/comum/CLAUDE.md"
t "módulo de módulo cabe em ~15 linhas (C5)" \
  "[ \$(wc -l < $R/src/comum/CLAUDE.md) -le 15 ]"
t "não sobrescreve CLAUDE.md alheio (D3)" \
  "grep -q 'pnpm build' $R/CLAUDE.md"
t "e deixa a proposta ao lado para merge" \
  "[ -f $R/.harness/CLAUDE.md.proposto ]"
t "a proposta cabe em ~60 linhas (C5)"    "[ \$(wc -l < $R/.harness/CLAUDE.md.proposto) -le 60 ]"
t "a proposta não cita comando inexistente (C4)" \
  "! grep -q 'pnpm build' $R/.harness/CLAUDE.md.proposto"

echo "→ install / idempotência (D3)"
h1=$(find "$R" -type f -exec sha256sum {} \; | sort -k2 | sha256sum)
$I/gen-config.sh "$R" --plan "$RP" --owner "Outro Dono" --fase 1 >/dev/null 2>&1
$I/gen-config.sh "$R" --plan "$RP" --owner "Outro Dono" --fase 3 >/dev/null 2>&1
h2=$(find "$R" -type f -exec sha256sum {} \; | sort -k2 | sha256sum)
t "rodar duas vezes não altera nada"      "[ '$h1' = '$h2' ]"
t "e não troca o dono já registrado"      "jq -e '.owner==\"Dona Eval <eval@exemplo>\"' $R/.harness/harness.json"
echo "# nota do time" >> "$R/src/comum/CLAUDE.md"
$I/gen-config.sh "$R" --plan "$RP" --owner "Dona Eval" --fase 3 > "$W/retro.f3b.json" 2>/dev/null
t "customização manual é preservada"      "grep -q 'nota do time' $R/src/comum/CLAUDE.md"
t "e o pulo é relatado, não silenciado" \
  "jq -e '[.pulados[] | select(test(\"src/comum\"))] | length==1' $W/retro.f3b.json"

echo "→ install / dono é obrigatório (D6)"
t "gen-config recusa sem dono" \
  "! $I/gen-config.sh $R --plan $RP --fase 1"
t "scaffold recusa sem dono" \
  "! $I/scaffold.sh $F/repo-vazio"
