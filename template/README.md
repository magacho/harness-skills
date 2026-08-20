# harness-template

Scaffolding de projeto com o harness do Claude Code já montado: contexto,
verificação automática, fronteiras de módulo executáveis e ops com stg/prd.

## Estrutura

    CLAUDE.md                     contexto raiz (instrução, não documentação)
    .dependency-cruiser.js        a arquitetura, como teste
    .claude/
      settings.json               permissões + 4 hooks
      hooks/guard-prod.sh         PreToolUse — bloqueia escrita em prod
      hooks/on-edit.sh            PostToolUse — formata e rastreia (async)
      hooks/verify.sh             Stop — lint + fronteiras + types, escopo da sessão
      hooks/cleanup.sh            SessionEnd
      agents/architect.md         auditoria do acoplamento invisível ao grafo
      commands/                   /plan /review /investigate /ship
    modules/
      shared/   tipos puros, folha do grafo
      domain/   regras de negócio, puro, I/O por porta
      data/     acesso a dados, dono do schema
      api/      HTTP + composition root, contracts/ é a API pública do web
      web/      interface, só vê api/contracts
    ops/
      investigate.sh              read-only, seguro em prod
      deploy.sh                   stg livre, prd exige humano
      env.stg.sh / env.prd.sh     coordenadas (sem segredo)
    docs/adr/                     decisões de fronteira

## A pirâmide de verificação

| camada | quando | custo | pega |
|---|---|---|---|
| CLAUDE.md por módulo | sempre em contexto | zero | intenção |
| prettier | por edição | ~200ms | formatação |
| eslint + depcruise + tsc | por turno (Stop) | segundos | fronteira, tipo, lint |
| subagente architect | pré-PR / semanal | caro | acoplamento por runtime |
| suíte completa | CI | minutos | regressão |

Regra: por edição só o que é grátis pro contexto; por turno o que precisa
realimentar o agente; no CI o que só precisa impedir o merge.

## Setup

    pnpm install
    chmod +x .claude/hooks/*.sh ops/*.sh
    # jq precisa estar no PATH
    pnpm boundaries        # confirme que o baseline está verde

**Se o repo já é legado e tem violação:** gere o baseline e o gate passa a falhar
só no que é novo —

    npx depcruise --config .dependency-cruiser.js --output-type baseline modules \
      > .dependency-cruiser-known-violations.json

e descomente `knownViolations` em `.dependency-cruiser.js`.

## Adaptando

1. Renomeie os módulos para o seu domínio — a estrutura importa, os nomes não
2. Ajuste os paths em `.dependency-cruiser.js` junto
3. Preencha `ops/env.*.sh` e os comandos de deploy da sua stack
4. Substitua o exemplo de `invoice` pelo seu primeiro caso de uso real

## Múltiplas janelas

O tracker é por `session_id` e por `agent_id`, então subagentes na mesma sessão
funcionam. **Duas janelas no mesmo repo, não:** a working tree é compartilhada e o
`tsc` de uma vê o trabalho meio-feito da outra. Use `claude --worktree`.

## O loop que mantém isso vivo

Todo achado do `architect` termina em uma de duas coisas: regra nova no
`.dependency-cruiser.js`, ou ADR. Se terminar em relatório, você recontrata o
mesmo achado no mês que vem.
