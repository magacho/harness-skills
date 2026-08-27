# USAGE.md — Guia de uso

Como avaliar um repositório e instalar o harness nele. Documento para **quem
usa** as skills; o porquê está em `INTENT.md`, as regras em `HARNESS.md`, o
roadmap em `PLAN.md`.

Todas as saídas abaixo são **reais**, e são recapturáveis num comando:

    ./scripts/capture-usage.sh        # todos os blocos
    ./scripts/capture-usage.sh 5.2    # um bloco

As fixtures são as de `evals/fixtures/` — `legado-com-instrucao-falsa`,
`legado-com-ciclos` (Node, com um ciclo e um órfão de verdade), `sem-harness`,
`nao-merece-harness`, `python-sem-adaptador` e `repo-vazio`. Nos blocos de
catraca de tamanho, o `legado-com-ciclos` recebe o mesmo god file de 450 linhas
que o eval `70-catraca-tamanho` planta: fixture sem arquivo grande não tem o que
congelar.

Nada aqui é ilustrativo, e isso é verificado: a mesma regra C4 que a skill cobra
dos outros vale para esta página. Uma vez a afirmação ficou falsa — os blocos de
tamanho traziam sete god files e um arquivo de 1840 linhas que nenhuma fixture
tinha, e a prosa em volta media um repositório inexistente. O script acima existe
para que recapturar seja mais barato que inventar.

---

## 1. Pré-requisitos

| item | por quê | sem ele |
|---|---|---|
| `jq` | os scripts falam JSON | os scripts não rodam |
| `git` | detecção de modo e contagem de commits | detecção degrada |
| Node + `npx` | adaptador de fronteira JS/TS | instala sem o gate de fronteira; o de tamanho continua valendo |

Stack que não é JS/TS instala todo o resto e **declara a lacuna em voz alta** —
ver §9.

## 2. Instalar o plugin

    /plugin marketplace add magacho/harness-skills
    /plugin install harness@harness-mp

Duas skills ficam disponíveis:

| skill | escreve? | quando |
|---|---|---|
| `harness:audit` | **não** — read-only | sempre primeiro, em projeto que já existe |
| `harness:install` | sim, com confirmação | depois de ler o relatório |

---

## 3. Avaliar — `harness:audit`

Read-only. Não altera um byte. Produz o relatório que **é a especificação** do
que a instalação precisa fazer.

Peça em linguagem natural:

> audita o harness deste repositório

A skill roda quatro coletas mecânicas e interpreta o resultado.

### 3.1 Contexto do repositório

    ./scripts/detect-stack.sh <repo>

```json
{
  "stack": "node",
  "layout": "single",
  "package_manager": "unknown",
  "boundary_adapter": "dependency-cruiser",
  "harness": {
    "claude_md_root": true,
    "claude_dir": false,
    "settings": false,
    "hooks": false,
    "agents": false,
    "commands": false,
    "boundary_config": false,
    "harness_dir": false,
    "gate": false,
    "adapters": false,
    "baseline": false,
    "baseline_nativo": false,
    "versao": null,
    "dono": null,
    "teto_de_autonomia": null,
    "adr_dir": false,
    "other_agent_configs": false
  },
  "ci": false,
  "claude_md_module_count": 0
}
```

Leitura: existe um `CLAUDE.md` na raiz e **nada mais**. Sem hooks, sem
permissões, sem fronteira, sem catraca, e sem dono registrado.

Num repositório que **já tem** o harness, os mesmos campos respondem se a
instalação está inteira: `harness_dir`, `gate`, `baseline`, `versao`, `dono` e
`teto_de_autonomia`. `baseline_nativo` é campo à parte de propósito — encontrar
o baseline da própria ferramenta significa catraca delegada ao mecanismo dela,
que é o que a regra V8 proíbe. `other_agent_configs` é o que abre a lista de
**remover**: `.cursorrules` e `AGENTS.md` conectados e não usados.

### 3.2 As afirmações são verdadeiras? (regra C4)

Este é o achado mais comum e o mais barato de corrigir.

    ./scripts/check-claims.sh <repo>

```
FALSA pnpm lint  (script ausente no package.json)
OK    pnpm test
FALSA pnpm typecheck  (script ausente no package.json)
---
verificadas=3 ok=1 falsas=2
```

Verifica dois tipos de afirmação: script de pacote (`npm run x`, `make y`) e
caminho executável citado em crase (`./ops/deploy.sh`). Caminho que não existe,
ou que existe sem bit de execução, conta como falso.

Sai com código **3** quando há afirmação falsa. O `CLAUDE.md` desta fixture
prometia `pnpm lint` e `pnpm typecheck`; o `package.json` só tem `test`. O agente
confia na promessa e erra com confiança — por isso instrução falsa é o
**primeiro** item da lista de corrigir, antes de qualquer coisa nova.

