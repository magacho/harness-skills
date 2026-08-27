---
description: Mostra a trilha do harness gravada nesta máquina — bloqueios, reprovações de gate e atividade, deste repositório ou de todos os que têm trilha.
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/harness-stats.sh *)
---

O script já rodou: a saída dele está logo abaixo, injetada antes desta mensagem
chegar até você (`!` = injeção dinâmica). **Não rode nada.**

!`"${CLAUDE_PLUGIN_ROOT}/scripts/harness-stats.sh"`

## O que fazer com isso

Repita o bloco acima para o usuário **palavra por palavra, dentro de um bloco de
código**, preservando alinhamento e linhas em branco. Ele pediu para ver o que
está gravado; resumir ou reformatar é perder a informação.

Se no lugar da saída aparecer o texto do comando em vez do resultado, a injeção
não rodou neste ambiente: aí sim execute o script com o Bash e cole a saída.

**Este comando mostra, não interpreta.** Quem interpreta é o `/stats` que a
instalação escreve dentro do repositório — ele aponta o gate que nunca disparou,
a catraca parada e a lacuna de cobertura. Aqui o trabalho é outro: exibir o que
os hooks gravaram, neste repositório ou em todos os da máquina.

## Só então, e só se houver uma destas

Sem nenhuma delas, o bloco basta. Não comente.

- **`sem-emissor`** — o harness daquele repositório é anterior à `0.3.0` e não
  registra nada. `0 evento` ali **não** quer dizer que nada aconteceu: quer dizer
  que ninguém estava medindo. Ofereça rodar `harness:install` de novo; é
  idempotente, e em hook editado à mão a telemetria é enxertada sem sobrescrever
  as regras locais.
- **`desligada`** — `telemetry.enabled: false`. É decisão registrada do projeto,
  não defeito. Só mencione se o usuário estranhar o vazio.
- **`vazia`** — trilha ligada e ainda sem evento. Diga que ela enche a partir do
  próximo comando, edição ou fim de turno.
- **modo de permissão `bypassPermissions`** — o `permissions.allow` do
  `settings.json` daquele repositório não tem efeito algum, e a trava de produção
  passa a depender só do hook (A2 → R5). Vale dizer uma vez.

Outras janelas, se o usuário pedir: `--since 7d`, `--all` (a máquina inteira),
`--json`, ou um caminho para o relatório completo de um repositório específico.
