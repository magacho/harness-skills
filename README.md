# harness

Harness de desenvolvimento agêntico: contexto, verificação e fronteiras de módulo
**verificáveis por máquina**, instaláveis em projeto novo ou legado sem tocar em
código-fonte.

## O problema

Um agente escreve código correto e código plausível com a mesma fluência e na
mesma velocidade. Sem um mecanismo que os distinga, a conta de revisão migra para
o humano e cresce, a arquitetura decai silenciosamente, e cada mudança precisa do
sistema inteiro carregado em contexto.

A aposta: **a restrição que importa não é a capacidade do modelo — é a ausência de
oráculo e o tamanho da janela.**

## O que tem aqui

    docs/INTENT.md      por quê — problema, resultados (R1–R12), o que não queremos
    docs/HARNESS.md     regras — 45 regras, cada uma rastreando a um resultado
    docs/PLAN.md        como — construção da skill, implantação, deploy
    docs/adapters/      contrato de adaptador por linguagem
    plugin/             plugin Claude Code (skill harness:audit)
    template/           scaffold pronto para projeto novo
    evals/              fixtures e testes dos scripts
    scripts/validate.sh validação do próprio produto antes do release

## Começando

**Projeto novo** — copie `template/`, renomeie os módulos para o seu domínio,
ajuste os paths da config de fronteira, e plante uma violação para confirmar que o
gate reprova. Detalhes em `template/README.md`.

**Projeto existente** — instale o plugin e rode a auditoria. Ela é read-only:

    /plugin marketplace add <user>/harness
    /plugin install harness

A auditoria produz três listas — remover, corrigir, adicionar — e um sumário de
conformidade. A lista de *remover* costuma ser a mais valiosa.

## A pirâmide de verificação

| camada | quando | custo | pega |
|---|---|---|---|
| `CLAUDE.md` por módulo | sempre em contexto | zero | intenção |
| formatador | por edição | ~200ms | formatação |
| lint + fronteira + tipos | por turno | segundos | o que realimenta o agente |
| subagentes de auditoria | pré-PR / semanal | caro | acoplamento invisível ao grafo |
| suíte completa | CI | minutos | impedir o merge |

Regra: por edição só o que é grátis para o contexto; por turno o que precisa
realimentar o agente; no CI o que só precisa impedir o merge.

## Catraca

Em repositório legado você não fica verde. O gate opera sobre um baseline de
violações conhecidas e falha **só no que é novo** — e o baseline só encolhe. Isso
converte "40 erros, gate inútil" em "40 erros parados": a decadência para antes de
qualquer refactor.

É a regra que torna o harness aplicável a código que já existe.

## Status

`0.1.0` — primeiro corte deliberadamente pequeno.

| | disponível |
|---|---|
| `harness:audit` | sim, read-only |
| `harness:retrofit` | não |
| `harness:init` | não (o `template/` já serve) |
| Fronteiras em JS/TS | sim, via dependency-cruiser |
| Fronteiras em Python, JVM, Go | não — contrato de adaptador escrito, ausência declarada em voz alta |

O contrato de adaptador só foi exercitado por uma implementação. Provavelmente
está errado em algum detalhe, e a segunda é que vai revelar onde.

## Escopo

O harness **verifica** fronteiras; não as **desenha**. Reorganizar módulos, mover
código e redesenhar limites é modularização — outra disciplina, outro risco. As
fases que instalam harness não tocam código-fonte, e isso é o que torna a adoção
possível.

## Licença

MIT.
