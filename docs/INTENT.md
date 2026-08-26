# INTENT.md — O que queremos com o harness

Primeiro dos três documentos. Aqui está o **por quê**: o problema, o resultado
desejado, o que explicitamente não queremos, e como saber se funcionou.

As regras derivam deste documento (`HARNESS.md`). A implantação deriva das regras
(`PLAN.md`). Se uma regra não serve a nada declarado aqui, ela é cerimônia e sai.

Versão 1.1 · Público: qualquer equipe que adote o harness, não um projeto ou
empresa específicos.

---

## 1. O problema

Um agente escreve código correto e código plausível com a mesma fluência e na
mesma velocidade. Sem um mecanismo que os distinga, três coisas acontecem:

**A conta de revisão migra para o humano e cresce.** O gargalo deixa de ser
escrever e passa a ser confiar. Um PR de 400 linhas gerado em dez minutos consome
o mesmo tempo de revisão que um escrito em dois dias — só que agora chegam cinco
por dia.

**A arquitetura decai mais rápido do que decaía.** Fronteira que existe como
acordo social não sobrevive a um agente que não participou do acordo. E decai
silenciosamente: o import atravessa camada, o teste passa, o PR é aprovado.

**Contexto é o recurso escasso, e código emaranhado o desperdiça.** Se uma
mudança típica atravessa quatro camadas, o agente precisa carregar o sistema
inteiro para fazer qualquer coisa. Modularidade deixa de ser questão estética e
passa a ser economia de contexto.

**E antes de tudo isso: demanda vaga é a causa raiz da maior parte do
retrabalho.** Um agente não pergunta o que não sabe — ele preenche a lacuna com o
mais provável e segue com confiança. O erro nasce antes da primeira linha.

## 2. A aposta central

**A restrição que importa não é a capacidade do modelo. É a ausência de oráculo e
o tamanho da janela.**

Um agente com verificação automática e escopo estreito produz mais valor que um
agente melhor sem nenhum dos dois. É nisso que apostamos, e é por isso que o
investimento vai em harness em vez de em prompt melhor.

## 3. Quem o harness serve

| leitor | o que quer |
|---|---|
| **O agente** | saber o que fazer sem ser lembrado, e descobrir que errou enquanto corrigir ainda é barato |
| **Quem desenvolve** | não gastar atenção repetindo a mesma correção nem revisando o que a máquina pega |
| **Quem revisa** | um diff limpo, no escopo da tarefa, sem trabalho adotado por acidente |
| **Quem herda o repositório em um ano** | entender a fronteira sem arqueologia, e saber por que ela é assim |

O agente é o leitor mais literal e o menos capaz de inferir contexto. Escrever
para ele com clareza acaba servindo os outros três.

## 4. Um harness, vários agentes

O harness é único e do repositório; os agentes que operam sob ele são vários e
mudam. Três consequências:

**Papel só se justifica quando difere em ferramentas, permissões ou no que é
cego.** Diferir apenas em tom de prompt é custo sem retorno.

**Há um antes, um durante e um depois.** Especificação acontece antes de existir
código; implementação durante; auditoria depois. Os papéis "depois" encontram
problemas já escritos — o papel "antes" evita que sejam escritos, e por isso tem o
maior retorno da lista.

**Quem opera sob o harness não o altera.** Subagente propõe emenda; nunca escreve
regra, `CLAUDE.md` ou configuração de gate. Emenda passa pela thread principal
com aprovação humana e é revisada como código. Sem isso o harness se automodifica
para caber na tarefa do momento, e deriva.

O roster concreto de papéis é mecanismo: vive no `HARNESS.md`.

## 5. Teto de autonomia

O valor do harness muda de natureza conforme a autonomia do agente:

| modo | quem é o oráculo | o que o harness é |
|---|---|---|
| **assistido** — humano no teclado | o humano | assistivo: pega o absurdo |
| **supervisionado** — humano aprova ações | humano + gates | complementar |
| **autônomo** — agendado, CI, headless | só o harness | única linha de defesa |

**Regra de monotonicidade.** As garantias não podem degradar quando a autonomia
sobe. Desenhar para o autônomo entrega o assistido de graça; o contrário produz um
harness que fica silenciosamente inadequado na primeira execução agendada.

**O teto é parâmetro, em três níveis, e só desce:**

- **Projeto** declara o teto. Versionado no repositório, revisado como código.
  Default: `supervisionado`.
- **Usuário** pode declarar um modo efetivo mais restritivo, nunca mais permissivo.
- **Execução** pode restringir ainda mais para uma rodada específica.

Elevar o teto exige alterar o arquivo do repositório, com revisão — nunca uma flag
de linha de comando. E o teto tem de ser sustentado por **permissão**, não por
hook: uma flag de execução sempre consegue desligar hooks, então hook nunca é a
trava de um limite de autonomia.

**Exceção absoluta.** Escrita em produção pelo agente não é parametrizável em
nenhum nível. Ver R5.

