#!/usr/bin/env bash
# Gera a configuração do harness. Escreve — mas só nos caminhos que HARNESS.md
# §1 autoriza: CLAUDE.md · .claude/** · config de verificação · docs/adr/** ·
# ops/**  (e .harness/**, que é config de verificação). Nunca código-fonte.
#
#   gen-config.sh <repo> --plan <plan.json> --owner "<nome>" [--ceiling <modo>] --fase <1|3>
#
# D3 → R10: idempotente. Todo arquivo gerado leva marca de versão e hash do
# próprio conteúdo. Arquivo editado à mão é PULADO, nunca sobrescrito.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="0.2.6"

repo=""; plan=""; owner=""; ceiling="supervisionado"; fase=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan) plan="$2"; shift 2 ;;
    --owner) owner="$2"; shift 2 ;;
    --ceiling) ceiling="$2"; shift 2 ;;
    --fase) fase="$2"; shift 2 ;;
    -*) echo "argumento desconhecido: $1" >&2; exit 64 ;;
    *) repo="$1"; shift ;;
  esac
done
[[ -n "$repo" && -n "$plan" && -n "$fase" ]] || { echo "uso: gen-config.sh <repo> --plan <json> --owner <nome> --fase <1|3>" >&2; exit 64; }
root="$(cd "$repo" && pwd)"
[[ -f "$plan" ]] || { echo "plano ausente: $plan" >&2; exit 1; }

# D6 → R6: o dono é o único parâmetro sem default. Sem ele, nenhum modo de
# fracasso tem quem reaja e o critério de três meses fica sem observador.
if [[ -z "$owner" ]]; then
  echo "FALTA O DONO. É obrigatório (D6 → R6) e não tem default." >&2
  echo "Rode de novo com --owner \"Nome <email>\"." >&2
  exit 2
fi
case "$ceiling" in assistido|supervisionado|autonomo) ;;
  *) echo "teto inválido: $ceiling (assistido|supervisionado|autonomo)" >&2; exit 64 ;; esac

escritos=(); pulados=()

# --- marca de versão -------------------------------------------------------
# O hash é do corpo sem a linha de marca. Se o hash do arquivo em disco bate
# com o registrado, ninguém encostou: pode regerar. Se não bate, foi editado.
body_sha() { grep -v 'harness-generated:' "$1" | sha256sum | cut -c1-16; }

write_marked() {  # write_marked <caminho-relativo> <abre-comentario> [fecha]
  local rel="$1" ab="$2" fe="${3:-}" dest="$root/$1" body sha marca first rest
  body="$(cat)"
  if [[ -e "$dest" ]]; then
    if ! grep -q 'harness-generated:' "$dest"; then
      pulados+=("$rel — existe e não é nosso; nunca sobrescrevemos edição manual")
      return 0
    fi
    local rec cur; rec=$(grep -o 'sha=[0-9a-f]*' "$dest" | head -1 | cut -d= -f2)
    cur=$(body_sha "$dest")
    if [[ -n "$rec" && "$rec" != "$cur" ]]; then
      pulados+=("$rel — gerado por nós e editado depois; customização preservada")
      return 0
    fi
  fi
  sha=$(printf '%s\n' "$body" | sha256sum | cut -c1-16)
  marca="$ab harness-generated: $VERSION sha=$sha${fe:+ $fe}"
  mkdir -p "$(dirname "$dest")"
  # A marca vai DEPOIS do shebang: shebang tem de ser a primeira linha do arquivo.
  first=$(head -1 <<<"$body")
  if [[ "$first" == '#!'* ]]; then
    rest=$(tail -n +2 <<<"$body")
    printf '%s\n%s\n%s\n' "$first" "$marca" "$rest" > "$dest"
  else
    printf '%s\n%s\n' "$marca" "$body" > "$dest"
  fi
  escritos+=("$rel")
}

copy_marked() {  # copy_marked <origem> <rel-destino> <abre> [fecha]
  # A marca do asset é removida aqui; write_marked põe a dele, com o hash certo.
  # Sem pipeline: pipeline roda write_marked em subshell e perde o relatório.
  local corpo; corpo=$(grep -v 'harness-generated:' "$1" | sed "s/__VERSION__/$VERSION/g")
  write_marked "$2" "$3" "${4:-}" <<<"$corpo"
  [[ -e "$root/$2" && "$2" == *.sh ]] && chmod +x "$root/$2"
  return 0
}

