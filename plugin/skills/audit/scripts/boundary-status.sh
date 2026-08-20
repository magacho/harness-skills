#!/usr/bin/env bash
# Estado do grafo e do baseline. Só Node/TS por enquanto (D4: ausência declarada).
set -uo pipefail
root="${1:-.}"; cd "$root" || exit 1

if [[ ! -f package.json ]]; then
  echo "ADAPTADOR_INDISPONIVEL: esta stack não tem adaptador de fronteira implementado."
  echo "O harness pode ser instalado sem o gate de fronteira. Declare isso no relatório."
  exit 0
fi

if [[ -f .dependency-cruiser.js ]]; then
  echo "CONFIG_EXISTENTE: .dependency-cruiser.js"
  npx --yes depcruise --config .dependency-cruiser.js src modules 2>&1 | tail -5
else
  echo "SEM_CONFIG: contando ciclos com regra mínima para dimensionar o baseline"
  npx --yes depcruise --no-config --validate 2>/dev/null <<< '' || true
  npx --yes madge --circular --extensions ts,tsx,js,jsx src modules 2>&1 | tail -20 \
    || echo "(instale madge ou dependency-cruiser para dimensionar)"
fi
