#!/bin/bash
# Deploy. stg é livre; prd exige humano + token digitado.
set -euo pipefail

env="${1:-}"
[[ "$env" =~ ^(stg|prd)$ ]] || { echo "uso: deploy.sh <stg|prd>"; exit 1; }
source "$(dirname "$0")/env.$env.sh"

if [[ "$DEPLOY_ALLOWED" != "true" ]]; then
  cat >&2 <<MSG
Deploy em $ENV_NAME é operação humana.

Se você é o agente: pare aqui. Escreva o plano de release (o que muda, blast radius,
plano de rollback, migrations envolvidas) e entregue ao responsável.

Se você é humano: rode com o token explícito.
  ./ops/deploy.sh prd --i-am-human-and-i-reviewed-the-diff
MSG
  [[ "${2:-}" == "--i-am-human-and-i-reviewed-the-diff" ]] || exit 1
  echo "→ confirmação recebida, seguindo com $ENV_NAME"
fi

echo "→ pré-voo"
pnpm typecheck
pnpm lint
pnpm boundaries
pnpm test

echo "→ deploy em $ENV_NAME ($ECS_CLUSTER/$ECS_SERVICE)"
# aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE" --force-new-deployment
echo "(preencha o comando de deploy da sua stack)"

echo "→ verificação pós-deploy"
sleep 20
"$(dirname "$0")/investigate.sh" "$env" --health