# --- dados do plano --------------------------------------------------------
adapter=$(jq -r '.boundary.adapter // empty' "$plan")
bcfg=$(jq -r '.boundary.config // empty' "$plan")
breason=$(jq -r '.boundary.reason // empty' "$plan")
formatter=$(jq -r '.formatter // empty' "$plan")
mapfile -t targets < <(jq -r '.boundary.targets[]?' "$plan")
mapfile -t modulos < <(jq -r '.modulos[]?' "$plan")
size_cfg=$(jq -c '.size // empty | del(.acima_do_teto, .maior)' "$plan")
lint_cmd=$(jq -r 'if .gates_hoje.lint.estado=="verde" then .gates_hoje.lint.comando else empty end' "$plan")
tc_cmd=$(jq -r 'if .gates_hoje.typecheck.estado=="verde" then .gates_hoje.typecheck.comando else empty end' "$plan")

# Dono e teto já registrados MANDAM sobre o que veio na linha de comando. Duas
# razões: idempotência (D3 → R10), e o fato de que trocar o dono ou elevar o
# teto tem de ser edição revisada do arquivo versionado, nunca efeito colateral
# de rodar a instalação de novo (A7 → R5).
if [[ -f "$root/.harness/harness.json" ]]; then
  prev=$(jq -r '.owner // empty' "$root/.harness/harness.json")
  [[ -n "$prev" ]] && owner="$prev"
  prev=$(jq -r '.autonomy_ceiling // empty' "$root/.harness/harness.json")
  [[ -n "$prev" ]] && ceiling="$prev"
fi

