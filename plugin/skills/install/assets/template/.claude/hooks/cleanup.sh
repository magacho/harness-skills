#!/bin/bash
sid=$(jq -r '.session_id' <<<"$(cat)")
rm -f /tmp/cc-touched-"$sid"-*.txt /tmp/cc-tries-"$sid"
exit 0
