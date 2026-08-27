# PLAN.md — Construção da skill e implantação

Como levar o harness definido em `HARNESS.md` para projetos reais, e como
empacotar e publicar isso como produto distribuível.

Documento **executável e descartável**: quando as fases terminarem, vira
histórico. As regras duráveis estão no `HARNESS.md`; o porquê, no `INTENT.md`.

Versão 2.3 · Derivado de `INTENT.md` v1.1 e `HARNESS.md` v2.2

---

## 1. Escopo — primeiro e segundo cortes

O primeiro corte foi deliberadamente pequeno: uma skill, uma linguagem, sem
escrita. O segundo adiciona a escrita.

| | dentro | fora |
|---|---|---|
| Skills | `harness:audit`, `harness:install` | — |
| Linguagem | Node / TypeScript | Python, JVM, Go |
| Escrita | `CLAUDE.md`, `.claude/**`, `.harness/**`, config de fronteira | código-fonte, sempre |
| Fases do §4 | 1, 2 e 3 (modo A, projeto existente); trilho inteiro (modo B, projeto novo) | 4 (roster), 5–6 (modularização) |

**Por que o `audit` veio primeiro:** é read-only, entrega valor sozinho, roda em
qualquer repositório sem negociação — e o relatório dele é a especificação do que
a instalação precisa fazer. Construir a instalação antes do audit seria desenhar
sem dado.

**Emenda ao plano: `harness:install` no lugar de `harness:init` + `harness:retrofit`.**
Este documento previa duas skills. São uma só, com dois modos. O que muda entre
greenfield e legado é o risco e a ordem das fases, não o mecanismo: detecção,
geração de config, catraca e teste de fumaça são idênticos. Duas skills
duplicariam os quatro, e a duplicação divergiria na primeira correção aplicada a
só um dos lados. Registrado em `CHANGELOG.md` 0.2.0.

**Por que só Node:** `D4 → R10` exige declarar a ausência em voz alta, não cobri-la
mal. Uma linguagem bem feita, as outras anunciadas como não suportadas.

---

## 2. Preparação para multi-linguagem — sem construir

O erro a evitar é o fracasso nº 7 do `INTENT`: inventar abstração a partir de um
exemplo só. Preparamos duas coisas, ambas sem código:

**O contrato de adaptador, escrito.** Quatro verbos, invariantes porque vêm da
pirâmide de verificação e não da ferramenta:

| verbo | responsabilidade |
|---|---|
| `detect` | esta stack é minha? |
| `generate-config` | produzir a configuração de fronteira |
| `run` | executar a verificação |
| `normalize` | traduzir a saída para `[{origem, destino, regra}]` |

Documentado com tabela de status: `node` implementado; `python`, `jvm`, `go`
declarados como não implementados.

**A catraca genérica, desde já.** `V8 → R7,R12`. A comparação com o baseline é do
harness, não da ferramenta — `dependency-cruiser` tem baseline nativo,
`import-linter` não tem nenhum, ArchUnit tem outro formato. Se a catraca depender
do mecanismo nativo, ela existe em duas linguagens de quatro e a fase 2 é reescrita
quando chegar a terceira. Custo hoje: ~20 linhas. Custo depois: refazer.

---

## 3. A skill `harness:audit`

Read-only. Não altera nada. Produz um relatório.

### O que coleta

**Contexto do repositório** — stack, gerenciador de pacotes, monorepo ou
polirepo, CI existente, testes, typecheck.

**Harness existente** — `CLAUDE.md`, definições de agente e comando, hooks,
permissões, configurações de outras ferramentas de agente.

**Verificação das afirmações** `C4 → R1` — **executa** o que o `CLAUDE.md`
afirma e marca o que é falso. Comando citado que não existe é o achado mais
comum e o mais barato de corrigir.

**Grafo de dependência real** — ciclos, direções, módulos de fato. Descritivo,
nunca comparado a um template `C6 → R7`.

**Estado do baseline** — quantas violações existiriam sob um gate. É o número que
decide se a catraca é obrigatória.

**Postura de risco** `A → R5` — caminhos para produção, segredo versionado,
permissões ausentes.

**Parâmetros não declarados** `§11` — teto de autonomia e dono, que em repositório
sem harness simplesmente não existem.

### O que produz

Relatório com três listas — **remover**, **corrigir**, **adicionar** — e um
sumário de conformidade contra o checklist da §12 do `HARNESS.md`.

> A lista de **remover** costuma ser a mais valiosa. Repositório com harness
> antigo sofre de excesso: `CLAUDE.md` que virou documentação, comando citado que
> não existe, ferramentas conectadas e não usadas. `P1 → R1`

### Princípio de implementação

**A skill decide; o script executa.** Detecção de stack, execução das afirmações,
geração do grafo e contagem de baseline são determinísticos e vivem em `scripts/`.
LLM escrevendo config à mão é mais caro, mais lento e menos confiável que um
gerador — e não é reproduzível entre execuções.

