#!/usr/bin/env bash
# Modo B — projeto novo. Copia o template, renomeia os módulos para o domínio
# real e instala a mesma maquinaria de catraca do modo A.
#
#   scaffold.sh <repo> --owner "<nome>" [--ceiling <modo>]
#               [--modules "shared=comum,domain=faturamento,..."]
#
# Só roda em repositório SEM código-fonte. Havendo código, é modo A — e aí vale
# a fronteira de HARNESS.md §1: instalar harness não toca código-fonte.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="0.2.6"
tpl="$here/../assets/template"

repo=""; owner=""; ceiling="supervisionado"; mapa=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner) owner="$2"; shift 2 ;;
    --ceiling) ceiling="$2"; shift 2 ;;
    --modules) mapa="$2"; shift 2 ;;
    -*) echo "argumento desconhecido: $1" >&2; exit 64 ;;
    *) repo="$1"; shift ;;
  esac
done
root="$(cd "${repo:?uso: scaffold.sh <repo> --owner ...}" && pwd)"

# D6 → R6: o dono é obrigatório e não tem default.
[[ -n "$owner" ]] || { echo "FALTA O DONO (D6 → R6). Rode com --owner \"Nome <email>\"." >&2; exit 2; }
case "$ceiling" in assistido|supervisionado|autonomo) ;;
  *) echo "teto inválido: $ceiling" >&2; exit 64 ;; esac

n_src=$(find "$root" \( -name node_modules -o -name .git \) -prune -o \
  -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.py' -o -name '*.go' \) -print 2>/dev/null | wc -l)
if [[ "$n_src" -gt 0 ]]; then
  echo "RECUSADO: $root já tem $n_src arquivo(s) de código." >&2
  echo "Scaffold escreveria por cima de trabalho existente. Isto é modo A —" >&2
  echo "use plan-install.sh + gen-config.sh, que não tocam código-fonte." >&2
  exit 1
fi

# --- cópia -----------------------------------------------------------------
copiados=(); pulados=()
while IFS= read -r rel; do
  if [[ -e "$root/$rel" ]]; then pulados+=("$rel"); continue; fi
  mkdir -p "$root/$(dirname "$rel")"
  cp -a "$tpl/$rel" "$root/$rel"
  copiados+=("$rel")
done < <(cd "$tpl" && find . -type f -printf '%P\n' | sort)

# --- renomeação dos módulos ------------------------------------------------
# C6 → R7: os nomes vêm do domínio real. É o passo que evita que o projeto
# herde o vocabulário do template e passe a vida com módulo chamado "domain".
renomeados=(); residuo="[]"
if [[ -n "$mapa" ]]; then
  IFS=',' read -ra pares <<<"$mapa"
  for par in "${pares[@]}"; do
    old="${par%%=*}"; new="${par#*=}"
    [[ -n "$old" && -n "$new" && "$old" != "$new" ]] || continue
    [[ -d "$root/modules/$old" ]] || { echo "aviso: modules/$old não existe no template; ignorado." >&2; continue; }
    mv "$root/modules/$old" "$root/modules/$new"
    # Padrões ancorados: caminho, import relativo, nome entre crases, subpasta.
    while IFS= read -r f; do
      sed -i -e "s|modules/$old\\b|modules/$new|g" \
             -e "s|\\.\\./\\.\\./$old/|../../$new/|g" \
             -e "s|\`$old\`|\`$new\`|g" \
             -e "s|\\b$old/\\(ports\\|contracts\\|src\\)\\b|$new/\\1|g" "$f"
      # Alternação de regex na config de fronteira: ^modules/(domain|data|api).
      # Sem esta passada a regra sobrevive apontando para módulo que não existe
      # mais — aparência de fronteira sem fronteira, o pior dos dois mundos.
      sed -i -e "/modules\/(/ s|\\([(|]\\)$old\\([|)]\\)|\\1$new\\2|g" "$f"
      # Prosa dos arquivos que NÓS enviamos: no template estas cinco palavras
      # só aparecem como nome de módulo, então a varredura larga é segura aqui
      # e não seria em repositório alheio. Instrução com nome velho é instrução
      # falsa (C4 → R1), e o CLAUDE.md é o primeiro lugar onde o agente olha.
      case "$f" in *.md) sed -i -e "s|\\b$old\\b|$new|g" "$f" ;; esac
    done < <(grep -rlI "$old" "$root" --exclude-dir=.git --exclude-dir=node_modules 2>/dev/null)
    renomeados+=("modules/$old → modules/$new")
  done
  # O que sobrou é prosa: o script não adivinha, a skill resolve.
  residuo=$(for par in "${pares[@]}"; do
      old="${par%%=*}"; new="${par#*=}"
      [[ "$old" != "$new" ]] || continue
      grep -rnI "\b$old\b" "$root" --exclude-dir=.git --exclude-dir=node_modules 2>/dev/null \
        | sed "s|^$root/||" | head -20
    done | jq -R . | jq -s 'map(select(length>0)) | unique')