### 3.3 Fronteiras e dimensão do baseline

    ./scripts/boundary-status.sh <repo>

```
SEM_CONFIG: regra mínima (ciclo e órfão) só para dimensionar o baseline
{
  "alvos": ["src"],
  "violacoes": 2,
  "por_regra": { "sem-ciclos": 1, "sem-orfaos": 1 },
  "catraca_obrigatoria": true
}
```

A primeira linha vai para `stderr` e é parte da resposta: o repositório auditado
não tem config de fronteira, então o script sonda com a regra mínima em vez de
inventar uma arquitetura para medir contra.

`violacoes` é o número que decide se a catraca de fronteira é obrigatória. O script detecta
os alvos reais do repositório — `modules`, `packages`, `apps`, `libs`,
`services` ou `src` — e usa o adaptador pelos quatro verbos, o mesmo mecanismo
da instalação. Sonda o grafo **sem escrever nada** no repositório auditado.

Quando não consegue medir, sai com código **3** e diz por quê, em vez de
reportar verde sem ter cruzado o grafo:

```
SEM_ALVO: nenhum diretório de código reconhecido (modules, packages, apps, libs, services, src).
Isto NÃO é verde: o grafo não foi medido.
```

### 3.4 O relatório

A skill preenche `reference/report-template.md`. Três listas, nesta ordem:

1. **Remover** — instrução falsa, documentação disfarçada de instrução,
   ferramenta conectada e não usada
2. **Corrigir** — o que existe e está errado
3. **Adicionar** — o que falta

> A lista de **remover** costuma ser a mais valiosa. Repositório com harness
> antigo sofre de excesso, não de falta.

Fecha com o checklist de conformidade de `reference/conformance-checklist.md` e
uma recomendação: instalar, instalar parcialmente, ou **não instalar**.

---

## 4. Nem todo repositório merece harness

O veredito é explícito e vem com razão:

```json
{
  "modo": "retrofit",
  "merece_harness": {
    "veredito": false,
    "razoes": [
      "1 arquivo(s) de código, nenhum teste, nenhum CI — cabe inteiro em um contexto",
      "um único arquivo de código: harness custaria mais que o artefato"
    ]
  }
}
```

Script de uso único e protótipo descartável pagam a cerimônia e não recebem
nada. **Quando o veredito é `false`, a skill diz isso e para.** Instalar mesmo
assim é como o harness ganha má fama.

---

## 5. Instalar — modo A, projeto existente

> As fases 1 a 3 **não tocam código-fonte**. Só `CLAUDE.md`, `.claude/**`,
> `.harness/**` e a config de fronteira. Isso não é conveniência: é o que torna
> a adoção possível.

### 5.0 Antes de qualquer escrita

    ./scripts/plan-install.sh <repo>

Read-only. Devolve modo, veredito, módulos reais, alvos de fronteira, quais
gates passam **hoje**, o manifesto completo e as pendências:

```json
{
  "modo": "retrofit",
  "modulos": ["src/cobranca", "src/comum", "src/faturamento"],
  "boundary": {
    "adapter": "node",
    "reason": "",
    "config": ".dependency-cruiser.cjs",
    "targets": ["src"]
  },
  "gates_hoje": {
    "lint":      { "estado": "verde",    "comando": "npm run lint" },
    "typecheck": { "estado": "vermelho", "comando": "npm run typecheck" }
  },
  "size": {
    "ceiling": 400,
    "acima_do_teto": 1,
    "maior": { "arquivo": "src/cobranca/gigante.js", "linhas": 450 }
  },
  "pendencias": [
    "A3 → R5: não há script de investigação read-only. O harness instala sem ele; escreva um para a sua stack e o gate de conformidade fecha.",
    "V10 → R4: 1 arquivo(s) já passam de 400 linhas (o maior: src/cobranca/gigante.js, 450). Entram no baseline e param de crescer; reduzi-los é trabalho à parte, nunca requisito da instalação.",
    "typecheck reprova hoje (npm run typecheck). Fica FORA do gate de turno pelo mesmo motivo."
  ]
}
```

O bloco `size` acima está abreviado nos campos de varredura: a saída completa
traz também `targets`, `extensions` e `exclude` — a lista canônica que o gate
expõe por `--defaults`, para que plano, audit e gate contem os mesmos arquivos.

`size.acima_do_teto` é medido **antes** de escrever qualquer coisa. Não muda a
instalação — o arquivo entra no baseline e para de crescer de qualquer forma.
Muda a conversa depois dela: num repositório real esse número é dezenas, e é aí
que a catraca deixa de ser detalhe.

Repare em `gates_hoje`: o typecheck está vermelho, então **fica fora do gate** e
vira pendência declarada. Ligar gate que reprova trabalho legítimo é o modo de
fracasso nº 1 — o time desliga em duas semanas, e gate desligado é pior que gate
nenhum.