---

## 4. Trilhos de implantação

### Modo B — projeto novo (greenfield)

Até a v2.1 este trilho se chamava "A" e o retrofit "B" — exatamente ao contrário
dos modos que a skill expõe. Os nomes aqui passam a ser os da skill: o que o
usuário lê no `install/SKILL.md` é o que ele encontra neste documento.

Resolvido pelo scaffold. Sequência: copiar; renomear módulos para o domínio real;
ajustar os paths da config de fronteira junto; instalar dependências (sem
`typescript-eslint` o lint do gate falha por config, não por código); preencher
ambiente e deploy;
substituir o exemplo pelo primeiro caso de uso real; **plantar violação e confirmar
que o gate reprova** `V9 → R3`.

O exemplo do scaffold é o que o agente vai imitar. Trocá-lo cedo importa mais do
que parece.

### Modo A — projeto existente (retrofit)

| fase | o que faz | toca código? | aceite |
|---|---|---|---|
| **0** | auditoria, relatório | não | relatório aponta instrução falsa quando existe |
| **1** | hooks, permissões, comandos, dono, teto | não | gate roda, passa hoje, reprova violação plantada |
| **2** | **catracas** (fronteira e tamanho) | não | dois baselines commitados; violação nova reprova, antiga não; arquivo acima do teto não cresce |
| **3** | contexto: raiz enxuta + `CLAUDE.md` por módulo existente | não | toda afirmação executa |
| **4** | roster onda 1: revisor de mudança, arquiteto | não | cada um declara o que não repete `G3`. Fora do escopo da skill hoje — com uma exceção: o template do modo B já traz `.claude/agents/architect.md`, então projeto novo nasce com metade da onda |
| **5** | piloto de modularização | **sim** | fora do escopo do harness |
| **6** | catraca apertando | sim | baseline decrescente por sprint |

**A fase 2 é onde o valor chega.** Congelar as violações existentes e falhar só no
novo transforma "40 erros, gate inútil" em "40 erros parados". A decadência para
antes de qualquer refactor. Se a implantação for interrompida, que seja depois
dela.

**As fases 0 a 4 não tocam código-fonte.** Isso não é conveniência: é o que torna
a adoção possível `R7, R10`. Deve ser dito explicitamente na venda interna.

**A fase 1 registra dois parâmetros obrigatórios** `A6, D6`: teto de autonomia
(default `supervisionado`) e dono nomeado. Sem o segundo, nenhum critério de
sucesso tem observador.

---

## 5. Empacotamento

### A bifurcação — decidida

Havia duas opções. **A escolha foi repositório separado**, e está no disco:
`harness-skills`, com marketplace próprio (`harness-mp`) e release por tag
`harness-v*`. O que a tabela abaixo previa como custo — CI e validação
duplicados — não se materializou: o `validate.sh` e o `run.sh` deste repositório
não têm equivalente no `vibe`, então não há duplicação, há divergência de escopo.

| | plugin separado, mesmo marketplace | repositório separado |
|---|---|---|
| CI, validação, release | reaproveitados | duplicados |
| Instalação para quem adota | um `marketplace add` | dois |
| Cadência de release | independente **se** houver tag por prefixo | independente por construção |
| Custo | uma linha no workflow | manutenção paralela |

A recomendação original era plugin separado no **mesmo** marketplace, com tag por
prefixo. O prefixo ficou (`harness-v0.2.9`), o marketplace compartilhado não: com
repositório próprio, a cadência já é independente por construção e o prefixo passa
a ser convenção de leitura, não mecanismo de separação.

**Por que plugin separado e não mais uma skill dentro do `vibe`:** as skills de
julgamento são portáveis e rodam em qualquer lugar, inclusive num chat. As de
harness escrevem arquivos, precisam de shell e só fazem sentido em ambiente
agêntico com acesso ao repositório. Misturar as naturezas quebra a promessa de
portabilidade e gera skill que "não funciona" para metade dos usuários.

### Composição com o que já existe

`harness:*` **consome** o resultado da disciplina de modularização — o grafo
permitido vira config executável — e **detecta** quando ela é necessária: catraca
que não encolhe é o sinal. Nenhuma das duas duplica a outra `§10`.

---

## 6. Processo de deploy da skill

**Versionamento.** Semântico, por plugin. Menor até o primeiro adotante externo;
`0.x` enquanto o contrato de adaptador não estiver exercitado por uma segunda
linguagem — antes disso não há evidência de que ele está certo.

**Validação automática, antes do release.** O `validate.sh` precisa checar, no
mínimo: frontmatter presente e `description` não vazia; caminhos referenciados
existentes; scripts com bit de execução; nenhum segredo em arquivo versionado; e
todo comando citado na documentação da skill efetivamente executável — a mesma
regra C4 aplicada ao próprio produto.

**Publicação por tag com prefixo**, disparando release apenas do plugin
correspondente.

