# Changelog

Skill que modifica repositório alheio sem changelog é impossível de adotar com
confiança.

## [0.3.0] — 2026-08-27

O harness instalava quatro hooks e dois gates, e **nenhum deixava rastro**. O
`on-edit.sh` gravava em `/tmp/cc-touched-*` e o `cleanup.sh` apagava no
`SessionEnd`, de propósito. A consequência é que o dono do repositório não
conseguia responder "o harness está funcionando?" sem arqueologia nos transcripts
do Claude Code — onde só o hook `Stop` aparece; `guard-prod.sh` e `on-edit.sh`
eram invisíveis.

Um harness que protege sem registrar não é auditável. E um gate desligado por
engano se parece exatamente com um gate que nunca precisou reprovar.

### Adicionado — a trilha (V12 → R6)
- **`.harness/log.sh`** — emissor sourceado pelos três hooks que decidem. Uma
  linha JSON por evento em `.harness/log/events-AAAA-MM.jsonl`, append-only, com
  rotação mensal pelo nome do arquivo e retenção aplicada quando o mês vira.
  Três invariantes, e todas valem mais que qualquer evento:
  - **nunca falha e nunca bloqueia.** A casca
    `harness_log() { { … } >/dev/null 2>&1 || true; }` torna isso estrutural em
    vez de disciplina. Disco cheio, `jq` ausente ou diretório sem permissão não
    podem derrubar um hook — muito menos o `PreToolUse`, que decide permissão:
    perder uma linha de log é barato, perder a trava de produção não é;
  - **nunca vaza segredo.** No veredito `allow` entra só o primeiro token do
    comando (`harness_bin`): `API_KEY=segredo pnpm build` vira `pnpm`. Só no
    `deny` o comando é gravado, e o truncamento em 200 caracteres mora no
    emissor, não no chamador — regra de vazamento que depende de cada call site
    lembrar já vazou;
  - **nunca fala.** Nada em stdout, que no `PreToolUse` é o protocolo de decisão.
- **`.harness/stats.sh`** — leitor read-only, com `--since 7d|30d|all|AAAA-MM-DD`,
  `--json` e `--denies`. A ordem das seções é a ordem das perguntas do dono, e a
  primeira é sempre *o que ele impediu?*. Responde ainda: reprovações do gate de
  turno por gate, com duração mediana; estado das duas catracas, com **há quantos
  dias não encolhem** (lido do `git log`, comparando o baseline com o do commit
  anterior); cobertura, onde `lint` ausente aparece como **lacuna** e não como
  silêncio; e os arquivos mais tocados.
- **`/stats`** — o comando roda o script e **interpreta**: aponta o gate que
  nunca disparou, a catraca parada, a lacuna de cobertura. Não repete números.
- **`instrument-hook.sh`** — o retrofit de hook editado à mão, descrito abaixo.
- **`75-telemetria`** — 56 testes. Entre eles: com o arquivo da trilha sem
  permissão de escrita o `guard-prod` continua negando e o evento é perdido em
  silêncio; `API_KEY=` e a senha de uma URL do `psql` não aparecem em byte nenhum
  do arquivo; e o hook permissivo continua com stdout vazio.

### Adicionado — quem lê a trilha
- **`/harness:stats`** (comando do plugin) — mostra o que está gravado nesta
  máquina, sem interpretar: relatório completo deste repositório, ou uma tabela
  com todos os que têm trilha. A linha que justifica a tabela é `sem-emissor` —
  repositório com harness anterior à `0.3.0`, gates funcionando e **nenhum
  registro deles**. Sem essa distinção ele apareceria como `0 eventos,
  0 bloqueios`, indistinguível de um repositório tranquilo. Complementa o
  `/stats` instalado no repositório, que é quem julga.
- **`harness:audit` passa a medir a trilha.** `telemetry-status.sh` entra na
  coleta mecânica, o relatório ganha a seção **Trilha**, e o modo de permissão
  predominante entra na postura de risco (§3.1): em `bypassPermissions` o
  `permissions.allow` do repositório auditado não tem efeito algum. Os quatro
  estados — `medindo`, `sem-emissor`, `desligada`, `vazia` — significam coisas
  diferentes, e a skill é instruída a não colapsar nenhum deles em "0 bloqueios".