A skill mostra o manifesto e **espera o ok**. Pergunta duas coisas:

| parâmetro | default | obrigatório |
|---|---|---|
| **dono** | nenhum | **sim** — sem ele nenhum critério de sucesso tem observador (D6) |
| teto de autonomia | `supervisionado` | ratificar basta |

### 5.1 Fase 1 — hooks, permissões, comandos, dono, teto

```bash
./scripts/gen-config.sh <repo> --plan <plan.json> \
    --owner "Flavio Magacho" --ceiling supervisionado --fase 1
```

```json
{
  "fase": "1",
  "versao": "0.3.0",
  "escritos": [
    ".harness/log.sh", ".harness/stats.sh",
    ".claude/hooks/on-edit.sh", ".claude/hooks/verify.sh",
    ".claude/hooks/guard-prod.sh", ".claude/hooks/cleanup.sh",
    ".claude/commands/plan.md", ".claude/commands/review.md",
    ".claude/commands/stats.md", ".claude/commands/ship.md",
    ".harness/log/.gitignore",
    ".harness/gate-boundaries.sh", ".harness/gate-size.sh",
    ".harness/adapters/node.sh",
    ".dependency-cruiser.cjs", ".harness/harness.json",
    ".claude/settings.json"
  ],
  "pulados": [],
  "telemetria": []
}
```

São **dois gates**. O de fronteira depende de adaptador; o de tamanho não depende
de nada — contagem de linha é o único oráculo estrutural que existe em toda
linguagem, e por isso ele é o gate que sobra numa stack sem adaptador.

Os gates e o adaptador vão **para dentro do repositório**, não ficam no plugin:
quem clona recebe o mesmo comportamento sem ter a skill instalada (D1 → R8), e o
gate roda em CI e sob outro agente.

Produção é negada em **dois lugares** — permissão e hook — porque uma só camada
é contornável (A2 → R5).

`.harness/log.sh` e `.harness/stats.sh` são a **telemetria** (V12 → R6): o
emissor que os hooks sourceiam, e o leitor da trilha. O campo `telemetria` do
relatório fica vazio aqui porque nenhum hook precisou de enxerto — todos foram
escritos do zero. Ele deixa de ser vazio no retrofit da §10.

`.harness/log/.gitignore` faz a trilha se ignorar de dentro de `.harness/`. Não
tocamos no `.gitignore` da raiz: ele não está na fronteira de escrita de
`HARNESS.md` §1, e abrir exceção para uma linha de conveniência é como fronteira
declarada vira fronteira negociável.

**Aceite:** o gate roda, passa hoje, e reprova violação plantada.

#### O merge de `settings.json`

O arquivo do projeto **manda**, e o do harness soma. Três regras, cada uma por um
modo de perda real (`scripts/merge-settings.jq`):

| caminho | regra | por quê |
|---|---|---|
| `permissions.allow` / `.deny` | união de conjunto | o que o projeto negou continua negado (A7 → R5) |
| `hooks.<evento>` | entrada do harness substituída, do projeto preservada | somar duplicaria o hook quando a definição muda de versão |
| resto | merge recursivo; escalar novo vence | chave que o harness não conhece atravessa intacta |

**Não há fallback.** Se o merge não pode ser feito — `settings.json` inválido, ou
uma invariante violada —, o arquivo **não é tocado**, entra em `pulados`, e a
proposta fica em `.harness/settings.proposto.json` para merge à mão. Isso importa
mais do que parece: settings.json é onde mora a garantia, e um merge que perde
uma negação em silêncio é pior que uma instalação que não aconteceu.

O gerador confere duas invariantes contra o **resultado**, não contra a intenção:
nenhuma negação do projeto desapareceu, e nenhum hook fora de `.claude/hooks/`
desapareceu. Se qualquer uma falhar, recusa.

### 5.2 Fase 2 — as catracas

**É aqui que o valor chega.** Se a instalação for interrompida, que seja depois
desta fase.

    ./scripts/gen-baseline.sh <repo>

```json
{
  "fronteira": {
    "baseline": ".harness/baseline.json",
    "violacoes_congeladas": 3,
    "catraca": "ligada: o gate falha só no que é novo",
    "por_regra": { "sem-ciclos": 1, "sem-orfaos": 2 }
  },
  "tamanho": {
    "baseline": ".harness/baseline-size.json",
    "teto": 400,
    "arquivos_congelados": 1,
    "maior": { "key": "src/cobranca/gigante.js", "value": 450 },
    "catraca": "ligada: os 1 arquivo(s) acima do teto não podem crescer"
  }
}
```

