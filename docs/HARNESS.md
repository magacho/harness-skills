# HARNESS.md — Definições e diretrizes

Documento **normativo**. Descreve o que o harness é, quais regras ele impõe, e
como verificar se um projeto está conforme.

Deriva de `INTENT.md`. **Toda regra aqui rastreia a um resultado (R) declarado
lá.** Regra sem R correspondente é cerimônia e foi removida — ver §12.

A implantação é o `PLAN.md`. Este documento não descreve como instalar.

Versão 2.1 · Escopo: harness distribuível, adotável por qualquer projeto

---

## 1. Escopo e fronteira

Harness é a camada que torna o trabalho de um agente **verificável e repetível**
num repositório. É feito de contexto, especificação, verificação, permissão,
agentes e comandos.

**O harness não toca código-fonte.** Esta é a fronteira que define o documento.
Instalar, revisar ou remover harness altera apenas:

    CLAUDE.md · .claude/** · configs de verificação · docs/adr/** · ops/**

Reorganizar módulos, mover código, alterar imports e redesenhar fronteiras é
**modularização** — outra disciplina, outro risco (§10).

*Por que:* R7 e R10. Se instalar exigir refatorar, não instala em repositório que
importa.

---

## 2. Princípios

**P1 — Instrução, não documentação.** `→ R1`
Se uma linha não muda o comportamento do agente, ela não pertence ao harness.

**P2 — Permissão é garantia; hook é conveniência.** `→ R5`
O que não pode acontecer de jeito nenhum vai em `permissions.deny`. Hook é
best-effort, falha aberto, e é desligável por flag de execução. Nunca use hook
como única trava.

**P3 — O agente precisa de um oráculo.** `→ R2, R3`
Sem verificação executável, um agente não produz código correto: produz código
plausível.

**P4 — Escopo estreito no caminho quente.** `→ R2`
Verificação reporta apenas o que está no raio da mudança. Erro fora do escopo
contamina o diff: o agente adota trabalho que não é dele.

**P5 — Custo de contexto é custo real.** `→ R9`
Verificação que passa custa zero token. Só o que falha entra no contexto.

**P6 — O erro de hoje vira o gate de amanhã.** `→ R6`
Correção recorrente termina em regra executável ou linha de `CLAUDE.md`. Achado
que termina em relatório será recontratado.

**P7 — Descrever antes de prescrever.** `→ R7`
Em repositório existente, o harness documenta a estrutura que existe. Impor
nomenclatura de template sobre projeto real produz instrução falsa.

**P8 — O gate é script; o hook é só o gatilho.** `→ R12`
Toda verificação roda por um comando invocável à mão. Nenhuma lógica de decisão
mora dentro do hook.

---

## 3. Camadas

| camada | artefato | cadência | custo | responsabilidade |
|---|---|---|---|---|
| Especificação | etapa da thread principal | antes da tarefa | atenção humana | entender a demanda |
| Contexto | `CLAUDE.md` hierárquico | sempre carregado | zero | intenção e convenção |
| Formatação | hook por edição | por edição | ~200ms | consistência |
| Verificação | hook de fim de turno | por turno | segundos | lint, tipo, fronteira, tamanho |
| Permissão | config de permissões | por tool call | zero | o que não pode acontecer |
| Julgamento | subagentes | pré-PR / semanal | caro | o que a máquina não vê |
| Rede final | CI | por push | minutos | impedir o merge |

**Regra de alocação** `→ R9`: por edição só o que é grátis para o contexto; por
turno o que precisa realimentar o agente; no CI o que só precisa impedir o merge.

---

## 4. Contexto — regras C

**C1 — Hierárquico.** `→ R1`
Raiz para o projeto, um por módulo. Configuração pessoal existe, mas nada
essencial mora nela (ver D1).

**C2 — Conteúdo da raiz.** `→ R1`
Stack em uma linha, comandos executáveis, convenções, seção "Nunca", e o que
fazer ao terminar uma tarefa.

**C3 — Conteúdo do módulo.** `→ R1, R4`
Três coisas: o que o módulo possui, o que pode importar, o que nunca importa.

**C4 — Toda afirmação verificável é verdadeira.** `→ R1`
Se o `CLAUDE.md` cita um comando que não existe, é instrução falsa — pior que
instrução ausente, porque o agente confia. **Conformidade exige executar as
afirmações, não lê-las.**

**C5 — Alvo de tamanho do CLAUDE.md.** `→ R1, R9`
Trata do arquivo de contexto, **não do código-fonte** — tamanho de código é V10.
Raiz até ~60 linhas; módulo até ~15. Acima disso, provavelmente virou
documentação (P1) e passa a ser ignorada.

**C6 — Nomes vêm do projeto, não do template.** `→ R7`
Módulo se chama como já se chama. Fronteiras são inferidas do grafo real.

---

## 5. Especificação — regras E

**E1 — Etapa, não subagente.** `→ R11`
Especificação é conversa com a pessoa e mora na thread principal. Delegada, a
pergunta perde contexto no caminho de volta.

**E2 — Gatilho é o custo do erro, não o tamanho da tarefa.** `→ R11`
Irreversibilidade e blast radius decidem. Migration de dez linhas merece
entrevista; ajuste de texto não merece pergunta alguma.

**E3 — Em lote, com default proposto.** `→ R11`
Perguntas de uma vez, ou duas rodadas no máximo. Cada pergunta traz um default
para ratificar. Volume alto é aceitável — a ordem de dez por assunto é razoável —
desde que ratificar seja a ação, não preencher.

**E4 — Agrupadas e puláveis.** `→ R11`
Por assunto, com o bloco inteiro dispensável. "Decide você" é resposta válida.

**E5 — Regra de parada.** `→ R11, R9`
Pare quando as respostas deixam de mudar a implementação. Se a resposta não altera
o que vai ser escrito, é curiosidade.

**E6 — Duas saídas obrigatórias.** `→ R11`
Lista de **premissas assumidas** (nada decidido em silêncio) e **critério de
aceitação** escrito. Sem artefato, a entrevista gastou atenção e não deixou nada.

**E7 — Sai do caminho quando a demanda já vem clara.** `→ R11`
Confirma e passa. Re-interrogar demanda detalhada faz a etapa ser desligada — e aí
ela não existe nem quando importa.

---

## 6. Verificação — regras V

**V1 — Rastreamento silencioso.** `→ R2, R9`
O hook por edição registra os caminhos editados. Nunca reporta ao agente, nunca
bloqueia, roda assíncrono.

**V2 — Shard por agente.** `→ R2`
O registro é particionado por sessão e por agente, para funcionar com subagentes
em paralelo.

**V3 — Gate no fim do turno.** `→ R2`
Roda uma vez por turno, sobre a coleção acumulada da sessão, e devolve os erros ao
agente com código de bloqueio.

**V4 — Filtro de saída.** `→ R2, R9`
Verificação de projeto inteiro roda inteira mas **reporta apenas erros em arquivos
da sessão**.

**V5 — Guarda anti-loop.** `→ R2`
Após N tentativas sem passar (padrão 3), o gate libera com aviso. O contador zera
quando passa.

**V6 — O gate em lote não escreve em disco.** `→ R2`
Correção automática só no hook por edição, no arquivo recém-tocado. Em lote,
read-only: outra sessão pode estar editando.

**V7 — Catraca.** `→ R7`
Em repositório com violações preexistentes, o gate opera sobre baseline de
violações conhecidas e falha apenas no que é **novo**. O baseline só encolhe.
**Esta é a regra que torna o harness aplicável a legado.**

**V8 — Catraca é do harness, não da ferramenta.** `→ R7, R12`
O adaptador de linguagem normaliza achados para uma lista (`origem`, `destino`,
`regra`); a comparação com o baseline é do harness. Baseline nativo de ferramenta é
otimização, não requisito — sem isso, a catraca existe em algumas linguagens e não
em outras.

**V9 — Conformidade exige gate reprovado de propósito.** `→ R3`
Plante uma violação e confirme que o gate falha. Gate que nunca reprovou não é
gate.

**V10 — Tamanho de arquivo é catraca, nunca limite absoluto em legado.** `→ R4, R7`
Arquivo acima do teto entra no baseline e **não pode crescer**; arquivo novo
acima do teto reprova. A semântica é de grandeza, não de presença: o baseline é
`{caminho: linhas}` e a comparação é `>`, ao contrário da fronteira, que é
diferença de conjunto. O oráculo é contagem de linha — o único estrutural que
existe em toda linguagem, e por isso a catraca de tamanho vale onde não há
adaptador de fronteira (`→ R12`).

*Por que catraca e não teto:* limite absoluto sobre legado reprova centenas de
arquivos no primeiro turno, o time desliga o gate, e gate desligado é pior que
gate nenhum. Em projeto novo o baseline nasce vazio e o mesmo número age como
limite absoluto — um mecanismo, dois regimes.

**V11 — O gate de tamanho mede função onde há parser, e arquivo onde não há.**
`→ R4, R9`
Limite de arquivo é a catraca do harness; limite de função e de ramificação são
do linter, que sabe onde uma função começa. Duas perguntas, dois donos, uma
resposta cada. Nunca as duas no mesmo lugar: um `max-lines` no linter daria uma
segunda resposta à pergunta que a catraca já responde, e as duas divergiriam na
primeira vez que só uma fosse corrigida.

*Modo de fracasso a antecipar:* qualquer limite de tamanho convida a partir o
arquivo em `-parte2` para satisfazer o número. A recusa do gate tem de dizer isso
(A4 → R1), e o gate de ciclo é a rede que pega a partição arbitrária — que
quase sempre produz import mútuo ou órfão. Sem V7 e sem o gate de fronteira, um
gate de tamanho isolado piora o código que deveria proteger.

---

## 7. Ambiente, permissão e autonomia — regras A

**A1 — Assimetria de ambiente.** `→ R5`
Staging: o agente investiga e faz deploy. Produção: investiga, e nada mais.

**A2 — Dupla trava para produção.** `→ R5`
Escrita em produção é negada em permissão **e** em hook. A permissão cobre o
padrão óbvio; o hook cobre a variação.

**A3 — Investigação read-only por construção.** `→ R5`
O script de investigação usa apenas verbos de leitura. É seguro em produção porque
não tem como não ser.

**A4 — Recusa que ensina.** `→ R1`
Ao bloquear, dizer o que fazer em vez disso. "Deploy em produção é humano —
escreva o plano de release" ensina; "negado" não.

**A5 — Segredo nunca no harness.** `→ R5`
Arquivos de ambiente contêm coordenadas, não credenciais. Leitura de `.env*`
negada.

**A6 — Teto de autonomia declarado.** `→ R5`
Cada projeto declara seu teto em arquivo versionado. Default: `supervisionado`.

**A7 — Monotonicidade.** `→ R5`
Usuário e execução podem restringir abaixo do teto, nunca acima. Elevar exige
alterar o arquivo do repositório, com revisão — nunca flag de linha de comando.

**A8 — Teto sustentado por permissão.** `→ R5`
Como uma flag de execução consegue desligar hooks, um limite de autonomia nunca
pode depender de hook (P2).

**A9 — Garantias não degradam quando a autonomia sobe.** `→ R5`
O mesmo conjunto de travas vale nos três modos. Desenhar para o autônomo entrega
o assistido de graça; o contrário produz harness silenciosamente inadequado na
primeira execução agendada.

---

## 8. Agentes e papéis — regras G

**G1 — Papel só existe se difere em ferramentas, permissões ou no que é cego.**
`→ R9`
Diferir apenas em tom de prompt é custo sem retorno.

**G2 — Subagente de auditoria é read-only.** `→ R5`

**G3 — Subagente não repete o gate, e declara o que não repete.** `→ R9`
Sem isso, vários relatórios chegam com os mesmos achados e a thread principal
gasta contexto reconciliando: paga-se várias vezes pelo mesmo item.

**G4 — Cadência de julgamento não é cadência de turno.** `→ R9`
Auditoria de julgamento roda pré-PR ou agendada. A cada turno é caro e vira ruído.

**G5 — Todo achado termina em regra ou ADR.** `→ R6`
Nunca em relatório.

**G6 — Subagente propõe; nunca emenda o harness.** `→ R6`
Nenhum subagente escreve regra, `CLAUDE.md` ou config de gate. Emenda passa pela
thread principal com aprovação humana e é revisada como código. Sem isso o harness
se automodifica para caber na tarefa do momento e deriva.

### Roster

Um antes, um durante, quatro depois. A thread principal faz os dois primeiros.

| papel | onde | escrita | cadência | é cego a — e mais ninguém é |
|---|---|---|---|---|
| **especificador** | thread principal | artefato de spec | antes da tarefa | — (etapa, ver §5) |
| **desenvolvedor** | thread principal | sim | contínuo | — |
| **revisor de mudança** | subagente | não | por PR | blast radius, ordem de migration, o que o rollback não desfaz — além da corretude do diff |
| **arquiteto** | subagente | não | pré-PR / semanal | acoplamento por runtime, dono de schema, transporte vazando no domínio, contrato sem versão |
| **segurança** | subagente | não | por PR | authz, segredo, injection, dado sensível em log |
| **testes** | subagente | só arquivos de teste | ao fechar tarefa | o viés de quem escreveu o código — contexto fresco é a feature |

**Notas de desenho:**

- **Desenvolvedor não é subagente.** Delegar a implementação faz a thread
  principal perder o contexto do próprio trabalho e passar a revisar relatório.
- **Não existe "revisor de código" separado.** Corretude foi absorvida pelo revisor
  de mudança: lint, tipo, fronteira e testes já cobrem o mecânico, e um revisor
  genérico é o único cuja cegueira não é distinta de ninguém (G1).
- **Adoção em ondas.** Onda 1: revisor de mudança e arquiteto. Onda 2: testes
  (exige escrita restrita a arquivos de teste, o mais chato de configurar) e
  segurança (achado mais raro no início, e vale calibrar com um humano da área
  antes de automatizar).

---

## 9. Distribuição e concorrência — regras D e N

**D1 — Nada essencial em configuração pessoal.** `→ R8`
Quem clona o repositório recebe o mesmo comportamento. Configuração pessoal é
preferência, nunca garantia. A revisão do harness verifica isso.

**D2 — Instalar não toca código-fonte.** `→ R7, R10`

**D3 — Idempotente e versionado.** `→ R10`
Arquivos gerados carregam marca de versão; o que foi editado à mão não é
sobrescrito. Retrofit que estraga customização roda uma vez na vida.

**D4 — Ausência declarada em voz alta.** `→ R10`
Stack sem adaptador de fronteira instala todo o resto e **diz** que o gate de
fronteira não está disponível. Silenciar a lacuna é o erro grave; instalar 80% não
é.

**D5 — Todo gate é comando invocável.** `→ R12`
Cada verificação roda à mão, em CI, e sob outro agente. O hook apenas invoca.

**D6 — Dono nomeado na instalação.** `→ R6`
Sem dono registrado, nenhum modo de fracasso tem quem reaja, e o critério de
sucesso de três meses fica sem observador.

**N1 — Subagentes na mesma sessão: cobertos.** `→ R2`
Hooks disparam dentro de subagentes; o shard por agente mantém o rastreamento
correto.

**N2 — Múltiplas sessões no mesmo repositório exigem isolamento.** `→ R2`
A working tree é compartilhada: o typecheck de uma sessão vê o trabalho meio-feito
da outra. Exige worktree por sessão.

**N3 — Sem isolamento, os gates são read-only.** `→ R2`
Nada de correção automática em lote quando há concorrência de escrita.

---

## 10. Fronteira com modularização

O harness **verifica** fronteiras; não as **desenha**.

| harness | modularização |
|---|---|
| instala o gate de dependência | decide qual é o grafo permitido |
| congela violações em catraca | extrai módulo, move código |
| escreve `CLAUDE.md` do módulo que existe | propõe o módulo que deveria existir |
| não toca código-fonte | move código-fonte |
| minutos, reversível | dias, com risco de regressão |

Composição: o harness **consome** o resultado da modularização (o grafo permitido
vira config executável) e **detecta** a necessidade dela (catraca que não encolhe é
o sinal). Nunca duplique a disciplina de desenho dentro do harness.

---

## 11. Parametrização

O que cada projeto adotante define. Nenhum destes tem resposta universal.

| parâmetro | default | onde vive |
|---|---|---|
| Teto de autonomia | `supervisionado` | arquivo versionado |
| Dono do harness | — obrigatório | registrado na instalação |
| Nomes e limites de módulo | inferidos do grafo real | `CLAUDE.md` de módulo |
| Ferramenta de fronteira | conforme a stack | config de verificação |
| Ritmo da catraca | acordo do time | acordo de sprint |
| Papéis ativos | onda 1 | definições de subagente |
| Gatilho de especificação | irreversibilidade e blast radius | `CLAUDE.md` raiz |

---

## 12. Conformidade

Verificável, não declarável. Cada item cita o R que serve.

- [ ] `CLAUDE.md` na raiz, e **todo comando citado nele executa** `C4 → R1`
- [ ] `CLAUDE.md` por módulo, com o que importa e o que não importa `C3 → R1,R4`
- [ ] Nenhuma garantia depende de configuração pessoal `D1 → R8`
- [ ] Hook por edição: assíncrono, silencioso, não escreve no contexto `V1 → R9`
- [ ] Gate de turno: filtra por arquivos da sessão, bloqueia de verdade `V3,V4 → R2`
- [ ] Guarda anti-loop presente; contador zera ao passar `V5 → R2`
- [ ] **Violação plantada de propósito reprova** `V9 → R3`
- [ ] Baseline de catraca existe se havia violações; e encolhe `V7 → R7`
- [ ] Catraca de tamanho ativa: arquivo acima do teto não cresce `V10 → R4,R7`
- [ ] Limite de função no linter, limite de arquivo na catraca — nunca os dois no mesmo lugar `V11 → R4`
- [ ] Todo gate roda como comando à mão `D5 → R12`
- [ ] Escrita em produção negada em permissão **e** em hook `A2 → R5`
- [ ] Script de investigação existe e é read-only `A3 → R5`
- [ ] Teto de autonomia declarado; elevá-lo exige revisão `A6,A7 → R5`
- [ ] Dono registrado `D6 → R6`
- [ ] Nenhum arquivo do harness contém segredo `A5 → R5`
- [ ] Cada subagente declara o que não repete `G3 → R9`

---

## Apêndice — notas de plataforma

Fatos do ambiente, não regras. Estavam como regras na v1.0 e foram rebaixados por
não rastrearem a nenhum R:

- **Código de saída.** Em Claude Code, `exit 2` num hook bloqueia e devolve a saída
  de erro ao agente; `exit 1` é tratado como erro não-bloqueante e a ação
  prossegue. Convenção Unix não se aplica.
- **Taxonomia.** Comando é ritual invocado explicitamente; skill é conhecimento
  acionado por contexto; subagente é papel com contexto e ferramentas próprios;
  hook é gatilho determinístico. Útil para não confundir os quatro — mas é
  vocabulário, não norma.
- **Saída de hook truncada.** Há limite de tamanho na saída que chega ao agente.
  Protege contra o pior caso; não substitui o filtro de escopo (V4).

## Histórico

- **2.1** — acrescentadas V10 (catraca de tamanho) e V11 (divisão função/arquivo
  entre linter e catraca), ambas rastreando a R4. C5 renomeada para deixar
  explícito que trata do `CLAUDE.md` e não do código-fonte.
- **2.0** — derivada de `INTENT.md` v1.1. Toda regra rastreia a um R. Adicionadas
  as famílias E (especificação, R11) e D (distribuição, R8/R10/R12); regras de
  autonomia A6–A9; roster de papéis; parametrização. Rebaixadas para apêndice as
  duas regras órfãs da v1.0 (código de saída e taxonomia).
- **1.0** — primeira versão, derivada de conversa sobre hooks.