- **`stats.sh --root <dir>`** — é o que torna o item acima possível sem uma
  segunda implementação. O audit e o comando da máquina chamam o **mesmo** leitor
  que o repositório instalado usa; `validate.sh` reprova consumidor que leia
  `events-*.jsonl` por conta própria. Mesma razão pela qual o gate de tamanho
  expõe `--measure --root`: foi a varredura em três cópias que fez o plano
  acusar god file em `.next/`.

### Adicionado — honestidade do número (V13 → R6)
- **`0 bloqueios` tem três significados, e o relatório diz qual é.** Trilha vazia
  é *sem dado*; trilha que cobre a janela é *um fato sobre o repositório*; trilha
  mais curta que a janela é *não há dado sobre o resto*. Confundir os três produz
  confiança falsa, e confiança falsa em número de segurança é pior que não ter o
  número.
- **Fonte secundária rotulada.** Quando a trilha é mais curta que a janela, o
  leitor complementa com os `stop_hook_summary` dos transcripts e marca a seção
  como **reconstruída**, nunca como medida — histórico no dia zero em vez de
  relatório vazio.
- **Modo de permissão predominante.** Lido dos transcripts, que são a única fonte
  disponível. Quando for `bypassPermissions`, o relatório diz em voz alta que o
  bloco `permissions.allow` do `settings.json` não tem efeito algum — só as
  negações são honradas — e que a dupla trava de produção passa a depender só do
  hook. Metade da configuração de permissão que a instalação escreveu vira
  decoração enquanto isso durar, e hoje ninguém percebe.

### Adicionado — retrofit sem perder regra escrita à mão
A `0.3.0` precisa instrumentar os hooks, e `guard-prod.sh` é justamente onde as
regras do projeto são acrescentadas ao fim. **Perder uma regra `deny` escrita à
mão para ganhar estatística seria um péssimo negócio**, então:

- sha bate → o hook é reescrito inteiro e já sai instrumentado;
- sha não bate → a telemetria é **enxertada**. O bloco captura a função existente
  com `declare -f` e a chama depois de registrar, sem mover uma linha das regras
  locais. O resultado passa por `bash -n` antes de substituir o arquivo, porque
  hook quebrado é pior que hook sem trilha;
- não deu para enxertar → ação `nao-instrumentado` **com o motivo**, e o arquivo
  fica intacto (D4 → R10).

A granularidade menor do enxerto é declarada, não escondida: `guard-prod` editado
à mão registra o bloqueio como `nao-rotulado`, porque a assinatura antiga da
`deny()` não carrega o motivo — inventar categoria a partir do texto da recusa
seria pior que admitir a lacuna.

### Corrigido — defeitos encontrados construindo isto
- **`jq` lê `false` como vazio.** `.telemetry.enabled // true` devolve `true` para
  `{"enabled": false}`: a chave que desliga a telemetria seria lida como se a
  ligasse. Agora o teste é de igualdade, e `validate.sh` reprova a volta do `//`.
- **O enxerto duplicava a trilha.** A guarda de idempotência procurava a marca do
  próprio enxerto, e um hook **gerado** por esta versão já emite eventos por
  dentro — chegando ao enxerto pelo caminho do sha divergente depois de uma
  edição à mão. Cada `deny` entrava duas vezes e a estatística mostrava o dobro
  do que aconteceu. A guarda passa a ser por `harness_log`.
- **O eval reprovava quando o texto estava lá.** `stats.sh | grep -q` devolve 141
  sob `pipefail`: o `grep` fecha o pipe no primeiro casamento e o script morre de
  SIGPIPE. A saída vai para variável antes do teste.
- **`chmod` no diretório não impede append em arquivo existente.** O teste de
  "disco cheio" passava sem ter impedido nada; agora ele tira a permissão do
  arquivo.
- **O eval do enxerto media outra coisa a cada commit.** Ele montava o "hook da
  versão anterior" com `git show HEAD:` — e assim que a telemetria entrou no
  histórico, HEAD passou a devolver o hook já instrumentado: o caso exercitava
  `ja-instrumentado` achando que exercitava o enxerto. O hook agora é escrito no
  próprio eval, pelo formato e não pelo histórico.
