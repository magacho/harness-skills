---
description: Explora e planeja antes de escrever código
---
Não escreva código nesta rodada.

1. Leia o `CLAUDE.md` raiz e o `CLAUDE.md` dos módulos que a tarefa toca.
2. Diga em quais módulos a mudança cai e se ela respeita o grafo de dependência.
   Se exigir import novo entre módulos, PARE e diga: isso é ADR, não tarefa.
3. Liste os arquivos que serão tocados e o blast radius.
4. Diga como a mudança será verificada — qual teste, qual comando.
5. Aponte o que não sabe e precisa de resposta minha. Pergunte em lote, com um
   default proposto para cada item, e agrupado por assunto. Pare quando as
   respostas deixarem de mudar a implementação.
6. Entregue duas coisas por escrito: as **premissas assumidas** e o **critério
   de aceitação**.

Se a demanda já veio detalhada, confirme e passe. Não re-interrogue.

Saída: plano curto. Espere aprovação.
