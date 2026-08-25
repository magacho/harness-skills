# Evals

Skill que audita repositório alheio sem eval é risco não medido.

`./run.sh` roda os evals das duas skills. Fixtures em `fixtures/`. A instalação
sempre roda sobre uma cópia em diretório temporário: fixture que a suíte suja
deixa de ser fixture.

## Cobertura atual

| fixture | testa |
|---|---|
| `assets/template/` (na skill `install`) | repositório conforme: nenhuma instrução falsa, harness completo |
| `legado-com-instrucao-falsa/` | regra C4 — o achado mais comum |
| `legado-com-ciclos/` | ciclo real e órfão real: baseline não vazio, e lint verde com typecheck vermelho |
| `python-sem-adaptador/` | regra D4 — degradação declarada em voz alta |
| `sem-harness/` | repositório cru não quebra a auditoria |
| `repo-vazio/` | modo B, o trilho de greenfield |
| `nao-merece-harness/` | **eval negativo:** script de uso único. A skill diz não |
| `depcruise-bruto.json` | saída gravada da ferramenta: `normalize` e catraca rodam offline |

## O que cada eval de instalação prova

- **Legado com violações** — baseline não vazio, no formato do harness (V8); o
  typecheck vermelho fica fora do gate; nenhum arquivo-fonte é tocado.
- **Idempotência** — rodar duas vezes não altera um byte, o dono registrado não
  é trocado por argumento de linha de comando, e a customização manual sobrevive
  com o pulo relatado (D3).
- **Stack sem adaptador** — instala todo o resto, e catraca, fumaça e gate saem
  com código 3 dizendo o que falta. Não aborta, não silencia (D4).
- **Repo vazio** — scaffold renomeia módulos, imports e os paths da config junto,
  inclusive dentro de alternações de regex; e recusa rodar onde já há código.
- **Negativo** — o veredito vem com a razão, não só com o "não".

Os evals que dependem do `dependency-cruiser` são **pulados com motivo impresso**
quando a ferramenta não está acessível. Silenciar a lacuna seria o mesmo erro que
a regra D4 proíbe.

## Cobertura que falta

Antes do primeiro release público (ver `docs/PLAN.md` §7):

- Monorepo com pacotes
- Repositório com harness de outra ferramenta (`.cursorrules`, `AGENTS.md`)
- Repositório de terceiro. Harness testado só na casa do autor sempre parece
  funcionar.
