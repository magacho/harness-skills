# CONFORMIDADE.md — Como cada critério é validado

Documento **derivado e descritivo**. O checklist de `HARNESS.md` §12 diz *o que
precisa ser verdade*; esta página diz *quem verifica, com que mecanismo, e com
que grau de confiança*.

Não cria regra. Se divergir de `HARNESS.md`, o `HARNESS.md` manda. Se divergir do
código, o código manda e esta página está velha — reverifique com
`./scripts/validate.sh` e `./evals/run.sh` (§7).

Alinhado a `HARNESS.md` v2.1 · scripts do produto v0.2.9 · esta página v1.2

---

## 1. Por que este documento existe

O checklist §12 é uma lista de afirmações. Sozinho, ele não responde às duas
perguntas que decidem se a conformidade vale algo:

1. **É medido por script ou por leitura?** Critério que depende de alguém ler um
   arquivo só é verificado quando alguém pede a auditoria.
2. **Existe prova de que reprova?** Gate que nunca falhou de propósito não é
   gate (V9 → R3) — e o mesmo raciocínio vale para os critérios que não são gate.

Este documento responde as duas, item por item.

## 2. Taxonomia e os dois planos

**Cinco métodos de validação:**

| tipo | significado | sobrevive a um agente distraído? |
|---|---|---|
| **D** | determinístico puro — script, código de saída, sem modelo no caminho | sim |
| **P** | garantia da plataforma — `permissions.deny`, avaliada por tool call | sim |
| **D→IA** | script mede, o modelo interpreta o número no relatório | parcialmente |
| **IA** | julgamento por leitura, sem oráculo executável | não |
| **✗** | afirmado no checklist, sem verificação automatizada | não |

**Dois planos, e a distinção importa.** Um critério pode ser determinístico no
produto e não no repositório alvo:

| plano | quem valida | quando |
|---|---|---|
| **no produto** | `scripts/validate.sh` + `evals/cases/*.sh` | por push (CI: `.github/workflows/validate.yml`) |
| **no repositório alvo** | scripts de `harness:audit`, geradores de `harness:install`, e os gates instalados em `.harness/` | na auditoria, na instalação, e a cada turno |

Exemplo de por que separar: V11 (limite de função no linter, de arquivo na
catraca) é **D no produto** — `validate.sh` reprova se o `eslint.config.js`
enviado ganhar um `max-lines` — e **IA no repositório alvo**, porque o `audit`
não lê a config de lint do projeto. O critério é o mesmo; a confiança, não.

## 3. Os 17 critérios de `HARNESS.md` §12

