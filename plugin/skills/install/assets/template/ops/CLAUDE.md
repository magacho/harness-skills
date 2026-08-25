# ops — deploy e investigação

Dois ambientes: `stg` e `prd`. A assimetria é deliberada.

| ação | stg | prd |
|---|---|---|
| investigar (logs, health, migrations) | livre | livre, read-only |
| deploy | você pode | humano apenas |
| escrever no banco | via migration | nunca por aqui |

- `./ops/investigate.sh <env> [--health|--logs|--migrations|--deploys|--all]`
  Read-only por construção. Use isto para diagnosticar, sempre, antes de propor fix
- `./ops/deploy.sh stg` — deploy de staging
- `./ops/deploy.sh prd` — bloqueado por hook e por permissão. Não tente contornar:
  se o deploy de produção é necessário, escreva o plano e entregue ao humano

Ao investigar um incidente: colete evidência primeiro (health, logs, último deploy,
estado de migration), forme uma hipótese, e só então proponha mudança. Não altere
staging para "testar uma teoria" antes de dizer qual é a teoria.
