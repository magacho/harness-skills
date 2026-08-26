# Changelog

Skill que modifica repositório alheio sem changelog é impossível de adotar com
confiança.

## [0.2.5] — 2026-08-26

### Corrigido
- **`gen-config.sh` apagava as negações de permissão do projeto no reinstall.**
  O defeito mais caro que o harness teve, porque o dano era invisível e o arquivo
  é justamente onde mora a garantia. A expressão de merge indexava `.[0]` **depois**
  de `.[0] * .[1]`, onde o contexto já é o objeto mesclado — erro de tipo em toda
  execução. O `|| jq -s '.[0] * .[1]'` engolia o erro, e o `*` do jq deixa o lado
  direito **substituir** o array: um repositório com 23 negações customizadas
  ficava com 12, perdendo as travas de tag semver, `pnpm etl:*`, `gh workflow
  run`, leitura de `*key*.json` e três ferramentas MCP de escrita. O script
  reportava `.claude/settings.json (merge)` e saía 0
- **O mesmo caminho perdia hook do projeto.** `hooks.<evento>` é array, então o
  `*` substituía a entrada do time pela do harness. Um `PreToolUse` próprio
  desaparecia sem uma linha de aviso — pior que a perda de permissão, porque não
  há como notar sem diff
- **O fallback foi removido, não corrigido.** `expr || fallback` foi o que
  transformou erro de sintaxe em perda de dados que reporta sucesso; consertar só
  a expressão deixaria o padrão pronto para esconder o próximo erro. Agora, se o
  merge não pode ser feito com segurança, o arquivo **não é tocado**, entra em
  `pulados` dizendo `PERMISSÕES NÃO INSTALADAS (A2/A8 → R5)`, e a proposta fica em
  `.harness/settings.proposto.json` para merge à mão — que é o que D3 já manda
  fazer com tudo que foi editado à mão
- `scaffold.sh` tinha a mesma família em menor escala: `jq ... && mv` sem `else`.
  Falha de jq deixava o arquivo do template como estava, em silêncio. Agora avisa

### Adicionado
- **`scripts/merge-settings.jq`** — o merge saiu de dentro do gerador e virou
  função com regra por caminho e teste próprio: união de conjunto em
  `permissions.*`, substituição da entrada do harness em `hooks.*`, merge
  recursivo no resto, escalar novo vence. A entrada do harness é reconhecida pelo
  **caminho** (`.claude/hooks/{on-edit,verify,guard-prod,cleanup}.sh`) e não pelo
  objeto inteiro: comparar o objeto deixaria a entrada velha para trás na primeira
  vez que um timeout mudasse, e o repositório rodaria o hook duas vezes
- **Duas invariantes verificadas contra o resultado**, depois do merge e antes de
  escrever: nenhuma negação do projeto desapareceu (A7 → R5), e nenhum comando de
  hook fora de `.claude/hooks/` desapareceu. A checagem é independente da lógica
  do merge de propósito — guarda que reusa o que verifica esconde o próprio
  defeito. O critério "fora de `.claude/hooks/`" evita enumerar os hooks do
  harness, que mudam de versão para versão
- Caso de eval `55-merge-settings` (21 testes): a união, a substituição, a
  idempotência em três rodadas, e a recusa. Um dos testes afirma que **o merge
  ingênuo perderia**, para que a intenção fique registrada onde alguém vai ler
- `validate.sh` reprova a **família**, não a instância: `.[0]` indexado depois de
  um `*`, `|| jq` como fallback, e a ausência de qualquer uma das invariantes.
  Os três guards foram verificados quebrando o código de propósito (V9 aplicado
  ao validador)

- **`docs/CONFORMIDADE.md`** — mapa de validação: para cada um dos 17 critérios de
  `HARNESS.md` §12, qual mecanismo o verifica, em que arquivo, se é determinístico
  puro, garantia de permissão ou julgamento por leitura, e qual eval o prova. O
  checklist dizia o que precisa ser verdade e não dizia quem verifica — e a
  resposta não era a mesma para todos: A5 e V11 são determinísticos no produto
  (`validate.sh`) e leitura no repositório alvo. Documenta também as sete
  garantias que reprovam sozinhas e não estão no §12, e as cinco lacunas
  conhecidas, incluindo a única cuja conformidade hoje é declarada e não
  verificada (segredo no repositório alvo, A5)

### Notas de desenho
- A primeira escrita de `settings.json` também passa pela função de merge, contra
  `{}`. Escrever `$novo_settings` direto produzia ordem de chave diferente da que
  o merge produz, e a segunda instalação reescrevia o arquivo só por isso —
  idempotência quebrada por formatação (D3 → R10). O eval de idempotência pegou

