---
description: Revisa o diff contra main antes do PR
---
Rode `git diff main...HEAD` e revise.

Ordem: (1) corretude e casos de borda, (2) violação de fronteira ou de CLAUDE.md,
(3) testes ausentes, (4) segurança — segredo, injection, authz.

Depois, delegue ao subagente `architect` a auditoria de acoplamento invisível ao
grafo de import, e incorpore os achados.

Saída: achados por severidade (bloqueia / deveria / nit), cada um com
arquivo:linha e a correção sugerida. Não edite nada.
