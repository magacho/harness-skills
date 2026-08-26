#!/usr/bin/env bash
# Caso: o audit lê o contexto declarado — stack, harness existente, e se as
# afirmações do CLAUDE.md são verdadeiras (C4). Sourced por run.sh: usa $A, $T,
# $F, $W, t() e s() do runner.

echo "→ audit / detect-stack"
t "identifica node-ts no template"        "$A/detect-stack.sh $T | grep -q '\"stack\": \"node-ts\"'"
t "identifica harness existente"          "$A/detect-stack.sh $T | grep -q '\"settings\": true'"
t "conta CLAUDE.md de módulo"             "[ \$($A/detect-stack.sh $T | grep -o '\"claude_md_module_count\": [0-9]*' | awk '{print \$2}') -ge 5 ]"
t "declara stack sem adaptador"           "$A/detect-stack.sh $F/python-sem-adaptador | grep -q 'unsupported'"

# Regressão: o audit reportava boundary_config=false e baseline=false num repo
# que TINHA os dois. Procurava .dependency-cruiser.js (o instalador escreve
# .cjs) e o baseline NATIVO da ferramenta em vez de .harness/baseline.json —
# ficava cego para a instalação que a skill irmã acabara de fazer.
RI=$W/repo-instalado
mkdir -p "$RI/.harness" && echo '{}' > "$RI/package.json"
: > "$RI/.dependency-cruiser.cjs"; echo '[]' > "$RI/.harness/baseline.json"
printf '{"harness_version":"0.2.0","owner":"Fulano","autonomy_ceiling":"supervisionado"}\n' \
  > "$RI/.harness/harness.json"
t "enxerga a config .cjs que o instalador escreve" \
  "$A/detect-stack.sh $RI | jq -e '.harness.boundary_config == true'"
t "enxerga o baseline do harness (V8)"    "$A/detect-stack.sh $RI | jq -e '.harness.baseline == true'"
t "distingue baseline nativo do da catraca" \
  "$A/detect-stack.sh $RI | jq -e '.harness.baseline_nativo == false'"
t "lê o dono registrado (D6)"             "$A/detect-stack.sh $RI | jq -e '.harness.dono == \"Fulano\"'"
t "lê o teto de autonomia (A6)"           "$A/detect-stack.sh $RI | jq -e '.harness.teto_de_autonomia == \"supervisionado\"'"

echo "→ audit / check-claims (regra C4)"
t "template não tem instrução falsa"      "$A/check-claims.sh $T"
t "detecta instrução falsa no fixture"    "! $A/check-claims.sh $F/legado-com-instrucao-falsa"
t "aponta exatamente 2 falsas"            "{ $A/check-claims.sh $F/legado-com-instrucao-falsa || true; } | grep -q 'falsas=2'"
t "repo sem CLAUDE.md não quebra"         "$A/check-claims.sh $F/sem-harness | grep -q SEM_CLAUDE_MD"

# Regressão: só scripts de package.json eram verificados. O CLAUDE.md que o
# próprio harness gera cita ./.harness/gate-boundaries.sh — apagar o gate não
# aparecia como instrução falsa, e o audit reportava falsas=0.
CP=$W/claims-caminho
mkdir -p "$CP"; echo '{"scripts":{}}' > "$CP/package.json"
printf '# x\n\n- `./.harness/gate-boundaries.sh` — fronteiras\n' > "$CP/CLAUDE.md"
t "acusa caminho citado e ausente (C4)"   "! $A/check-claims.sh $CP"
t "e diz que o caminho não existe"        "{ $A/check-claims.sh $CP || true; } | grep -q 'não existe'"
mkdir -p "$CP/.harness"; printf '#!/bin/sh\n' > "$CP/.harness/gate-boundaries.sh"
t "caminho presente mas não executável reprova" "! $A/check-claims.sh $CP"
chmod +x "$CP/.harness/gate-boundaries.sh"
t "caminho presente e executável passa"   "$A/check-claims.sh $CP"

echo "→ audit / read-only"
before=$(find $T $F -type f -newermt '-1 second' 2>/dev/null | wc -l)
$A/detect-stack.sh $T >/dev/null; $A/check-claims.sh $T >/dev/null
after=$(find $T $F -type f -newermt '-1 second' 2>/dev/null | wc -l)
t "auditoria não escreve arquivo"         "[ $before -eq $after ]"