- **Um caso sujava o estado do seguinte.** O teste de "reinstalar não religa a
  telemetria" deixava a fixture com `enabled: false`, e o caso do audit reprovava
  três telas abaixo, longe da causa.
- **Asset que menciona a marca de versão perde a linha na instalação.** O
  `copy_marked` remove toda linha que contenha `harness-generated:` antes de pôr
  a sua — e o `--help` do `stats.sh` tinha um `awk` que filtrava exatamente essa
  linha. O arquivo passava em `bash -n` aqui e saía quebrado no repositório do
  usuário. `validate.sh` passa a reprovar qualquer asset que cite a marca mais de
  uma vez.

### Alterado
- **A trilha se ignora de dentro de `.harness/`**, com um `.gitignore` próprio, e
  o `.gitignore` da raiz **não é tocado**. A especificação desta feature pedia
  uma linha na raiz, mas a raiz não está na fronteira de escrita de `HARNESS.md`
  §1 — e abrir exceção para uma linha de conveniência é como fronteira declarada
  vira fronteira negociável. `validate.sh` reprova quem escrever lá.
- **`deny()` do `guard-prod.sh` passa a receber o rótulo do motivo** como
  primeiro argumento (`release`, `tag-push`, `deploy-prod`, `prod-write`,
  `drop-truncate`). Regra local escolhe o seu.
- **`fail()` do `verify.sh` passa a receber o nome do gate** que reprovou.
- `cleanup.sh` é o único hook **não** instrumentado, de propósito: ele apaga
  rastro de sessão, e a trilha é persistente por definição.
- **`/harness:version` ganha a linha `trilha`** — ligada com N eventos, ligada e
  vazia, ou desligada. Telemetria desligada era exatamente a coisa que ficaria
  invisível: o `/stats` existiria e não teria o que ler.
- `HARNESS.md` vai a v2.2 (V12, V13, e os dois critérios novos em §12);
  `CONFORMIDADE.md` a v1.3, com a lacuna §6.6; `PLAN.md` a v2.3, registrando o
  trilho do enxerto para toda feature futura que precise tocar hook.
- `harness.json` ganha `telemetry: {enabled, retention_months}`. `enabled: false`
  faz os emissores virarem no-op imediato, o leitor diz isso em vez de imprimir
  relatório vazio, e **sobrevive a reinstalar** — a mesma regra que protege o
  dono e o teto de autonomia.

## [0.2.9] — 2026-08-26

Revisão da documentação inteira, cruzando cada afirmação verificável com o
código. Onze divergências, e a mais grave era a página que prega a regra C4
violando-a: `USAGE.md` declarava que nenhuma saída dela é ilustrativa e publicava
sete god files e um arquivo de 1840 linhas que nenhuma fixture tinha.

Nenhum comportamento de skill mudou. O que mudou é que essa classe de defeito
agora reprova no CI.

### Corrigido — afirmação falsa sobre o próprio produto
- **`USAGE.md`: os blocos de catraca de tamanho mediam um repositório
  inexistente.** `size.acima_do_teto: 7`, `maior: cobrar.js` com 1840 linhas,
  baseline `{cobrar.js: 1840, faturar.js: 612}` — o maior arquivo de qualquer
  fixture tem três linhas. Recapturado do real: um god file de 450 linhas, o
  mesmo que o eval `70-catraca-tamanho` planta. A prosa em volta media os números
  inventados e foi reescrita junto
- **`USAGE.md`: `copiados: 36` no scaffold** — são 33. E `residuo_de_prosa`
  mostrava 3 de 21 entradas sem dizer que estava cortado
- **`USAGE.md`: `check-claims.sh` e `detect-stack.sh` com saída de outra versão** —
  o primeiro prometia `FALSA pnpm build` sobre uma fixture que fala de `lint` e
  `typecheck`; o segundo trazia 8 campos de um objeto que tem 19
- **`USAGE.md`: marca de versão `0.2.1` em quatro blocos**, quatro releases atrás
- **`USAGE.md` §7: o gate de tamanho não estava na lista do que fica no
  repositório.** Faltavam `gate-size.sh` e `baseline-size.json`, e o
  `harness.json` de exemplo tinha 4 das 9 chaves. O gate que some da lista é
  justamente o único que vale em stack sem adaptador
