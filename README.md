# harness

Plugin do Claude Code com **duas skills** que auditam e instalam um harness de
desenvolvimento agêntico: contexto, verificação e fronteiras de módulo
**verificáveis por máquina**, em projeto novo ou legado — sem tocar em
código-fonte.

| skill | o que faz | escreve? |
|---|---|---|
| `harness:audit` | diagnostica o repositório e produz três listas: remover, corrigir, adicionar | **não** — read-only |
| `harness:install` | instala hooks, permissões, catraca de violações e `CLAUDE.md` por módulo | sim, sempre com confirmação |

E um comando: **`/harness:version`** — que versão da skill está rodando, que
versão instalou o harness deste repositório, e se as duas divergiram.

O guia de uso, com a saída real de cada passo, está em
[`docs/USAGE.md`](docs/USAGE.md).

## Instalação

São dois "instalar" diferentes, e vale separá-los.

**1 — o plugin, no seu Claude Code.** Enquanto não há repositório remoto
definido, o marketplace aponta para o diretório local:

    /plugin marketplace add ~/Workspace/harness-skills
    /plugin install harness@harness-mp

**2 — o harness, no seu repositório.** É o que as skills fazem depois de
instaladas.

*Projeto existente* — rode `harness:audit` primeiro. É read-only e o relatório
dele é a especificação do que corrigir; a lista de *remover* costuma ser a mais
valiosa. Depois `harness:install`, que executa as fases 1 a 3 com um checkpoint
humano entre cada uma. Nenhuma delas toca código-fonte.

*Projeto novo* — `harness:install` detecta que não há código e cai no modo
scaffold: copia o template, pergunta os nomes dos módulos do seu domínio, ajusta
os paths da config de fronteira junto, e planta uma violação para confirmar que o
gate reprova.

Nos dois modos a instalação mostra o que vai escrever e espera confirmação, é
idempotente, e nunca sobrescreve o que você editou à mão.

## O problema

Um agente escreve código correto e código plausível com a mesma fluência e na
mesma velocidade. Sem um mecanismo que os distinga, a conta de revisão migra para
o humano e cresce, a arquitetura decai silenciosamente, e cada mudança precisa do
sistema inteiro carregado em contexto.

A aposta: **a restrição que importa não é a capacidade do modelo — é a ausência de
oráculo e o tamanho da janela.**

## A pirâmide de verificação

Por edição só o que é grátis para o contexto; por turno o que precisa realimentar
o agente; no CI o que só precisa impedir o merge. As regras completas estão em
[`docs/HARNESS.md`](docs/HARNESS.md).

| camada | quando | custo | pega |
|---|---|---|---|
| `CLAUDE.md` por módulo | sempre em contexto | zero | intenção |
| formatador | por edição | ~200ms | formatação |
| lint + fronteira + tipos | por turno | segundos | o que realimenta o agente |
| subagentes de auditoria | pré-PR / semanal | caro | acoplamento invisível ao grafo |
| suíte completa | CI | minutos | impedir o merge |

## Catraca

Em repositório legado você não fica verde. O gate opera sobre um baseline do que
já existe e falha **só no que é novo** — e o baseline só encolhe. Isso converte
"40 erros, gate inútil" em "40 erros parados": a decadência para antes de
qualquer refactor.

É a regra que torna o harness aplicável a código que já existe. São duas
catracas, com semânticas diferentes de propósito:

| | fronteira | tamanho |
|---|---|---|
| pergunta | esta dependência existe? | este arquivo passou do teto? |
| baseline | conjunto de violações | `{caminho: linhas}` |
| falha quando | aparece violação nova | arquivo novo passa do teto, ou um antigo cresce |
| depende de ferramenta | sim, por adaptador | não — contagem de linha vale em toda linguagem |

Em projeto novo os dois baselines nascem vazios, e aí o teto age como limite
absoluto. Um mecanismo, dois regimes.

## God file e god function

O que a catraca de tamanho protege não é estética: é R4 — *uma mudança típica
cabe num módulo, e portanto num contexto pequeno*. Arquivo de 2.000 linhas obriga
a carregar tudo para mudar uma coisa.

A divisão de trabalho é deliberada. **Arquivo** é da catraca do harness, porque
precisa valer em legado e em qualquer linguagem. **Função e ramificação** são do
linter, porque quem sabe onde uma função começa é o parser — no template,
`max-lines-per-function` em 60 e `complexity` em 10. Nunca as duas no mesmo
lugar: duas respostas para a mesma pergunta divergem na primeira correção.

Contagem de arquivos por módulo **não** é gate. Mede ao contrário do que se
quer: um módulo de dados com 40 repositórios pequenos é saudável, um domínio com
6 arquivos de 900 linhas é doente, e a contagem premia o segundo.
Responsabilidade dupla continua sendo julgamento, e o lugar dela é o subagente
`architect`.

## Status

`0.2.6` — diagnostica e instala.

| | disponível |
|---|---|
| `harness:audit` | sim, read-only |
| `harness:install` — modo A, projeto existente | sim: fases 1 a 3 do `PLAN.md` §4 |
| `harness:install` — modo B, projeto novo | sim: scaffold com módulos renomeados |
| Catraca de violações | sim, genérica: a comparação é do harness, não da ferramenta |
| Fronteiras em JS/TS | sim, via dependency-cruiser |
| Fronteiras em Python, JVM, Go | não — contrato de adaptador escrito, ausência declarada em voz alta |
| Roster de subagentes (fase 4) | não |
| Piloto de modularização (fases 5–6) | não, e não é escopo do harness |

`harness:install` para na fase 3. O roster da onda 1 — revisor de mudança e
arquiteto — ainda é trabalho manual, e a skill diz isso ao terminar em vez de
deixar como omissão.

O contrato de adaptador só foi exercitado por uma implementação. Provavelmente
está errado em algum detalhe, e a segunda é que vai revelar onde.

## Escopo

O harness **verifica** fronteiras; não as **desenha**. Reorganizar módulos, mover
código e redesenhar limites é modularização — outra disciplina, outro risco. As
fases que instalam harness não tocam código-fonte, e isso é o que torna a adoção
possível.

## O que tem aqui

    plugin/commands/        /harness:version
    plugin/skills/audit/    diagnostica: read-only, produz o relatório
    plugin/skills/install/  instala: dois modos, um mecanismo
      assets/template/      scaffold de projeto novo
      scripts/adapters/     o contrato de adaptador, implementado
    docs/USAGE.md       guia de uso — avaliação, instalação, saídas reais
    docs/INTENT.md      por quê — problema, resultados (R1–R12), o que não queremos
    docs/HARNESS.md     regras — 45 regras, cada uma rastreando a um resultado
    docs/PLAN.md        como — construção da skill, implantação, deploy
    docs/CONFORMIDADE.md  mapa de validação — cada critério de §12, o mecanismo e o tipo
    docs/adapters/      contrato de adaptador por linguagem
    evals/              fixtures e testes dos scripts
    scripts/validate.sh validação do próprio produto antes do release

## Licença

MIT.
