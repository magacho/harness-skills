# modules/api — HTTP e composition root

Onde as dependências são conectadas. A única camada que conhece todo mundo.

- Pode importar: `modules/shared`, `modules/domain`, `modules/data`, `contracts/`
- NUNCA importa: `modules/web`
- Handler não tem regra de negócio: valida entrada, chama caso de uso do domínio,
  serializa saída. Se um `if` de negócio apareceu aqui, ele mora no domain
- `contracts/` é a única pasta que `modules/web` pode importar. Trate como API
  pública versionada: mudança quebrando contrato precisa de ADR