| # | critério (regra) | validação no repositório alvo | tipo | prova no produto |
|---|---|---|---|---|
| 1 | `CLAUDE.md` raiz, e todo comando citado executa `C4 → R1` | `audit/scripts/check-claims.sh` extrai `` `pnpm x` ``, `` `npm run x` ``, `` `make x` `` e `` `./caminho` `` do markdown; confere script em `package.json`, alvo em `Makefile`, e existência + bit de execução do caminho. Exit 3 se houver afirmação falsa. Na instalação, `plan-install.sh` **executa de verdade** `lint` e `typecheck` | **D** | `10-audit-contexto`; `validate.sh` aplica C4 ao próprio produto |
| 2 | `CLAUDE.md` por módulo, com o que importa e o que não importa `C3 → R1,R4` | contagem: `detect-stack.sh → claude_md_module_count`. Conteúdo: `gen-config.sh --fase 3` deriva a linha "hoje importa" do **grafo real** (adaptador → `jq`), e escreve `NÃO APURADO` quando não conseguiu ler o grafo, em vez de afirmar "não importa nada". A linha "o que este módulo faz" fica em branco de propósito | **D** (grafo) + **IA** (semântica) | `50-retrofit`, `90-scaffold` |
| 3 | Nenhuma garantia depende de configuração pessoal `D1 → R8` | por construção: gate, adaptador e baselines são escritos em `.harness/**` versionado, e as permissões em `.claude/settings.json` do projeto — nada mora em config de usuário. Em repositório alheio, é leitura (audit §3.1) | **D** (construção) + **IA** (auditoria) | `50-retrofit` (gate e adaptador dentro do repo) |
| 4 | Hook por edição assíncrono, silencioso, não escreve no contexto `V1 → R9` | por construção: `async: true` no `settings.json`, `on-edit.sh` sempre sai 0, formatador com saída para `/dev/null`; o hook só registra caminho em `/tmp/cc-touched-$sid-$aid.txt` (shard por agente, V2) | **D** (construção); auditoria **IA** | `55-merge-settings` (a entrada `PostToolUse` sobrevive ao merge) |
| 5 | Gate de turno filtra por arquivos da sessão e bloqueia de verdade `V3,V4 → R2` | `verify.sh` monta `/tmp/cc-scope-$sid.txt` a partir do rastro dos hooks e passa `--scope` aos dois gates, que filtram por `jq` — fronteira por origem **ou** destino, porque um ciclo novo pode ser relatado pela ponta que a sessão não editou. Lint e typecheck rodam no projeto inteiro e têm a **saída** filtrada (`grep -F -f`). Bloqueio é `exit 2` | **D** | `60-catraca-fronteira`, `70-catraca-tamanho` (ambos exercitam `--scope`) |
| 6 | Guarda anti-loop; contador zera ao passar `V5 → R2` | contador em `/tmp/cc-tries-$sid`, teto lido de `.anti_loop_tries` no `harness.json` (padrão 3); acima disso libera com aviso em `stderr`; `: > "$tries"` no caminho verde; `cleanup.sh` apaga no fim da sessão | **D** | — (lacuna §6.4) |
| 7 | **Violação plantada de propósito reprova** `V9 → R3` | `smoke-test.sh` planta um ciclo de import e um arquivo de `teto + 1` linhas, exige `rc = 1` **com** a violação e `rc = 0` **sem**, e remove os arquivos na mesma execução. Exit 3 só quando nenhum dos dois gates pôde ser provado | **D** | `95-fumaca` (com a ferramenta de verdade); `validate.sh` exige que a fumaça cubra os dois gates |
| 8 | Baseline existe se havia violações, e só encolhe `V7 → R7` | `gen-baseline.sh` recusa (exit 1) se regerar acrescentaria violação; `gate-size.sh --init` recusa se afrouxaria; há exatamente dois caminhos que mexem no baseline sem afrouxá-lo — `--tighten` (o arquivo encolheu, o teto individual acompanha) e `--rename <a> <b>` (move a entrada, mesmo número). `--force` é a escapatória explícita, e existe para que afrouxar exija dizer por escrito por que | **D** | `60-catraca-fronteira`, `70-catraca-tamanho` |
| 9 | Catraca de tamanho ativa: arquivo acima do teto não cresce `V10 → R4,R7` | `gate-size.sh` conta linha física com `awk 'END{print NR+0}'` (não `wc -l`: arquivo sem newline final ficaria devendo uma linha), baseline `{caminho: linhas}`, comparação `>` por arquivo. Teto 400. Sem ferramenta externa — vale em qualquer stack, inclusive nas que não têm adaptador de fronteira | **D** | `15-audit-dimensao`, `70-catraca-tamanho`; `validate.sh` exige baseline próprio, `--tighten` e recusa que ensina |
| 10 | Limite de função no linter, de arquivo na catraca — nunca os dois no mesmo lugar `V11 → R4` | `eslint.config.js` traz `max-lines-per-function: 60`, `complexity: 10`, `max-depth: 4`, e **ausência deliberada** de `max-lines`; testes têm as duas primeiras desligadas. No repositório alvo, nada lê a config de lint do projeto | **IA** no alvo, **D** no produto | `validate.sh`: reprova `max-lines` no template e exige `max-lines-per-function` |
| 11 | Todo gate roda como comando à mão `D5 → R12` | por construção: `gate-boundaries.sh` e `gate-size.sh` têm CLI própria (`--scope`, `--json`, `--tighten`, `--init`, `--rename`) e o hook apenas os invoca (P8). Indiretamente coberto pelo item 1: o `CLAUDE.md` gerado cita `./.harness/gate-*.sh`, e `check-claims.sh` exige que o caminho exista e seja executável | **D** (indireto) | `60`, `70`, `95` invocam os gates fora de qualquer hook |
| 12 | Escrita em produção negada em permissão **e** em hook `A2 → R5` | `permissions.deny` com 17 padrões (`*deploy*prd*`, `aws * --profile prd*`, `psql *prd*`, `kubectl * --context *prod*`, `git push --force*`, `git tag:*`, `gh release create*`, `Read(./**/.env*)`…) **e** `guard-prod.sh`: deploy por segmento sem exigir ordem, verbo de leitura como válvula (`LEITURA`, num lugar só), `drop`/`truncate` com cliente SQL, e tag decidida **token a token** pelo verbo de escrita — nunca pelo formato do nome, que era o furo até 0.2.7 e foi fechado em 0.2.8. A recusa devolve o que fazer em vez disso (A4) | **P** + **D** | `05-guard-prod` (49 testes, nos dois sentidos) prova o bloqueio e prova que a leitura passa; `55-merge-settings` prova que as negações do projeto sobrevivem ao reinstall |
| 13 | Script de investigação existe e é read-only `A3 → R5` | `plan-install.sh` checa `ops/investigate.sh` e emite **pendência declarada** se faltar; a instalação segue sem ele. "Usar só verbos de leitura" é por construção e revisão | **D** (presença) + **IA** (conteúdo) | `40-plan` (pendências) |
| 14 | Teto de autonomia declarado; elevá-lo exige revisão `A6,A7 → R5` | `gen-config.sh` valida o enum (`assistido\|supervisionado\|autonomo`) e, na reinstalação, o valor gravado em `.harness/harness.json` **vence a flag de linha de comando**. O teto é sustentado por permissão, nunca por hook (A8): `assistido` **acrescenta** negações (`git commit`, `git push`) e nunca remove. Depois do merge, `perdeu_deny` verifica que nenhuma negação do projeto saiu | **D** | `50-retrofit`, `55-merge-settings` |
| 15 | Dono registrado `D6 → R6` | `gen-config.sh` e `scaffold.sh` saem com **exit 2** sem `--owner`. Único parâmetro sem default | **D** bloqueante | `validate.sh` exige a checagem nos dois geradores |
| 16 | Nenhum arquivo do harness contém segredo `A5 → R5` | `deny` de `Read(./.env*)`, `Read(./**/.env*)` e `Read(./**/secrets/**)` — isso impede **ler**, não detecta segredo já escrito. Nenhum script do `audit` varre o repositório alvo | **P** + **✗** | `validate.sh` varre o próprio produto (`AKIA…`, `BEGIN … PRIVATE KEY`) |
| 17 | Cada subagente declara o que não repete `G3 → R9` | texto de `.claude/agents/architect.md`, lido. No modo A a onda 1 do roster (`HARNESS.md` §8) **não é instalada**, e isso é dito na entrega em vez de ficar como omissão; no modo B o `architect` vem no template e o revisor de mudança não — metade da onda, declarada como metade | **IA** | — |

