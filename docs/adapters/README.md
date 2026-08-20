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
| JavaScript / TypeScript | dependency-cruiser | **implementado** |
| Python | import-linter | não implementado |
| JVM | ArchUnit | não implementado |
| Go | go-arch-lint | não implementado |

**Regra D4:** stack sem adaptador recebe o harness completo **sem** o gate de
fronteira, e a auditoria declara a lacuna em voz alta. Silenciar é o erro grave;
instalar 80% não é.

## Adicionando um adaptador

O contrato acima só foi exercitado por uma implementação. Ele provavelmente está
errado em algum detalhe — a segunda implementação é que vai revelar onde. Trate a
primeira revisão do contrato como esperada, não como falha.