Três violações de fronteira, e o audit da §3.3 tinha achado duas: o god file
plantado para exercitar a catraca de tamanho **também** é órfão, porque ninguém o
importa. É o grafo real respondendo, não um número escolhido — e é exatamente o
tipo de efeito colateral que só aparece medindo.

São duas catracas com semânticas diferentes de propósito. O baseline de
fronteira é do harness, em formato próprio — não o mecanismo nativo da
ferramenta (V8) — e a pergunta é **presença**:

```json
[
  { "origem": "src/cobranca/gigante.js", "destino": "src/cobranca/gigante.js",     "regra": "sem-orfaos" },
  { "origem": "src/comum/data.js",       "destino": "src/comum/data.js",           "regra": "sem-orfaos" },
  { "origem": "src/cobranca/cobrar.js",  "destino": "src/faturamento/faturar.js",  "regra": "sem-ciclos" }
]
```

O de tamanho guarda **grandeza**: o arquivo pode continuar existindo, o número é
que não pode subir.

```json
{ "src/cobranca/gigante.js": 450 }
```

Isso converte "40 erros, gate inútil" em "40 erros parados": a decadência para
antes de qualquer refactor. E converte "sete god files" em "sete god files que
não crescem mais" — sem exigir que ninguém os parta hoje.

**O baseline só encolhe.** O gerador recusa regerá-lo maior e diz por quê. Essa
recusa é a regra funcionando — não um obstáculo a contornar com `--force`.

Baseline grande não é motivo para adiar: é o argumento a favor da catraca.
Baseline vazio também não é motivo para pular: a partir de agora, qualquer
violação é nova.

### 5.3 Fase 3 — contexto

```bash
./scripts/gen-config.sh <repo> --plan <plan.json> --owner "Flavio Magacho" --fase 3
```

```json
{
  "fase": "3",
  "versao": "0.3.0",
  "escritos": [
    ".harness/CLAUDE.md.proposto — o CLAUDE.md atual não é nosso; compare e faça o merge à mão",
    "src/cobranca/CLAUDE.md", "src/comum/CLAUDE.md", "src/faturamento/CLAUDE.md"
  ],
  "pulados": [
    "CLAUDE.md — existe e não é nosso; nunca sobrescrevemos edição manual"
  ]
}
```

Um `CLAUDE.md` por módulo **existente**, com os nomes que os módulos já têm:

