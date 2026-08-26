#!/usr/bin/env bash
# Planeja a instalação. READ-ONLY: não escreve um byte no repositório alvo.
#
# É o "mostre o que vai escrever e espere meu ok". A skill nunca chama
# gen-config.sh sem antes exibir a saída daqui.
#
#   plan-install.sh <repo>  → JSON
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
detect="$here/../../audit/scripts/detect-stack.sh"
root="${1:-.}"
root="$(cd "$root" 2>/dev/null && pwd)" || { echo "repo inexistente: ${1:-.}" >&2; exit 1; }

# Detecção vem do harness:audit — uma implementação só (não reimplementar).
if [[ -x "$detect" ]]; then
  stackjson=$("$detect" "$root")
else
  echo "plan-install: $detect ausente; a detecção é do harness:audit." >&2
  exit 1
fi
stack=$(jq -r '.stack' <<<"$stackjson")
adapter_raw=$(jq -r '.boundary_adapter' <<<"$stackjson")

FIND_PRUNE=( -name node_modules -o -name .git -o -name vendor -o -name dist -o -name build -o -name .venv -o -name __pycache__ )
srcfiles() {
  find "$root" \( "${FIND_PRUNE[@]}" \) -prune -o \
    -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' \
               -o -name '*.py' -o -name '*.go' -o -name '*.java' -o -name '*.kt' -o -name '*.rb' \
               -o -name '*.rs' -o -name '*.php' -o -name '*.cs' \) -print 2>/dev/null
}
n_src=$(srcfiles | wc -l | tr -d ' ')

# ---------------------------------------------------------------- modo
# Modo B (scaffold) só quando NÃO há código-fonte. Havendo código, é modo A por
# definição — e aí vale integralmente a fronteira de HARNESS.md §1: instalar
# harness não toca código-fonte.
if [[ $n_src -eq 0 ]]; then modo="scaffold"; else modo="retrofit"; fi

# ---------------------------------------------------- merece harness?
# Nem todo repositório merece. Script de uso único e protótipo descartável
# pagam a cerimônia e não recebem nada (PLAN.md §7, eval negativo).
razoes=(); merece=true
n_test=$(find "$root" \( "${FIND_PRUNE[@]}" \) -prune -o \
  -type f \( -name '*test*' -o -name '*spec*' -o -name 'test_*' \) -print 2>/dev/null | wc -l | tr -d ' ')
has_ci=$(jq -r '.ci' <<<"$stackjson")
# Só conta commits se $root for a raiz de um repositório — senão estaríamos
# lendo o histórico do repositório de cima e reportando número falso.
n_commits=0
[[ "$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" == "$root" ]] \
  && n_commits=$(git -C "$root" rev-list --count HEAD 2>/dev/null || echo 0)
base=$(basename "$root")

if [[ $modo == retrofit && $n_src -le 3 && $n_test -eq 0 && $has_ci == false ]]; then
  merece=false
  razoes+=("$n_src arquivo(s) de código, nenhum teste, nenhum CI — cabe inteiro em um contexto")
fi
if [[ "$base" =~ (spike|poc|proto|prototipo|prototype|scratch|sandbox|throwaway|descartavel|rascunho|tmp|temp)([-_.]|$) ]]; then
  merece=false
  razoes+=("o nome do repositório ('$base') anuncia trabalho descartável")
fi
if [[ $modo == retrofit && $n_src -eq 1 ]]; then
  merece=false
  razoes+=("um único arquivo de código: harness custaria mais que o artefato")
fi
if [[ "$merece" == true ]]; then
  if [[ $modo == scaffold ]]; then
    razoes+=("repositório novo: o harness nasce junto com o código, que é quando custa menos")
  else
    razoes+=("$n_src arquivo(s) de código, $n_test de teste, CI=$has_ci — volume justifica a cerimônia")
  fi
fi