## [0.2.4] — 2026-08-26

### Adicionado
- **Catraca de tamanho** (`.harness/gate-size.sh`, V10 → R4,R7). O harness já
  garantia direção de dependência e ausência de ciclo; god file passava limpo.
  Agora arquivo acima do teto (400 linhas) entra no baseline e **não pode
  crescer**, e arquivo novo acima do teto reprova. Semântica diferente da
  catraca de fronteira de propósito: fronteira é presença (diferença de
  conjunto), tamanho é grandeza — o baseline é `{caminho: linhas}` e a
  comparação é `>`
- O gate de tamanho **não tem adaptador**: contagem de linha é o único oráculo
  estrutural que existe em toda linguagem. Numa stack sem gate de fronteira,
  onde antes não havia gate estrutural nenhum, agora há um — e o teste de fumaça
  o prova (V9), em vez de sair 3 sem provar nada
- `--rename <antigo> <novo>` no gate de tamanho. Sem ele, renomear um arquivo do
  baseline reprovava um commit legítimo, e a saída natural seria editar o
  baseline à mão — que é exatamente o que V7 proíbe. O rename move a entrada e
  nunca aumenta o número
- **`eslint.config.js` no template** com `max-lines-per-function` em 60,
  `complexity` em 10 e `max-depth` em 4 (V11 → R4). Isento em arquivo de teste:
  `describe` com trinta casos é bom teste e passaria dos sessenta
- `harness:audit` ganhou `scripts/size-status.sh` — mede mediana, p95 e quantos
  arquivos passam do teto, **sem instalar nada**. O número absoluto sozinho não
  decide: mediana 90 com dez pontos quentes é um repositório saudável, mediana
  600 é outra conversa
- `HARNESS.md` 2.1: regras **V10** (catraca de tamanho) e **V11** (limite de
  função no linter, limite de arquivo na catraca — nunca os dois no mesmo lugar)

### Corrigido
- O template não tinha **nenhum** `eslint.config.js`. Com ESLint 9, `pnpm lint`
  e o passo 1 do hook de turno falhavam por config ausente em todo scaffold
  novo — e o agente lê "erro de config" como "meu código está errado". A
  dependência `typescript-eslint` também faltava, sem a qual o parser não lê
  `.ts`
- `verify.sh` do template invocava `npx depcruise` direto, ignorando o baseline:
  o modo B tinha um gate com resposta diferente do modo A. Agora chama
  `.harness/gate-boundaries.sh`, como o retrofit
- C5 (`HARNESS.md`) foi renomeada para **"Alvo de tamanho do CLAUDE.md"**. Como
  "C5 — Alvo de tamanho", era lida como limite de código-fonte, quando sempre
  tratou do arquivo de contexto

### Interno
- **Os evals foram divididos por família.** `evals/run.sh` tinha 424 linhas e era
  o único arquivo do repositório acima do teto que esta versão publica. Virou um
  corredor de 68 linhas mais `evals/cases/*.sh`, onze arquivos de 22 a 62 linhas,
  carregados com `source`. Roda um caso só com `./evals/run.sh 70-catraca-tamanho`
- **Cada caso monta o próprio repositório** (`legado_instalado <nome>`). Havia um
  `$W/legado` atravessando meia suíte: a ordem dos blocos era carregada e
  invisível — a fase 3 dependia de a fase 2 ter rodado antes, e mexer num bloco
  quebrava outro três telas abaixo. Custa ~0,4s por caso e o tempo total não
  mudou (20s), porque o arquivo único já refazia plano e fase 1 no meio do
  caminho
- A função **recusa** nome de fixture já usado. Foi o defeito que a própria
  divisão produziu na primeira tentativa: `cp -a src dst` com `dst` existente
  copia para dentro, e dois casos com o mesmo nome mediam uma árvore aninhada
  com cara de sucesso
- `validate.sh` passa `bash -n` em todo shell do repositório e exige que cada
  caso declare numa linha o que testa. Nada checava sintaxe antes — e um
  `source` com erro de sintaxe aborta o corredor inteiro

### Notas de desenho
- **Teto absoluto foi descartado para legado.** Reprova centenas de arquivos no
  primeiro turno, o time desliga o gate, e gate desligado é pior que gate
  nenhum. O mesmo número age como limite absoluto em projeto novo, onde o
  baseline nasce vazio
