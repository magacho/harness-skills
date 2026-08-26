#!/usr/bin/env bash
# Valida o próprio produto antes do release.
# Aplica ao harness a mesma regra C4 que ele cobra dos outros.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0
err() { echo "FALHA: $*"; fail=1; }

echo "→ manifestos"
[[ -f plugin/.claude-plugin/plugin.json ]] || err "plugin.json ausente"
[[ -f .claude-plugin/marketplace.json ]] || err "marketplace.json ausente"
command -v jq >/dev/null && {
  jq empty plugin/.claude-plugin/plugin.json 2>/dev/null || err "plugin.json inválido"
  jq empty .claude-plugin/marketplace.json 2>/dev/null || err "marketplace.json inválido"
}

echo "→ frontmatter das skills"
for s in plugin/skills/*/SKILL.md; do
  head -1 "$s" | grep -q '^---$' || err "$s sem frontmatter"
  grep -qE '^name:' "$s" || err "$s sem name"
  grep -qE '^description:.{40,}' "$s" || err "$s com description ausente ou curta demais"
done

echo "→ scripts executáveis"
# env.*.sh são sourced, não executados: não exigem bit de execução
while IFS= read -r f; do [[ -x "$f" ]] || err "$f sem bit de execução"; done \
  < <(find plugin scripts evals -name '*.sh' -not -name 'env.*.sh' 2>/dev/null)

echo "→ todo shell do repositório passa em bash -n"
while IFS= read -r f; do
  bash -n "$f" 2>/dev/null || err "$f não é bash válido"
done < <(find plugin scripts evals -name '*.sh' 2>/dev/null)

echo "→ os evals são divididos por família, e o corredor os carrega"
[[ -d evals/cases ]] || err "evals/cases ausente: a suíte voltou a ser um arquivo só"
grep -q 'evals/cases/\*.sh' evals/run.sh || err "run.sh não carrega os casos"
while IFS= read -r c; do
  head -3 "$c" | grep -q '^# Caso:' || err "$c não declara em uma linha o que testa"
done < <(find evals/cases -name '*.sh' 2>/dev/null)

echo "→ frontmatter dos comandos"
for c in plugin/commands/*.md; do
  [[ -e "$c" ]] || continue
  head -1 "$c" | grep -q '^---$' || err "$c sem frontmatter"
  grep -qE '^description:.{40,}' "$c" || err "$c com description ausente ou curta demais"
done

# Substituição de processo, nunca pipe: pipe põe o laço em subshell, err define
# fail=1 lá dentro e o valor se perde — o validador imprimia a falha e ainda
# assim dizia "pronto para release".
echo "→ caminhos citados nos comandos existem (C4 aplicada ao próprio produto)"
for c in plugin/commands/*.md; do
  [[ -e "$c" ]] || continue
  while read -r p; do
    rel="${p#\$\{CLAUDE_PLUGIN_ROOT\}/}"
    [[ -e "plugin/$rel" ]] || err "$c cita $p que não existe"
  done < <(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[a-zA-Z0-9._/-]+' "$c" | sort -u)
done

echo "→ comando com injeção dinâmica tem permissão que casa"
# Comando que injeta saída com !`cmd` precisa de uma regra allowed-tools que
# case com o comando real; sem ela o usuário leva prompt de permissão e a
# injeção deixa de ser determinística — degrada para "o modelo decide rodar",
# que foi o defeito original.
for c in plugin/commands/*.md; do
  [[ -e "$c" ]] || continue
  while read -r cmd; do
    bin=${cmd%% *}; bin=${bin#\"}; bin=${bin%\"}
    grep -q "Bash(${bin}" "$c" \
      || err "$c injeta '${bin}' sem regra allowed-tools correspondente"
  done < <(sed -n 's/^!`\(.*\)`$/\1/p' "$c")
done

echo "→ caminhos citados nas skills existem"
for s in plugin/skills/*/SKILL.md; do
  d=$(dirname "$s")
  while read -r p; do
    [[ -e "$d/${p#./}" ]] || err "$s cita $p que não existe"
  done < <(grep -oE '\./(scripts|reference|assets)/[a-zA-Z0-9._/-]+' "$s" | sort -u)
done

echo "→ sem segredo versionado"
grep -rInE '(AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY)' \
  --exclude-dir=.git --exclude-dir=node_modules . >/dev/null 2>&1 \
  && err "possível segredo versionado"