**Subir de nível é decisão explícita, com marcos.** Um projeto que queira passar
de supervisionado para autônomo preenche seus próprios critérios; sugestão de
template:

- [ ] Baseline de violações decrescendo por N sprints consecutivos
- [ ] Zero afirmação falsa no `CLAUDE.md`, verificado por execução
- [ ] O gate já reprovou violação real de trabalho — não apenas plantada em teste
- [ ] Caminho para produção provado inalcançável por teste, não por inspeção
- [ ] Dono nomeado e ativo

Sem marcos escritos, "ainda não temos maturidade" se torna permanente por omissão
em vez de por decisão — e "já temos" se torna opinião de quem tem pressa.

## 6. O que queremos — resultados observáveis

**R1. O agente age dentro das regras sem ser lembrado.**
A regra mora onde ele já vai olhar. Se precisou ser lembrado, o lugar está errado.

**R2. O erro é descoberto pelo agente, não pelo humano.**
No mesmo turno, com o contexto da tarefa ainda carregado. Erro que chega ao review
custa uma ordem de magnitude mais.

**R3. Fronteira de arquitetura é fato verificável.**
Não acordo, não documento, não boa intenção. Se não é executável, não existe.

**R4. Uma mudança típica cabe num módulo.**
E portanto num contexto pequeno. É o resultado que justifica o custo da
modularização.

**R5. Nada que o agente faça pode causar dano irreversível.**
Produção, segredo, exclusão permanente. Investigar sempre; alterar, não. Não
parametrizável.

**R6. O conhecimento acumula em vez de evaporar.**
Correção recorrente vira regra executável; achado de auditoria vira gate ou ADR.
O que termina em relatório será recontratado no mês seguinte.

**R7. Funciona em repositório que já existe, sem exigir refactor.**
Legado é a maioria dos casos. Harness que só serve para greenfield serve para
quase nada.

**R8. O harness é do repositório, não da máquina nem da pessoa.**
Quem clona recebe o mesmo comportamento. Nada essencial mora em configuração
pessoal.

**R9. Custo proporcional ao valor.**
Verificação que passa não custa contexto. Julgamento caro roda em cadência de
julgamento, não a cada turno.

**R10. Instalar é questão de uma hora, não de um trimestre.**
Sem isso não há adoção — e harness não adotado tem valor zero.

**R11. A demanda é entendida antes de ser executada.**
Antes de escrever código, o que foi pedido está escrito, com o que está fora do
escopo, as premissas assumidas e o critério de aceitação. Nenhuma decisão de
escopo tomada em silêncio.

**R12. A camada de garantia sobrevive à ferramenta.**
O gate é script: roda em hook, em CI, no terminal, sob outro agente. Só a camada
de conveniência é específica de uma ferramenta. Trocar de agente não recomeça o
trabalho.

## 7. Especificação como etapa

R11 não é um revisor a mais; é um degrau antes da implementação, e mora na thread
principal — especificação é conversa com a pessoa, e delegá-la a um subagente faz
a pergunta perder o contexto no caminho de volta.

**No modo supervisionado, é o ponto de aprovação humana mais barato que existe:**
antes da primeira linha de código.

**Calibragem pelo custo do erro, não pelo tamanho da tarefa.** Uma migration de
dez linhas merece entrevista; um ajuste de texto não merece nenhuma pergunta. O
gatilho é irreversibilidade e blast radius.

**Formato da entrevista.** Quando a demanda justifica, perguntar bastante é
correto — a ordem de dez perguntas por assunto é razoável, e um analista humano
faria mais. O que decide se funciona não é o número:

- **Em lote, não em série.** Dez perguntas uma a uma são dez idas e voltas, e a
  pessoa abandona na quarta. Todas de uma vez, ou duas rodadas no máximo.
- **Toda pergunta com default proposto.** Ratificar dez decisões é fácil;
  preencher dez campos em branco é trabalho.
- **Agrupadas por assunto, com o bloco inteiro pulável.** A pessoa escolhe onde
  gasta atenção: "dados: decide você" é resposta válida.
- **Segunda rodada só se a primeira revelou bifurcação real.**
- **Fora do caminho quando a demanda já vem detalhada.** Re-interrogar demanda
  clara é o segundo-adivinhar que faz as pessoas desligarem a etapa.

**Regra de parada:** pare quando as respostas deixam de mudar a implementação. Se
a resposta não altera o que vai ser escrito, é curiosidade.

**Duas saídas obrigatórias:** a lista de **premissas assumidas** — o que foi
decidido sem resposta, nada em silêncio — e o **critério de aceitação**, que é o
que a revisão final vai conferir. Sem artefato, a entrevista gastou atenção e não
deixou nada.

## 8. O que explicitamente não queremos

**Não é substituto de revisão humana.** Elimina o achado mecânico para que a
atenção humana vá para desenho, risco e intenção. Reduz o volume de review, não a
necessidade.

**Não é freio.** Gate que atrapalha trabalho legítimo será desligado — e um
desligado é pior que nenhum, porque cria falsa sensação de cobertura. Na dúvida
entre rigoroso e usável, usável.