- **Contagem de arquivos por módulo não virou gate.** Mede ao contrário do que
  se quer: módulo de dados com 40 repositórios pequenos é saudável, domínio com
  6 arquivos de 900 linhas é doente, e a contagem premia o segundo. O sinal
  mecânico honesto nesse nível é a largura da fronteira exportada, não a
  contagem — e responsabilidade dupla continua sendo julgamento do subagente
  `architect`
- **A via de escape é conhecida e está tapada.** Todo gate de tamanho convida a
  partir o arquivo em `-parte2`. A recusa do gate ensina a saída certa (A4 → R1),
  e a partição arbitrária quase sempre cria import mútuo ou órfão — que cai em
  `sem-ciclos` e `sem-orfaos`. O gate de fronteira é a rede do gate de tamanho:
  é por já existir que o de tamanho é defensável

## [0.2.3] — 2026-08-26

### Corrigido
- `/harness:version` **não mostrava a saída**. O comando pedia ao modelo que
  rodasse o script e colasse o resultado — execução por instrução, que depende
  de o modelo decidir obedecer, e às vezes ele resume em vez de repetir. Agora
  usa injeção dinâmica (`` !`comando` ``): o Claude Code executa o script e
  substitui a linha pela saída **antes** de o conteúdo chegar ao modelo, então
  o resultado já está em contexto sem chamada de ferramenta. O que era pedido
  virou mecanismo
- `allowed-tools` passou a declarar a regra exata do script
  (`Bash(${CLAUDE_PLUGIN_ROOT}/scripts/harness-version.sh *)`) em vez de `Bash`
  genérico: casa com o comando injetado e roda sem prompt de permissão
- `validate.sh` confere que todo comando com injeção dinâmica tem regra
  `allowed-tools` que casa com o comando real. Sem a regra o usuário leva prompt
  e a injeção deixa de ser determinística — degrada de volta para "o modelo
  decide rodar", que era o defeito

## [0.2.2] — 2026-08-26

### Adicionado
- Comando **`/harness:version`** — mostra a versão da skill em execução, a
  versão que instalou o harness do repositório atual, o dono, o teto de
  autonomia e o estado da catraca. As duas versões divergem com o tempo, e a
  divergência é a informação acionável: arquivo gerado carrega marca de versão
  justamente para que a próxima instalação saiba o que é dela (`D3 → R10`).
  Quando o marketplace é um diretório local e a fonte está à frente do que roda,
  o comando diz que o cache está velho
- Primeiro comando do plugin. `plugin/commands/` e `plugin/scripts/` passam a
  existir ao lado de `plugin/skills/`
- 9 evals do comando (111 → 120)

### Corrigido
- `scripts/validate.sh` **imprimia a falha e mesmo assim dizia "pronto para
  release"**. Os dois laços que conferem caminhos citados rodavam dentro de
  pipe, e pipe cria subshell: o `fail=1` do `err` morria lá dentro. Valia para o
  check de caminhos das skills desde o 0.1.0 — nunca conseguiu reprovar nada.
  Trocado por substituição de processo. É o mesmo defeito que o resto deste
  release corrigiu nos scripts de auditoria, desta vez no validador do produto
- `validate.sh` agora também confere frontmatter e caminhos citados nos
  comandos, a mesma regra C4 aplicada ao próprio produto

### Nota
Os evals do comando usam `grep` sem `-q` de propósito: `-q` fecha o pipe ao
primeiro casamento e, com `pipefail` ligado, o produtor morre de SIGPIPE e o
pipeline sai 141 mesmo tendo casado. Os demais `grep -q` da suíte passam porque
o produtor termina antes; é fragilidade latente, não defeito ativo.

## [0.2.1] — 2026-08-26

Release de correção. Dois grupos de defeito com a mesma raiz: **um gate ou um
script reportando sucesso sem ter medido** — a falha nº 5 do `INTENT.md`, criar
a sensação de cobertura. O 0.2.0 já a tinha corrigido no adaptador; faltava
aplicar a mesma guarda em todo o resto.

### Corrigido — o gate não cruzava o grafo em TypeScript
Todo projeto TS recebia um gate instalado que nunca verificou nada. E como o
adaptador só recusa o falso verde quando cruza *zero* módulo, bastava um `.js`
no alvo para o gate reportar "sem violações" tendo olhado uma fração do código.

- `dependency-cruiser` 18 não expande **diretório nu** para `.ts`/`.tsx`: só
  entra sob glob. A 16 expandia — e o `package.json` do template fixa `^16`,
  enquanto o adaptador cai em `npx` (que baixa a 18) quando o repositório não
  tem a ferramenta instalada. O mesmo gate dava respostas diferentes conforme
  existisse `node_modules`, que é garantia dependendo de configuração de máquina
  (`D1 → R8`). O verbo `run` agora converte alvo que é diretório em
  `alvo/**/*.{ts,tsx,mts,cts,js,jsx,mjs,cjs}`
