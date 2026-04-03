#!/usr/bin/env bash
# Gauntlet — Run a single task (for debugging)
#
# Usage: ./scripts/run-task.sh <task-name> [--profile NAME]

set -euo pipefail

TASK_NAME="${1:?Usage: run-task.sh <task-name> [--profile NAME]}"
PROFILE="${2:-gauntlet}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GAUNTLET_DIR="$(dirname "$SCRIPT_DIR")"
TASK_DIR="$GAUNTLET_DIR/tasks/$TASK_NAME"

if [ ! -f "$TASK_DIR/instruction.md" ]; then
  echo "Task not found: $TASK_NAME"
  echo "Available tasks:"
  ls "$GAUNTLET_DIR/tasks/" 2>/dev/null | while read d; do
    [ -f "$GAUNTLET_DIR/tasks/$d/instruction.md" ] && echo "  $d"
  done
  exit 1
fi

echo "=== Task: $TASK_NAME ==="
echo ""
echo "--- Instruction ---"
cat "$TASK_DIR/instruction.md"
echo ""
echo "--- Sending to agent (profile: $PROFILE) ---"
echo ""

# Reset session
openclaw --profile "$PROFILE" gateway call sessions.reset \
  --params "{\"key\":\"gauntlet:$TASK_NAME\"}" \
  >/dev/null 2>&1 || true

# Run agent
RESPONSE=$(openclaw --profile "$PROFILE" agent \
  --message "$(cat "$TASK_DIR/instruction.md")" \
  2>&1)

echo "--- Response ---"
echo "$RESPONSE"
echo ""

# Run checks if they exist
if [ -f "$TASK_DIR/checks.sh" ]; then
  echo "$RESPONSE" > /tmp/gauntlet-response.md
  echo "--- Checks ---"
  if bash "$TASK_DIR/checks.sh" /tmp/gauntlet-response.md; then
    echo "CHECKS: PASS"
  else
    echo "CHECKS: FAIL"
  fi
fi
