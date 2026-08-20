---
description: Prepara o PR — verifica, resume, entrega
---
1. `pnpm typecheck && pnpm lint && pnpm boundaries && pnpm test` — tudo verde.
2. `git diff main...HEAD --stat` e confirme que só há arquivos da tarefa.
   Se tem arquivo fora do escopo, pare e me mostre.
3. Escreva a descrição do PR: o que muda, por quê, como testar, o que NÃO muda.
4. Se algum ADR foi necessário, confirme que está em docs/adr/ e referenciado.

Não faça push nem abra o PR sem eu pedir.
