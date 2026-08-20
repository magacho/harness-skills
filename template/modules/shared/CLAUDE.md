# modules/shared — tipos e utils puros

Folha do grafo. Se algo aqui precisa importar outro módulo, não pertence aqui.

- Pode importar: nada de `modules/`
- Sem I/O, sem estado global, sem dependência de framework
- Antes de adicionar: pergunte se dois módulos realmente compartilham isto.
  `shared` que cresce sem critério vira o acoplamento que ela deveria evitar