**Changelog obrigatório por release.** Skill que modifica repositório alheio sem
changelog é impossível de adotar com confiança.

**Rollback.** Versão anterior instalável, e o `retrofit` idempotente `D3 → R10` —
arquivos gerados marcados com versão, customização manual nunca sobrescrita.

**Feature que precisa entrar em arquivo já editado.** Aconteceu na 0.3.0, com a
telemetria: os três hooks precisavam ser instrumentados, e `guard-prod.sh` é
justamente onde o projeto adotante acrescenta regras à mão. A saída **não** é
abrir exceção em D3. É enxertar: o instalador insere um bloco que envolve a
função existente sem mover uma linha das regras locais, valida o resultado com
`bash -n` antes de trocar o arquivo, e **declara no relatório** o que fez e com
que granularidade — inclusive quando não deu, caso em que o arquivo fica intacto.
Toda feature futura que precise tocar hook segue esse trilho.

---

## 7. Evals antes de publicar

Skill que modifica repositório alheio sem eval é risco não medido. Mínimo de cinco
formatos:

1. Legado TS, monolito, sem testes, muitos ciclos
2. Monorepo TS com pacotes
3. Python — **testa a degradação honesta** `D4`
4. Repositório que **já tem** harness — testa idempotência e lista de remoção
5. Repositório vazio — trilho A

Métrica por eval: rodou sem erro · não escreveu nada (no caso do `audit`) ·
apontou instrução falsa quando ela existia · não sobrescreveu customização ·
declarou em voz alta o que não suporta.

**E um eval negativo, que costuma faltar:** repositório onde o harness **não**
deveria ser instalado — script de uso único, protótipo descartável. A skill deve
dizer isso em vez de instalar.

---

## 8. Riscos

| risco | mitigação |
|---|---|
| Só funciona em TS | contrato de adaptador escrito; ausência declarada, nunca silenciosa `D4` |
| Monorepo vs polirepo | detectar na fase 0 e tratar como dois retrofits distintos |
| Retrofit sobrescreve customização | marca de versão; nunca sobrescrever edição manual `D3` |
| Repositório vermelho sem catraca | fase 2 obrigatória antes de ligar qualquer gate em legado `V7` |
| Gate nunca testado | violação plantada obrigatória ao fim de toda instalação `V9` |
| Teto de autonomia contornado | sustentado por permissão, não por hook `A8` |
| Time rejeita | fases 0–4 não tocam código; dizer isso explicitamente |
| Testado só na casa do autor | eval em repositório de terceiro antes do primeiro release |

---

## 9. Sequência recomendada

1. ~~**`harness:audit`, Node apenas.**~~ Feito em `0.1.0`.
2. ~~**`harness:install`, modo A fases 1–3 e modo B.**~~ Feito em `0.2.0`. A
   catraca é a entrega, e os dois trilhos couberam numa skill só (§1).
3. ~~**Evals: instalação em vazio, em legado com violações, idempotência, stack
   sem adaptador, e o negativo.**~~ Feito em `0.2.0`.
4. **Rodar em um piloto pequeno e bagunçado.** Repositório limpo tem baseline
   vazio, catraca sem função, e não ensina nada sobre a fase que decide. É o
   próximo passo, e o único que ainda não tem dado.
5. **Repositório de terceiro.** ~~Harness testado só na casa do autor sempre
   parece funcionar.~~ Aconteceu parcialmente em `0.2.8`: um avaliador externo
   rodou a skill num repositório real e achou que `git tag -a v1.2.3 -m rel`
   contornava a trava de produção — a forma usual de release. Um uso, um defeito
   grave encontrado, e nenhum eval daqui o teria pego. O passo continua aberto
   porque um repositório não é evidência; a lição é que ele vale mais que o passo
   4.
6. **Roster onda 1** — revisor de mudança e arquiteto (fase 4 do §4).
7. **Segundo adaptador de linguagem.** É o que vai revelar onde o contrato de
   quatro verbos está errado.
8. **Piloto de modularização** em repositório real, já com o harness instalado.

---

## 10. Decisões em aberto

| decisão | quem decide | bloqueia | estado |
|---|---|---|---|
| Plugin separado ou repositório separado | mantenedor | §5 e §6 | **fechada:** repositório separado, marketplace `harness-mp`, tag `harness-v*` |
| Formato do arquivo de teto de autonomia | mantenedor | fase 1 | **fechada:** `.harness/harness.json → autonomy_ceiling`, enum validado, o valor gravado vence a flag (A7) |
| Repositório piloto | mantenedor | passo 4 da §9 | aberta |
| Segunda linguagem a suportar | evidência de uso | validação do contrato | aberta |

Decisão fechada fica na tabela com o resultado em vez de sair dela: o valor deste
documento é registrar o que foi decidido, e uma linha apagada não conta a
história. Nenhuma das duas abertas bloqueia usar o que já existe.
