# ADR 0001 — Três documentos, nesta ordem

**Status:** aceito

## Contexto
A primeira versão das regras nasceu de baixo para cima, a partir de uma conversa
sobre hooks. Sem intenção declarada, não havia como distinguir regra necessária de
mecanismo que apareceu na conversa.

## Decisão
Três documentos com dependência unidirecional: `INTENT` (por quê) → `HARNESS`
(regras) → `PLAN` (como). Toda regra cita o resultado que serve.

## Consequências
A rastreabilidade é verificável por script e roda no CI. Duas regras da primeira
versão não rastreavam a nada e foram rebaixadas a apêndice — eram vocabulário e
fato de plataforma, não norma.

Custo: mudança no porquê obriga revisar as regras. É o ponto.
