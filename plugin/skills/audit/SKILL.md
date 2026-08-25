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
```

Se `boundary_adapter` vier como `unsupported:*`, **declare em voz alta** no
relatório que o gate de fronteira não está disponível para esta stack, e siga com
o resto (regra D4). Nunca silencie a lacuna; nunca aborte a auditoria.

### 2. Leitura de contexto

Leia o `CLAUDE.md` raiz e os de módulo. Avalie contra as regras C:

- **C1/C4** — afirmações verdadeiras (o script já respondeu; interprete)
- **C5** — tamanho: raiz ~60 linhas, módulo ~15. Acima disso virou documentação
- **P1** — cada seção muda comportamento do agente? O que não muda, sai
- **C3** — cada módulo declara o que importa e o que nunca importa?

### 3. Postura de risco

- Caminho para produção alcançável pelo agente (regra A1/A2)
- Segredo versionado ou legível (A5)
- Permissões ausentes ou permissivas demais
- Garantia dependendo de configuração pessoal (D1)

### 4. Parâmetros ausentes

Em repositório sem harness, teto de autonomia e dono simplesmente não existem.
Registre como pendência — **o dono é obrigatório** e sem ele nenhum critério de
sucesso tem observador (D6).

### 5. Relatório

Use `reference/report-template.md`. Três listas, nesta ordem:

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
