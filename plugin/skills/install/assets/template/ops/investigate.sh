#!/bin/bash
# Investigação read-only. Seguro em produção por construção:
# só verbos de leitura, nenhum comando de mutação.
set -uo pipefail

env="${1:-}"; shift || true
[[ "$env" =~ ^(stg|prd)$ ]] || { echo "uso: investigate.sh <stg|prd> [--health|--logs|--migrations|--deploys|--all]"; exit 1; }
source "$(dirname "$0")/env.$env.sh"

what="${1:---all}"
line() { printf '\n── %s ─────────────────────────\n' "$1"; }

health() {
  line "health ($ENV_NAME)"
  curl -sS -m 10 -o /tmp/h.json -w 'HTTP %{http_code} em %{time_total}s\n' "$HEALTH_URL" || true
  head -c 800 /tmp/h.json 2>/dev/null; echo
}

deploys() {
  line "último deploy"
  aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" \
    --query 'services[0].{desired:desiredCount,running:runningCount,taskDef:taskDefinition,deployments:deployments[0].{status:status,createdAt:createdAt,rollout:rolloutState}}' \
    --output table 2>&1 | head -30
}

logs() {
  line "erros nos últimos 30min"
  aws logs filter-log-events --log-group-name "$LOG_GROUP" \
    --start-time "$(( ($(date +%s) - 1800) * 1000 ))" \
    --filter-pattern '?ERROR ?FATAL ?Exception' \
    --max-items 40 --query 'events[].message' --output text 2>&1 | tail -40
}

migrations() {
  line "estado das migrations"
  # read-only: apenas SELECT na tabela de controle
  echo "→ pnpm db:status --env $ENV_NAME   (implemente conforme sua ferramenta)"
}

case "$what" in
  --health) health ;;
  --logs) logs ;;
  --deploys) deploys ;;
  --migrations) migrations ;;
  --all|*) health; deploys; logs; migrations ;;
esac

line "próximo passo"
echo "Forme a hipótese ANTES de mudar qualquer coisa. Diga qual é, e o que a confirmaria."
