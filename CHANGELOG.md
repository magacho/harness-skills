# Changelog

Skill que modifica repositório alheio sem changelog é impossível de adotar com
confiança.

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
