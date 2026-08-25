---
description: Diagnostica um problema em stg ou prd, sem alterar nada
argument-hint: stg|prd [sintoma]
---
Investigue o ambiente **$1**. Sintoma relatado: $2

1. Rode `./ops/investigate.sh $1 --all` e leia a saída inteira.
2. Correlacione: o sintoma começou junto com o último deploy? Com uma migration?
3. Forme UMA hipótese principal e diga qual evidência a confirmaria ou refutaria.
4. Se precisar de mais dado, rode outra leitura — nunca uma mutação.

Produção é read-only. Não proponha alteração em prd: proponha a mudança no
código, com plano de release para um humano executar.

Saída: cronologia dos fatos, hipótese, evidência que falta, correção proposta.