## 4. Os gates no repositório instalado

O que efetivamente roda depois da instalação, e sob qual regime:

| gate | cadência | oráculo | catraca | bloqueia? |
|---|---|---|---|---|
| formatação | por edição | formatador do projeto (só o que ele já escolheu) | — | não — silencioso por desenho (V1) |
| lint | fim de turno | `eslint --max-warnings=0` | — | sim; **só entra no gate se estava verde no dia da instalação** |
| typecheck | fim de turno | compilador | — | idem, com saída filtrada pelo escopo da sessão |
| fronteira | fim de turno | `dependency-cruiser`: `sem-ciclos` (error) e `sem-orfaos` (warn) | **presença** — diferença de conjunto sobre `[{origem,destino,regra}]` | sim |
| tamanho | fim de turno | contagem de linha | **grandeza** — `{caminho: linhas}`, o número não sobe | sim |
| produção | por tool call | `permissions.deny` + regex do `guard-prod.sh` | — | sim (`permissionDecision: deny`) |

**As duas semânticas de catraca são diferentes de propósito.** Fronteira pergunta
se a violação existe; tamanho pergunta se o número subiu. Um baseline de lista e
um de dicionário, e é por isso que são dois arquivos: `.harness/baseline.json` e
`.harness/baseline-size.json`.