# ===========================================================================
# FASE 1 — hooks, permissões, comandos, dono, teto
# ===========================================================================
if [[ "$fase" == 1 ]]; then

  for h in on-edit verify guard-prod cleanup; do
    copy_marked "$here/../assets/retrofit/hooks/$h.sh" ".claude/hooks/$h.sh" "#"
  done
  mkdir -p "$root/.claude/commands"
  for c in plan review; do
    if [[ -e "$root/.claude/commands/$c.md" ]]; then
      pulados+=(".claude/commands/$c.md — já existe; comando do projeto manda")
    else
      cp "$here/../assets/retrofit/commands/$c.md" "$root/.claude/commands/$c.md"
      escritos+=(".claude/commands/$c.md")
    fi
  done

  # /ship só cita comando que EXISTE. C4 → R1 aplicada onde a instrução falsa
  # nasceria: um comando inventado aqui é obedecido com confiança.
  verificados=()
  [[ -n "$tc_cmd" ]] && verificados+=("$tc_cmd")
  [[ -n "$lint_cmd" ]] && verificados+=("$lint_cmd")
  [[ -n "$adapter" ]] && verificados+=(".harness/gate-boundaries.sh")
  [[ -n "$size_cfg" ]] && verificados+=(".harness/gate-size.sh")
  {
    echo "---"
    echo "description: Prepara o PR — verifica, resume, entrega"
    echo "---"
    if [[ ${#verificados[@]} -gt 0 ]]; then
      echo "1. Rode e exija verde:"
      for v in "${verificados[@]}"; do echo "   - \`$v\`"; done
    else
      echo "1. Este projeto ainda não tem comando de verificação verificado pelo"
      echo "   harness. Rode a suíte que o time usa e diga qual foi."
    fi
    cat <<'SHIP'
2. `git diff --stat` contra a branch base e confirme que só há arquivos da
   tarefa. Se tem arquivo fora do escopo, pare e me mostre.
3. Escreva a descrição do PR: o que muda, por quê, como testar, o que NÃO muda.
4. Se algum ADR foi necessário, confirme que está em `docs/adr/` e referenciado.

Não faça push nem abra o PR sem eu pedir.
SHIP
  } > "$root/.claude/commands/ship.md"
  escritos+=(".claude/commands/ship.md")

  # gate + adaptador entram no REPOSITÓRIO, não ficam no plugin: quem clona
  # recebe o mesmo comportamento sem ter a skill instalada (D1 → R8, D5 → R12).
  copy_marked "$here/../assets/gate/boundaries.sh" ".harness/gate-boundaries.sh" "#"
  # A catraca de tamanho não tem adaptador: não depende de ferramenta e vale em
  # qualquer linguagem (V10 → R12). Vai sempre, inclusive nas stacks onde o gate
  # de fronteira não existe.
  copy_marked "$here/../assets/gate/size.sh" ".harness/gate-size.sh" "#"
  if [[ -n "$adapter" ]]; then
    copy_marked "$here/adapters/$adapter.sh" ".harness/adapters/$adapter.sh" "#"
    if [[ ! -e "$root/$bcfg" ]]; then
      local_cfg=$("$here/adapters/$adapter.sh" generate-config "$root" "$(IFS=,; echo "${targets[*]}")" \
        | grep -v 'harness-generated:')
      write_marked "$bcfg" "//" <<<"$local_cfg"
    else
      pulados+=("$bcfg — já existe; a config de fronteira do projeto manda")
    fi
  fi

  # A6 → R5: teto declarado em arquivo versionado. A7: elevá-lo exige alterar
  # este arquivo com revisão, nunca uma flag de linha de comando.
  mkdir -p "$root/.harness"
  jq -n --arg v "$VERSION" --arg o "$owner" --arg c "$ceiling" \
        --arg a "$adapter" --arg bc "$bcfg" --arg br "$breason" \
        --argjson sz "${size_cfg:-null}" \
        --arg lint "$lint_cmd" --arg tc "$tc_cmd" --arg fmt "$formatter" \
        --argjson t "$(printf '%s\n' "${targets[@]+"${targets[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" '
    { harness_version: $v,
      owner: $o,
      autonomy_ceiling: $c,
      anti_loop_tries: 3,
      formatter: (if $fmt == "" then null else $fmt end),
      boundary: (if $a == "" then {adapter: null, reason: $br}
                 else {adapter: $a, config: $bc, targets: $t} end),
      size: $sz,
      gates: { boundaries: ($a != ""),
               size: ($sz != null),
               lint: (if $lint == "" then null else $lint end),
               typecheck: (if $tc == "" then null else $tc end) } }' \
    > "$root/.harness/harness.json"
  escritos+=(".harness/harness.json")

  # A2/A5/A8 → R5. O teto é sustentado por PERMISSÃO, nunca por hook: uma flag
  # de execução desliga hook. A9: o conjunto base é idêntico nos três modos —
  # teto mais baixo só ACRESCENTA negações, nunca remove (A7, monotonicidade).
  base_deny='["Read(./.env*)","Read(./**/.env*)","Read(./**/secrets/**)",
    "Bash(*deploy*prd*)","Bash(*deploy*prod*)","Bash(*deploy*production*)",
    "Bash(git push --force*)","Bash(git push -f*)",
    "Bash(aws * --profile prd*)","Bash(aws * --profile prod*)",
    "Bash(psql *prd*)","Bash(kubectl * --context *prod*)"]'
  extra_deny='[]'
  [[ "$ceiling" == assistido ]] && extra_deny='["Bash(git commit*)","Bash(git push*)"]'
  allow='["Bash(git diff:*)","Bash(git log:*)","Bash(git status:*)",
    "Bash(./.harness/gate-boundaries.sh:*)","Bash(./.harness/gate-size.sh:*)"]'
  [[ -f "$root/ops/investigate.sh" ]] && allow=$(jq -c '. + ["Bash(./ops/investigate.sh:*)"]' <<<"$allow")

  hookdef() { jq -n --arg e "$1" --arg m "$2" --arg c "$3" --argjson async "$4" --argjson to "$5" '
    { ($e): [ ( {hooks:[ ({type:"command", command:("${CLAUDE_PROJECT_DIR}/.claude/hooks/" + $c), timeout:$to}
        + (if $async then {async:true} else {} end)) ]} + (if $m=="" then {} else {matcher:$m} end) ) ] }'; }
  novo_settings=$(jq -n \
    --argjson allow "$allow" --argjson deny "$base_deny" --argjson extra "$extra_deny" \
    --argjson pre "$(hookdef PreToolUse Bash guard-prod.sh false 10)" \
    --argjson post "$(hookdef PostToolUse 'Edit|Write|NotebookEdit' on-edit.sh true 15)" \
    --argjson stop "$(hookdef Stop '' verify.sh false 240)" \
    --argjson end "$(hookdef SessionEnd '' cleanup.sh false 5)" \
    --arg v "$VERSION" '
      { _harness: {generated: $v},
        permissions: { allow: $allow, deny: ($deny + $extra) },
        hooks: ($pre + $post + $stop + $end) }')
  # Merge com regra por caminho, em arquivo próprio e testado
  # (./merge-settings.jq). SEM FALLBACK: se o merge não pode ser feito com
  # segurança, o arquivo não é tocado e a lacuna é relatada como pulo (D3 → R10).
  #
  # O que havia aqui era `expr || fallback`, e o `expr` tinha erro de tipo:
  # depois de `.[0] * .[1]` o contexto já é o objeto mesclado, e `.[0]` nele não
  # existe. Toda instalação caía no fallback `.[0] * .[1]`, que em array deixa o
  # lado direito SUBSTITUIR — um reinstall apagava as negações que o projeto
  # tinha escrito à mão, e ainda contava o arquivo como escrito e saía 0.
  set_json="$root/.claude/settings.json"
  mkdir -p "$root/.claude"
  guardar_proposta() { printf '%s\n' "$novo_settings" > "$root/.harness/settings.proposto.json"; }

  if [[ -f "$set_json" ]]; then
    if jq -n -f "$here/merge-settings.jq" \
         --slurpfile v "$set_json" \
         --slurpfile n <(printf '%s' "$novo_settings") > "$set_json.tmp" 2>/dev/null \
       && [[ -s "$set_json.tmp" ]]; then

      # Duas invariantes, verificadas contra o resultado e não contra a intenção.
      # A checagem é independente do merge de propósito: guarda que reusa a
      # lógica do que verifica esconde o próprio defeito.
      #
      # A7 → R5: nada que o projeto negou pode sair. Autonomia se restringe,
      # nunca se afrouxa.
      perdeu_deny=$(jq -n --slurpfile a "$set_json" --slurpfile b "$set_json.tmp" \
        '(($a[0].permissions.deny // []) - ($b[0].permissions.deny // [])) | length' 2>/dev/null || echo 1)
      # Hook do projeto sobrevive. O harness só escreve dentro de .claude/hooks/,
      # então todo comando FORA desse diretório é do projeto, por construção —
      # sem enumerar os nossos, que mudam de versão para versão.
      perdeu_hook=$(jq -n --slurpfile a "$set_json" --slurpfile b "$set_json.tmp" '
        def alheios: [ .. | objects | select(has("command")) | .command
                       | strings | select(test("/\\.claude/hooks/") | not) ];
        (($a[0] | alheios) - ($b[0] | alheios)) | length' 2>/dev/null || echo 1)

      if [[ "$perdeu_deny" == 0 && "$perdeu_hook" == 0 ]]; then
        mv "$set_json.tmp" "$set_json"
        escritos+=(".claude/settings.json (merge)")
      else
        rm -f "$set_json.tmp"; guardar_proposta
        pulados+=(".claude/settings.json — RECUSADO: o merge perderia $perdeu_deny negação(ões) e $perdeu_hook hook(s) do projeto. PERMISSÕES NÃO INSTALADAS (A2/A8 → R5): sem elas não há dupla trava de produção. Proposta em .harness/settings.proposto.json — compare à mão")
      fi
    else
      rm -f "$set_json.tmp"; guardar_proposta
      pulados+=(".claude/settings.json — não é JSON válido, ou o merge falhou. PERMISSÕES NÃO INSTALADAS (A2/A8 → R5). Proposta em .harness/settings.proposto.json — compare à mão")
    fi
  else
    # Passa pela MESMA função, contra `{}`. Escrever direto o $novo_settings aqui
    # produzia ordem de chave diferente da que o merge produz, e a segunda
    # instalação reescrevia o arquivo só por isso — idempotência quebrada por
    # formatação (D3 → R10).
    if jq -n -f "$here/merge-settings.jq" \
         --slurpfile v /dev/null \
         --slurpfile n <(printf '%s' "$novo_settings") > "$set_json" 2>/dev/null \
       && [[ -s "$set_json" ]]; then
      escritos+=(".claude/settings.json")
    else
      rm -f "$set_json"; guardar_proposta
      pulados+=(".claude/settings.json — o merge falhou na primeira escrita. PERMISSÕES NÃO INSTALADAS (A2/A8 → R5). Proposta em .harness/settings.proposto.json")
    fi
  fi
fi

# ===========================================================================
# FASE 3 — contexto: raiz enxuta + um CLAUDE.md por módulo EXISTENTE
# ===========================================================================
if [[ "$fase" == 3 ]]; then
  nome=$(basename "$root")
  stack=$(jq -r '.repo.stack' "$plan")

  # Grafo real, para descrever o que cada módulo HOJE importa. Descritivo,
  # nunca prescritivo (P7/C6 → R7): não comparamos com template nenhum.
  graph="{}"; graph_ok=0
  if [[ -n "$adapter" && -f "$root/$bcfg" && ${#targets[@]} -gt 0 ]]; then
    raw=$("$root/.harness/adapters/$adapter.sh" run "$root" "$bcfg" "${targets[@]}" 2>/dev/null) \
      && graph=$(jq --argjson mods "$(printf '%s\n' "${modulos[@]+"${modulos[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" '
        def owner($p): ($mods | map(select(. as $mod | $p | startswith($mod + "/"))) | first // null);
        [ .modules[]? | . as $m | ($m.dependencies // [])[]
          | { de: owner($m.source), para: owner(.resolved) } ]
        | map(select(.de != null and .para != null and .de != .para))
        | group_by(.de) | map({key: .[0].de, value: (map(.para) | unique)}) | from_entries' <<<"$raw" 2>/dev/null) \
      && graph_ok=1 || graph="{}"
  fi

  {
    echo "# $nome"
    echo
    echo "$stack. Instalado por harness:install $VERSION — teto de autonomia:"
    echo "\`$ceiling\`, dono: $owner (\`.harness/harness.json\`)."
    echo
    echo "## Comandos"
    # C4 → R1: só entra comando que foi EXECUTADO e passou na hora da instalação.
    [[ -n "$tc_cmd" ]]   && echo "- \`$tc_cmd\` — zero erro"
    [[ -n "$lint_cmd" ]] && echo "- \`$lint_cmd\`"
    if [[ -n "$adapter" ]]; then
      echo "- \`./.harness/gate-boundaries.sh\` — fronteiras, falha só no que é novo"
      echo "- \`./.harness/gate-boundaries.sh --tighten\` — remove do baseline o já resolvido"
    fi
    if [[ -n "$size_cfg" ]]; then
      teto=$(jq -r '.ceiling' <<<"$size_cfg")
      echo "- \`./.harness/gate-size.sh\` — tamanho: arquivo acima de $teto linhas não cresce"
      echo "- \`./.harness/gate-size.sh --tighten\` — baixa o baseline dos que encolheram"
    fi
    [[ -f "$root/ops/investigate.sh" ]] && echo "- \`./ops/investigate.sh\` — investigação read-only"
    echo
    if [[ ${#modulos[@]} -gt 0 ]]; then
      echo "## Módulos"
      echo
      for m in "${modulos[@]}"; do echo "- \`$m\`"; done
      echo
      echo "Cada um tem seu \`CLAUDE.md\`. Leia o do módulo antes de editar dentro dele."
      echo
    fi
    echo "## Nunca"
    echo "- Escrever em produção. Prod é read-only para você: investigar sim, alterar não"
    echo "- Commitar \`.env*\` ou qualquer credencial"
    echo "- Editar migration já aplicada — criar nova"
    if [[ -n "$adapter" ]]; then
      echo "- Adicionar violação ao baseline para o gate passar. O baseline só encolhe"
      echo "- Import novo entre módulos sem ADR em \`docs/adr/\`"
    fi
    if [[ -n "$size_cfg" ]]; then
      echo "- Fazer crescer arquivo que já está acima do teto de tamanho. Se a"
      echo "  mudança cabe lá, ela cabe num arquivo novo com responsabilidade própria"
      echo "- Partir arquivo em \`-parte2\` para passar no gate: satisfaz o número e"
      echo "  piora o código. Parta por responsabilidade ou não parta"
    fi
    echo
    echo "## Antes de começar"
    echo "Quando a tarefa for irreversível ou de blast radius largo — migration,"
    echo "mudança de contrato, dado em produção — pergunte antes de escrever."
    echo "Perguntas em lote, com um default proposto para cada uma. Entregue as"
    echo "premissas assumidas e o critério de aceitação por escrito. Tarefa"
    echo "pequena e reversível não merece pergunta alguma."
    echo
    echo "## Ao terminar uma tarefa"
    echo "Um hook roda os gates sobre os arquivos desta sessão. Se reportar erro,"
    echo "corrija antes de dizer que terminou — não é opcional, e não é sobre"
    echo "trabalho de outra pessoa."
  } > "$root/.harness/.claude-md.tmp"
  antes=${#pulados[@]}
  write_marked "CLAUDE.md" "<!--" "-->" < "$root/.harness/.claude-md.tmp"
  if [[ ${#pulados[@]} -gt $antes ]]; then
    # D3 manda não sobrescrever. Mas o CLAUDE.md que já existe é justamente
    # onde mora a instrução falsa: deixamos a proposta ao lado, para merge
    # humano, em vez de engolir o achado.
    mv "$root/.harness/.claude-md.tmp" "$root/.harness/CLAUDE.md.proposto"
    escritos+=(".harness/CLAUDE.md.proposto — o CLAUDE.md atual não é nosso; compare e faça o merge à mão")
  fi
  rm -f "$root/.harness/.claude-md.tmp"

  for m in "${modulos[@]}"; do
    deps=$(jq -r --arg m "$m" '.[$m] // [] | map("`" + . + "`") | join(", ")' <<<"$graph")
    {
      echo "# $m"
      echo
      echo "<!-- uma linha: o que este módulo faz. Preencha — o gerador não sabe. -->"
      echo
      echo "- Possui: \`$m/**\`"
      if [[ -n "$adapter" && $graph_ok -eq 1 ]]; then
        if [[ -n "$deps" ]]; then
          echo "- Hoje importa: $deps — descrito do grafo real, não prescrito"
        else
          echo "- Hoje importa: nenhum outro módulo deste repositório"
        fi
        echo "- Nunca importa: ciclo (a única direção proibida hoje). Import novo"
        echo "  para fora da lista acima é mudança de fronteira: ADR em \`docs/adr/\`"
      elif [[ -n "$adapter" ]]; then
        # O grafo não pôde ser lido nesta geração. Escrever "não importa nada"
        # seria afirmação falsa — e instrução falsa é pior que ausente (C4).
        echo "- Hoje importa: NÃO APURADO — o gate de fronteira não conseguiu ler"
        echo "  o grafo nesta geração. Rode \`./.harness/gate-boundaries.sh\` e regere"
        echo "- Nunca importa: ciclo (a única direção proibida hoje)"
      else
        echo "- Hoje importa: não apurado — esta stack não tem adaptador de fronteira"
        echo "- Nunca importa: nenhuma regra de direção é verificável aqui ainda"
      fi
    } > "$root/.harness/.claude-md.tmp"
    write_marked "$m/CLAUDE.md" "<!--" "-->" < "$root/.harness/.claude-md.tmp"
    rm -f "$root/.harness/.claude-md.tmp"
  done
fi

# --- relatório -------------------------------------------------------------
jq -n --argjson e "$(printf '%s\n' "${escritos[@]+"${escritos[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" \
      --argjson p "$(printf '%s\n' "${pulados[@]+"${pulados[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" \
      --arg f "$fase" --arg v "$VERSION" \
  '{fase: $f, versao: $v, escritos: $e, pulados: $p}'
