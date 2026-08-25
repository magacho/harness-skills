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
    plugin/skills/audit/    diagnostica: read-only, produz o relatório
    plugin/skills/install/  instala: dois modos, um mecanismo
      assets/template/      scaffold de projeto novo
      scripts/adapters/     o contrato de adaptador, implementado
    evals/              fixtures e testes dos scripts
    scripts/validate.sh validação do próprio produto antes do release

## Começando

    /plugin marketplace add <user>/harness
    /plugin install harness

**Projeto existente** — rode `harness:audit` primeiro. É read-only e produz três
listas: remover, corrigir, adicionar. A de *remover* costuma ser a mais valiosa.
Depois `harness:install`, que executa as fases 1 a 3 com um checkpoint humano
entre cada uma. Nenhuma delas toca código-fonte.

**Projeto novo** — `harness:install` detecta que não há código e cai no modo
scaffold: copia o template, pergunta os nomes dos módulos do seu domínio, ajusta
os paths da config de fronteira junto, e planta uma violação para confirmar que o
gate reprova.

Nos dois modos a instalação mostra o que vai escrever e espera confirmação, é
idempotente, e nunca sobrescreve o que você editou à mão.

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

`0.2.0` — diagnostica e instala.

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

## Licença

MIT.
