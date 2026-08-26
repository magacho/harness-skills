#!/usr/bin/env bash
# Caso: a trava de produção. `A2 → R5` é a única garantia que o INTENT chama de
# não parametrizável, e era o único gate nunca visto reprovando — o eval antigo
# fazia `grep -q 'deny'` no arquivo, que verifica que a palavra existe, não que o
# hook bloqueia. Um avaliador externo achou o furo que isso deixou passar.
#
# O hook recebe JSON no stdin e responde JSON no stdout: testável sem plataforma.
GP=$I/../assets/retrofit/hooks/guard-prod.sh

# Sem pipe para o hook: `grep -q` fecharia o pipe e o pipefail transformaria o
# casamento em falha (foi o defeito da divisão dos evals).
gp() {
  local out
  out=$(printf '{"tool_input":{"command":%s}}' "$(jq -Rn --arg c "$1" '$c')" | bash "$GP")
  [[ -z "$out" ]] && echo passou || jq -r '.hookSpecificOutput.permissionDecision' <<<"$out"
}
nega()  { t "nega: $1"  "[ \"\$(gp '$(sed "s/'/'\\\\''/g" <<<"$1")')\" = deny ]"; }
passa() { t "passa: $1" "[ \"\$(gp '$(sed "s/'/'\\\\''/g" <<<"$1")')\" = passou ]"; }

echo "→ install / trava de produção: deploy (V9 aplicado a A2)"
nega './ops/deploy.sh prd'
nega './ops/deploy.sh --env prd'
# Ambiente ANTES do verbo: a regra pedia prd depois de deploy e deixava passar.
nega 'PRD=1 ./ops/deploy.sh'
nega 'ENV=prod ./ops/deploy.sh'
# `_` é caractere de palavra, então `\bdeploy` não casava em `prd_deploy.sh`.
nega 'prd_deploy.sh'
nega 'make release-prod'
passa './ops/deploy.sh stg'
passa 'npm run build'
# Produção é investigável (A1/A3): negar leitura é reprovar trabalho legítimo.
passa 'cat deployment-prod.log'
passa './ops/investigate.sh prd'

echo "→ install / trava de produção: tag de release"
# O furo que o avaliador externo achou: a regra casava `tag` seguido de
# `v<dígito>`, então qualquer flag no meio contornava — inclusive `-a`, que é a
# forma usual de release. A correção não adivinha o formato do nome: enumera o
# verbo, que é o que distingue leitura de escrita.
nega 'git tag v1.2.3'
nega 'git tag -a v1.2.3 -m rel'
nega 'git tag --annotate v1.2.3'
nega 'git tag -s v1.2.3'
nega 'git tag -f v1.2.3'
# Flag com argumento quebra a cadeia `(-flag)*` de qualquer regex posicional.
nega 'git tag -m rel -a v1.2.3'
# Flag global do git antes do subcomando.
nega 'git -C /repo tag -a v1.2.3'
# Nome que não é semver: `v1.2`, `release-1`. Regex de formato erra nos dois.
nega 'git tag -a v1.2 -m rel'
nega 'git tag -a release-1 -m rel'
nega 'git tag -d v1.2.3'
# Empurrar tag já criada dispara o mesmo pipeline.
nega 'git push origin --tags'
nega 'git push --follow-tags'
nega 'git push origin refs/tags/v1.2.3'

echo "→ install / e a leitura de tag continua liberada"
passa 'git tag'
passa 'git tag -l'
passa 'git tag -n5'
passa 'git tag --points-at HEAD'
passa 'git tag --contains abc123'
passa 'git tag --sort=-creatordate'
passa 'git describe --tags'
passa 'git push origin main'
passa 'git commit -m x'

echo "→ install / trava de produção: destruição de dado"
nega 'DROP TABLE users'
nega 'TRUNCATE TABLE users'
# Postgres e MySQL aceitam TRUNCATE sem a palavra TABLE; a regra exigia TABLE.
nega 'psql -c "TRUNCATE users"'
nega 'psql -c "TRUNCATE ONLY users"'
nega 'mysql -e "DROP DATABASE x"'
# `truncate` do coreutils é trabalho legítimo: o que separa é o cliente SQL.
passa 'truncate -s 0 app.log'
passa 'psql -c "SELECT 1"'

echo "→ install / trava de produção: credencial e contexto"
nega 'aws s3 rm s3://x --profile prd'
nega 'aws --profile prd s3 rm s3://x'
nega 'kubectl delete pod x --context prod'
passa 'aws logs tail --profile prd'
passa 'kubectl get pods --context prod'

echo "→ install / a recusa ensina, e os dois modos usam o mesmo hook"
t "a recusa diz o que fazer em vez disso (A4 → R1)" \
  "printf '{\"tool_input\":{\"command\":\"./ops/deploy.sh prd\"}}' | bash $GP \
   | jq -e '.hookSpecificOutput.permissionDecisionReason | test(\"plano de release\")'"
t "a recusa da tag oferece o caminho humano" \
  "printf '{\"tool_input\":{\"command\":\"git tag -a v1 -m r\"}}' | bash $GP \
   | jq -e '.hookSpecificOutput.permissionDecisionReason | test(\"Leitura\")'"
t "existe UMA cópia de cada hook nos assets" \
  "[ \$(find plugin/skills/install/assets -name 'guard-prod.sh' | wc -l) -eq 1 ]"
t "o scaffold instala os quatro hooks da mesma fonte" \
  "for h in on-edit verify guard-prod cleanup; do grep -q \"retrofit/hooks/\$h.sh\" $I/scaffold.sh || exit 1; done"
t "o deny base cobre os caminhos de tag (A2, camada de garantia)" \
  "for p in 'git tag:' 'gh release create' 'update-ref refs/tags'; do grep -q \"\$p\" $I/gen-config.sh || exit 1; done"
