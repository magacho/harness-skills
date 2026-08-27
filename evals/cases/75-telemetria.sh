#!/usr/bin/env bash
# Caso: a TRILHA (V12 → R6) e a honestidade do leitor (V13 → R6). Um harness que
# protege sem registrar não é auditável — e telemetria que derruba um hook, vaza
# argumento ou imprime zero sem dizer sobre quanto tempo custa mais que entrega.
Y=$W/tel
legado_instalado tel

L="$Y/.harness/log.sh"
G="$Y/.claude/hooks/guard-prod.sh"
V="$Y/.claude/hooks/verify.sh"
E="$Y/.claude/hooks/on-edit.sh"
ST="$Y/.harness/stats.sh"
tel_log() { find "$Y/.harness/log" -name 'events-*.jsonl' -exec cat {} +; }
# O hook recebe o JSON do Claude Code em stdin e a raiz por variável de ambiente.
guard() { echo "{\"session_id\":\"e1\",\"tool_input\":{\"command\":$(jq -Rn --arg c "$1" '$c')}}" \
          | CLAUDE_PROJECT_DIR="$Y" "$G"; }

echo "→ install / a trilha existe e é instalada inteira (V12 → R6)"
t "emissor no repositório, não no plugin (D1)" "[ -f $L ]"
t "leitor executável, e é comando à mão (D5)"  "[ -x $ST ]"
t "comando /stats instalado"                   "[ -f $Y/.claude/commands/stats.md ]"
t "telemetria ligada por default, explícita"   "jq -e '.telemetry.enabled==true and .telemetry.retention_months==6' $Y/.harness/harness.json"
t "a trilha se ignora de dentro de .harness/"   "grep -qx '\*' $Y/.harness/log/.gitignore"
t "e o .gitignore da raiz não é tocado (§1)"    "! grep -q harness $Y/.gitignore 2>/dev/null"
t "e a permissão do leitor está no settings"   "jq -e '[.permissions.allow[]|select(test(\"stats.sh\"))]|length==1' $Y/.claude/settings.json"
t "cleanup.sh NÃO emite: a trilha não é da sessão" \
  "! grep -q harness_log $Y/.claude/hooks/cleanup.sh"

echo "→ install / o guard registra o que barrou, com o motivo (V12)"
t "deny de tag vira linha com rótulo"          "guard 'git tag -a v1.2.0 -m x' >/dev/null; tel_log | jq -e -s 'map(select(.ev==\"guard\" and .verdict==\"deny\"))|length==1 and (.[0].reason==\"release\")'"
t "e o comando barrado é gravado por inteiro"  "tel_log | jq -e -s '[.[]|select(.verdict==\"deny\")][0].subject|test(\"git tag\")'"
t "deny de deploy tem o SEU rótulo"            "guard './ops/deploy.sh --env prd' >/dev/null; tel_log | jq -e -s '[.[]|select(.verdict==\"deny\")][-1].reason==\"deploy-prod\"'"
t "leitura de produção passa e vira allow"     "guard 'kubectl --context prod get pods' >/dev/null; tel_log | jq -e -s '[.[]|select(.verdict==\"allow\")]|length==1'"

echo "→ install / o allow NÃO pode vazar argumento (V12, regra nº 2)"
guard 'API_KEY=segredo-que-nao-pode-vazar pnpm run build' >/dev/null
t "só o binário entra na trilha"               "tel_log | jq -e -s '[.[]|select(.verdict==\"allow\")][-1].subject==\"pnpm\"'"
t "e o segredo não aparece em lugar nenhum"    "! grep -q 'segredo-que-nao-pode-vazar' $(find $Y/.harness/log -name 'events-*.jsonl')"
guard 'psql postgres://user:senha123@host/db -c "select 1"' >/dev/null
t "nem a senha da URL de conexão"              "! grep -q 'senha123' $(find $Y/.harness/log -name 'events-*.jsonl')"