- **`README.md`: "45 regras"** — o `HARNESS.md` tem 56
- **`README.md` e `USAGE.md`: instalação apontando para um caminho local.** O
  texto dizia "enquanto não há repositório remoto definido"; há, com `main` e as
  tags publicadas. Quem lia o README não conseguia instalar
- **"O roster da fase 4 não é instalado" era falso no modo B.** O template traz
  `.claude/agents/architect.md` e o scaffold o copia: projeto novo sai com metade
  da onda 1. Corrigido em `README`, `install/SKILL.md`, `USAGE.md`, `PLAN.md` e
  `CONFORMIDADE.md` — agora os dois modos declaram qual metade falta
- **`evals/README.md`: 12 casos de 13.** Faltava `05-guard-prod`, o caso de
  segurança que a 0.2.8 adicionou
- **`PLAN.md` chamava de trilho A o que a skill chama de modo B**, e vice-versa.
  Os nomes passam a ser os da skill
- **`PLAN.md` declarava em aberto duas decisões já fechadas:** repositório
  separado (está no disco, com marketplace e tag próprios) e o formato do arquivo
  de teto de autonomia (`.harness/harness.json → autonomy_ceiling`). Ficam na
  tabela com o resultado, não apagadas
- **`CONFORMIDADE.md` datava o furo de tag como sendo "de 0.2.8"**, que é a
  versão que o fechou
- Menores: `PLAN.md` derivava do `HARNESS.md` v2.0 e o v2.1 já estava
  incorporado; o `README` não listava `docs/adr/`; o `CLAUDE.md` do template
  dizia "quatro módulos" sobre uma tabela de cinco; `INTENT.md` §9 e
  `HARNESS.md` §11 davam defaults diferentes para o roster; a ADR 0001 dizia
  "três documentos" sem delimitar que fala da cadeia normativa

### Adicionado
- **`scripts/capture-usage.sh`** — recaptura, rodando os scripts de verdade sobre
  as fixtures, cada bloco de saída que o `USAGE.md` publica.
  `./scripts/capture-usage.sh 5.2` traz um bloco só. Existe porque a causa do
  defeito acima não foi descuido: era mais barato inventar o número que
  reproduzi-lo
- **Cinco travas em `validate.sh`, aplicando C4 aos documentos** e não só às
  skills. Reprovam: contagem de regras do `README` divergindo do `HARNESS`; caso
  de eval fora da tabela do `evals/README`; marca de versão velha no `USAGE`;
  `marketplace.json` divergindo do `plugin.json`; `VERSION` de gerador atrasado —
  este último faria arquivo gerado sair com marca errada e nunca mais receber
  atualização (D3 → R10). As cinco foram verificadas quebrando cada uma de
  propósito, que é V9 aplicado ao validador

### Alterado
- O template passa a pedir `dependency-cruiser: ^18`. Estava em `^16` enquanto o
  adaptador e a config gerada já absorviam os quirks da 18 — diretório nu que não
  expande para `.ts` e resolução sem extensão. Projeto novo recebia a versão para
  a qual a correção não foi escrita

## [0.2.8] — 2026-08-26

Achado por avaliador de código externo num repositório real, no primeiro uso
sério da skill fora daqui. A lacuna que o permitiu era conhecida e estava
registrada: `CONFORMIDADE.md` §6.2 dizia que nada fazia com a trava de produção
o que o `smoke-test.sh` faz com os gates.

### Corrigido — segurança
- **A trava de tag de release era contornável pela forma usual de release.** A
  regra casava `tag` seguido imediatamente de `v<dígito>`, então qualquer flag no
  meio passava: `git tag -a v1.2.3 -m rel` — anotada, que é como release se
  cria — não era vista. Também passavam `--annotate`, `-s`, `-f`, flag com
  argumento antes do nome (`-m rel -a v1.2.3`), flag global do git
  (`git -C x tag -a v1`), nome fora de semver (`v1.2`, `release-1`), e empurrar
  tag já criada (`git push --tags`)
