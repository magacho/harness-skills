---
name: audit
description: Audita o harness de um repositório — contexto, verificação, permissões, fronteiras e riscos — e produz um relatório com o que remover, corrigir e adicionar. Use quando o usuário pedir para avaliar, revisar ou diagnosticar a configuração de agente de um projeto, perguntar se o CLAUDE.md está bom, quiser preparar um repositório para trabalho agêntico, ou antes de instalar o harness em projeto existente. Read-only: nunca altera arquivo.
---

# harness:audit

Diagnostica o estado do harness de um repositório e produz um relatório
acionável. **Não altera nada.** É a porta de entrada: o relatório desta skill é a
especificação do que o `harness:install` precisa fazer.

Base normativa: `docs/HARNESS.md` (regras) e `docs/INTENT.md` (resultados).

## Princípio

**A skill decide; o script executa.** Detecção, verificação de afirmações e
contagem de baseline são determinísticas e vivem em `scripts/`. Não reimplemente
com leitura manual: menos confiável e não reproduzível entre execuções.

## Procedimento

### 1. Coleta mecânica

```bash
./scripts/detect-stack.sh <repo>       # stack, layout, harness existente → JSON
./scripts/check-claims.sh <repo>       # regra C4: as afirmações são verdadeiras?
./scripts/boundary-status.sh <repo>    # grafo e dimensão do baseline
./scripts/size-status.sh <repo>        # god files: mediana, p95, quantos acima do teto
./scripts/telemetry-status.sh <repo>   # a trilha: existe? liga? o que registrou? (V12)
```

Se `boundary_adapter` vier como `unsupported:*`, **declare em voz alta** no
relatório que o gate de fronteira não está disponível para esta stack, e siga com
o resto (regra D4). Nunca silencie a lacuna; nunca aborte a auditoria.

`size-status.sh` não depende de adaptador nem de ferramenta: mede em qualquer
stack. Relate `acima_do_teto` junto com `mediana` e `p95` — o número absoluto
sozinho não diz nada. Mediana 90 com dez arquivos acima de 400 é um repositório
saudável com dez pontos quentes; mediana 600 é outra conversa, e nesse caso o
teto precisa ser discutido antes de instalar, não depois. Ele também sai com
**código 3** quando não achou código-fonte: isso é dimensão desconhecida, nunca
"nenhum god file".

`boundary-status.sh` sai com **código 3** quando não conseguiu medir o grafo —
sem diretório de código reconhecido, ou adaptador que cruzou zero módulo. Isso
**não é "sem violações"**: é dimensão desconhecida. Relate como lacuna e não
conclua nada sobre a catraca a partir dela.

`telemetry-status.sh` responde o que nenhuma leitura de arquivo responde: **o
que os hooks efetivamente pegaram**. Ele não reimplementa nada — chama o mesmo
leitor da trilha que o repositório instalado usa (`stats.sh --root`), e por isso
funciona inclusive onde o harness é anterior à telemetria.

Também sai com **código 3** quando não há o que medir, e as quatro razões são
diferentes entre si — o campo `estado` diz qual:

- **`sem-emissor`** — harness instalado por versão anterior à `0.3.0`. É o caso
  mais traiçoeiro: o repositório tem gates funcionando e **nenhum registro deles**.
  Vai para *Adicionar*, com a frase certa: não é "0 bloqueios", é "ninguém estava
  medindo". Reinstalar liga a trilha sem sobrescrever hook editado à mão.
- **`desligada`** — `telemetry.enabled: false`, decisão registrada do projeto.
  Registre; não recomende religar sem perguntar.
- **`vazia`** — ligada, ainda sem evento.
- **`sem-harness`** — não se aplica.

Quando o estado for `medindo`, o número **nunca** vai ao relatório sozinho:
`0 bloqueios` numa trilha de 40 dias é um fato sobre o repositório; numa trilha
de ontem é ausência de dado (V13). O campo `dias_de_trilha` acompanha o número
sempre.

E leia `allow_efetivo`: quando for `false`, as sessões daquele repositório rodam
em `bypassPermissions`, o bloco `permissions.allow` não tem efeito algum, e a
dupla trava de produção passa a depender só do hook. É achado de risco (§3.1),
não rodapé.

### 2. Leitura de contexto

Leia o `CLAUDE.md` raiz e os de módulo. Avalie contra as regras C:

- **C1/C4** — afirmações verdadeiras (o script já respondeu; interprete)
- **C5** — tamanho do próprio `CLAUDE.md`: raiz ~60 linhas, módulo ~15. Acima
  disso virou documentação. Não confunda com V10, que é tamanho de código
- **P1** — cada seção muda comportamento do agente? O que não muda, sai
- **C3** — cada módulo declara o que importa e o que nunca importa?

### 3. Tamanho e responsabilidade

O que `size-status.sh` mede é arquivo. O que interessa é responsabilidade, e isso
nenhum script mede: **módulo cuja responsabilidade não cabe numa frase sem "e"**
é achado de leitura, não de contagem. Contagem de arquivos por módulo não serve
como proxy — um módulo de dados com 40 repositórios pequenos é saudável e um
domínio com 6 arquivos de 900 linhas é doente, e a contagem premia o segundo.

Relate os dois separados: o número (V10, verificável) e o julgamento (leitura,
com o arquivo e a frase que não fecha).

### 3.1. Postura de risco

- Caminho para produção alcançável pelo agente (regra A1/A2)
- Modo de permissão predominante (`telemetry-status.sh → allow_efetivo`): em
  `bypassPermissions`, metade da configuração de permissão é decoração
- Segredo versionado ou legível (A5)
- Permissões ausentes ou permissivas demais
- Garantia dependendo de configuração pessoal (D1)

### 4. Parâmetros ausentes

Em repositório sem harness, teto de autonomia e dono simplesmente não existem.
Registre como pendência — **o dono é obrigatório** e sem ele nenhum critério de
sucesso tem observador (D6).

### 5. Relatório

Use `reference/report-template.md`. A seção **Trilha** é onde entra o que
`telemetry-status.sh` mediu — e onde a distinção entre zero medido e zero
desconhecido tem de aparecer em palavras, não só em número.

Três listas, nesta ordem:

1. **Remover** — instrução falsa, documentação disfarçada de instrução,
   ferramenta conectada e não usada
2. **Corrigir** — o que existe mas está errado
3. **Adicionar** — o que falta

E o sumário de conformidade de `reference/conformance-checklist.md`.

> A lista de **remover** costuma ser a mais valiosa. Repositório com harness
> antigo sofre de excesso, não de falta.

## Limites

- **Read-only.** Se o usuário pedir para corrigir, diga o que fazer e ofereça o
  `harness:install` — não edite.
- **Descreva, não prescreva** (P7/C6). Os módulos do projeto têm os nomes que já
  têm. Nunca compare a um template nem sugira renomear para `domain`/`data`.
- **Só Node/TS tem adaptador de fronteira.** As demais stacks recebem auditoria
  completa das outras camadas, com a lacuna declarada.
- **Nem todo repositório merece harness.** Script de uso único ou protótipo
  descartável: diga isso em vez de recomendar instalação.
