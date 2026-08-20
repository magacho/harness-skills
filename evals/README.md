# Evals

Skill que audita repositório alheio sem eval é risco não medido.

`./run.sh` roda os evals dos scripts. Fixtures em `fixtures/`.

## Cobertura atual

| fixture | testa |
|---|---|
| `template/` | repositório conforme: nenhuma instrução falsa, harness completo |
| `legado-com-instrucao-falsa/` | regra C4 — o achado mais comum |
| `python-sem-adaptador/` | regra D4 — degradação declarada em voz alta |
| `sem-harness/` | repositório cru não quebra a auditoria |

## Cobertura que falta

Antes do primeiro release público (ver `docs/PLAN.md` §7):

- Monorepo com pacotes
- Repositório legado com ciclos reais e baseline grande
- Repositório com harness de outra ferramenta (`.cursorrules`, `AGENTS.md`)
- **Eval negativo:** repositório onde o harness *não* deveria ser instalado —
  script de uso único, protótipo descartável. A skill deve dizer isso.
- Repositório de terceiro. Harness testado só na casa do autor sempre parece
  funcionar.
