# Changelog

Skill que modifica repositório alheio sem changelog é impossível de adotar com
confiança.

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
