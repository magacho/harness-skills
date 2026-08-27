# Evals

Skill que audita repositório alheio sem eval é risco não medido.

`./run.sh` roda os evals das duas skills. Fixtures em `fixtures/`. A instalação
sempre roda sobre uma cópia em diretório temporário: fixture que a suíte suja
deixa de ser fixture.

## Estrutura

`run.sh` é só o corredor — caminhos, contadores, o par `t()`/`s()`, a sonda de
rede e o construtor de fixture. Os testes moram em `cases/`, **uma família por
arquivo**, carregados com `source` (não subshell, para que os contadores sejam
os mesmos).

    ./run.sh                     roda tudo
    ./run.sh 70-catraca-tamanho  roda um caso — prefixo basta

| caso | prova |
|---|---|
| `05-guard-prod` | a dupla trava de produção, nos dois sentidos: bloqueia escrita e libera leitura |
| `10-audit-contexto` | o audit lê stack, harness existente e afirmações do `CLAUDE.md` (C4) |
| `15-audit-dimensao` | quantos god files e quantas violações uma catraca congelaria |
| `20-version` | `/harness:version`: as duas versões e a divergência entre elas |
| `30-adapter` | contrato de quatro verbos, e o grafo TypeScript |
| `40-plan` | `plan-install.sh`: modo, módulos do projeto, gates de hoje, veredito |
| `50-retrofit` | modo A: fases 1 e 3, idempotência, dono obrigatório |
| `55-merge-settings` | o merge de `settings.json`: união, substituição, e a recusa |
| `60-catraca-fronteira` | presença: diferença de conjunto, baseline só encolhe |
| `70-catraca-tamanho` | grandeza: o número não sobe, `--tighten`, `--rename` |
| `75-telemetria` | a trilha: registra sem falhar, sem vazar e sem falar; e o leitor não confunde zero com ausência de dado |
| `80-sem-adaptador` | D4: a lacuna é dita, e a catraca de tamanho continua valendo |
| `90-scaffold` | modo B: nomes do domínio real, baselines vazios, teto absoluto |
| `95-fumaca` | V9 de ponta a ponta, com a ferramenta de verdade |

**Cada caso monta o próprio repositório**, por `legado_instalado <nome>`. Antes
havia um `$W/legado` atravessando meia suíte: a ordem dos blocos era carregada e
invisível, e mexer num quebrava outro três telas abaixo. A função **recusa** um
nome que já existe — `cp -a src dst` com `dst` existente copia para dentro, e o
caso seguiria medindo uma árvore aninhada com cara de sucesso. Foi exatamente o
defeito que a divisão produziu na primeira tentativa.

## Cobertura atual

| fixture | testa |
|---|---|
| `assets/template/` (na skill `install`) | repositório conforme: nenhuma instrução falsa, harness completo |
| `legado-com-instrucao-falsa/` | regra C4 — o achado mais comum |
| `legado-com-ciclos/` | ciclo real e órfão real: baseline não vazio, e lint verde com typecheck vermelho |
| `python-sem-adaptador/` | regra D4 — degradação declarada em voz alta |
| `sem-harness/` | repositório cru não quebra a auditoria |
| `repo-vazio/` | modo B, o trilho de greenfield |
| `nao-merece-harness/` | **eval negativo:** script de uso único. A skill diz não |
| `ts-com-ciclo/` | **grafo TypeScript** com ciclo, órfão e imports sem extensão |
| `legado-customizado/` | `.claude/settings.json` escrito à mão: cinco negações, um allow, um hook próprio e uma chave que o harness não conhece. Cada um é um caminho de perda do merge |
| `depcruise-bruto.json` | saída gravada da ferramenta: `normalize` e catraca rodam offline |

## O que cada eval de instalação prova

- **Legado com violações** — baseline não vazio, no formato do harness (V8); o
  typecheck vermelho fica fora do gate; nenhum arquivo-fonte é tocado.
- **Idempotência** — rodar duas vezes não altera um byte, o dono registrado não
  é trocado por argumento de linha de comando, e a customização manual sobrevive
  com o pulo relatado (D3).
- **Stack sem adaptador** — instala todo o resto, e catraca, fumaça e gate saem
  com código 3 dizendo o que falta. Não aborta, não silencia (D4).
- **Repo vazio** — scaffold renomeia módulos, imports e os paths da config junto,
  inclusive dentro de alternações de regex; e recusa rodar onde já há código.
- **Negativo** — o veredito vem com a razão, não só com o "não".
- **Catraca de tamanho** — o god file existente é congelado e para de crescer; o
  arquivo novo acima do teto reprova; `--tighten` só desce; `--rename` move a
  entrada sem afrouxar; a recusa ensina a saída certa em vez de só negar (A4).
  Um dos evals reprova um `.py` acima do teto: a catraca vale onde não há
  adaptador de fronteira nenhum (V10 → R12).

Os evals que dependem do `dependency-cruiser` são **pulados com motivo impresso**
quando a ferramenta não está acessível. Silenciar a lacuna seria o mesmo erro que
a regra D4 proíbe.

## O merge que apagava as travas do projeto