- **A correção não adivinha o formato do nome: enumera o verbo.** Regex de
  formato erra na próxima flag, na próxima ordem e no próximo nome; o conjunto de
  verbos de escrita (`-a -s -u -m -F -f -d` e as formas longas) é finito. A
  decisão virou token a token, em `tag_escreve()`. **Leitura passa inteira** —
  `git tag --list`, `-n`, `--points-at`, `--contains`, `--sort` — porque negar
  leitura é reprovar trabalho legítimo, o modo de fracasso nº 1
- **`PRD=1 ./ops/deploy.sh` passava**: a regra pedia `prd` **depois** de `deploy`,
  e o ambiente vem antes. Agora a checagem é por segmento e sem ordem
- **`prd_deploy.sh` passava**: `_` é caractere de palavra, então `\bdeploy` não
  casava. Em vez de mais uma regex, a regra passou a usar o desenho que o resto
  do arquivo já usava — exige verbo de leitura para liberar. `cat
  deployment-prod.log` continua sendo investigação
- **`TRUNCATE users` passava**: a regra exigia a palavra `TABLE`, e Postgres e
  MySQL aceitam sem. Agora um cliente SQL no comando (`psql`, `mysql`, `sqlite3`…)
  basta para reprovar `drop`/`truncate` — o que preserva o `truncate -s 0 app.log`
  do coreutils, que é trabalho legítimo
- O `deny` base ganhou `Bash(git tag:*)`, `Bash(git push*--tags*)`,
  `Bash(git update-ref refs/tags*)` e `Bash(gh release create*)`. É
  deliberadamente cego: aqui é a camada de **garantia** (A2/A8 → R5), e padrão
  fino é contornado só reordenando flags. Ler tag continua possível pelo hook e
  por `git describe --tags`

### Corrigido — a causa por trás do furo
- **Havia duas cópias divergentes de cada um dos quatro hooks**, e o `scaffold.sh`
  só trocava o `verify.sh`. O modo B recebia um `guard-prod.sh` de 27 linhas cuja
  regra de deploy casava `deploy.sh prd` **literal** — `./ops/deploy.sh --env prd`
  passava. Projeto novo saía com trava mais fraca que projeto legado, e nada
  media a diferença. Agora os quatro vêm dos assets de retrofit, o template não
  tem mais cópia, e `validate.sh` reprova a segunda
- **Arquivo copiado pelo scaffold perdia a marca de versão.** Defeito
  preexistente, ampliado de 4 para 7 arquivos por esta mudança e por isso
  corrigido junto: sem `harness-generated: <versão> sha=<hash>`, o `gen-config`
  de uma versão futura classifica o arquivo como "existe e não é nosso" e o manda
  para `pulados` — repositório criado pelo modo B **nunca receberia atualização
  de hook ou de gate** (D3 → R10). O hash gravado é o mesmo que o `gen-config`
  calcula, senão os dois discordariam
- Os verbos de leitura estavam escritos numa regra e usados numa; agora duas
  precisam deles e viraram `LEITURA`, em um lugar só

### Adicionado
- **Caso de eval `05-guard-prod` (49 testes)** — o que faltava para fechar
  `CONFORMIDADE.md` §6.2 e boa parte da issue #1. O hook recebe JSON no stdin e
  responde JSON no stdout: testável sem plataforma. Cobre deploy, tag, destruição
  de dado, credencial e contexto, **nos dois sentidos** — e a metade "tem de
  passar" é a que importa mais, porque gate que reprova trabalho legítimo é
  desligado em duas semanas
- Evals do modo B: os quatro hooks vindos da fonte única, marca de versão
  presente, hash conferido contra o corpo, shebang na primeira linha
- `validate.sh` reprova a família: segunda cópia de qualquer hook, trava de tag
  que volte a casar formato de nome, verbos de leitura duplicados, `deny` base
  sem `Bash(git tag:*)`, e ausência do eval da trava

### Verificado
- O eval novo **reprova 20 vezes** contra o `guard-prod.sh` anterior, restaurado
  de propósito. Eval que passa contra o bug não está medindo o bug
- 247 evals, 0 falhas

### Nota honesta sobre o alcance
O hook não é à prova de adversário e não pretende ser: quem quiser burlar
`./ops/deploy.sh prd --status` consegue, porque a válvula de leitura é por
palavra. Quem garante é `permissions.deny`, avaliado pela plataforma antes do
hook (P2/A8 → R5). O hook cobre a variação distraída, que é o caso real.

