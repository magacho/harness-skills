---
description: Mostra a versão da skill harness em execução e a versão que instalou o harness deste repositório, com dono, teto de autonomia e estado da catraca.
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/harness-version.sh *)
---

O script já rodou: a saída dele está logo abaixo, injetada antes desta mensagem
chegar até você (`!` = injeção dinâmica). **Não rode nada.**

!`"${CLAUDE_PLUGIN_ROOT}/scripts/harness-version.sh" .`

## O que fazer com isso

Repita o bloco acima para o usuário **palavra por palavra, dentro de um bloco de
código**, preservando alinhamento e linhas em branco. Ele pediu para ver a saída
como ela é; resumir ou reformatar é perder a informação.

Se no lugar da saída aparecer o texto do comando em vez do resultado, a injeção
não rodou neste ambiente: aí sim execute o script com o Bash e cole a saída.

## Só então, e só se houver divergência

Sem nenhuma das três abaixo, o bloco basta. Não comente.

- **`← a fonte está à frente`** — o cache do plugin está velho. `/plugin update
  harness@harness-mp` ativa a versão nova.
- **`← instalado por outra versão`** — o harness deste repositório foi escrito
  por outra versão da skill. Ofereça rodar `harness:install` de novo; é
  idempotente e nunca sobrescreve edição manual.
- **`dono: NÃO REGISTRADO`** — violação de D6. Sem alguém nomeado, nenhum modo
  de fracasso tem quem reaja. Diga isso e ofereça registrar.

Se o repositório não tem harness, o script já diz o que fazer. Não insista: nem
todo repositório merece harness.