```markdown
<!-- harness-generated: 0.3.0 sha=1382e8bbf6cead4f -->
# src/cobranca

<!-- uma linha: o que este módulo faz. Preencha — o gerador não sabe. -->

- Possui: `src/cobranca/**`
- Hoje importa: `src/comum`, `src/faturamento` — descrito do grafo real, não prescrito
- Nunca importa: ciclo (a única direção proibida hoje). Import novo
  para fora da lista acima é mudança de fronteira: ADR em `docs/adr/`
```

Duas coisas exigem você:

- **Preencher a linha "o que este módulo faz".** O gerador lê o grafo; ele não
  sabe a intenção. Você, depois de ler o código, sabe.
- **Fazer o merge do `CLAUDE.md` raiz item a item**, começando pelas afirmações
  falsas que o audit encontrou. O arquivo existente nunca é sobrescrito; a
  proposta fica ao lado, em `.harness/CLAUDE.md.proposto`.

Módulos **nunca** são renomeados para `domain`/`data`/`api`. O template é ponto
de partida de projeto novo, não gabarito de projeto existente.

### 5.4 Fim — obrigatório

    ./scripts/smoke-test.sh <repo>

```
V9 OK (tamanho) — reprovou arquivo de 401 linhas com teto 400, e voltou a passar.
V9 OK (fronteira) — reprovou o ciclo plantado e voltou a passar depois de removido.
2 de 2 gate(s) estrutural(is) provado(s).
```

Planta uma violação por gate, confirma que cada um reprova, remove. **Gate que
nunca reprovou não é gate.** Reporta por gate, e só sai 3 quando nenhum dos dois
pôde ser provado. Se falhar, a instalação **não** está concluída.

A skill encerra dizendo o que **não** instalou: no modo A, a fase 4 do `PLAN.md`
inteira — o roster da onda 1, revisor de mudança e arquiteto, é trabalho manual.
No modo B a conta é diferente: o template traz `.claude/agents/architect.md`, e o
scaffold o copia, então projeto novo sai com **metade** da onda 1 — falta o
revisor de mudança. Nos dois casos a skill diz qual metade falta, em vez de
deixar como omissão.

---

## 6. Instalar — modo B, projeto novo

Quando não há código-fonte, o `plan-install.sh` devolve `"modo": "scaffold"` e a
skill copia o template — quatro módulos mais `shared`, com fronteiras já verificáveis.

**Pergunte os nomes dos módulos antes de copiar.** Em lote, com um default para
cada um, e com o bloco inteiro pulável: "mantém os nomes do template" é resposta
válida.

```bash
./scripts/scaffold.sh <repo> --owner "Flavio Magacho" \
    --modules "shared=comum,domain=cobranca,data=persistencia,api=http,web=ui"
```

```json
{
  "modo": "scaffold",
  "versao": "0.3.0",
  "copiados": 35,
  "pulados": [],
  "renomeados": [
    "modules/shared → modules/comum",
    "modules/domain → modules/cobranca",
    "modules/data → modules/persistencia",
    "modules/api → modules/http",
    "modules/web → modules/ui"
  ],
  "residuo_de_prosa": [
    ".dependency-cruiser.js:15:      name: \"domain-e-puro\",",
    ".dependency-cruiser.js:18:        \"domain só conhece shared e a si mesmo. I/O sai por domain/ports.\",",
    "…21 entradas no total — a lista completa sai em ./scripts/capture-usage.sh 6",
    "modules/ui/src/pay-button.ts:3:/** web só conhece o contrato. Não sabe o que \"payable\" significa. */",
    "ops/env.prd.sh:6:export ECS_SERVICE=\"api-prd\""
  ],
  "proximo_passo": "rode smoke-test.sh: gate que nunca reprovou não é gate (V9 → R3)"
}
```

Diretórios, imports e os paths da config de fronteira são renomeados **na mesma
passada** — inclusive dentro de alternações de regex, para que nenhuma regra
sobre apontando para módulo que não existe mais.

`residuo_de_prosa` é o que sobrou em comentário, nome de regra e variável de
ambiente — 21 entradas nesta renomeação, e o bloco acima mostra quatro delas com
a linha do meio dizendo que está cortado. O script não adivinha prosa: **varra a
lista à mão.** Nome de regra como `domain-e-puro` continua válido — só está
falando de um módulo que agora se chama `cobranca`.

O script **recusa rodar onde já há código-fonte**. Havendo, é modo A.

Depois, nesta ordem:

1. **Instale as dependências do projeto.** Sem elas o gate cruza zero módulo — o
   adaptador detecta e recusa, mas o certo é instalar antes.
2. `./scripts/gen-baseline.sh <repo>` — baseline nasce vazio. Em projeto novo
   qualquer violação é nova, e é assim que deve ser.
3. `./scripts/smoke-test.sh <repo>` — obrigatório, igual ao modo A.
4. **Substitua o exemplo `invoice` pelo primeiro caso de uso real.** O exemplo do
   scaffold é o que o agente vai imitar; trocá-lo cedo importa mais do que
   parece.

---

## 7. O que fica no repositório

```
.claude/settings.json          permissões + registro dos hooks
.claude/hooks/on-edit.sh       por edição: assíncrono, silencioso
.claude/hooks/verify.sh        por turno: gates sobre os arquivos da sessão
.claude/hooks/guard-prod.sh    nega produção também em hook (A2)
.claude/hooks/cleanup.sh       fim de sessão
.claude/commands/              plan, review, ship, stats
.harness/harness.json          dono, teto de autonomia, gates ligados, alvos
.harness/baseline.json         fronteira: as violações congeladas
.harness/baseline-size.json    tamanho: {caminho: linhas}, o número que não sobe
.harness/gate-boundaries.sh    o gate de fronteira, invocável à mão (D5)
.harness/gate-size.sh          o gate de tamanho, idem — e sem adaptador
.harness/log.sh                o emissor da trilha, sourceado pelos hooks (V12)
.harness/stats.sh              o leitor da trilha, read-only
.harness/log/.gitignore        a trilha se ignora de dentro; a raiz não é tocada
.harness/adapters/node.sh      o adaptador, dentro do repo (D1 → R8)
.dependency-cruiser.cjs        a config de fronteira
<módulo>/CLAUDE.md             um por módulo existente
```

São **dois gates e dois baselines**, e os quatro arquivos estão nesta lista de
propósito: uma versão desta página listava só os de fronteira, e o gate de
tamanho — o único que vale em stack sem adaptador — desaparecia justamente para
quem mais precisa dele.

`.harness/harness.json` é o registro do que foi decidido:

```json
{
  "harness_version": "0.3.0",
  "owner": "Flavio Magacho",
  "autonomy_ceiling": "supervisionado",
  "anti_loop_tries": 3,
  "formatter": null,
  "boundary": {
    "adapter": "node",
    "config": ".dependency-cruiser.cjs",
    "targets": ["src"]
  },
  "size": {
    "ceiling": 400,
    "targets": ["src"],
    "extensions": ["ts", "tsx", "mts", "cts", "js", "jsx", "mjs", "cjs",
                   "py", "go", "java", "kt", "rb", "rs", "php", "cs", "sh"],
    "exclude": ["*.d.ts", "*.generated.*", "*.min.js", "*.pb.go",
                "*_pb2.py", "*.snap", "*-lock.json"]
  },
  "telemetry": {
    "enabled": true,
    "retention_months": 6
  },
  "gates": {
    "boundaries": true,
    "size": true,
    "lint": "npm run lint",
    "typecheck": null
  }
}
```

`telemetry.enabled: false` desliga a trilha inteira, e sobrevive a reinstalar:
desligar é decisão registrada do projeto, nunca efeito colateral de rodar a
instalação de novo — a mesma regra que protege o dono e o teto de autonomia.

`"typecheck": null` é a pendência declarada da §5.0 — visível, não esquecida.
`anti_loop_tries` é o teto de V5, e `size.extensions`/`size.exclude` são a lista
canônica de varredura: existe uma só, exposta pelo gate em `--defaults`, para que
plano, audit e gate nunca contem coisas diferentes.

---

## 8. Depois de instalado

O gate roda sozinho no fim de cada turno do agente. À mão:

    ./.harness/gate-boundaries.sh

Silêncio e código 0 quando passa. Quando alguém introduz algo novo:

```
FRONTEIRA: 1 violação(ões) NOVA(S) — fora do baseline.
  sem-ciclos: src/comum/ciclo-novo.js → src/comum/moeda.js

