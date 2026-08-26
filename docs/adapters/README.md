# Contrato de adaptador de fronteira

Um adaptador conecta uma linguagem ao gate de fronteira. O contrato é invariante
porque deriva da pirâmide de verificação, não de nenhuma ferramenta específica.

## Quatro verbos

| verbo | entrada | saída | responsabilidade |
|---|---|---|---|
| `detect` | raiz do repo | bool | esta stack é minha? |
| `generate-config` | grafo desejado | arquivo de config | materializar as regras |
| `run` | config | saída bruta | executar a verificação |
| `normalize` | saída bruta | `[{origem, destino, regra}]` | traduzir para o formato do harness |

## Por que `normalize` existe

A catraca é do harness, não da ferramenta (regra V8). `dependency-cruiser` tem
baseline nativo; `import-linter` não tem nenhum; ArchUnit tem outro formato. Se a
catraca dependesse do mecanismo nativo, ela existiria em algumas linguagens e não
em outras — e a fase 2 da implantação teria de ser reescrita a cada nova stack.

Baseline nativo, quando existe, é otimização. Nunca requisito.

## Status

| linguagem | ferramenta | status |
|---|---|---|
| JavaScript / TypeScript | dependency-cruiser | **implementado** — `plugin/skills/install/scripts/adapters/node.sh` |
| Python | import-linter | não implementado |
| JVM | ArchUnit | não implementado |
| Go | go-arch-lint | não implementado |

**Regra D4:** stack sem adaptador recebe o harness completo **sem** o gate de
fronteira, e a auditoria declara a lacuna em voz alta. Silenciar é o erro grave;
instalar 80% não é.

## Onde o adaptador vive em quem adota

Na instalação, o adaptador é **copiado para dentro do repositório alvo**, em
`.harness/adapters/`, junto com o gate que o invoca. Não fica no plugin: quem
clona o repositório recebe o mesmo comportamento sem ter a skill instalada
(`D1 → R8`), e o gate roda em CI e sob outro agente (`R12`).

## Um verbo `run` que devolve verde sem ter verificado nada

O `node.sh` recusa reportar sucesso quando cruza zero módulo. Um projeto
TypeScript sem o compilador instalado faz o `dependency-cruiser` avisar em
stderr e sair com "no dependency violations found" — verde, sem ter analisado
arquivo nenhum. Todo adaptador novo precisa da mesma guarda: gate
silenciosamente verde é pior que gate nenhum, porque cria a sensação de
cobertura (`INTENT.md` §11, fracasso nº 5).

## Normalizar a ferramenta é trabalho do adaptador

O `run` do `node.sh` converte alvo que é diretório em
`alvo/**/*.{ts,tsx,mts,cts,js,jsx,mjs,cjs}` antes de chamar o binário. O
`dependency-cruiser` 18 não expande diretório nu para `.ts`/`.tsx` — a 16
expandia — e sem a conversão todo projeto TypeScript recebia um gate que cruzava
zero módulo.

A conversão mora no adaptador de propósito. Três chamadores entregam alvos
(`harness:audit`, o gate instalado e o planejador da instalação); corrigir em
cada um significaria três correções divergindo na primeira que fosse aplicada a
só um deles. **Quirk de ferramenta pertence ao adaptador — é o que o contrato
existe para absorver.**

O mesmo vale para resolução: a config gerada declara
`enhancedResolveOptions.extensions` porque sem ela a 18 não resolve import sem
extensão e transforma import legítimo em violação. Adaptador novo deve garantir
que **duas versões da mesma ferramenta deem a mesma resposta** — se dependem de
qual versão o `npx` baixou, a garantia depende de configuração de máquina
(`D1 → R8`).

## Adicionando um adaptador

O contrato acima só foi exercitado por uma implementação. Ele provavelmente está
errado em algum detalhe — a segunda implementação é que vai revelar onde. Trate a
primeira revisão do contrato como esperada, não como falha.
