# Ambiente de staging. Sem segredo aqui — só coordenadas.
export ENV_NAME="stg"
export AWS_PROFILE="stg"
export AWS_REGION="us-east-1"
export ECS_CLUSTER="app-stg"
export ECS_SERVICE="api-stg"
export LOG_GROUP="/ecs/api-stg"
export HEALTH_URL="https://api.stg.example.com/health"
export DEPLOY_ALLOWED="true"