O defeito mais caro que o harness teve, corrigido em 0.2.5. `gen-config.sh` fazia
`.[0] * .[1] | .permissions.deny = ((.[0].permissions.deny // []) + ...)` — mas
depois do `*` o contexto já é o objeto mesclado, e `.[0]` nele é erro de tipo.
**Toda** instalação caía no `|| jq -s '.[0] * .[1]'`, e o `*` do jq deixa a
direita SUBSTITUIR o array. Reinstalar sobre um projeto customizado levava 23
negações a 12, reportava `.claude/settings.json (merge)` e saía 0.

Três coisas foram travadas por eval, não só a linha:

- **a união** — negação e hook do projeto sobrevivem, e um teste prova que o
  merge ingênuo perderia (para que a intenção fique registrada no próprio eval);
- **a substituição** — a entrada de hook do harness é trocada, não somada, senão
  mudar um timeout deixaria as duas e o hook rodaria duas vezes;
- **a recusa** — `settings.json` inválido não é sobrescrito, não conta como
  escrito, e o pulo diz `PERMISSÕES NÃO INSTALADAS`.

E `validate.sh` reprova a *família*, não a instância: `.[0]` indexado depois de
um `*`, `|| jq` como fallback, e a ausência de qualquer uma das duas invariantes.

## O plano que acusava god file em `.next/`

A varredura de arquivo-fonte estava reimplementada em três lugares com listas de
poda diferentes. O plano acusava 4 arquivos acima do teto num repositório onde
nenhum passava — todos artefato de build — e a pendência V10 recomendava trabalho
inexistente. O gate media certo: o mesmo repositório tinha duas respostas, e a
errada era a que a pessoa lia antes de decidir.

Corrigido em 0.2.7 pela raiz: o gate expõe `--measure` e `--defaults`, e plano,
audit e scaffold chamam em vez de reimplementar. O eval que trava isso **não**
verifica a lista de poda — verifica que os três consumidores contam o mesmo. E o
fixture tem um arquivo grande fora de diretório podado *e* fora dos alvos, para
que cada metade do defeito reprove sozinha.

## Regressões travadas

Três defeitos da mesma família — **o script reportava sucesso sem ter medido** —
foram corrigidos em 0.2.1 e agora têm eval:

- `boundary-status.sh` cruzava `src modules` fixo. Repo sem `modules/` devolvia
  ENOENT, não media nada e saía 0.
- `detect-stack.sh` procurava `.dependency-cruiser.js` (o instalador escreve
  `.cjs`) e o baseline **nativo** da ferramenta. Ficava cego para a instalação
  que a skill irmã acabara de fazer.
- `check-claims.sh` só verificava script de `package.json`. Apagar o gate que o
  `CLAUDE.md` gerado cita não aparecia como instrução falsa.

## A lacuna que deixou o gate cego em TypeScript

Todo fixture com grafo era JavaScript — a única linguagem em que o
`dependency-cruiser` expande diretório nu. Projeto TypeScript recebia um gate que
cruzava zero módulo, e a suíte inteira ficava verde. `ts-com-ciclo/` fecha isso.

Os evals afirmam `totalCruised > 0` **e** a contagem esperada de violações. Um
eval que só verificasse "saiu 0" continuaria passando com o defeito — foi
exatamente o que aconteceu. Um deles entrega o diretório nu direto à ferramenta
e exige que cruze zero: trava a regressão pelo mecanismo, não pelo sintoma.

## A trilha que não podia derrubar o hook

A telemetria da 0.3.0 é a primeira coisa do harness que roda dentro de um hook
sem ser a decisão dele. Três invariantes do emissor têm eval próprio, porque
falhar em qualquer uma custa mais do que a estatística vale:

- **não derruba** — com o arquivo da trilha sem permissão de escrita, o
  `guard-prod` continua negando e o evento é perdido em silêncio. O teste usa
  `chmod` no ARQUIVO: `chmod` no diretório não impede append em arquivo que já
  existe, e passaria sem ter impedido nada;
- **não vaza** — `API_KEY=segredo pnpm build` entra na trilha como `pnpm`, e a
  senha de uma URL de conexão do `psql` não aparece em byte nenhum;
- **não fala** — a saída do hook permissivo continua vazia, porque no
  `PreToolUse` o stdout é o protocolo de decisão.

E dois evals cobrem o retrofit, que é onde o dano seria irreversível: um hook da
versão anterior com uma regra `deny` do projeto acrescentada à mão é **enxertado,
nunca sobrescrito** — a regra local continua bloqueando, o bloqueio entra na
trilha, e rodar a instalação de novo não enxerta uma segunda camada. Sem essa
última verificação cada bloqueio valeria duas linhas e a estatística mostraria o
dobro do que aconteceu — foi o primeiro defeito que a suíte pegou.

## Cobertura que falta

Antes do primeiro release público (ver `docs/PLAN.md` §7):

- Monorepo com pacotes
- Repositório com harness de outra ferramenta (`.cursorrules`, `AGENTS.md`)
- Repositório de terceiro. Harness testado só na casa do autor sempre parece
  funcionar.
