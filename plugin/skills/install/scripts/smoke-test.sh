#!/usr/bin/env bash
# V9 → R3: gate que nunca reprovou não é gate.
#
# Planta uma violação de propósito, confirma que o gate falha, e remove. Os
# arquivos são criados e apagados dentro desta execução, nunca commitados — é
# a única forma de provar um gate sem confiar em inspeção.
#
# São dois gates e duas provas. A de tamanho não depende de adaptador: numa
# stack sem gate de fronteira, o teste de fumaça continua provando algo, e o
# exit 3 passa a significar "nenhum dos dois pôde ser provado".
#
#   smoke-test.sh <repo>
#
# Saída: 0 os gates disponíveis reprovaram · 1 algum não reprovou · 3 nenhum existe
set -uo pipefail
root="$(cd "${1:?uso: smoke-test.sh <repo>}" && pwd)"
cfg="$root/.harness/harness.json"
[[ -f "$cfg" ]] || { echo "smoke: harness não instalado em $root." >&2; exit 1; }

provados=0; falhou=0; pulados=0

# ---------------------------------------------------------------------------
# 1. Gate de tamanho — arquivo acima do teto
# ---------------------------------------------------------------------------
gate_size="$root/.harness/gate-size.sh"
teto=$(jq -r '.size.ceiling // empty' "$cfg")
if [[ -x "$gate_size" && -n "$teto" ]]; then
  alvo=$(jq -r '.size.targets[0] // "."' "$cfg")
  ext=$(jq -r '.size.extensions[0] // "js"' "$cfg")
  dir="$root/$alvo/__harness_smoke_size__"
  if [[ -e "$dir" ]]; then
    echo "smoke: $dir já existe. Remova antes de rodar." >&2; exit 1
  fi
  limpar_sz() { rm -rf "$dir"; }
  trap limpar_sz EXIT INT TERM
  mkdir -p "$dir"
  # Uma linha a mais que o teto: prova o limite, e não um valor folgado que
  # passaria mesmo se a comparação estivesse com o sinal trocado.
  {
    echo "// violação de tamanho plantada por harness:install — removida ao fim"
    for ((i = 1; i <= teto; i++)); do echo "const linha$i = $i;"; done
  } > "$dir/gordo.$ext"
  "$gate_size" >/dev/null 2>&1; rc_com=$?
  limpar_sz; trap - EXIT INT TERM
  "$gate_size" >/dev/null 2>&1; rc_sem=$?
  if [[ $rc_com -eq 1 && $rc_sem -eq 0 ]]; then
    echo "V9 OK (tamanho) — reprovou arquivo de $((teto + 1)) linhas com teto $teto, e voltou a passar."
    provados=$((provados + 1))
  else
    echo "V9 FALHOU (tamanho) — com violação: $rc_com (esperado 1); sem: $rc_sem (esperado 0)." >&2
    falhou=$((falhou + 1))
  fi
else
  echo "sem prova de tamanho: gate-size.sh ou .size.ceiling ausente." >&2
  pulados=$((pulados + 1))
fi

# ---------------------------------------------------------------------------
# 2. Gate de fronteira — ciclo de import
# ---------------------------------------------------------------------------
gate_bnd="$root/.harness/gate-boundaries.sh"
adapter=$(jq -r '.boundary.adapter // empty' "$cfg")
if [[ -x "$gate_bnd" && -n "$adapter" ]]; then
  alvo=$(jq -r '.boundary.targets[0] // "."' "$cfg")
  ext=js; [[ -f "$root/tsconfig.json" ]] && ext=ts
  dir="$root/$alvo/__harness_smoke__"
  if [[ -e "$dir" ]]; then
    echo "smoke: $dir já existe. Remova antes de rodar." >&2; exit 1
  fi
  limpar_bnd() { rm -rf "$dir"; }
  trap limpar_bnd EXIT INT TERM
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
  "$gate_bnd" >/dev/null 2>&1; rc_com=$?
  limpar_bnd; trap - EXIT INT TERM
  "$gate_bnd" >/dev/null 2>&1; rc_sem=$?
  if [[ $rc_com -eq 1 && $rc_sem -eq 0 ]]; then
    echo "V9 OK (fronteira) — reprovou o ciclo plantado e voltou a passar depois de removido."
    provados=$((provados + 1))
  else
    echo "V9 FALHOU (fronteira) — com violação: $rc_com (esperado 1); sem: $rc_sem (esperado 0)." >&2
    falhou=$((falhou + 1))
  fi
else
  echo "SEM TESTE DE FUMAÇA DE FRONTEIRA: não há gate de fronteira nesta stack (D4)." >&2
  pulados=$((pulados + 1))
fi

# ---------------------------------------------------------------------------
if [[ $falhou -gt 0 ]]; then
  echo >&2
  echo "Um gate que não reprova violação plantada não é gate. NÃO reporte a" >&2
  echo "instalação como concluída: investigue a configuração antes." >&2
  exit 1
fi
if [[ $provados -eq 0 ]]; then
  echo "SEM TESTE DE FUMAÇA: nenhum gate estrutural pôde ser provado ($pulados pulado(s))." >&2
  exit 3
fi
echo "$provados de $((provados + pulados)) gate(s) estrutural(is) provado(s)."
exit 0