# ------------------------------------------------------------- módulos
# C6/P7 → R7: os nomes vêm do projeto. Nunca renomeamos para domain/data, nunca
# comparamos com o template.
modulos=(); alvos=()
for parent in modules packages apps libs services src; do
  [[ -d "$root/$parent" ]] || continue
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    find "$d" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.py' \) \
      -print -quit 2>/dev/null | grep -q . && modulos+=("${d#"$root"/}")
  done < <(find "$root/$parent" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  [[ ${#modulos[@]} -gt 0 ]] && { alvos+=("$parent"); break; }
done
if [[ ${#modulos[@]} -eq 0 && -d "$root/src" ]]; then modulos+=("src"); alvos+=("src"); fi
[[ ${#alvos[@]} -eq 0 && $modo == retrofit ]] && alvos+=(".")

# ------------------------------------------------------ gates que passam hoje
# Só entra no gate o que já passa. Ligar gate que reprova trabalho legítimo é o
# modo de fracasso nº 1 do INTENT — e um gate desligado é pior que nenhum.
gate_status() {  # $1 = nome do script npm
  local nome="$1" cmd=""
  [[ -f "$root/package.json" ]] || { echo "ausente|"; return; }
  cmd=$(jq -r --arg n "$nome" '.scripts[$n] // empty' "$root/package.json" 2>/dev/null)
  [[ -n "$cmd" ]] || { echo "ausente|"; return; }
  # Script que corrige escreve em disco: não executamos para descobrir (V6).
  if grep -qE '(--fix|--write)' <<<"$cmd"; then echo "escreve|$nome"; return; fi
  local pm; pm=$(jq -r '.package_manager' <<<"$stackjson")
  [[ "$pm" == unknown ]] && pm=npm
  local run="$pm run $nome"
  if (cd "$root" && eval "$run" >/dev/null 2>&1); then echo "verde|$run"; else echo "vermelho|$run"; fi
}
IFS='|' read -r lint_st lint_cmd <<<"$(gate_status lint)"
IFS='|' read -r tc_st tc_cmd <<<"$(gate_status typecheck)"

# Formatador: só o que o repositório já escolheu.
formatter=""
if [[ -f "$root/package.json" ]] && jq -e '.devDependencies.prettier // .dependencies.prettier' "$root/package.json" >/dev/null 2>&1; then
  formatter="npx --no-install prettier --write"
fi

# --------------------------------------------------- catraca de tamanho
# O teto é o mesmo para todo mundo; o que varia é quanto do repositório já
# passou dele. Esse número aparece no plano ANTES de qualquer escrita, porque é
# ele que a pessoa precisa ver para decidir (R10): 3 arquivos acima do teto é
# uma tarde de trabalho, 300 é uma decisão de roadmap — e nos dois casos a
# catraca congela e para a decadência hoje (V10 → R4,R7).
SIZE_TETO=400
SIZE_EXT=(ts tsx mts cts js jsx mjs cjs py go java kt rb rs php cs sh)
SIZE_EXCL=('*.d.ts' '*.generated.*' '*.min.js' '*.pb.go' '*_pb2.py' '*.snap' '*-lock.json')
n_grandes=0; maior_arq=""; maior_n=0
while IFS= read -r f; do
  base="${f##*/}"; pula=0
  for p in "${SIZE_EXCL[@]}"; do [[ "$base" == $p ]] && { pula=1; break; }; done
  [[ $pula -eq 1 ]] && continue
  n=$(awk 'END{print NR+0}' "$f" 2>/dev/null) || continue
  if [[ "$n" -gt $SIZE_TETO ]]; then
    n_grandes=$((n_grandes+1))
    [[ "$n" -gt "$maior_n" ]] && { maior_n=$n; maior_arq="${f#"$root"/}"; }
  fi
done < <(srcfiles)

# ------------------------------------------------------------- adaptador
adapter=null; adapter_reason=""; bcfg=""
case "$adapter_raw" in
  dependency-cruiser) adapter='"node"'; bcfg=".dependency-cruiser.cjs"
    [[ -f "$root/.dependency-cruiser.js" ]] && bcfg=".dependency-cruiser.js" ;;
  unsupported:*) adapter_reason="stack $stack: gate de fronteira não implementado (${adapter_raw#unsupported:})" ;;
  *) adapter_reason="stack $stack: nenhum adaptador de fronteira conhecido" ;;
esac

# ------------------------------------------------------------ manifesto
# Status por arquivo. 'manual' nunca é sobrescrito (D3 → R10).
st() {
  local p="$root/$1"
  if [[ ! -e "$p" ]]; then echo novo
  elif grep -q 'harness-generated:' "$p" 2>/dev/null; then echo gerado
  else echo manual; fi
}
manifesto=$(jq -n '[]')
add() { manifesto=$(jq -n --argjson m "$manifesto" --arg c "$1" --arg f "$2" --arg s "$(st "$1")" \
          '$m + [{caminho:$c, fase:$f, status:$s}]'); }

if [[ $modo == scaffold ]]; then
  add "CLAUDE.md" scaffold; add ".dependency-cruiser.js" scaffold
  add "eslint.config.js" scaffold
  add ".claude/settings.json" scaffold; add "modules/" scaffold
  add "ops/" scaffold; add "docs/adr/" scaffold
  add ".harness/harness.json" scaffold
else
  for f in .claude/hooks/on-edit.sh .claude/hooks/verify.sh .claude/hooks/guard-prod.sh \
           .claude/hooks/cleanup.sh .claude/commands/plan.md .claude/commands/review.md \
           .claude/commands/ship.md .claude/settings.json .harness/harness.json \
           .harness/gate-boundaries.sh .harness/gate-size.sh; do add "$f" 1; done
  [[ $adapter != null ]] && { add ".harness/adapters/node.sh" 1; add "$bcfg" 1; }
  [[ $adapter != null ]] && add ".harness/baseline.json" 2
  add ".harness/baseline-size.json" 2
  add "CLAUDE.md" 3
  for m in "${modulos[@]}"; do add "$m/CLAUDE.md" 3; done
fi

# ------------------------------------------------------------ pendências
pend=()
[[ -f "$root/ops/investigate.sh" ]] || pend+=("A3 → R5: não há script de investigação read-only. O harness instala sem ele; escreva um para a sua stack e o gate de conformidade fecha.")
[[ $adapter == null ]] && pend+=("D4 → R10: $adapter_reason. Todo o resto instala; o gate de fronteira NÃO fica disponível. A catraca de TAMANHO não depende de adaptador e fica ativa mesmo assim.")
[[ $n_grandes -gt 0 ]] && pend+=("V10 → R4: $n_grandes arquivo(s) já passam de $SIZE_TETO linhas (o maior: $maior_arq, $maior_n). Entram no baseline e param de crescer; reduzi-los é trabalho à parte, nunca requisito da instalação.")
[[ "$lint_st" == vermelho ]] && pend+=("lint reprova hoje ($lint_cmd). Fica FORA do gate de turno — ligá-lo reprovaria trabalho legítimo. Verde o lint e ligue depois.")
[[ "$tc_st" == vermelho ]] && pend+=("typecheck reprova hoje ($tc_cmd). Fica FORA do gate de turno pelo mesmo motivo.")
[[ "$lint_st" == escreve ]] && pend+=("o script 'lint' corrige em disco (--fix/--write). Não entra no gate em lote (V6 → R2).")
[[ "$tc_st" == escreve ]] && pend+=("o script 'typecheck' escreve em disco. Não entra no gate em lote (V6 → R2).")

jq -n \
  --argjson stack "$stackjson" \
  --arg modo "$modo" \
  --argjson merece "$merece" \
  --argjson razoes "$(printf '%s\n' "${razoes[@]}" | jq -R . | jq -s .)" \
  --argjson modulos "$(printf '%s\n' "${modulos[@]+"${modulos[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" \
  --argjson alvos "$(printf '%s\n' "${alvos[@]+"${alvos[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" \
  --argjson adapter "$adapter" \
  --arg adapter_reason "$adapter_reason" \
  --arg bcfg "$bcfg" \
  --arg lint_st "$lint_st" --arg lint_cmd "$lint_cmd" \
  --arg tc_st "$tc_st" --arg tc_cmd "$tc_cmd" \
  --arg formatter "$formatter" \
  --argjson size_teto "$SIZE_TETO" \
  --argjson size_ext "$(printf '%s\n' "${SIZE_EXT[@]}" | jq -R . | jq -s .)" \
  --argjson size_excl "$(printf '%s\n' "${SIZE_EXCL[@]}" | jq -R . | jq -s .)" \
  --argjson n_grandes "$n_grandes" \
  --arg maior_arq "$maior_arq" --argjson maior_n "$maior_n" \
  --argjson n_src "$n_src" --argjson n_test "$n_test" --argjson n_commits "${n_commits:-0}" \
  --argjson manifesto "$manifesto" \
  --argjson pendencias "$(printf '%s\n' "${pend[@]+"${pend[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" \
  '{
     modo: $modo,
     merece_harness: { veredito: $merece, razoes: $razoes },
     repo: ($stack + {arquivos_de_codigo: $n_src, arquivos_de_teste: $n_test, commits: $n_commits}),
     modulos: $modulos,
     boundary: { adapter: $adapter, reason: $adapter_reason, config: $bcfg, targets: $alvos },
     gates_hoje: { lint: {estado:$lint_st, comando:$lint_cmd}, typecheck: {estado:$tc_st, comando:$tc_cmd} },
     formatter: $formatter,
     size: { ceiling: $size_teto, targets: $alvos, extensions: $size_ext,
             exclude: $size_excl,
             acima_do_teto: $n_grandes,
             maior: (if $maior_arq == "" then null
                     else {arquivo: $maior_arq, linhas: $maior_n} end) },
     manifesto: $manifesto,
     pendencias: $pendencias
   }'
