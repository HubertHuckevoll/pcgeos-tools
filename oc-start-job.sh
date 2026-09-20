#!/usr/bin/env bash

set -euo pipefail

PROMPT_FILE="$(mktemp /tmp/oc-job-prompt.XXXXXX)"
cat >"$PROMPT_FILE"

gnome-terminal \
    --working-directory="$PWD" \
    -- bash -lc \
    '~/pcgeos-tools/oc-job.sh < "$1"; rc=$?; rm -f "$1"; echo; echo "oc-job finished (exit $rc)"; exec bash' \
    bash "$PROMPT_FILE"