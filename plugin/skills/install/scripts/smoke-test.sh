#!/usr/bin/env bash
# V9 → R3: gate que nunca reprovou não é gate.
#
# Planta uma violação de propósito, confirma que o gate falha, e remove. Os
# arquivos são criados e apagados dentro desta execução, nunca commitados — é
# a única forma de provar a fronteira sem confiar em inspeção.
#
#   smoke-test.sh <repo>
#
# Saída: 0 o gate reprovou (e voltou a passar) · 1 o gate NÃO reprovou · 3 sem adaptador
set -uo pipefail
root="$(cd "${1:?uso: smoke-test.sh <repo>}" && pwd)"
cfg="$root/.harness/harness.json"
gate="$root/.harness/gate-boundaries.sh"
[[ -f "$cfg" && -x "$gate" ]] || { echo "smoke: harness não instalado em $root." >&2; exit 1; }

adapter=$(jq -r '.boundary.adapter // empty' "$cfg")
if [[ -z "$adapter" ]]; then
  echo "SEM TESTE DE FUMAÇA: não há gate de fronteira nesta stack (D4)." >&2
  echo "Os demais gates continuam valendo; este não pode ser provado." >&2
  exit 3
fi

alvo=$(jq -r '.boundary.targets[0] // "."' "$cfg")
dir="$root/$alvo/__harness_smoke__"
ext=js; [[ -f "$root/tsconfig.json" ]] && ext=ts

# Nunca escrever por cima de algo que já existe — nem para testar.
[[ -e "$dir" ]] && { echo "smoke: $dir já existe. Remova antes de rodar." >&2; exit 1; }

limpar() { rm -rf "$dir"; }
trap limpar EXIT INT TERM

mkdir -p "$dir"
cat > "$dir/a.$ext" <<EOF
// violação plantada por harness:install — removida ao fim do teste
import { b } from "./b.$ext";
export const a = () => b();
EOF
cat > "$dir/b.$ext" <<EOF
import { a } from "./a.$ext";
export const b = () => a();
EOF
# dependency-cruiser resolve import sem extensão em TS
if [[ $ext == ts ]]; then
  sed -i 's|/b\.ts"|/b"|; s|/a\.ts"|/a"|' "$dir/a.$ext" "$dir/b.$ext"
fi

"$gate" >/dev/null 2>&1; rc_com=$?
limpar; trap - EXIT INT TERM
"$gate" >/dev/null 2>&1; rc_sem=$?

if [[ $rc_com -eq 1 && $rc_sem -eq 0 ]]; then
  echo "V9 OK — o gate reprovou a violação plantada e voltou a passar depois de removida."
  exit 0
fi
echo "V9 FALHOU — gate com violação: $rc_com (esperado 1); sem violação: $rc_sem (esperado 0)." >&2
if [[ $rc_com -ne 1 ]]; then
  echo "Um gate que não reprova violação plantada não é gate. NÃO reporte a" >&2
  echo "instalação como concluída: investigue a config de fronteira antes." >&2
fi
exit 1