Não adicione ao baseline para passar: o baseline só encolhe (V7).
Se a regra está errada, discuta antes — alterar fronteira exige ADR.
```

Código 1. As três violações antigas do baseline da §5.2 continuam congeladas e
**não** reprovam: o gate relata uma, que é a que a sessão introduziu.

Quando alguém resolve uma violação antiga, aperte a catraca:

    ./.harness/gate-boundaries.sh --tighten
    baseline apertado: 0 violação(ões) resolvida(s) removida(s).

Coloque o gate no CI. É o mesmo comando — não há segunda implementação.

### 8.1 A trilha: o que o harness registrou

Cada decisão de hook vira uma linha em `.harness/log/events-AAAA-MM.jsonl`.
Append-only, rotação mensal pelo nome do arquivo, e nunca versionada:

```json
{"ts":"2026-08-27T03:55:23Z","sid":"s1","ev":"guard","verdict":"deny","subject":"git tag -a v1.4.0 -m \"release\"","reason":"release"}
```

Três coisas que o emissor **não** faz, e que valem mais que qualquer evento:

- **não falha.** Todo caminho é engolido. Disco cheio, `jq` ausente ou diretório
  sem permissão não podem derrubar um hook — muito menos o `PreToolUse`, que
  decide permissão. Perder uma linha de log é barato; perder a trava de produção
  não é;
- **não vaza.** No veredito `allow` entra **só o primeiro token** do comando — o
  binário. `API_KEY=segredo pnpm build` vira `pnpm`. Argumento carrega
  credencial, e este hook vê todo comando que o agente tenta rodar. Só no `deny`
  o comando é gravado, truncado em 200 caracteres;
- **não fala.** Nada em stdout: o `PostToolUse` é assíncrono e o `PreToolUse` usa
  stdout como protocolo de decisão.

`cleanup.sh` é o único hook **não** instrumentado, de propósito: ele apaga rastro
de sessão, e a trilha é persistente por definição.

Para ler:

```
$ ./.harness/stats.sh
harness:stats — tel · janela: últimos 30 dias
trilha: 0 dia(s), desde 2026-08-27T03:55:23Z — MAIS CURTA que a janela pedida

1. BLOQUEIOS DO guard-prod ────────────────────────────────────────
   3 bloqueio(s). Por motivo:
     deploy-prod  1
     drop-truncate  1
     release  1
   Os mais recentes:
     2026-08-27 03:55  drop-truncate  psql -h db -c "TRUNCATE faturas"
     2026-08-27 03:55  deploy-prod  ./ops/deploy.sh --env prd
     2026-08-27 03:55  release  git tag -a v1.4.0 -m "release"

2. GATE DE TURNO ──────────────────────────────────────────────────
   1 execução(ões): 1 passaram, 0 reprovaram, 0 saíram cedo (escopo vazio), 0 liberada(s) pelo anti-loop.
   Duração mediana das execuções completas: 790 ms

3. ESTADO DA CATRACA ──────────────────────────────────────────────
   fronteira: 3 entrada(s); não versionado, sem histórico de encolhimento
   tamanho: 1 entrada(s); não versionado, sem histórico de encolhimento

4. COBERTURA ──────────────────────────────────────────────────────
   ligados: boundaries, size, lint
   lacunas: typecheck (desligado), formatter (desligado)

5. ATIVIDADE ──────────────────────────────────────────────────────
   3 edição(ões) em 2 arquivo(s), 1 sessão(ões).
     2×  src/comum/moeda.js
     1×  src/cobranca/cobrar.js

