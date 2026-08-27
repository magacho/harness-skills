#!/usr/bin/env bash
# PreToolUse — última linha de defesa contra escrita em produção.
# harness-generated: __VERSION__
#
# A2 → R5: dupla trava. A permissão em .claude/settings.json cobre o padrão
# óbvio; este hook cobre a variação criativa. Nenhum dos dois sozinho basta —
# e o teto de autonomia nunca depende deste arquivo (P2/A8), porque uma flag de
# execução desliga hook.
#
# Desenho das regras, aprendido de um furo real: **não adivinhe o formato do
# argumento, enumere o verbo.** Uma regra que casava `tag` seguido de `v<dígito>`
# era contornada por `git tag -a v1.2.3` — a forma usual de release. Flag nova,
# ordem nova ou nome novo abrem caminho; o conjunto de verbos de escrita, não.
input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")

# V12 → R6: trilha. Este hook era o mais invisível dos quatro — negava sem
# deixar registro em lugar nenhum, e "o que o harness impediu?" era a pergunta
# nº 1 do dono sem resposta possível.
HARNESS_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
HARNESS_SID=$(jq -r '.session_id // "sem-sessao"' <<<"$input")
export HARNESS_ROOT HARNESS_SID
# shellcheck source=/dev/null
source "$HARNESS_ROOT/.harness/log.sh" 2>/dev/null || true
if ! type harness_log >/dev/null 2>&1; then harness_log() { :; }; harness_bin() { :; }; fi

# A4 → R1: recusa que ensina. Diga o que fazer em vez disso.
#
#   deny <rótulo> <texto>
#
# O rótulo é curto e estável, para agrupar na estatística: release, tag-push,
# deploy-prod, prod-write, drop-truncate. Regra acrescentada à mão neste
# repositório escolhe o seu — `etl`, `workflow`, o que descrever o risco local.
# O comando inteiro (truncado) entra na trilha só aqui, no deny: no allow entra
# apenas o binário, porque argumento carrega credencial.
deny() {
  harness_log guard verdict=deny subject="$cmd" reason="$1"
  jq -n --arg r "$2" '{hookSpecificOutput:{hookEventName:"PreToolUse",
    permissionDecision:"deny", permissionDecisionReason:$r}}'
  exit 0
}

# Verbos de leitura. Produção pode ser INVESTIGADA à vontade (A1/A3 → R5): é o
# que separa "toca produção" de "escreve em produção", e negar leitura seria
# reprovar trabalho legítimo — o modo de fracasso nº 1.
LEITURA='\b(describe|get|list|logs|tail|head|status|show|cat|less|grep|diff|filter-log-events|dry-run)\b'

# --- deploy em produção ----------------------------------------------------
# Por segmento, e sem exigir ordem: `PRD=1 ./ops/deploy.sh` põe o ambiente ANTES
# do verbo, e a regra antiga — que pedia prd depois de deploy — deixava passar.
# Por segmento e sem exigir ordem: `PRD=1 ./ops/deploy.sh` põe o ambiente ANTES
# do verbo. Sem fronteira de palavra à esquerda, porque `_` é caractere de
# palavra e `prd_deploy.sh` escapava de `\bdeploy`. O verbo de leitura é a
# válvula: `cat deployment-prod.log` é investigação, não deploy.
while IFS= read -r seg; do
  grep -qiE '(deploy|release|publish)' <<<"$seg" || continue
  grep -qiE '(\b|_)(prd|prod|production)(\b|_)' <<<"$seg" || continue
  grep -qiE "$LEITURA" <<<"$seg" \
    || deny deploy-prod "Deploy em produção é operação humana. Escreva o plano de release — o que muda, blast radius, rollback, migrations — e entregue ao responsável."
done < <(tr '|;&' '\n' <<<"$cmd")

# --- produção read-only ----------------------------------------------------
if grep -qE '(--profile[[:space:]]+(prd|prod)|PRD_|prod-cluster|\.prd\.|--context[[:space:]]+[^ ]*prod)' <<<"$cmd"; then
  grep -qiE "$LEITURA" <<<"$cmd" \
    || deny prod-write "Comando toca produção e não é leitura. Produção é read-only para você: investigue à vontade, altere nada."