- A correção é **no adaptador**, não nos três chamadores (`boundary-status.sh`,
  `gate/boundaries.sh`, `plan-install.sh`): saber qual glob a ferramenta exige é
  conhecimento do adaptador, e é o que o contrato de quatro verbos existe para
  absorver. Corrigido lá, vale para audit, install e gate de uma vez
- O glob é restrito a extensões de código de propósito. `alvo/**` varre
  `CLAUDE.md` e cada um vira órfão: 4 violações fantasma por repositório, todas
  no baseline
- `enhancedResolveOptions.extensions` passou a ser gerado na config e foi
  acrescentado à do template. Sem ele a 18 não resolve import TypeScript sem
  extensão (`./invoice`): registra o especificador cru, a regra de direção não
  casa, e o import legítimo vira violação. A 16 resolvia sozinha
- `ADAPTADOR_NAO_CRUZOU` listava duas causas e nenhuma era a verdadeira neste
  caso. Somada a terceira, com a instrução de que a conversão de alvo deveria
  ter rodado
- O script `boundaries` do template chamava `depcruise ... modules` direto,
  passando por fora do gate e do baseline. Agora chama
  `./.harness/gate-boundaries.sh`

### Corrigido — a auditoria reportava sucesso sem ter medido
- `boundary-status.sh` cruzava os diretórios `src modules` fixos. Repositório
  cujo código não está em `modules/` recebia um ENOENT, não media nada e **ainda
  assim saía 0** — a dimensão do baseline, que é o número que decide se a
  catraca é obrigatória, voltava vazia com cara de sucesso. Agora detecta os
  alvos reais, sai 3 quando não consegue medir, e devolve JSON com `alvos`,
  `violacoes`, `por_regra` e `catraca_obrigatoria`
- `boundary-status.sh` passou a usar o adaptador pelos **quatro verbos** em vez
  de invocar o `dependency-cruiser` à mão. A guarda de "cruzou zero módulo" já
  morava no adaptador; duas implementações divergiriam na primeira correção
  aplicada a só um dos lados. Removida também uma linha morta que rodava
  `depcruise --no-config` com stdin vazio e descartava a saída
- `detect-stack.sh` procurava só `.dependency-cruiser.js`, mas o instalador
  escreve `.cjs`; e procurava o baseline **nativo** da ferramenta em vez de
  `.harness/baseline.json`. O audit reportava `boundary_config: false` e
  `baseline: false` em repositório que tinha os dois — ficava cego para a
  instalação que a skill irmã acabara de fazer. Agora aceita as quatro extensões
  e distingue os dois baselines: achar o nativo é um **achado**, porque significa
  catraca delegada ao mecanismo da ferramenta (V8)
- `check-claims.sh` só verificava script de `package.json` e alvo de `Makefile`.
  O `CLAUDE.md` que o próprio harness gera cita `./.harness/gate-boundaries.sh`
  — apagar o gate não aparecia como instrução falsa e o audit reportava
  `falsas=0`. Agora verifica caminho executável citado em crase: ausente ou sem
  bit de execução conta como falso (C4 → R1)

### Adicionado
- `docs/USAGE.md` — guia de uso com avaliação, instalação nos dois modos e a
  saída real de cada passo, capturada das fixtures. Nenhum exemplo é ilustrativo
- `evals/fixtures/ts-com-ciclo/` — fixture TypeScript com ciclo e órfão
  conhecidos, imports **sem extensão**. Todo fixture com grafo era JavaScript,
  onde o diretório nu funciona: a suíte inteira ficava verde com o defeito
  presente
- `detect-stack.sh` reporta `harness_dir`, `gate`, `adapters`, `versao`, `dono` e
  `teto_de_autonomia`, lidos de `.harness/harness.json`. Sem isso a auditoria não
  distinguia repositório instalado de repositório cru, nem verificava D6 sem
  abrir arquivo à mão
- O verbo `run` do adaptador aceita config em caminho absoluto, para que a
  sondagem do audit não precise escrever dentro do repositório auditado.
  "Escreve e apaga depois" não é read-only
- 25 evals novos (86 → 111). Os de fronteira afirmam `totalCruised > 0` **e** a
  contagem esperada de violações — um eval que só checasse "saiu 0" continuaria
  passando com o bug, que foi exatamente o que aconteceu. Um deles entrega o
  diretório nu direto à ferramenta e exige que cruze zero: trava a regressão
  pelo mecanismo, não pelo sintoma

