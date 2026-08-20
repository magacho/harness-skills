# Changelog

Skill que modifica repositório alheio sem changelog é impossível de adotar com
confiança.

## [0.1.0] — não publicado

### Adicionado
- `docs/INTENT.md` v1.1 — 12 resultados, teto de autonomia parametrizável,
  especificação como etapa
- `docs/HARNESS.md` v2.0 — 45 regras, todas rastreando a um resultado
- `docs/PLAN.md` v2.0 — trilhos greenfield e retrofit, processo de deploy
- `docs/adapters/README.md` — contrato de quatro verbos
- `plugin/skills/audit` — auditoria read-only, stack Node/TS
- `template/` — scaffold com quatro módulos e fronteiras verificáveis
- `evals/` — 9 evals, 4 fixtures
- `scripts/validate.sh` — validação do produto antes do release

### Conhecido
- Adaptador de fronteira apenas para JS/TS
- `harness:retrofit` e `harness:init` não implementados
- Contrato de adaptador exercitado por uma só implementação