6. MODO DE PERMISSÃO ──────────────────────────────────────────────
   sem dado: não há transcripts para este repositório em ~/.claude/projects/.
```

A ordem das seções é a ordem das perguntas do dono, e a primeira é sempre a
mesma: **o que ele impediu?**

Repare em duas frases que não são enfeite. `MAIS CURTA que a janela pedida` diz
que os números cobrem menos tempo do que os 30 dias pedidos — sem isso, um zero
qualquer viraria "nada acontece aqui". E `typecheck (desligado)` aparece como
**lacuna**: gate que não existe é informação, e a ausência dele no relatório é
como um gate desligado por engano fica invisível por mais um trimestre.

Outras janelas e saídas:

```bash
./.harness/stats.sh --since 7d        # 7d, 30d, all, ou YYYY-MM-DD
./.harness/stats.sh --json            # o mesmo conteúdo, legível por máquina
./.harness/stats.sh --denies          # só os bloqueios, um por linha
```

```
$ ./.harness/stats.sh --denies
2026-08-27T03:55:23Z  drop-truncate  psql -h db -c "TRUNCATE faturas"
2026-08-27T03:55:23Z  deploy-prod  ./ops/deploy.sh --env prd
2026-08-27T03:55:23Z  release  git tag -a v1.4.0 -m "release"
```

Quando a trilha é mais curta que a janela, o leitor **complementa** com os
`stop_hook_summary` dos transcripts em `~/.claude/projects/<slug>/*.jsonl` e
rotula a seção como **reconstruída**, não medida — assim há histórico no dia
zero, em vez de relatório vazio. Ali só o gate de turno deixa rastro: `guard-prod`
e `on-edit` são invisíveis nessa fonte, que é exatamente a lacuna que a trilha
fecha.

Os transcripts também são a única fonte do **modo de permissão**. Quando o
predominante for `bypassPermissions`, o relatório diz em voz alta que o bloco
`permissions.allow` do `settings.json` não tem efeito algum — só as negações são
honradas — e que a dupla trava de produção passa a depender só do hook. Metade da
configuração de permissão que a instalação escreveu vira decoração enquanto isso
durar, e hoje ninguém percebe.

O comando `/stats` roda o script e **interpreta**: aponta o gate que nunca
disparou, a catraca parada e a lacuna de cobertura, sem repetir os números.

**E há um segundo comando, do plugin:** `/harness:stats` mostra o que está
gravado, sem julgar — deste repositório, ou de todos os da máquina:

```
$ harness-stats.sh --all
repositório                               versão   trilha      eventos  bloqueios
────────────────────────────────────────────────────────────────────────────────
/home/fulano/Workspace/faturamento        0.3.0    medindo     412      7
/home/fulano/Workspace/legado             0.2.7    sem-emissor 0        0

  1 repositório(s) com harness anterior à telemetria: nenhum hook
  registra nada ali, e 0 evento não quer dizer que nada aconteceu.
  harness:install de novo liga a trilha sem sobrescrever edição manual.
```

`sem-emissor` é a linha que justifica a tabela existir: um repositório com gates
funcionando e **nenhum registro deles**. Sem essa distinção, ele apareceria como
`0 eventos, 0 bloqueios` — indistinguível de um repositório tranquilo.

Os dois comandos leem pelo **mesmo** `stats.sh`, via `--root`. Não há segunda
implementação da leitura, pela mesma razão que não há segunda varredura de
arquivo-fonte: listas paralelas divergem, e a errada é sempre a que alguém lê
antes de decidir.

Para desligar tudo: `telemetry.enabled: false` em `.harness/harness.json`. O
leitor passa a dizer isso, em vez de imprimir um relatório vazio que pareceria
inatividade.

---

## 9. Stack sem adaptador de fronteira

Só JS/TS tem adaptador hoje. Python, JVM e Go **recebem o harness completo sem o
gate de fronteira**, com a lacuna dita em voz alta:

```json
{
  "boundary": {
    "adapter": null,
    "reason": "stack python: gate de fronteira não implementado (import-linter)",
    "config": "",
    "targets": []
  },
  "pendencias": [
    "A3 → R5: não há script de investigação read-only. O harness instala sem ele; escreva um para a sua stack e o gate de conformidade fecha.",
    "D4 → R10: stack python: gate de fronteira não implementado (import-linter). Todo o resto instala; o gate de fronteira NÃO fica disponível. A catraca de TAMANHO não depende de adaptador e fica ativa mesmo assim."
  ]
}
```

`gen-baseline.sh` e `smoke-test.sh` saem com código **3** e explicam o que falta.
Isso não é erro de instalação: é a ausência sendo declarada. Não aborte.

---

## 10. Rodar de novo, e o que nunca é sobrescrito

A instalação é idempotente. Rodando a fase 1 uma segunda vez num repositório que
já foi customizado à mão:

```json
{
  "fase": "1",
  "versao": "0.3.0",
  "escritos": [
    ".harness/log.sh", ".harness/stats.sh",
    ".claude/hooks/on-edit.sh", ".claude/hooks/verify.sh",
    ".claude/hooks/guard-prod.sh", ".claude/hooks/cleanup.sh",
    ".claude/commands/ship.md",
    ".harness/gate-boundaries.sh", ".harness/gate-size.sh",
    ".harness/adapters/node.sh", ".harness/harness.json",
    ".claude/settings.json (merge)"
  ],
  "pulados": [
    ".claude/commands/plan.md — já existe; comando do projeto manda",
    ".claude/commands/review.md — já existe; comando do projeto manda",
    ".claude/commands/stats.md — já existe; comando do projeto manda",
    ".dependency-cruiser.cjs — já existe; a config de fronteira do projeto manda"
  ],
  "telemetria": []
}
```

Hook e gate reaparecem em `escritos` porque o hash confere: são nossos e da mesma
versão, então reescrever é operação nula. `ship.md` é regerado sempre — ele cita
os comandos que **existem**, e essa lista pode ter mudado desde a última rodada.

Arquivo que você editou **nunca** é sobrescrito, e o pulo é relatado — não
silenciado (D3 → R10). O dono já registrado também não é trocado por argumento
de linha de comando: passar `--owner "Outra Pessoa"` na segunda rodada não muda
`harness.json`.

Arquivos gerados carregam marca de versão e hash (`harness-generated: 0.3.0
sha=…`). É assim que a próxima versão sabe o que é dela e o que é seu.

### O hook que você editou, e a telemetria

Há um caso em que a regra "não sobrescrever" e uma feature nova se chocam: a
`0.3.0` precisa instrumentar os hooks, e `guard-prod.sh` é justamente onde as
regras específicas do projeto costumam ser acrescentadas à mão. Perder uma regra
`deny` escrita à mão para ganhar estatística seria um péssimo negócio.

Então quando o hash **não** confere, o hook não é reescrito: a telemetria é
**enxertada**. O enxerto envolve a função que já está lá — captura a `deny()` do
projeto com `declare -f` e a chama depois de registrar — sem mover uma linha das
regras locais. O resultado é validado com `bash -n` antes de substituir o
arquivo, porque hook quebrado é pior que hook sem trilha.

```json
"telemetria": [
  {
    "hook": "guard-prod.sh",
    "acao": "instrumentado",
    "detalhe": "deny() envolvida e allow registrado na saída; regras locais intactas. Sem rótulo de motivo: a assinatura antiga não o carrega"
  }
]
```

Leia o `detalhe`: alguns enxertos vêm com **menos granularidade** e isso é dito,
não escondido. O `guard-prod` editado à mão registra o bloqueio como
`nao-rotulado`, porque a assinatura antiga da `deny()` não carrega o motivo — e
inventar uma categoria a partir do texto da recusa seria pior que admitir a
lacuna. Quando o enxerto não é possível, a ação vem `nao-instrumentado` com o
motivo, e o arquivo fica intacto (D4 → R10).

---

## 11. Códigos de saída

| código | significa | o que fazer |
|---|---|---|
| 0 | passou | seguir |
| 1 | violação nova, fora do baseline | corrigir o código, não o baseline |
| 3 | afirmação falsa (`check-claims`), grafo não medido (`boundary-status`), ou capacidade ausente | corrigir / declarar a lacuna — **nunca ler como "sem violações"** |
| 64 | uso errado do adaptador | argumento errado |

Dois erros do adaptador que **não** são verde:

- `ADAPTADOR_FALHOU` — a ferramenta não produziu JSON válido.
- `ADAPTADOR_NAO_CRUZOU: 0 módulos analisados` — o gate não verificou nada.
  Causa comum: projeto TypeScript sem `typescript` instalado, ou alvo errado em
  `.harness/harness.json → boundary.targets`. **Nunca trate como verde**: gate
  silenciosamente verde é pior que gate nenhum.

---

## 12. Limites

- Fronteiras só em JS/TS. As demais stacks recebem o resto, com a lacuna
  declarada.
- O harness **verifica** fronteiras; não as **desenha**. Se a instalação parecer
  exigir mover código, pare: isso é modularização, outra disciplina e outro
  risco.
- Em modo A a config gerada proíbe só ciclo e órfão. Regra de direção entre
  módulos é decisão de arquitetura — some uma por vez, cada uma com ADR.
- A fase 4 (roster de subagentes) não é instalada.
- O único critério de sucesso que não dá para fraudar: **o harness continua
  ligado daqui a três meses**. Quem observa isso é o dono registrado.