## [0.2.7] — 2026-08-26

### Corrigido
- **`plan-install.sh` contava artefato de build como código-fonte.** O plano
  acusava 4 arquivos acima do teto num repositório onde nenhum passava — todos em
  `.next/`, sequer versionado — e nomeava um deles na pendência V10, recomendando
  trabalho que não existia. Duas causas independentes: a lista de poda do plano
  não tinha `.next`, `coverage`, `out` nem `target`, e ele varria a raiz em vez
  dos `size.targets` que ele mesmo emite. O gate media certo, então o baseline
  nunca foi contaminado — o defeito era no relatório, que é justamente o que a
  pessoa lê antes de decidir
- O mesmo desvio inflava `repo.arquivos_de_codigo` e `arquivos_de_teste`, e com
  isso podia classificar como `retrofit` um repositório que só tinha artefato de
  build — quando o certo seria `scaffold`

### Alterado
- **A varredura de arquivo-fonte virou uma só.** Estava reimplementada em três
  lugares (`plan-install.sh`, `assets/gate/size.sh`, `audit/size-status.sh`) com
  listas de poda diferentes, e o scaffold tinha uma quarta cópia do teto e das
  extensões. Cópia de política divergiu na primeira correção aplicada a um lado
  só. O gate passou a expor dois modos sem estado, e os outros três chamam:
  - `gate-size.sh --measure --root D [--targets a,b] [--ext …] [--exclude …]` →
    `linhas<TAB>caminho` de todo arquivo-fonte
  - `gate-size.sh --defaults` → teto, extensões, exclusões e poda canônicos
- A lista de poda canônica ganhou `.next`, `.nuxt`, `.svelte-kit`, `out`,
  `target`, `.turbo`, `.cache` e `.parcel-cache`

### Adicionado
- Fixture **`legado-customizado/`** — repositório que já tinha
  `.claude/settings.json` escrito à mão: cinco negações, um allow, um hook
  `PreToolUse` próprio e uma chave que o harness não conhece. Cada um é um
  caminho de perda distinto do defeito de 0.2.5
- **Eval de idempotência sobre repositório customizado**, na árvore inteira e não
  só no `settings.json`. É o que o `## Limites` da skill promete, e era
  exatamente o que o merge violava sem que nada medisse
- Eval que afirma que **plano, gate e audit contam o mesmo** — a guarda durável
  não é a lista de poda, é os três consumidores concordarem. O fixture inclui um
  arquivo grande fora de diretório podado **e** fora dos alvos, para que cada
  metade do defeito reprove sozinha
- `validate.sh` reprova lista de poda própria em qualquer consumidor, teto ou
  extensões copiados fora do gate, e plano que mede sem restringir aos alvos

### Verificado
- Os dois conjuntos de eval **reprovam contra o código defeituoso**, restaurado
  de propósito: 8 falhas para o bug do merge, 4 para o do `.next/` (e 2 quando só
  metade do defeito está presente). Eval que passa contra o bug não está medindo
  o bug — é a mesma regra V9 que o harness cobra dos outros

## [0.2.6] — 2026-08-26

### Corrigido
- **O CI rodava sobre Node 20 em fim de vida.** `actions/checkout@v4` ainda
  targeta o runtime Node 20, e o runner passou a forçar 24 com um aviso de
  deprecação em cada execução. `checkout` e `setup-node` foram para `@v7`
- **A versão de Node do CI era a que o runner trouxesse.** Sem `setup-node`, os
  evals cruzavam o grafo com o `dependency-cruiser` sob uma versão que muda sem
  aviso — a mesma classe de verde silencioso que o adaptador recusa (V8 → R12).
  Agora está fixada em **24**, o LTS ativo (desde 2025-10-28, manutenção até
  2028-04-30). O 26 já existe e ficou de fora de propósito: só entra em LTS em
  2026-10-28, e o cronograma é `nodejs/Release/schedule.json`

### Alterado
- Template: `CLAUDE.md` declarava Node 22 e agora declara **24**, e o
  `package.json` ganhou `engines.node: ">=24"`. A linha de stack do `CLAUDE.md` é
  instrução, não enfeite (C4 → R1): sem `engines`, ela era a única fonte da
  afirmação e nada a verificava

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
