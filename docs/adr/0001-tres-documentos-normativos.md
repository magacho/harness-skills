# ADR 0001 — Três documentos, nesta ordem

**Status:** aceito

## Contexto
A primeira versão das regras nasceu de baixo para cima, a partir de uma conversa
sobre hooks. Sem intenção declarada, não havia como distinguir regra necessária de
mecanismo que apareceu na conversa.

## Decisão
Três documentos com dependência unidirecional: `INTENT` (por quê) → `HARNESS`
(regras) → `PLAN` (como). Toda regra cita o resultado que serve.

## Escopo — o que "três" quer dizer
Três documentos formam a **cadeia normativa**, e é dela que a ordem fala. Outros
documentos existem e não a contradizem: `docs/adapters/README.md` é contrato de
extensão (normativo dentro do seu escopo, e o `validate.sh` o exige presente),
`CONFORMIDADE.md` é derivado e descritivo — se divergir do `HARNESS.md`, o
`HARNESS.md` manda — e `USAGE.md` é guia de uso. Nenhum deles cria regra.

## Consequências
A rastreabilidade é verificável por script e roda no CI. Duas regras da primeira
versão não rastreavam a nada e foram rebaixadas a apêndice — eram vocabulário e
fato de plataforma, não norma.

Custo: mudança no porquê obriga revisar as regras. É o ponto.