echo "→ o template é distribuído por uma skill, não solto na raiz"
[[ -d plugin/skills/install/assets/template ]] || err "template ausente de plugin/skills/install/assets/"
[[ ! -d template ]] || err "template solto na raiz: nenhuma skill o distribui de lá"

echo "→ eslint.config.js do template é carregável (C4 aplicada ao que enviamos)"
# Config que não carrega faz o gate de turno falhar por erro de config, e o
# agente lê isso como "meu código está errado". Sem typescript-eslint instalado
# aqui, o que se pode verificar é a sintaxe do arquivo.
node --check plugin/skills/install/assets/template/eslint.config.js 2>/dev/null \
  || err "eslint.config.js do template não é JavaScript válido"

echo "→ contrato de adaptador implementado, não só escrito"
for v in detect generate-config run normalize; do
  grep -qE "^${v}\)" plugin/skills/install/scripts/adapters/node.sh \
    || err "adaptador node.sh não implementa o verbo $v"
done

echo "→ catraca de tamanho: gate, config e o modo de fracasso conhecido (V10/V11)"
[[ -x plugin/skills/install/assets/gate/size.sh ]] || err "gate de tamanho ausente"
grep -q 'baseline-size.json' plugin/skills/install/assets/gate/size.sh \
  || err "o gate de tamanho não tem baseline próprio (V10)"
grep -q -- '--tighten' plugin/skills/install/assets/gate/size.sh \
  || err "o baseline de tamanho não tem caminho para encolher (V7)"
# V11: o limite de arquivo é da catraca. Um max-lines no linter daria uma segunda
# resposta à mesma pergunta, e as duas divergiriam na primeira correção.
grep -qE '^\s*"?max-lines"?:' plugin/skills/install/assets/template/eslint.config.js \
  && err "max-lines no linter duplica a catraca de tamanho (V11)"
grep -q 'max-lines-per-function' plugin/skills/install/assets/template/eslint.config.js \
  || err "o linter do template não limita tamanho de função (V11)"
grep -q 'typescript-eslint' plugin/skills/install/assets/template/package.json \
  || err "eslint.config.js usa typescript-eslint sem declarar a dependência (C4)"
# A recusa tem de ensinar: sem isto o agente parte o arquivo em -parte2 e passa.
grep -q 'parte 1 / parte 2' plugin/skills/install/assets/gate/size.sh \
  || err "a recusa do gate de tamanho não ensina a saída certa (A4 → R1)"
# V9 nos dois gates: fumaça que só prova um deixa o outro sem prova nenhuma.
for g in gate-size gate-boundaries; do
  grep -q "$g" plugin/skills/install/scripts/smoke-test.sh \
    || err "smoke-test.sh não prova o $g (V9 → R3)"
done

echo "→ os dois gates entram no hook de turno e nas permissões"
grep -q 'gate-size.sh' plugin/skills/install/assets/retrofit/hooks/verify.sh \
  || err "o hook de turno não chama o gate de tamanho"
grep -q 'gate-size.sh' plugin/skills/install/scripts/gen-config.sh \
  || err "gen-config.sh não instala o gate de tamanho"
grep -q 'gate-size.sh' plugin/skills/install/scripts/scaffold.sh \
  || err "scaffold.sh não instala o gate de tamanho"

echo "→ hook mora em um lugar só, e a trava de produção é provada"
for h in on-edit verify guard-prod cleanup; do
  n=$(find plugin/skills/install/assets -name "$h.sh" | wc -l)
  [[ "$n" -eq 1 ]] || err "há $n cópias de $h.sh nos assets — foi assim que o modo B ficou com trava mais fraca"
  grep -q "retrofit/hooks/$h.sh" plugin/skills/install/scripts/scaffold.sh \
    || err "scaffold.sh não instala $h.sh da fonte única"
done
GP=plugin/skills/install/assets/retrofit/hooks/guard-prod.sh
# A regra de tag não pode voltar a depender do formato do nome: era o que
# `git tag -a v1.2.3` contornava. O que decide é o verbo.
grep -q 'tag_escreve' $GP || err "a trava de tag não enumera o verbo de escrita"
grep -qE "tag[^\n]*v\?\[0-9\]" $GP \
  && err "a trava de tag voltou a casar formato de nome de versão"
grep -q 'LEITURA=' $GP || err "os verbos de leitura não estão em um lugar só"
grep -q "Bash(git tag:\*)" plugin/skills/install/scripts/gen-config.sh \
  || err "o deny base não nega o subcomando git tag (camada de garantia, A2)"
[[ -f evals/cases/05-guard-prod.sh ]] \
  || err "a trava de produção não tem eval — V9 aplicado a A2"

