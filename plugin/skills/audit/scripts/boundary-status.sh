#!/usr/bin/env bash
# Estado do grafo e dimensão do baseline. Read-only.
#
# Usa o adaptador pelos quatro verbos (docs/adapters/README.md) em vez de
# invocar a ferramenta à mão: é o mesmo mecanismo que a instalação usa, e a
# guarda de "cruzou zero módulo" mora lá. Duas implementações divergiriam na
# primeira correção aplicada a só um dos lados.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
adapter="$here/../../install/scripts/adapters/node.sh"

root="${1:-.}"
[[ -d "$root" ]] || { echo "raiz inexistente: $root" >&2; exit 64; }
root="$(cd "$root" && pwd)"

if [[ ! -f "$root/package.json" ]]; then
  echo "ADAPTADOR_INDISPONIVEL: esta stack não tem adaptador de fronteira implementado."
  echo "O harness pode ser instalado sem o gate de fronteira. Declare a lacuna no relatório (D4 → R10)."
  exit 0
fi
[[ -x "$adapter" ]] || { echo "ADAPTADOR_AUSENTE: $adapter" >&2; exit 3; }

# Alvos reais do repositório, na mesma ordem que plan-install.sh usa. Assumir
# "src modules" media o diretório errado e ainda assim saía 0: o grafo não era
# cruzado e a dimensão do baseline voltava vazia — verde sem ter medido.
alvos=()
for parent in modules packages apps libs services src; do
  [[ -d "$root/$parent" ]] && { alvos+=("$parent"); break; }
done
if [[ ${#alvos[@]} -eq 0 ]]; then
  echo "SEM_ALVO: nenhum diretório de código reconhecido (modules, packages, apps, libs, services, src)." >&2
  echo "Isto NÃO é verde: o grafo não foi medido." >&2
  exit 3
fi

# Config do projeto manda. Sem ela, uma mínima e descartável só para dimensionar
# — descritiva, nunca comparada a template (C6 → R7).
cfg=""
for f in .dependency-cruiser.js .dependency-cruiser.cjs .dependency-cruiser.mjs .dependency-cruiser.json; do
  [[ -e "$root/$f" ]] && { cfg="$f"; break; }
done
# A config de sondagem vive FORA do repositório: o audit é read-only, e escrever
# no repositório alheio para apagar depois não é read-only.
tmp=""
if [[ -z "$cfg" ]]; then
  echo "SEM_CONFIG: regra mínima (ciclo e órfão) só para dimensionar o baseline" >&2
  tmp="$(mktemp -t harness-audit-XXXXXX.cjs)"
  trap 'rm -f "$tmp"' EXIT
  "$adapter" generate-config "$root" "$(IFS=,; echo "${alvos[*]}")" > "$tmp" 2>/dev/null \
    || { echo "NAO_MEDIDO: falha ao gerar config de sondagem." >&2; exit 3; }
  cfg="$tmp"
else
  echo "CONFIG_EXISTENTE: $cfg" >&2
fi

bruto=$("$adapter" run "$root" "$cfg" "${alvos[@]}"); rc=$?

# O adaptador sai 3 quando cruzou zero módulo ou não produziu JSON. Repassar o
# verde nesse caso criaria a sensação de cobertura (INTENT §11, fracasso nº 5).
if [[ $rc -ne 0 ]]; then
  echo "NAO_MEDIDO: o adaptador não cruzou o grafo (código $rc)." >&2
  echo "A dimensão do baseline é desconhecida. NÃO trate como verde." >&2
  exit 3
fi

viol=$("$adapter" normalize <<<"$bruto") || { echo "NAO_MEDIDO: normalize falhou." >&2; exit 3; }

jq -n \
  --argjson alvos "$(printf '%s\n' "${alvos[@]}" | jq -R . | jq -s .)" \
  --argjson viol "$viol" \
  '{
     alvos: $alvos,
     violacoes: ($viol | length),
     por_regra: ($viol | group_by(.regra) | map({(.[0].regra): length}) | add // {}),
     catraca_obrigatoria: (($viol | length) > 0)
   }'
