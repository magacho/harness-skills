# modules/domain — regras de negócio

Este módulo é **puro**. Ele decide; não executa.

- Pode importar: `modules/shared`
- NUNCA importa: Prisma, pg, Kafka, AWS SDK, Express, React, nada de `data/` ou `api/`
- Todo efeito colateral é declarado como interface em `ports/` e recebido por
  injeção. Quem implementa é `modules/data`; quem conecta é `modules/api`
- Teste de domínio não sobe container: se precisou de banco, a fronteira vazou

Nomeie casos de uso pelo que o negócio faz, não pelo endpoint que os chama.
