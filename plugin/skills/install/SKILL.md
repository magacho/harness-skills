---
name: install
description: Instala o harness em um repositório — hooks, permissões, comandos, catraca de violações e CLAUDE.md hierárquico. Use quando o usuário pedir para instalar, aplicar, montar ou configurar o harness num projeto, quiser preparar um repositório novo com scaffold pronto, pedir para ligar os gates de verificação e fronteira de módulo, quiser fazer o retrofit de um projeto legado, ou depois de rodar harness:audit e quiser executar o que o relatório recomendou. Uma skill, dois modos: projeto novo e projeto existente. Nunca escreve sem confirmação.
---

# harness:install

Aplica o harness a um repositório. **Dois modos, um mecanismo:** o que muda entre
eles é o risco e a ordem das fases, não a maquinaria.

| | modo A — projeto existente | modo B — projeto novo |
|---|---|---|
| gatilho | há código-fonte | não há código-fonte |
| ordem | fases 1 → 2 → 3, com checkpoint humano entre elas | scaffold → dependências → catraca → fumaça |
| risco | alto: repositório com trabalho de outras pessoas | baixo: não há o que estragar |
| toca código-fonte | **nunca** | escreve o exemplo inicial |

Base normativa: `docs/HARNESS.md` (regras) e `docs/INTENT.md` (resultados).
A ordem das fases é `docs/PLAN.md` §4.

## Princípio

**A skill decide; o script executa.** Detecção, geração de config, baseline e
teste de fumaça são determinísticos e vivem em `scripts/`. Não escreva config à
mão: mais caro, mais lento, menos confiável, e não reproduzível entre execuções.

## 0. Antes de qualquer coisa

```bash
./scripts/plan-install.sh <repo>        # read-only: modo, stack, módulos, manifesto
```

Rode também `harness:audit` se o repositório já tem harness — o relatório dele é
a especificação do que corrigir. Não reimplemente a detecção.

Leia `merece_harness` na saída. **Se o veredito for `false`, diga isso e pare.**
Script de uso único e protótipo descartável pagam a cerimônia e não recebem nada;
instalar mesmo assim é como o harness ganha má fama. Ofereça o audit, que é
read-only, e deixe a decisão com a pessoa.

**Mostre o manifesto e espere o ok.** Nenhum script que escreve roda antes disso.
Vale para as duas coisas que o manifesto revela: o que será criado, e o que já
existe e por isso não será tocado.

Pergunte o **dono** — é obrigatório e não tem default (D6 → R6). Sem alguém
nomeado, nenhum modo de fracasso tem quem reaja e o critério de sucesso de três
meses fica sem observador. Pergunte junto o **teto de autonomia**; o default é
`supervisionado` e ratificar basta.

---

## Modo A — projeto existente

Fases 1 a 3 do `PLAN.md` §4, **nesta ordem, com checkpoint humano entre cada
uma**. Ver `./reference/checkpoints.md` para o que exibir em cada parada.

### Fase 1 — hooks, permissões, comandos, dono, teto

```bash
./scripts/gen-config.sh <repo> --plan <plan.json> --owner "<nome>" \
    [--ceiling supervisionado] --fase 1
```

Instala os quatro hooks, as permissões, os comandos, o gate de fronteira e o
adaptador **dentro do repositório** (`.harness/`), não no plugin: quem clona
recebe o mesmo comportamento sem ter a skill instalada (D1 → R8).

Três coisas para conferir na saída e relatar:

- **`pulados`** — arquivo editado à mão nunca é sobrescrito (D3 → R10). Diga
  quais foram e por quê; não insista.
- **Gates ligados** — só entra o que já passava hoje. Lint ou typecheck vermelho
  fica **fora** do gate e vira pendência declarada. Ligar gate que reprova
  trabalho legítimo é o modo de fracasso nº 1: o time desliga em duas semanas, e
  um gate desligado é pior que nenhum.
- **`pendencias`** — leia em voz alta, uma por uma. Ausência declarada é
  requisito (D4 → R10), não rodapé.

Aceite da fase: o gate roda, passa hoje, e reprova violação plantada.

### Fase 2 — a catraca

```bash
./scripts/gen-baseline.sh <repo>
```

Congela as violações que já existem e liga o gate em "falha só no que é novo"
(V7 → R7).

**É onde o valor chega.** Transforma "40 erros, gate inútil" em "40 erros
parados": a decadência para antes de qualquer refactor. Não pule, não inverta a
ordem, e se a instalação for interrompida, que seja depois desta fase.

