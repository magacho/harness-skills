#!/usr/bin/env bash
# Evals dos scripts de auditoria. Cada um verifica um comportamento declarado.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
S=plugin/skills/audit/scripts
pass=0; fail=0
t() { if eval "$2" >/dev/null 2>&1; then echo "  ok   $1"; pass=$((pass+1)); else echo "  FAIL $1"; fail=$((fail+1)); fi; }

echo "→ detect-stack"
t "identifica node-ts no template"        "$S/detect-stack.sh template | grep -q '\"stack\": \"node-ts\"'"
t "identifica harness existente"          "$S/detect-stack.sh template | grep -q '\"settings\": true'"
t "conta CLAUDE.md de módulo"             "[ \$($S/detect-stack.sh template | grep -o '\"claude_md_module_count\": [0-9]*' | awk '{print \$2}') -ge 5 ]"
t "declara stack sem adaptador"           "$S/detect-stack.sh evals/fixtures/python-sem-adaptador | grep -q 'unsupported'"

echo "→ check-claims (regra C4)"
t "template não tem instrução falsa"      "$S/check-claims.sh template"
t "detecta instrução falsa no fixture"    "! $S/check-claims.sh evals/fixtures/legado-com-instrucao-falsa"
t "aponta exatamente 2 falsas"            "{ $S/check-claims.sh evals/fixtures/legado-com-instrucao-falsa || true; } | grep -q 'falsas=2'"
t "repo sem CLAUDE.md não quebra"         "$S/check-claims.sh evals/fixtures/sem-harness | grep -q SEM_CLAUDE_MD"

echo "→ read-only"
before=$(find template evals/fixtures -type f -newermt '-1 second' 2>/dev/null | wc -l)
$S/detect-stack.sh template >/dev/null; $S/check-claims.sh template >/dev/null
after=$(find template evals/fixtures -type f -newermt '-1 second' 2>/dev/null | wc -l)
t "auditoria não escreve arquivo"         "[ $before -eq $after ]"

echo
echo "pass=$pass fail=$fail"
[[ $fail -eq 0 ]]