echo "→ varredura de arquivo-fonte mora em um lugar só"
GS=plugin/skills/install/assets/gate/size.sh
grep -q -- '--measure' $GS || err "o gate não expõe --measure: os consumidores voltam a reimplementar find"
grep -q -- '--defaults' $GS || err "o gate não expõe --defaults: o teto volta a ser copiado"
# A causa raiz do bug do `.next/`: cada consumidor tinha a sua lista de poda, e
# elas divergiram. Poda e extensão canônicas só podem existir aqui.
for consumidor in plugin/skills/install/scripts/plan-install.sh \
                  plugin/skills/audit/scripts/size-status.sh; do
  grep -q -- '--measure' "$consumidor" \
    || err "$consumidor não mede pelo gate"
  grep -qE '\-name node_modules|FIND_PRUNE' "$consumidor" \
    && err "$consumidor tem lista de poda própria — foi assim que o plano acusou god file em .next/"
done
[[ $(grep -c 'PODAR=(' $GS) -eq 1 ]] || err "a lista de poda canônica não é única"
grep -qE 'SIZE_EXT=|SIZE_EXCL=|ceiling: 400' plugin/skills/install/scripts/*.sh \
  && err "teto ou extensões copiados fora do gate"
# O plano tem de medir os MESMOS alvos que o gate vai vigiar depois; varrer a
# raiz aqui e targets lá foi a outra metade do defeito.
grep -q 'measure --root "$root" \\' plugin/skills/install/scripts/plan-install.sh \
  && grep -q -- '--targets' plugin/skills/install/scripts/plan-install.sh \
  || err "plan-install mede sem restringir aos alvos do plano"

echo "→ merge de settings.json: sem fallback silencioso, com invariante travada"
MS=plugin/skills/install/scripts/merge-settings.jq
[[ -f $MS ]] || err "merge-settings.jq ausente: o merge voltou para dentro do gerador"
grep -q "merge-settings.jq" plugin/skills/install/scripts/gen-config.sh \
  || err "gen-config.sh não usa a função de merge testada"
# O defeito original: `.[0]` indexado DEPOIS de `.[0] * .[1]`, onde o contexto já
# é o objeto mesclado. Erro de tipo em toda execução, escondido por um `||`.
grep -qE '\.\[0\] \* \.\[1\].*\|' plugin/skills/install/scripts/gen-config.sh \
  && err "gen-config.sh voltou a indexar .[0] depois do merge (erro de tipo)"
# E o que transformou o erro em perda de dados: fallback que engole a falha do
# merge e ainda escreve.
grep -qE '^\s*\|\| jq ' plugin/skills/install/scripts/gen-config.sh \
  && err "gen-config.sh tem fallback de jq que esconde falha de merge"
for inv in 'perdeu_deny' 'perdeu_hook'; do
  grep -q "$inv" plugin/skills/install/scripts/gen-config.sh \
    || err "gen-config.sh não verifica a invariante $inv depois do merge"
done
grep -q 'PERMISSÕES NÃO INSTALADAS' plugin/skills/install/scripts/gen-config.sh \
  || err "merge recusado não diz em voz alta que as permissões não entraram (A8)"

echo "→ a catraca é do harness, não da ferramenta (V8)"
grep -q 'baseline.json' plugin/skills/install/assets/gate/boundaries.sh \
  || err "o gate não compara com o baseline do harness"
grep -qE '^\s*knownViolations' plugin/skills/install/scripts/adapters/node.sh \
  && err "a catraca está delegada ao mecanismo nativo da ferramenta"

echo "→ o dono é obrigatório (D6)"
for f in plugin/skills/install/scripts/gen-config.sh plugin/skills/install/scripts/scaffold.sh; do
  grep -q 'D6' "$f" || err "$f não exige dono nomeado"
done

echo "→ documentos normativos presentes"
for d in docs/INTENT.md docs/HARNESS.md docs/PLAN.md docs/adapters/README.md; do
  [[ -f "$d" ]] || err "$d ausente"
done

echo "→ rastreabilidade: nenhuma regra órfã"
orphans=$(grep -cE '^\*\*[A-Z][0-9]+ — ' docs/HARNESS.md)
traced=$(grep -cE '`→ R' docs/HARNESS.md)
[[ $traced -ge $orphans ]] || err "há regras sem R correspondente ($traced/$orphans)"

echo
[[ $fail -eq 0 ]] && echo "OK — pronto para release" || echo "Corrija antes de publicar."
exit $fail
