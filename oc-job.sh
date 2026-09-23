#!/usr/bin/env bash
#
# oc-job.sh - One-shot coding worker using OpenCode
#
# Normally launched by oc-start-job.sh.
# The implementation prompt is read from stdin.
#

set -euo pipefail

if ! command -v opencode >/dev/null 2>&1; then
    echo "oc-job: opencode not found in PATH" >&2
    exit 127
fi

#
# Hardcode the model for now.
#
#MODEL=openrouter/deepseek/deepseek-v4.1-flash
MODEL=openrouter/~z-ai/glm-flash-latest
#MODEL=openrouter/openai/gpt-5.6-luna-pro
#MODEL=openrouter/openai/gpt-6-luna-pro
#MODEL=openrouter/qwen/qwen3.8-27b
#MODEL=openrouter/qwen/qwen3.8-flash
#MODEL=openrouter/google/gemini-3.8-flash

if [[ "$MODEL" == *:exacto ]] &&
   [[ ! "$MODEL" =~ ^openrouter/[A-Za-z0-9._~-]+(/[A-Za-z0-9._~-]+)+:exacto$ ]]; then
    echo "oc-job: invalid Exacto model: $MODEL" >&2
    exit 2
fi

#
# Require a Git repository.
#
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$REPO_ROOT" ]]; then
    echo "oc-job: not inside a Git repository" >&2
    exit 1
fi

#
# For PC/GEOS we never want a worker without repository instructions.
#
if [[ ! -f "$REPO_ROOT/AGENTS.md" ]]; then
    echo "oc-job: no AGENTS.md at repository root:" >&2
    echo "  $REPO_ROOT" >&2
    exit 1
fi

#
# Prompt from arguments or stdin.
#
if [[ $# -gt 0 ]]; then
    PROMPT="$*"
elif [[ ! -t 0 ]]; then
    PROMPT="$(cat)"
else
    echo "oc-job: no prompt supplied" >&2
    exit 2
fi

#
# Per-run OpenCode policy.
#
# Everything required for implementation is allowed, but git commit and
# git push are explicitly denied. The broad rule must come first because
# OpenCode uses the LAST matching rule.
#
MODEL_CONFIG=

if [[ "$MODEL" == *:exacto ]]; then
    OPENROUTER_MODEL="${MODEL#openrouter/}"

    MODEL_CONFIG="$(cat <<EOF
  "provider": {
    "openrouter": {
      "models": {
        "$OPENROUTER_MODEL": {}
      }
    }
  },
EOF
)"
fi

export OPENCODE_CONFIG_CONTENT="$(cat <<EOF
{
  "\$schema": "https://opencode.ai/config.json",

${MODEL_CONFIG}
  "permission": {
    "bash": {
      "*": "allow",

      "*git*commit*": "deny",
      "*git*push*": "deny"
    }
  }
}
EOF
)"

#
# Reinforce the policy in the task itself. The permission rules above are
# the actual enforcement; this tells the model what workflow is expected.
#
WORKER_PROMPT="$(cat <<EOF
You are an implementation worker delegated by a supervising Codex agent.

Before making changes:
- Read and obey the repository AGENTS.md and all applicable nested AGENTS.md
  files.

Workflow:
- Implement the requested change in the current working tree.
- Keep the patch focused and minimal.
- Run appropriate builds and tests.
- Inspect your resulting diff before finishing.
- Do NOT commit anything.
- Do NOT push anything.
- Do NOT create pull requests.
- Leave all changes in the working tree for the supervising Codex agent
  to review.

TASK FROM SUPERVISING AGENT:

${PROMPT}
EOF
)"

#
# Do not exec here: we want to regain control after OpenCode finishes so
# we can notify the user and preserve OpenCode's exit status.
#
set +e

opencode run \
    --pure \
    --auto \
    --agent build \
    --variant high \
    --model "$MODEL" \
    --dir "$PWD" \
    "$WORKER_PROMPT"

RC=$?

set -e

#
# The worktree is the result. The supervising Codex agent will inspect the
# diff itself after the user tells it that the worker has finished.
#
if command -v notify-send >/dev/null 2>&1; then
    notify-send \
        "OpenCode worker" \
        "Finished with exit code $RC"
fi

exit "$RC"