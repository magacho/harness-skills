# <NOME DO PROJETO>

TypeScript + Node 22, Postgres, deploy em <stg: ECS staging / prd: ECS prod>.

## Comandos
- `pnpm test` — vitest
- `pnpm typecheck` — zero erro
- `pnpm lint`
- `pnpm boundaries` — dependency-cruiser, valida fronteiras de módulo
- `./ops/investigate.sh stg|prd` — investigação read-only
- `./ops/deploy.sh stg` — deploy de staging

## Arquitetura: quatro módulos, dependência em uma direção

    web ──▶ api/contracts
             api ──▶ domain ◀── data
                       ▲          │
                       └──────────┘  (data implementa domain/ports)
    todos ──▶ shared

| módulo | responsabilidade | pode importar |
|---|---|---|
| `modules/shared` | tipos e utils puros | nada |
| `modules/domain` | regras de negócio, puro | shared |
| `modules/data` | acesso a dados, dono do schema | shared, domain |
| `modules/api` | HTTP e composition root | shared, domain, data, contracts |
| `modules/web` | interface | shared, `api/contracts` (só tipos) |

Cada módulo tem seu próprio `CLAUDE.md`. Leia o do módulo antes de editar dentro dele.

## Nunca
- Efeito colateral em `modules/domain` — I/O sai por porta declarada em `domain/ports/`
- `modules/web` importando `domain` ou `data` direto
- Duas partes lendo a mesma tabela: `modules/data` é o único dono do schema
- Editar migration já aplicada — criar nova
- Commitar `.env*`
- Escrever em produção. Prod é read-only para você: investigar sim, alterar não

## Ao terminar uma tarefa
Um hook roda lint, typecheck e validação de fronteiras nos arquivos desta sessão.
Se ele reportar erro, corrija antes de reportar pronto — não é opcional, e não é
sobre trabalho de outra pessoa.

## Mudança de fronteira
Alterar o grafo de dependência permitido exige ADR em `docs/adr/` e alteração
explícita de `.dependency-cruiser.js`. Não contorne a regra para fazer a tarefa
passar — se a regra está errada, discuta antes.
