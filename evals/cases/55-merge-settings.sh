#!/usr/bin/env bash
# Caso: o merge de .claude/settings.json. Um reinstall apagava as negações que o
# projeto tinha escrito à mão e reportava sucesso — o defeito mais caro que o
# harness já teve, porque o dano era invisível e o arquivo é justamente onde
# mora a garantia (A2/A8 → R5).
MS=$I/merge-settings.jq
m() { jq -c -n -f "$MS" --slurpfile v "$1" --slurpfile n "$2"; }
D=$W/ms; mkdir -p "$D"

echo "→ install / merge de settings.json (a função, isolada)"
printf '{"permissions":{"deny":["TRAVA_A","TRAVA_B"]}}' > "$D/proj.json"
printf '{"permissions":{"deny":["TEMPLATE_X"]}}'        > "$D/harn.json"
t "negação do projeto sobrevive (A7)" \
  "m $D/proj.json $D/harn.json | jq -e '.permissions.deny == [\"TEMPLATE_X\",\"TRAVA_A\",\"TRAVA_B\"]'"
t "e a do harness entra junto"        "m $D/proj.json $D/harn.json | jq -e '.permissions.deny | index(\"TEMPLATE_X\")'"

# `.[0] * .[1]` do jq parece resolver e não resolve: em array, a direita
# SUBSTITUI. É a linha exata que causou a perda.
t "prova que o merge ingênuo perderia" \
  "! jq -s '.[0] * .[1]' $D/proj.json $D/harn.json | jq -e '.permissions.deny | index(\"TRAVA_A\")'"

printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"./meu-guard.sh"}]}]}}' > "$D/ph.json"
printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"${CLAUDE_PROJECT_DIR}/.claude/hooks/guard-prod.sh"}]}]}}' > "$D/hh.json"
t "hook do projeto sobrevive ao merge" \
  "m $D/ph.json $D/hh.json | jq -e '[.hooks.PreToolUse[].hooks[0].command] | index(\"./meu-guard.sh\")'"
t "e o hook do harness entra"         "m $D/ph.json $D/hh.json | jq -e '.hooks.PreToolUse | length == 2'"

# Substituir a entrada do harness, e não somá-la, é o que mantém a idempotência
# quando a definição muda de versão. Somar+unique deixaria as duas.
printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"${CLAUDE_PROJECT_DIR}/.claude/hooks/verify.sh","timeout":120}]}]}}' > "$D/v1.json"
printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"${CLAUDE_PROJECT_DIR}/.claude/hooks/verify.sh","timeout":240}]}]}}' > "$D/v2.json"
t "hook do harness é substituído, não somado" "m $D/v1.json $D/v2.json | jq -e '.hooks.Stop | length == 1'"
t "e fica com a definição nova"               "m $D/v1.json $D/v2.json | jq -e '.hooks.Stop[0].hooks[0].timeout == 240'"

printf '{"model":"sonnet","includeCoAuthoredBy":false}' > "$D/e1.json"
printf '{"model":"opus"}'                               > "$D/e2.json"
t "escalar: o novo vence"                     "m $D/e1.json $D/e2.json | jq -e '.model == \"opus\"'"
t "chave do projeto que o harness não conhece fica" \
  "m $D/e1.json $D/e2.json | jq -e '.includeCoAuthoredBy == false'"
t "não inventa permissions que ninguém tinha" "m $D/e1.json $D/e2.json | jq -e 'has(\"permissions\") | not'"
t "projeto sem settings: só o do harness"     "m /dev/null $D/harn.json | jq -e '.permissions.deny == [\"TEMPLATE_X\"]'"

echo "→ install / merge no gerador: recusa em vez de perder"
# Fixture versionado (legado-customizado/): cinco negações, um allow, um hook
# PreToolUse próprio e uma chave que o harness não conhece. Cada um é um caminho
# de perda distinto do defeito que levou 23 negações a 12.
S=$W/ms-real
cp -a "$F/legado-customizado" "$S"
$I/plan-install.sh "$S" > "$W/ms-real.plan.json" 2>/dev/null
$I/gen-config.sh "$S" --plan "$W/ms-real.plan.json" --owner "Dona Eval <eval@exemplo>" --fase 1 > "$W/ms.f1.json" 2>/dev/null
# Por string exata, não por regex: o deny base do harness também casa "git tag",
# e contar por padrão frouxo media a soma dos dois lados em vez da sobrevivência
# do lado do projeto.
t "as 5 negações do projeto sobrevivem ao reinstall" \
  "jq -e --argjson p '[\"Bash(git tag -a v*)\",\"Bash(pnpm etl:*)\",\"Bash(gh workflow run*)\",\"Read(./**/*key*.json)\",\"mcp__supabase__apply_migration\"]' \
     '(\$p - .permissions.deny) | length == 0' $S/.claude/settings.json"
t "as do harness entraram por cima"     "jq -e '.permissions.deny | length > 10' $S/.claude/settings.json"
t "a trava de produção do harness está lá (A2)" \
  "jq -e '[.permissions.deny[] | select(test(\"prd|prod\"))] | length > 0' $S/.claude/settings.json"
t "o allow do projeto sobrevive"        "jq -e '.permissions.allow | index(\"Bash(pnpm test:*)\")' $S/.claude/settings.json"
t "o hook do projeto continua lá"       "jq -e '[.hooks.PreToolUse[].hooks[0].command] | index(\"./scripts/meu-guard.sh\")' $S/.claude/settings.json"
t "e a chave que não é nossa também"    "jq -e '.model == \"opus\"' $S/.claude/settings.json"

# Idempotência sobre repositório CUSTOMIZADO, e na árvore inteira — não só no
# settings.json. É o que o `## Limites` da skill promete, e o que o defeito do
# merge violava sem que nada medisse.
h1=$(find "$S" -type f -exec sha256sum {} \; | sort -k2 | sha256sum)
$I/gen-config.sh "$S" --plan "$W/ms-real.plan.json" --owner "Outro Dono" --fase 1 >/dev/null 2>&1
h2=$(find "$S" -type f -exec sha256sum {} \; | sort -k2 | sha256sum)
t "reinstalar sobre customização não altera um byte (D3)" "[ '$h1' = '$h2' ]"

# JSON inválido é o único caminho em que o merge não pode ser feito. Antes o
# fallback escrevia de qualquer forma; agora recusa, e diz que a garantia não
# entrou — silêncio aqui é pior que erro.
B=$W/ms-bad
legado_instalado ms-bad
printf '{"permissions": {"deny": ["A",]}' > "$B/.claude/settings.json"
hb=$(sha256sum "$B/.claude/settings.json" | cut -d' ' -f1)
$I/gen-config.sh "$B" --plan "$W/ms-bad.plan.json" --owner "Dona Eval" --fase 1 > "$W/msb.f1.json" 2>/dev/null
t "settings inválido não é sobrescrito (D3)" "[ '$hb' = \"\$(sha256sum $B/.claude/settings.json | cut -d' ' -f1)\" ]"
t "e não entra em escritos"                  "! jq -e '.escritos | map(select(test(\"settings\"))) | length > 0' $W/msb.f1.json"
t "entra em pulados, com o motivo"           "jq -e '[.pulados[] | select(test(\"settings.json\"))] | length == 1' $W/msb.f1.json"
t "dizendo que a garantia não foi instalada" \
  "jq -r '.pulados[]' $W/msb.f1.json | grep -q 'PERMISSÕES NÃO INSTALADAS'"
t "e deixa a proposta ao lado para merge à mão" "[ -f $B/.harness/settings.proposto.json ]"