fi

# --- maquinaria de catraca -------------------------------------------------
# Um mecanismo só nos dois modos: o gate é script, o hook é só o gatilho (P8).
# Por isso o verify.sh autocontido do template é trocado pelo dirigido por
# config — senão o repositório teria dois gates com respostas diferentes.
mkdir -p "$root/.harness/adapters"
for pair in "$here/../assets/gate/boundaries.sh:.harness/gate-boundaries.sh" \
            "$here/../assets/gate/size.sh:.harness/gate-size.sh" \
            "$here/adapters/node.sh:.harness/adapters/node.sh" \
            "$here/../assets/retrofit/hooks/verify.sh:.claude/hooks/verify.sh"; do
  src="${pair%%:*}"; dst="${pair#*:}"
  grep -v 'harness-generated:' "$src" | sed "s/__VERSION__/$VERSION/g" > "$root/$dst"
  chmod +x "$root/$dst"
done
echo '[]' > "$root/.harness/baseline.json"
echo '{}' > "$root/.harness/baseline-size.json"

bcfg=".dependency-cruiser.js"
# Em projeto novo o baseline nasce vazio, e aí o teto de tamanho age como
# limite absoluto — que é o que se pode exigir de greenfield sem custo nenhum.
# Em legado o mesmo número vira catraca. Um só mecanismo, dois regimes.
jq -n --arg v "$VERSION" --arg o "$owner" --arg c "$ceiling" --arg bc "$bcfg" '
  { harness_version: $v, owner: $o, autonomy_ceiling: $c, anti_loop_tries: 3,
    formatter: "npx --no-install prettier --write",
    boundary: { adapter: "node", config: $bc, targets: ["modules"] },
    size: { ceiling: 400, targets: ["modules"],
            extensions: ["ts","tsx","mts","cts","js","jsx","mjs","cjs"],
            exclude: ["*.d.ts","*.generated.*","*.min.js","*.snap"] },
    gates: { boundaries: true, size: true,
             lint: "pnpm lint", typecheck: "pnpm typecheck" } }' \
  > "$root/.harness/harness.json"

# A6/A8 → R5: teto sustentado por permissão. O template já traz o allow/deny da
# stack; acrescentamos o gate e, se o teto for mais restritivo, mais negações.
if [[ -f "$root/.claude/settings.json" ]]; then
  extra='[]'
  [[ "$ceiling" == assistido ]] && extra='["Bash(git commit*)","Bash(git push*)"]'
  jq --argjson x "$extra" '
    .permissions.allow = ((.permissions.allow // [])
      + ["Bash(./.harness/gate-boundaries.sh:*)","Bash(./.harness/gate-size.sh:*)"] | unique)
    | .permissions.deny = ((.permissions.deny // []) + $x | unique)
    | ._harness = {generated: "'"$VERSION"'"}' \
    "$root/.claude/settings.json" > "$root/.claude/settings.json.tmp" \
    && mv "$root/.claude/settings.json.tmp" "$root/.claude/settings.json" \
    || { rm -f "$root/.claude/settings.json.tmp"
         echo "AVISO: não foi possível acrescentar as permissões do gate a" >&2
         echo ".claude/settings.json. O arquivo do template ficou como estava —" >&2
         echo "confira permissions.allow à mão antes de usar (A8 → R5)." >&2; }
fi

jq -n --argjson c "$(printf '%s\n' "${copiados[@]+"${copiados[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" \
      --argjson p "$(printf '%s\n' "${pulados[@]+"${pulados[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" \
      --argjson r "$(printf '%s\n' "${renomeados[@]+"${renomeados[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" \
      --argjson res "$residuo" --arg v "$VERSION" '
  { modo: "scaffold", versao: $v, copiados: ($c | length), pulados: $p, renomeados: $r,
    residuo_de_prosa: $res,
    proximo_passo: "rode smoke-test.sh: gate que nunca reprovou não é gate (V9 → R3)" }'
