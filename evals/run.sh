#!/usr/bin/env bash
# Evals das skills. Skill que modifica repositório alheio sem eval é risco não
# medido — e a instalação escreve.
#
# Este arquivo é só o corredor: caminhos, contadores, o par t()/s(), a sonda de
# rede e o construtor de fixture. Os testes moram em evals/cases/*.sh, uma
# família por arquivo, e são SOURCED — não subshell — para que os contadores
# sejam os mesmos.
#
#   ./evals/run.sh                    roda tudo
#   ./evals/run.sh 70-catraca-tamanho roda um caso (prefixo basta)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
A=plugin/skills/audit/scripts
I=plugin/skills/install/scripts
T=plugin/skills/install/assets/template
F=evals/fixtures
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

pass=0; fail=0; skip=0
t() { if eval "$2" >/dev/null 2>&1; then echo "  ok   $1"; pass=$((pass+1)); else echo "  FAIL $1"; fail=$((fail+1)); fi; }
s() { echo "  skip $1 — $2"; skip=$((skip+1)); }

# A cadeia de fronteira precisa do dependency-cruiser. Sem rede, os evals que
# dependem dela são PULADOS COM MOTIVO, nunca silenciados (mesma regra D4 que a
# skill cobra dos outros).
rede=0
if timeout 120 npx --yes --package dependency-cruiser depcruise --version >/dev/null 2>&1; then rede=1; fi

# Fixture instalado, um por caso. Antes havia um só $W/legado atravessando meia
# suíte: a ordem dos blocos era carregada e invisível, e mexer num quebrava
# outro três telas abaixo. Custa ~0,8s por chamada e devolve a independência.
#
#   legado_instalado <nome> [--god]   → $W/<nome> instalado, $W/<nome>.plan.json
legado_instalado() {
  local nome="${1:?uso: legado_instalado <nome> [--god]}" god="${2:-}" d="$W/$1"
  # `cp -a src dst` com dst existente copia PARA DENTRO de dst, e o caso segue
  # medindo uma árvore aninhada com cara de sucesso. Dois casos com o mesmo
  # nome é erro de programação: reprova aqui, não três telas abaixo.
  [[ -e "$d" ]] && { echo "legado_instalado: '$nome' já existe — dois casos usam o mesmo nome." >&2; return 1; }
  cp -a "$F/legado-com-ciclos" "$d"
  if [[ "$god" == --god ]]; then
    python3 -c "open('$d/src/cobranca/gigante.js','w').write(chr(10).join(f'const l{i} = {i};' for i in range(1,451))+chr(10))"
  fi
  "$I/plan-install.sh" "$d" > "$W/$nome.plan.json" 2>/dev/null
  "$I/gen-config.sh" "$d" --plan "$W/$nome.plan.json" \
    --owner "Dona Eval <eval@exemplo>" --fase 1 > "$W/$nome.f1.json" 2>/dev/null
}

filtro="${1:-}"
casos=0
for caso in evals/cases/*.sh; do
  [[ -z "$filtro" || "$(basename "$caso")" == "$filtro"* ]] || continue
  casos=$((casos+1))
  # shellcheck source=/dev/null
  source "$caso"
done

if [[ $casos -eq 0 ]]; then
  echo "nenhum caso casou com '$filtro'. Disponíveis:" >&2
  basename -s .sh -a evals/cases/*.sh | sed 's/^/  /' >&2
  exit 64
fi

echo
echo "pass=$pass fail=$fail skip=$skip  ($casos caso(s))"
[[ $skip -gt 0 ]] && echo "($skip eval(s) pulado(s) por dependência externa — declarado, não silenciado)"
[[ $fail -eq 0 ]]