echo "→ install / o emissor não pode derrubar hook nenhum (V12, regra nº 1)"
# Trilha sem permissão de escrita é o "disco cheio" reproduzível. `chmod` no
# DIRETÓRIO não bastaria: append em arquivo que já existe não precisa de escrita
# no diretório, e o teste passaria sem ter impedido nada.
n_antes_ro=$(tel_log | wc -l)
chmod 400 "$Y"/.harness/log/events-*.jsonl
t "trilha não gravável: o guard segue decidindo" \
  "guard 'git tag -a v9 -m x' | jq -e '.hookSpecificOutput.permissionDecision==\"deny\"'"
t "e o evento é perdido em silêncio, sem erro" \
  "[ \$(tel_log | wc -l) -eq $n_antes_ro ]"
chmod 600 "$Y"/.harness/log/events-*.jsonl
t "o hook não fala nada além da decisão (stdout é protocolo)" \
  "[ -z \"\$(guard 'ls -la')\" ]"
t "harness.json ausente: emissor vira no-op, sem criar estado" \
  "mv $Y/.harness/harness.json $W/tel.cfg; guard 'ls' >/dev/null; r=\$?; mv $W/tel.cfg $Y/.harness/harness.json; [ \$r -eq 0 ]"

echo "→ install / o gate de turno registra veredito, gate e duração"
printf '%s\n' "$Y/src/comum/moeda.js" > "/tmp/cc-touched-e2-main.txt"
echo '{"session_id":"e2"}' | CLAUDE_PROJECT_DIR="$Y" "$V" >/dev/null 2>&1
t "turno com escopo vira evento de verify"     "tel_log | jq -e -s '[.[]|select(.ev==\"verify\")]|length>=1'"
t "com contagem de arquivos e duração em ms"   "tel_log | jq -e -s '[.[]|select(.ev==\"verify\")][-1] | (.files|type==\"number\") and (.ms|type==\"number\")'"
rm -f /tmp/cc-touched-e2-main.txt
echo '{"session_id":"e3"}' | CLAUDE_PROJECT_DIR="$Y" "$V" >/dev/null 2>&1
t "escopo vazio sai cedo e diz por quê"        "tel_log | jq -e -s '[.[]|select(.ev==\"verify\" and .verdict==\"skip\")][-1].reason==\"escopo-vazio\"'"

echo "→ install / a edição entra com caminho relativo, nunca absoluto"
echo "{\"session_id\":\"e4\",\"tool_input\":{\"file_path\":\"$Y/src/comum/moeda.js\"}}" \
  | CLAUDE_PROJECT_DIR="$Y" "$E" >/dev/null 2>&1
t "evento de edição gravado"                   "tel_log | jq -e -s '[.[]|select(.ev==\"edit\")]|length==1'"
t "e o caminho não vaza o layout da máquina"   "tel_log | jq -e -s '[.[]|select(.ev==\"edit\")][0].path==\"src/comum/moeda.js\"'"

echo "→ install / o leitor responde as cinco perguntas do dono"
# A saída vai para variável antes do grep. Sob `pipefail`, `stats.sh | grep -q`
# devolve 141: o grep fecha o pipe no primeiro casamento, o script morre de
# SIGPIPE, e o teste reprovaria justamente quando o texto ESTÁ lá.
stats() { (cd "$Y" && ./.harness/stats.sh "$@"); }
humano=$(stats); maquina=$(stats --json)
t "bloqueios com total e motivo"     "grep -q 'BLOQUEIOS DO guard-prod' <<<\"\$humano\""
t "e o comando barrado aparece"      "grep -q 'git tag -a v1.2.0' <<<\"\$humano\""
t "--denies lista um por linha"      "[ \$(stats --denies | wc -l) -eq 2 ]"
t "--json é o mesmo conteúdo"        "jq -e '.guard.deny==2 and (.verify.execucoes>=2)' <<<\"\$maquina\""
t "cobertura mostra o gate ausente como LACUNA, não silêncio" \
  "jq -e '[.cobertura.lacunas[]|select(test(\"typecheck\"))]|length==1' <<<\"\$maquina\""
