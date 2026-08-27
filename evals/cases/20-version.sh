#!/usr/bin/env bash
# Caso: o comando /harness:version. Duas versões — a da skill em execução e a
# que instalou o repositório — e a divergência entre elas é a informação
# acionável.

# grep -q fecha o pipe ao primeiro casamento e, com pipefail ligado, o produtor
# morre de SIGPIPE: o pipeline sai 141 mesmo tendo casado. Aqui o grep drena a
# entrada; a saída já é descartada por t().
echo "→ comando /harness:version"
V=plugin/scripts/harness-version.sh
export CLAUDE_PLUGIN_ROOT="$PWD/plugin"
t "reporta a versão em execução"        "$V . | grep 'skill em execução'"
t "e a versão bate com o plugin.json"   "$V . | grep \"$(jq -r .version plugin/.claude-plugin/plugin.json)\""
t "repo sem harness não quebra"         "$V $F/sem-harness | grep 'nenhum harness instalado'"
t "e sugere o audit, não a instalação"  "$V $F/sem-harness | grep 'harness:audit'"
VR=$W/com-harness; mkdir -p "$VR/.harness"
printf '{"harness_version":"0.0.9","owner":"Fulano","autonomy_ceiling":"supervisionado","boundary":{"adapter":"node"}}\n' > "$VR/.harness/harness.json"
echo '[]' > "$VR/.harness/baseline.json"
t "lê a versão que instalou o repo"     "$V $VR | grep '0.0.9'"
t "acusa divergência de versão"         "$V $VR | grep 'instalado por outra versão'"
t "e diz que reinstalar é seguro (D3)"  "$V $VR | grep 'idempotente'"
t "mostra o dono (D6)"                  "$V $VR | grep Fulano"
t "estado da trilha aparece (V12)"      "$V $VR | grep 'trilha'"
t "trilha ligada e vazia é dita assim"  "$V $VR | grep 'ainda sem evento'"
mkdir -p "$VR/.harness/log"
printf '{"ts":"2026-08-27T00:00:00Z","sid":"x","ev":"guard","verdict":"deny"}\n' \
  > "$VR/.harness/log/events-2026-08.jsonl"
t "e com evento aponta o leitor"        "$V $VR | grep 'stats.sh'"
# `// true` devolveria true aqui: em jq o false é vazio. Foi um defeito real.
jq '.telemetry={enabled:false}' "$VR/.harness/harness.json" > "$W/v.tel" \
  && mv "$W/v.tel" "$VR/.harness/harness.json"
t "telemetria desligada é dita, não omitida" "$V $VR | grep 'DESLIGADA'"
printf '{"harness_version":"0.0.9","autonomy_ceiling":"supervisionado"}\n' > "$VR/.harness/harness.json"
t "dono ausente é acusado como D6"      "$V $VR | grep 'NÃO REGISTRADO'"
unset CLAUDE_PLUGIN_ROOT
