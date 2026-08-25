#!/usr/bin/env bash
# SessionEnd — limpa o rastreamento da sessão.
# harness-generated: __VERSION__
sid=$(jq -r '.session_id // "sem-sessao"' <<<"$(cat)")
rm -f /tmp/cc-touched-"$sid"-*.txt /tmp/cc-tries-"$sid" /tmp/cc-scope-"$sid".txt
exit 0