O baseline **só encolhe**. O script recusa regerar se o total cresceria — e essa
recusa é a regra funcionando, não um obstáculo a contornar com `--force`.

Se a stack não tem adaptador, o script sai com código 3 e diz o que falta.
**Não aborte a instalação:** o resto está instalado e ativo, e a lacuna é dita em
voz alta (D4 → R10).

### Fase 3 — contexto

```bash
./scripts/gen-config.sh <repo> --plan <plan.json> --owner "<nome>" --fase 3
```

`CLAUDE.md` raiz enxuto e um por módulo **existente**, com os nomes inferidos do
grafo real (C6, P7 → R7).

- **Nunca renomeie módulo** para `domain`/`data`/`api`. Eles se chamam como já se
  chamam.
- **Nunca compare com o template.** O template é ponto de partida de projeto
  novo, não gabarito de projeto existente.
- O `CLAUDE.md` de módulo descreve **o que hoje importa**, lido do grafo. É
  descrição, não prescrição.
- Se o `CLAUDE.md` raiz já existe e não é nosso, o script não o sobrescreve e
  deixa a proposta em `.harness/CLAUDE.md.proposto`. **Faça o merge com a pessoa,
  item a item** — e comece pelas afirmações falsas que o audit encontrou, que são
  o achado mais barato de corrigir e o mais caro de deixar (C4 → R1).
- Complete a linha "o que este módulo faz" de cada módulo. O gerador não sabe;
  você, depois de ler o código, sabe.

### Fim — obrigatório nos dois modos

```bash
./scripts/smoke-test.sh <repo>
```

V9 → R3: planta uma violação, confirma que o gate reprova, remove. **Gate que
nunca reprovou não é gate.** Se o teste falhar, não reporte a instalação como
concluída — investigue primeiro.

A fase 4 do `PLAN.md` (roster onda 1: revisor de mudança e arquiteto) **não é
instalada por esta skill**. Diga isso ao entregar, em vez de deixar como omissão.

---

## Modo B — projeto novo

```bash
./scripts/scaffold.sh <repo> --owner "<nome>" \
    --modules "shared=<nome>,domain=<nome>,data=<nome>,api=<nome>,web=<nome>"
```

**Pergunte os nomes dos módulos antes de copiar.** Em lote, com um default
proposto para cada um, e com o bloco inteiro pulável — "mantém os nomes do
template" é resposta válida. O script renomeia diretórios, imports e os paths da
config de fronteira na mesma passada, e reporta o que sobrou como
`residuo_de_prosa`; varra o que sobrou.

O script recusa rodar se houver código-fonte. Havendo, é modo A.

Depois, nesta ordem:

1. **Instale as dependências do projeto.** Sem elas o gate de fronteira cruza
   zero módulo e reporta verde sem ter verificado nada — o adaptador detecta e
   recusa, mas o certo é instalar antes.
2. `./scripts/gen-baseline.sh <repo>` — baseline vazio, catraca ligada. Em
   projeto novo qualquer violação é nova, e é assim que deve ser.
3. `./scripts/smoke-test.sh <repo>` — obrigatório.
4. **Substitua o exemplo de `invoice` pelo primeiro caso de uso real.** O exemplo
   do scaffold é o que o agente vai imitar; trocá-lo cedo importa mais do que
   parece.

---

## Limites

- **Não toque em código-fonte no modo A.** Só `CLAUDE.md`, `.claude/**`,
  `.harness/**`, config de verificação, `docs/adr/**`, `ops/**`. Se a instalação
  parecer exigir mover código, **pare**: isso é modularização, outra disciplina e
  outro risco (`HARNESS.md` §10). Diga isso em vez de fazer.
- **Nunca instale sem confirmação.** Mostre o manifesto, espere o ok.
- **Idempotente.** Rodar duas vezes não estraga customização. Se algo foi pulado,
  isso é a regra funcionando — relate, não contorne.
- **O dono é obrigatório.** Os scripts se recusam a rodar sem ele. Não invente um.
- **Ausência é declarada em voz alta.** Stack sem adaptador instala todo o resto
  e diz que o gate de fronteira não está disponível. Não abortar, não silenciar.
- **Não escreva config à mão.** Se um gerador está errado, conserte o gerador.
- **Nem todo repositório merece harness.** Diga isso quando for o caso.