fi

# --- destruição de dado ----------------------------------------------------
# `TRUNCATE users` é válido em Postgres e MySQL sem a palavra TABLE, e a regra
# antiga exigia TABLE|DATABASE|SCHEMA. Exigir cliente SQL no comando é o que
# separa isso do `truncate -s 0 app.log` do coreutils, que é trabalho legítimo.
SQL_CLIENT='\b(psql|mysql|mariadb|sqlite3|clickhouse-client|cockroach|mongosh|redis-cli|pgcli)\b'
grep -qiE '\b(drop|truncate)[[:space:]]+(table|database|schema)\b' <<<"$cmd" \
  && deny drop-truncate "DROP/TRUNCATE bloqueado em qualquer ambiente. Crie uma migration."
if grep -qE "$SQL_CLIENT" <<<"$cmd"; then
  grep -qiE '\b(drop|truncate)\b' <<<"$cmd" \
    && deny drop-truncate "DROP/TRUNCATE bloqueado em qualquer ambiente. Crie uma migration."
fi

# --- tag de release --------------------------------------------------------
# Criar tag é irreversível para fora: em muitos projetos ela dispara o pipeline
# de produção em minutos, e o harness não tem como saber se é o caso deste. Por
# isso a criação é humana e a LEITURA passa inteira — negar `git tag --list`
# seria reprovar trabalho legítimo, que é o modo de fracasso nº 1.
tag_escreve() {
  local resto tok escreve=0 lista=0 posicional=0 aguarda=0
  resto=$(sed -E 's/.*[[:space:]]tag\b//' <<<"$1" | sed -E 's/[|;&].*//')
  # shellcheck disable=SC2086
  for tok in $resto; do
    if [[ $aguarda -eq 1 ]]; then aguarda=0; continue; fi
    case "$tok" in
      -a|--annotate|-s|--sign|-f|--force|-d|--delete) escreve=1 ;;
      -m|--message|-F|--file|-u|--local-user) escreve=1; aguarda=1 ;;
      -m*|--message=*|-F*|--file=*|-u*|--local-user=*) escreve=1 ;;
      -l|--list|--contains|--no-contains|--points-at|--merged|--no-merged) lista=1 ;;
      -n|-n[0-9]*|-i|--ignore-case|--sort=*|--format=*|--omit-empty|--color*) lista=1 ;;
      --sort|--format) lista=1; aguarda=1 ;;
      -*) ;;                      # flag desconhecida não decide sozinha
      *)  posicional=1 ;;         # nome de tag ou commit-ish
    esac
  done
  # Argumento posicional sem flag de listagem é criação: `git tag v1.2.3`.
  [[ $escreve -eq 1 ]] || { [[ $posicional -eq 1 ]] && [[ $lista -eq 0 ]]; }
}

if grep -qE '(^|[;&|]|[[:space:]])git\b[^;&|]*[[:space:]]tag\b' <<<"$cmd"; then
  tag_escreve "$cmd" \
    && deny release "Criar ou apagar tag é operação humana: em muitos projetos a tag dispara o deploy de produção. Diga qual versão você quer publicar e eu preparo as notas. Leitura (git tag --list, --points-at, --contains) está liberada."
fi

# Empurrar tag já criada dispara o mesmo pipeline.
grep -qE '(^|[;&|]|[[:space:]])git\b[^;&|]*[[:space:]]push\b[^;&|]*([[:space:]]--tags\b|[[:space:]]--follow-tags\b|refs/tags/)' <<<"$cmd" \
  && deny tag-push "Empurrar tag é o que dispara o pipeline de release. Isso é humano — o commit e o push da branch você pode fazer."

# Passou por todas as regras. Só o binário vai para a trilha: `git`, `pnpm`,
# `psql`. Nunca os argumentos — é neles que mora `API_KEY=...`, e este hook vê
# todo comando que o agente tenta rodar.
harness_log guard verdict=allow subject="$(harness_bin "$cmd")"
exit 0