### Alterado
- `README.md` reordenado: abre nomeando o artefato — plugin do Claude Code com
  duas skills — em vez de abrir pela tese. Os dois sentidos de "instalar" (o
  plugin no Claude Code, o harness no repositório) passaram a ser separados por
  nome. A doutrina desceu, sem sair

### Nota
As 11 violações que apareceram no template quando o grafo passou a ser cruzado
**não eram reais**: 4 eram `CLAUDE.md` varridos pelo glob amplo e 7 vinham dos
imports não resolvidos. Sob a 16, com resolução correta, o template sempre teve
**0 violações** — e continua tendo, agora idêntico nas duas versões. Não houve
baseline inicial a congelar, e o template não precisou ser corrigido.

## [0.2.0] — 2026-08-25

### Adicionado
- `plugin/skills/install` — instala o harness em repositório novo ou existente.
  Uma skill, dois modos: o que muda entre eles é o risco e a ordem das fases,
  não o mecanismo
- Modo A (projeto existente): fases 1 a 3 do `PLAN.md` §4, com checkpoint humano
  entre cada uma. Não toca código-fonte em nenhuma delas
- Modo B (projeto novo): scaffold com renomeação dos módulos para o domínio real
  — diretórios, imports e paths da config de fronteira na mesma passada
- Catraca genérica (`V8 → R7,R12`): o baseline é `[{origem,destino,regra}]` e a
  comparação é do harness, não do mecanismo nativo da ferramenta. O baseline só
  encolhe, e o gerador recusa regerá-lo maior sem `--force`
- Contrato de adaptador **implementado**, não só escrito: `adapters/node.sh` com
  os quatro verbos `detect | generate-config | run | normalize`
- Gate de fronteira como comando invocável à mão (`D5 → R12`), instalado dentro
  do repositório junto com o adaptador — quem clona recebe o mesmo comportamento
  sem ter a skill (`D1 → R8`)
- Teste de fumaça obrigatório nos dois modos (`V9 → R3`): planta violação,
  confirma que o gate reprova, remove
- `.harness/harness.json` — teto de autonomia e dono, versionados. O teto é
  sustentado por `permissions.deny`, nunca por hook (`A8 → R5`)
- 5 evals novos: instalação em repo vazio, em legado com violações, idempotência,
  stack sem adaptador, e o negativo — repositório que não deveria receber harness

### Alterado
- `template/` saiu da raiz para `plugin/skills/install/assets/template/`. Solto na
  raiz, nenhuma skill o distribuía
- `harness:install` substitui os previstos `harness:init` e `harness:retrofit`.
  Emenda registrada em `docs/PLAN.md` §1
- `README.md` e `docs/PLAN.md` §1 e §9 não declaram mais a instalação como fora
  de escopo

### Corrigido
- `npx --yes depcruise` resolvia para um pacote-placeholder: o pacote é
  `dependency-cruiser`, `depcruise` é só o binário. Afetava
  `audit/scripts/boundary-status.sh`, que nunca chegou a cruzar nada
- O adaptador agora recusa reportar verde quando cruza zero módulo. Projeto
  TypeScript sem o compilador instalado devolvia "no violations" com o gate não
  tendo verificado nada — gate silenciosamente verde é pior que gate nenhum

### Conhecido
- Adaptador de fronteira apenas para JS/TS
- A fase 4 do `PLAN.md` (roster onda 1) não é instalada; a skill diz isso ao
  terminar, em vez de deixar como omissão
- Em modo A, a config de fronteira gerada proíbe só ciclo e órfão. Regra de
  direção entre módulos é decisão de arquitetura, e o harness verifica
  fronteiras sem desenhá-las (`HARNESS.md` §10)
- Nunca rodou em repositório de terceiro

## [0.1.0] — 2026-08-20

### Adicionado
- `docs/INTENT.md` v1.1 — 12 resultados, teto de autonomia parametrizável,
  especificação como etapa
- `docs/HARNESS.md` v2.0 — 45 regras, todas rastreando a um resultado
- `docs/PLAN.md` v2.0 — trilhos greenfield e retrofit, processo de deploy
- `docs/adapters/README.md` — contrato de quatro verbos
- `plugin/skills/audit` — auditoria read-only, stack Node/TS
- `template/` — scaffold com quatro módulos e fronteiras verificáveis
  (movido para dentro da skill `install` em 0.2.0)
- `evals/` — 9 evals, 4 fixtures
- `scripts/validate.sh` — validação do produto antes do release

### Conhecido
- Adaptador de fronteira apenas para JS/TS
- `harness:retrofit` e `harness:init` não implementados
- Contrato de adaptador exercitado por uma só implementação
