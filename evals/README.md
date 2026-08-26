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
| `ts-com-ciclo/` | **grafo TypeScript** com ciclo, órfão e imports sem extensão |
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

## Regressões travadas

Três defeitos da mesma família — **o script reportava sucesso sem ter medido** —
foram corrigidos em 0.2.1 e agora têm eval:

- `boundary-status.sh` cruzava `src modules` fixo. Repo sem `modules/` devolvia
  ENOENT, não media nada e saía 0.
- `detect-stack.sh` procurava `.dependency-cruiser.js` (o instalador escreve
  `.cjs`) e o baseline **nativo** da ferramenta. Ficava cego para a instalação
  que a skill irmã acabara de fazer.
- `check-claims.sh` só verificava script de `package.json`. Apagar o gate que o
  `CLAUDE.md` gerado cita não aparecia como instrução falsa.

## A lacuna que deixou o gate cego em TypeScript

Todo fixture com grafo era JavaScript — a única linguagem em que o
`dependency-cruiser` expande diretório nu. Projeto TypeScript recebia um gate que
cruzava zero módulo, e a suíte inteira ficava verde. `ts-com-ciclo/` fecha isso.

Os evals afirmam `totalCruised > 0` **e** a contagem esperada de violações. Um
eval que só verificasse "saiu 0" continuaria passando com o defeito — foi
exatamente o que aconteceu. Um deles entrega o diretório nu direto à ferramenta
e exige que cruze zero: trava a regressão pelo mecanismo, não pelo sintoma.

## Cobertura que falta

Antes do primeiro release público (ver `docs/PLAN.md` §7):

- Monorepo com pacotes
- Repositório com harness de outra ferramenta (`.cursorrules`, `AGENTS.md`)
- Repositório de terceiro. Harness testado só na casa do autor sempre parece
  funcionar.
