#!/usr/bin/env bash
# Gauntlet — Run a single task (for debugging)
#
# Usage:
#   Local:  ./scripts/run-task.sh <task-name> [--profile NAME]
#   Docker: docker compose exec gauntlet /gauntlet/scripts/run-task.sh <task-name>

set -euo pipefail

TASK_NAME="${1:?Usage: run-task.sh <task-name>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect environment
if [ -d "/gauntlet/tasks" ]; then
  GAUNTLET_DIR="/gauntlet"
  OC_CMD="openclaw"
else
  GAUNTLET_DIR="$(dirname "$SCRIPT_DIR")"
  PROFILE="${2:-gauntlet}"
  OC_CMD="openclaw --profile $PROFILE"
fi

TASK_DIR="$GAUNTLET_DIR/tasks/$TASK_NAME"

if [ ! -f "$TASK_DIR/instruction.md" ]; then
  echo "Task not found: $TASK_NAME"
  echo "Available tasks:"
  for d in "$GAUNTLET_DIR/tasks"/*/; do
    [ -f "$d/instruction.md" ] && echo "  $(basename "$d")"
  done
  exit 1
fi

echo "=== Task: $TASK_NAME ==="
echo ""
echo "--- Instruction ---"
cat "$TASK_DIR/instruction.md"
echo ""
echo "--- Sending to agent ---"
echo ""

# Reset session
$OC_CMD gateway call sessions.reset \
  --params "{\"key\":\"gauntlet:$TASK_NAME\"}" \
  >/dev/null 2>&1 || true

# Run agent
RESPONSE=$($OC_CMD agent \
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
