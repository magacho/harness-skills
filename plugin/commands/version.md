---
description: Mostra a versão da skill harness em execução e a versão que instalou o harness deste repositório, com dono, teto de autonomia e estado da catraca.
allowed-tools: ["Bash"]
---

Rode o script e mostre a saída ao usuário **como ela veio**, sem reformatar:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/harness-version.sh" .
```

O script é a fonte da verdade: não deduza versão lendo arquivo à mão, não
reescreva a tabela, não invente campo que ele não imprimiu.

## O que interpretar depois de mostrar

Só comente se houver uma das três divergências abaixo. Sem elas, a saída basta.

- **`← a fonte está à frente`** — o cache do plugin está velho. Reinstalar com
  `/plugin marketplace update harness-mp` seguido de
  `/plugin install harness@harness-mp` ativa a versão nova.
- **`← instalado por outra versão`** — o harness deste repositório foi escrito
  por outra versão da skill. Ofereça rodar `harness:install` de novo; é
  idempotente e nunca sobrescreve edição manual.
- **`dono: NÃO REGISTRADO`** — é violação de D6. Sem alguém nomeado, nenhum
  modo de fracasso tem quem reaja. Diga isso e ofereça registrar.

Se o repositório não tem harness, o script já diz o que fazer. Não insista:
nem todo repositório merece harness.
