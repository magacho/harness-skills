---
description: Revisa o diff contra a branch base antes do PR
---
Rode `git diff $(git merge-base HEAD @{u} 2>/dev/null || echo main)...HEAD` e revise.

Ordem: (1) corretude e casos de borda, (2) violação de fronteira ou do
`CLAUDE.md`, (3) testes ausentes, (4) segurança — segredo, injection, authz.

O gate de turno já cobriu lint, tipo e fronteira. **Não repita esse trabalho.**
Diga explicitamente o que você não está revisando por já estar coberto.

Olhe o que a máquina não vê: blast radius, ordem de migration, o que o rollback
não desfaz, contrato mudado sem versão.

Saída: achados por severidade (bloqueia / deveria / nit), cada um com
`arquivo:linha` e a correção sugerida. Não edite nada.
