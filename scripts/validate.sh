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

echo "→ contrato de adaptador implementado, não só escrito"
for v in detect generate-config run normalize; do
  grep -qE "^${v}\)" plugin/skills/install/scripts/adapters/node.sh \
    || err "adaptador node.sh não implementa o verbo $v"
done

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
