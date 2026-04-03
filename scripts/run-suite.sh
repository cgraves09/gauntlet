#!/usr/bin/env bash
# Gauntlet — Run full task suite against the agent
#
# Usage:
#   Local:  ./scripts/run-suite.sh [--profile NAME]
#   Docker: docker compose exec gauntlet /gauntlet/scripts/run-suite.sh
#
# Inside Docker, no --profile is needed (gateway is local).
# Outside Docker, defaults to --profile gauntlet.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect environment: Docker (/gauntlet exists) or local
if [ -d "/gauntlet/tasks" ]; then
  GAUNTLET_DIR="/gauntlet"
  OC_CMD="openclaw"
else
  GAUNTLET_DIR="$(dirname "$SCRIPT_DIR")"
  PROFILE="${1:-gauntlet}"
  OC_CMD="openclaw --profile $PROFILE"
fi

RESULTS_DIR="$GAUNTLET_DIR/results"
LATEST_DIR="$RESULTS_DIR/latest"
TASKS_DIR="$GAUNTLET_DIR/tasks"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "================================================"
echo "  THE GAUNTLET — Task Suite Runner"
echo "  Tasks: $TASKS_DIR"
echo "================================================"
echo ""

# Ensure results directories exist
mkdir -p "$LATEST_DIR"

# Collect task directories
TASKS=()
for task_dir in "$TASKS_DIR"/*/; do
  [ -f "$task_dir/instruction.md" ] || continue
  TASKS+=("$(basename "$task_dir")")
done

if [ ${#TASKS[@]} -eq 0 ]; then
  echo "No tasks found in $TASKS_DIR"
  exit 1
fi

echo "Found ${#TASKS[@]} tasks: ${TASKS[*]}"
echo ""

# Run each task
TOTAL=0
PASSED=0
SUM_SCORE=0
RESULTS_JSON="["

for task_name in "${TASKS[@]}"; do
  echo -n "Running: $task_name ... "

  TASK_DIR="$TASKS_DIR/$task_name"
  INSTRUCTION=$(cat "$TASK_DIR/instruction.md")

  # Reset session for clean slate
  $OC_CMD gateway call sessions.reset \
    --params "{\"key\":\"gauntlet:$task_name\"}" \
    >/dev/null 2>&1 || true

  # Send task to agent via gateway
  RESPONSE=$($OC_CMD agent \
    --message "$INSTRUCTION" \
    --json 2>/dev/null || echo '{"error": "agent call failed"}')

  # Extract response text
  RESPONSE_TEXT=$(echo "$RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for key in ['text', 'content', 'message', 'response', 'result']:
        if key in data:
            print(data[key])
            sys.exit(0)
    print(json.dumps(data, indent=2))
except:
    print(sys.stdin.read())
" 2>/dev/null || echo "$RESPONSE")

  # Save raw response
  echo "$RESPONSE_TEXT" > "$LATEST_DIR/$task_name.response.md"

  # Run deterministic checks (if they exist)
  CHECK_SCORE=1.0
  if [ -f "$TASK_DIR/checks.sh" ]; then
    if bash "$TASK_DIR/checks.sh" "$LATEST_DIR/$task_name.response.md" >/dev/null 2>&1; then
      CHECK_SCORE=1.0
    else
      CHECK_SCORE=0.0
    fi
  fi

  SCORE="$CHECK_SCORE"

  # Save score
  cat > "$LATEST_DIR/$task_name.score.json" <<EOF
{
  "task": "$task_name",
  "score": $SCORE,
  "check_passed": $([ "$CHECK_SCORE" = "1.0" ] && echo "true" || echo "false"),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

  # Tally
  TOTAL=$((TOTAL + 1))
  if [ "$SCORE" = "1.0" ]; then
    PASSED=$((PASSED + 1))
    echo -e "${GREEN}PASS${NC} ($SCORE)"
  else
    echo -e "${RED}FAIL${NC} ($SCORE)"
  fi
  SUM_SCORE=$(echo "$SUM_SCORE + $SCORE" | bc)

  [ "$TOTAL" -gt 1 ] && RESULTS_JSON+=","
  RESULTS_JSON+="{\"task\":\"$task_name\",\"score\":$SCORE}"
done

RESULTS_JSON+="]"
AVG_SCORE=$(echo "scale=2; $SUM_SCORE / $TOTAL" | bc)

cat > "$RESULTS_DIR/latest.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total": $TOTAL,
  "passed": $PASSED,
  "avg_score": $AVG_SCORE,
  "tasks": $RESULTS_JSON
}
EOF

echo ""
echo "================================================"
echo -e "  Results: ${GREEN}$PASSED${NC}/$TOTAL passed (avg: $AVG_SCORE)"
echo "  Saved to: $RESULTS_DIR/latest.json"
echo "================================================"