t "e o gate ligado como ligado"      "jq -e '.cobertura.ligados|index(\"size\")' <<<\"\$maquina\""
t "janela inválida é recusada"       "! stats --since ontem 2>/dev/null"

echo "→ install / zero medido não é zero desconhecido (V13 → R6)"
t "trilha curta: o relatório diz que não há dado sobre o resto" \
  "jq -e '.telemetria.cobre_a_janela==false' <<<\"\$maquina\""
t "e o texto humano não afirma que nada aconteceu" \
  "o=\$(stats --since 7d); grep -q 'MAIS CURTA que a janela' <<<\"\$o\""
t "sem transcript, o modo de permissão é 'sem dado', não 'tudo bem'" \
  "(cd $Y && HOME=$W/sem-home ./.harness/stats.sh --json) | jq -e '.permissao.allow_efetivo==null'"

echo "→ install / bypassPermissions é dito em voz alta"
tsdir="$W/home-tel/.claude/projects/$(printf '%s' "$Y" | sed 's/[^A-Za-z0-9]/-/g')"
mkdir -p "$tsdir"
printf '{"type":"permission-mode","permissionMode":"bypassPermissions","sessionId":"a"}\n{"type":"permission-mode","permissionMode":"default","sessionId":"b"}\n' > "$tsdir/s.jsonl"
t "o modo predominante é lido do transcript" \
  "(cd $Y && HOME=$W/home-tel ./.harness/stats.sh --json) | jq -e '.permissao.modo_predominante==\"bypassPermissions\"'"
t "e o relatório avisa que o allow virou decoração" \
  "o=\$(cd $Y && HOME=$W/home-tel ./.harness/stats.sh); grep -q 'permissions.allow do .claude/settings.json não tem efeito' <<<\"\$o\""

echo "→ install / telemetria desligada não vira relatório vazio"
jq '.telemetry.enabled=false' "$Y/.harness/harness.json" > "$W/tel.off" && mv "$W/tel.off" "$Y/.harness/harness.json"
n_antes=$(tel_log | wc -l)
t "o emissor vira no-op imediato"    "guard 'git tag -a v3 -m x' >/dev/null; [ \$(tel_log | wc -l) -eq $n_antes ]"
t "e o leitor diz isso em vez de imprimir vazio" \
  "o=\$(stats); grep -q 'TELEMETRIA DESLIGADA' <<<\"\$o\""
jq '.telemetry.enabled=true' "$Y/.harness/harness.json" > "$W/tel.on" && mv "$W/tel.on" "$Y/.harness/harness.json"
t "e reinstalar NÃO religa o que o projeto desligou" \
  "jq '.telemetry.enabled=false' $Y/.harness/harness.json > $W/t2 && mv $W/t2 $Y/.harness/harness.json;
   $I/gen-config.sh $Y --plan $W/tel.plan.json --owner X --fase 1 >/dev/null 2>&1;
   jq -e '.telemetry.enabled==false' $Y/.harness/harness.json"

echo "→ install / retrofit: hook editado à mão é enxertado, nunca sobrescrito (D3)"
Z=$W/tel-retro
legado_instalado tel-retro
# Hook da versão anterior — sem telemetria — com uma regra do projeto ao fim.
git show HEAD:plugin/skills/install/assets/retrofit/hooks/guard-prod.sh \
  | sed 's/__VERSION__/0.2.9 sha=0000000000000000/' > "$Z/.claude/hooks/guard-prod.sh"
python3 - "$Z/.claude/hooks/guard-prod.sh" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("\nexit 0\n", '\n# regra local do time\ngrep -qiE "run_etl" <<<"$cmd" && deny "O ETL roda por agendamento."\n\nexit 0\n')
open(p, "w").write(s)
PY
chmod +x "$Z/.claude/hooks/guard-prod.sh"
$I/gen-config.sh "$Z" --plan "$W/tel-retro.plan.json" --owner X --fase 1 > "$W/tel-retro.f1b.json" 2>/dev/null
t "o hook é PULADO, não sobrescrito" \
  "jq -e '[.pulados[]|select(test(\"guard-prod\"))]|length==1' $W/tel-retro.f1b.json"