**Códigos de saída, e por que não são convenção Unix.** Nos gates: `0` nada novo,
`1` violação nova, `3` gate indisponível — que **não bloqueia** e é dito em voz
alta (D4 → R10). No hook de turno: `exit 2` é o que a plataforma trata como
bloqueio com devolução da saída ao agente; `exit 1` seria erro não-bloqueante e a
ação prosseguiria.

## 5. Garantias determinísticas que o checklist não lista

Nenhuma delas está em §12, e todas reprovam sozinhas:

1. **Adaptador que cruzou zero módulo não é verde.** `adapters/node.sh run` sai 3
   quando o `dependency-cruiser` analisou zero módulos — TypeScript sem
   `typescript` instalado, alvo errado, ou diretório nu entregue à ferramenta 18,
   que não expande sem glob. Antes disso, todo projeto TS recebia um gate que
   nunca verificava nada e reportava sucesso.
2. **Dimensão desconhecida não é ausência de problema.** `size-status.sh` e
   `boundary-status.sh` saem 3 quando não acharam código ou não cruzaram o grafo,
   com a frase explícita de que a dimensão não foi medida.
3. **Nem todo repositório merece harness.** `plan-install.sh → merece_harness`
   reprova: ≤3 arquivos de código sem teste e sem CI, nome do repositório
   anunciando descarte (`spike`, `poc`, `proto`, `scratch`, `tmp`…), ou um único
   arquivo de código.
4. **Só entra no gate o que já passava.** `lint`/`typecheck` são executados no
   plano; vermelho vira pendência declarada em vez de gate. Script que corrige em
   disco (`--fix`, `--write`) nem é executado (V6).
5. **Idempotência por hash.** Cada arquivo gerado leva
   `harness-generated: <versão> sha=<hash do corpo sem a linha de marca>`. Hash
   divergente significa edição humana: o arquivo entra em `pulados` e nunca é
   sobrescrito (D3 → R10).
6. **O merge de `settings.json` recusa em vez de perder.** `merge-settings.jq`
   faz união de conjunto em `permissions`, substitui só as entradas de hook do
   próprio harness e preserva as do projeto. Depois do merge, duas invariantes são
   verificadas **contra o resultado**: `perdeu_deny` e `perdeu_hook`. Qualquer uma
   diferente de zero, ou JSON inválido, e o arquivo não é tocado — a proposta fica
   em `.harness/settings.proposto.json` e o relatório diz `PERMISSÕES NÃO
   INSTALADAS`. Não há fallback: um `.[0] * .[1]` do `jq` já apagou 11 negações de
   produção escritas à mão, reportando sucesso.
7. **Regra de bloqueio enumera verbo, não formato de argumento.** A trava de tag
   casava `tag` seguido de `v<dígito>`; `git tag -a v1.2.3` passava, e era a forma
   usual de release. Regex de formato erra na próxima flag, na próxima ordem e no
   próximo nome — o conjunto de verbos de escrita é finito e a decisão virou token
   a token. `validate.sh` reprova o retorno do padrão por formato.
8. **Hook mora em um lugar só.** Havia duas cópias divergentes de cada um dos
   quatro hooks, e o `scaffold.sh` trocava apenas o `verify.sh`: projeto novo saía
   com trava de produção mais fraca que projeto legado. `validate.sh` reprova a
   segunda cópia.