**Não é framework de arquitetura.** Não impõe hexagonal, DDD ou camadas a qualquer
domínio. Só o núcleo do negócio paga o preço do isolamento pesado.

**Não é documentação.** Contexto do harness é instrução. Explicação, tutorial e
histórico vivem em `docs/`.

**Não substitui CI.** Camadas diferentes com custos diferentes: o harness
realimenta o agente, o CI impede o merge.

**Não cobre todas as linguagens agora.** Uma implementada e bem feita vale mais
que quatro pela metade — desde que a ausência das outras seja declarada em voz
alta, nunca silenciosa.

**Não é vigilância.** Os gates avaliam o artefato, não a pessoa. Nada aqui produz
métrica individual.

**Não é camada de abstração entre agentes.** Preservamos portabilidade por
construção (R12), mas não inventamos uma camada neutra a partir de um único
exemplo — isso é o fracasso nº 7.

## 9. O que cada projeto adotante decide

O harness é distribuível. Estes pontos não têm resposta universal e são
preenchidos por quem adota:

| decisão | default | onde vive |
|---|---|---|
| Teto de autonomia | `supervisionado` | arquivo versionado do projeto |
| Dono do harness | — (obrigatório) | registrado na instalação |
| Nomes e limites dos módulos | inferidos do grafo real | `CLAUDE.md` de módulo |
| Ferramenta de fronteira | conforme a stack | config de verificação |
| Ritmo da catraca | combinado com o time | acordo de sprint |
| Critérios para subir de autonomia | template de §5 | arquivo versionado |
| Papéis de agente ativos | onda 1 | `.claude/agents/` |

**O dono é obrigatório e é o único item sem default.** Todo modo de fracasso da
§11 é um evento que precisa de alguém para reagir: a catraca que parou de
encolher, a instrução que ficou falsa, o gate que alguém desligou. Sem dono
nomeado no momento da instalação, o critério de sucesso de três meses não tem
observador — e era o único que não dá para fraudar.

## 10. Como saber que funcionou

| sinal | direção | por que importa |
|---|---|---|
| Tempo entre introduzir e detectar um erro | de "review" para "mesmo turno" | é R2 |
| Achados mecânicos por PR (lint, tipo, fronteira) | tendendo a zero | atenção humana liberada |
| Violações no baseline | monotonicamente decrescente | a catraca aperta, não só para |
| Afirmações falsas no `CLAUDE.md` | zero, sempre | instrução falsa é pior que ausente |
| Arquivos por mudança típica | caindo | é R4 |
| Retrabalho por demanda mal entendida | caindo | é R11 |
| **O harness continua ligado após três meses** | verdadeiro | o único teste infraudável |

O último é o mais vigiado. Todo mecanismo aqui é desligável em uma linha; se
alguém desligou, ele cobrava mais do que entregava.

## 11. As formas de fracassar

Desenhamos contra estas, em ordem de probabilidade:

1. **Ruído.** Gate que reprova o que não é da tarefa; o time desliga em duas
   semanas. → Escopo estreito é requisito, não refinamento.
2. **Instrução que virou documentação.** Ninguém lê, o agente ignora, e sobra peso
   morto no contexto.
3. **Exigir refactor para instalar.** Nunca sai do papel em repositório real.
4. **Achado que termina em relatório.** Auditoria paga duas vezes.
5. **Regra que o agente contorna para a tarefa passar.** Pior que a ausência de
   regra: aparência de fronteira sem fronteira.
6. **Instrução falsa.** Comando citado que não existe; o agente confia e erra com
   confiança.
7. **Abstração inventada a partir de um exemplo só.** Multi-linguagem desenhada
   sobre um único adaptador sai errada e é refeita.
8. **Entrevista que virou interrogatório.** Especificação pesada em tarefa leve
   faz a etapa ser pulada — e aí ela não existe nem quando importa.
9. **Teto de autonomia decorativo.** Parâmetro que qualquer pressa contorna.
   → Sustentado por permissão, elevável só com revisão.

## 12. Restrições que aceitamos

- **Cerimônia extra por integração nova.** Porta e adaptador custam código a mais.
  Aceitamos em troca de R3 e R4.
- **Contrato entre módulos passa a ser API versionada.** Mudança quebrando exige
  ADR. Atrito deliberado.
- **Produção fica menos conveniente.** Não há caminho rápido para alterar produção
  pelo agente. É o preço de R5 e não é negociável.
- **Legado começa com violações congeladas, não zeradas.** Preferimos parar a
  decadência hoje a prometer limpeza que não acontece.
- **A especificação custa tempo antes de render.** A entrevista atrasa o início e
  economiza no retrabalho. Aceitamos a troca onde o custo do erro é alto, e a
  dispensamos onde não é.

---

**Próximo documento:** `HARNESS.md` — as regras que realizam estes resultados.
Toda regra lá deve apontar para um R desta lista; regra sem R correspondente é
cerimônia e sai.