t "e o enxerto é relatado, não silencioso" \
  "jq -e '[.telemetria[]|select(.hook==\"guard-prod.sh\" and .acao==\"instrumentado\")]|length==1' $W/tel-retro.f1b.json"
t "a regra local do projeto sobrevive"     "grep -q run_etl $Z/.claude/hooks/guard-prod.sh"
t "e continua bloqueando de verdade" \
  "echo '{\"session_id\":\"r1\",\"tool_input\":{\"command\":\"python run_etl.py\"}}' \
   | CLAUDE_PROJECT_DIR=$Z $Z/.claude/hooks/guard-prod.sh | jq -e '.hookSpecificOutput.permissionDecision==\"deny\"'"
t "o bloqueio local entra na trilha" \
  "find $Z/.harness/log -name 'events-*.jsonl' -exec cat {} + | jq -e -s '[.[]|select(.verdict==\"deny\")]|length==1'"
t "sem rótulo inventado: a assinatura antiga não o carrega" \
  "find $Z/.harness/log -name 'events-*.jsonl' -exec cat {} + | jq -e -s '[.[]|select(.verdict==\"deny\")][0].reason==\"nao-rotulado\"'"
$I/gen-config.sh "$Z" --plan "$W/tel-retro.plan.json" --owner X --fase 1 > "$W/tel-retro.f1c.json" 2>/dev/null
t "rodar de novo não enxerta uma segunda camada" \
  "jq -e '[.telemetria[]|select(.acao==\"ja-instrumentado\")]|length>=1' $W/tel-retro.f1c.json"
t "e cada bloqueio continua valendo uma linha só" \
  "rm -f $Z/.harness/log/events-*.jsonl;
   echo '{\"session_id\":\"r2\",\"tool_input\":{\"command\":\"python run_etl.py\"}}' \
   | CLAUDE_PROJECT_DIR=$Z $Z/.claude/hooks/guard-prod.sh >/dev/null;
   [ \$(find $Z/.harness/log -name 'events-*.jsonl' -exec cat {} + | wc -l) -eq 1 ]"

echo "→ install / hook que não dá para enxertar é declarado, não silenciado (D4)"
printf '#!/usr/bin/env bash\ninput=$(cat)\nexit 0\n' > "$Z/.claude/hooks/verify.sh"
t "a recusa vem com o motivo" \
  "$I/instrument-hook.sh $Z verify | jq -e '.acao==\"nao-instrumentado\" and (.detalhe|test(\"fail\\\\(\\\\)\"))'"
t "e o hook fica intacto" \
  "[ \$(wc -l < $Z/.claude/hooks/verify.sh) -eq 3 ]"

echo "→ install / modo B nasce com trilha (V12)"
N=$W/tel-novo; mkdir -p "$N"
$I/scaffold.sh "$N" --owner "Dona Eval" >/dev/null 2>&1
t "emissor e leitor no scaffold"    "[ -f $N/.harness/log.sh ] && [ -x $N/.harness/stats.sh ]"
t "comando /stats no scaffold"      "[ -f $N/.claude/commands/stats.md ]"
t "telemetria no harness.json"      "jq -e '.telemetry.enabled==true' $N/.harness/harness.json"
t "log ignorado de dentro de .harness/" "grep -qx '\*' $N/.harness/log/.gitignore"
t "e o CLAUDE.md do scaffold cita o leitor, que já existe (C4)" \
  "grep -q 'harness/stats.sh' $N/CLAUDE.md && [ -x $N/.harness/stats.sh ]"
t "permissão do leitor no settings" "jq -e '[.permissions.allow[]|select(test(\"stats.sh\"))]|length==1' $N/.claude/settings.json"
t "e o hook do modo B é o mesmo do modo A, instrumentado" \
  "grep -q harness_log $N/.claude/hooks/guard-prod.sh"