9. **Lacuna é declarada, nunca silenciada.** Stack sem adaptador instala todo o
   resto — inclusive a catraca de tamanho — e diz que o gate de fronteira não
   existe ali (D4 → R10).

## 6. Lacunas conhecidas

O que o checklist afirma e a implementação ainda não mede:

1. **Segredo no repositório alvo (A5, item 16).** `validate.sh` varre o produto;
   nada varre o repositório instalado. As permissões impedem leitura de `.env`,
   não detectam credencial já commitada. É o único item de §12 cuja conformidade
   hoje é declarada, não verificada.
2. ~~**Dupla trava de produção sem teste de fumaça (A2, item 12).**~~ **Fechada em
   0.2.8**, e a lacuna cobrou o preço antes: um avaliador externo achou num
   repositório real que `git tag -a v1.2.3 -m rel` — a forma usual de release —
   contornava a trava, porque a regra casava o formato do nome da tag em vez do
   verbo. `05-guard-prod` cobre os dois sentidos e reprova 20 vezes contra o hook
   anterior.

   **O que permanece é alcance, não ausência de prova.** O hook não é à prova de
   adversário: a válvula de leitura é por palavra, então `./ops/deploy.sh prd
   --status` passa. Quem garante é `permissions.deny`, avaliado pela plataforma
   antes do hook (P2/A8 → R5) — e o comportamento do casamento de permissão é da
   plataforma, fora do alcance dos evals daqui. O hook cobre a variação
   distraída, que é o caso real.
3. **C5 (tamanho do `CLAUDE.md`: ~60 linhas na raiz, ~15 no módulo).** Hoje é
   leitura do modelo, e o oráculo seria o mesmo `awk` que a catraca de tamanho já
   usa. É o critério mais barato de tornar determinístico.
4. **V5 (anti-loop) e V1 (hook silencioso)** são determinísticos no código e não
   têm eval próprio: um `verify.sh` que passasse a falar no caminho verde não
   reprovaria nada hoje.
5. **G3 (item 17)** depende de leitura, e o roster que ele governa só é instalado
   pela metade (o `architect`, e só no modo B) — a conformidade do item fica com
   quem instalar o resto à mão.

## 7. Como reverificar

    ./scripts/validate.sh              # invariantes do produto — o que o CI roda
    ./evals/run.sh                     # a suíte inteira, sobre fixtures reais
    ./evals/run.sh 70-catraca-tamanho  # um caso (prefixo basta)

No repositório alvo:

    <plugin>/skills/audit/scripts/check-claims.sh   .   # C4
    <plugin>/skills/audit/scripts/size-status.sh    .   # dimensão de V10
    <plugin>/skills/audit/scripts/boundary-status.sh .  # dimensão de V7
    ./.harness/gate-boundaries.sh --json
    ./.harness/gate-size.sh --json
    <plugin>/skills/install/scripts/smoke-test.sh   .   # V9, nos dois gates

Sem rede, os casos que dependem do `dependency-cruiser` são **pulados com
motivo** — a mesma regra D4 que a skill cobra dos outros.

## Histórico

- **1.2** — item 17 e a lacuna §6.5 param de dizer que o roster não é instalado:
  o `architect` vem no template do modo B, e "não instalado" era verdade só no
  modo A. Item 12 datava o furo de tag como sendo de 0.2.8, que é a versão que o
  fechou.
- **1.1** — item 12 deixa de ser "nada prova o bloqueio": `05-guard-prod` cobre a
  trava de produção nos dois sentidos. A lacuna §6.2 fecha, e o que resta dela
  passa a ser declarado como limite de alcance do hook, não como ausência de
  prova. Duas garantias novas em §5 (verbo em vez de formato; hook em um lugar
  só), ambas aprendidas de defeito real encontrado por avaliador externo.
- **1.0** — primeira versão. Mapeia os 17 critérios de `HARNESS.md` §12 (v2.1) à
  implementação v0.2.5, separa os dois planos de validação (produto e repositório
  alvo) e registra cinco lacunas.
