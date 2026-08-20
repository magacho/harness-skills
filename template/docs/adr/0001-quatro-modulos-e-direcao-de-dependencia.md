# ADR 0001 — Quatro módulos e dependência em uma direção

**Status:** aceito · **Data:** <preencher>

## Contexto
Mudança que atravessa camadas exige carregar o sistema inteiro no contexto — tanto
para humano quanto para agente. Queremos que uma feature típica toque um módulo.

## Decisão
Quatro módulos, mais `shared` como folha:

    web ──▶ api/contracts ; api ──▶ domain ◀── data ; todos ──▶ shared

- `domain` é puro: I/O sai por porta em `domain/ports/`
- `data` é o único dono do schema
- `api` é o composition root e o único que conhece todo mundo
- `web` só vê `api/contracts`

A regra é executável em `.dependency-cruiser.js` e roda no hook `Stop`.

## Consequências
Positivas: fronteira verificável, não acordada; teste de domínio sem container;
troca de infra sem tocar negócio.

Custo aceito: uma porta e um adaptador a mais por integração nova; `api/contracts`
passa a ser API versionada com política de compatibilidade.

## Como mudar esta decisão
Novo ADR + alteração explícita de `.dependency-cruiser.js`. Contornar a regra para
fazer uma tarefa passar não é permitido.
