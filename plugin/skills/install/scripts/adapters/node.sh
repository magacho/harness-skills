#!/usr/bin/env bash
# Adaptador de fronteira — JavaScript/TypeScript via dependency-cruiser.
#
# Implementa o contrato de quatro verbos de docs/adapters/README.md.
# É copiado para .harness/adapters/node.sh na instalação: o gate é do
# repositório, não do plugin (D1 → R8). Quem clona recebe o mesmo comportamento
# sem ter a skill instalada.
set -uo pipefail

verb="${1:-}"; shift 2>/dev/null || true

die() { echo "$*" >&2; exit 64; }

# depcruise local vence o remoto: repo que já tem a ferramenta não baixa nada.
depcruise_bin() {
  local root="$1"
  if [[ -x "$root/node_modules/.bin/depcruise" ]]; then
    echo "$root/node_modules/.bin/depcruise"
  else
    echo "npx --yes --package dependency-cruiser depcruise"
  fi
}

case "$verb" in

# detect <raiz> → 0 se esta stack é minha
detect)
  root="${1:-.}"
  [[ -f "$root/package.json" ]] || exit 1
  exit 0
  ;;

# generate-config <raiz> <alvos-csv> → config de fronteira em stdout
#
# Modo A gera o mínimo: ciclos e órfãos. Direção de dependência NÃO é inferida
# do grafo real — HARNESS.md §10, o harness verifica fronteiras e não as
# desenha. Inferir congelaria o acidente como regra.
generate-config)
  root="${1:?raiz}"; alvos="${2:-src}"
  tscfg=""
  [[ -f "$root/tsconfig.json" ]] && tscfg='
    tsConfig: { fileName: "tsconfig.json" },
    tsPreCompilationDeps: true,'
  cat <<CFG
/**
 * Fronteiras de módulo — gerado por harness:install.
 * harness-generated: __VERSION__
 *
 * Este arquivo começa com o mínimo verificável: ciclos e órfãos. Regra de
 * direção entre módulos é decisão de arquitetura, não de instalação — some
 * uma por vez, cada uma com ADR em docs/adr/.
 *
 * Alvos: ${alvos}
 */
module.exports = {
  forbidden: [
    {
      name: "sem-ciclos",
      severity: "error",
      comment: "Ciclo é a maior causa de código emaranhado.",
      from: {},
      to: { circular: true },
    },
    {
      name: "sem-orfaos",
      severity: "warn",
      comment: "Módulo que ninguém importa: ou é entrypoint, ou é código morto.",
      from: { orphan: true, pathNot: "\\\\.d\\\\.ts\$" },
      to: {},
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },${tscfg}
    // A catraca é do harness, não da ferramenta (V8 → R7,R12): a comparação
    // com o baseline vive em .harness/gate-boundaries.sh, e não em
    // knownViolations. Baseline nativo é otimização, nunca requisito.
  },
};
CFG
  ;;

# run <raiz> <config> <alvo...> → saída bruta da ferramenta em stdout
#
# Violação NÃO é erro deste verbo: a saída bruta é o produto. Quem decide se
# reprova é a catraca, depois do normalize.
run)
  root="${1:?raiz}"; cfg="${2:?config}"; shift 2
  [[ $# -gt 0 ]] || die "run: informe ao menos um alvo"
  [[ -f "$root/$cfg" ]] || die "run: config ausente em $root/$cfg"
  bin=$(depcruise_bin "$root")
  out=$(cd "$root" && $bin --config "$cfg" --output-type json "$@" 2>/dev/null)
  if ! jq -e . >/dev/null 2>&1 <<<"$out"; then
    echo "ADAPTADOR_FALHOU: dependency-cruiser não produziu JSON válido." >&2
    exit 3
  fi
  # Zero módulos cruzados não é "sem violação": é gate que não verificou nada.
  # Acontece, por exemplo, quando o projeto é TypeScript e o compilador não
  # está instalado — a ferramenta avisa em stderr e devolve verde. Um gate
  # silenciosamente verde é pior que gate nenhum, porque cria a sensação de
  # cobertura (INTENT §11, fracasso nº 5).
  if [[ "$(jq '.modules | length' <<<"$out")" -eq 0 ]]; then
    echo "ADAPTADOR_NAO_CRUZOU: 0 módulos analisados em: $*" >&2
    echo "O gate não verificou nada. Causas comuns:" >&2
    echo "  · projeto TypeScript sem 'typescript' instalado (rode a instalação de dependências)" >&2
    echo "  · alvo errado em .harness/harness.json → boundary.targets" >&2
    echo "NÃO trate isto como verde." >&2
    exit 3
  fi
  printf '%s' "$out"
  ;;

# normalize [arquivo] → [{origem,destino,regra}] ordenado e sem duplicata
#
# É por causa deste verbo que a catraca é do harness. Toda ferramenta relata
# violação no seu próprio formato; o baseline só tem um.
normalize)
  src="${1:--}"
  jq -S '[ (.summary.violations // [])[]
           | { origem: .from, destino: .to, regra: (.rule.name // "desconhecida") } ]
         | unique' "$src"
  ;;

*)
  die "uso: node.sh <detect|generate-config|run|normalize> [args]"
  ;;
esac
