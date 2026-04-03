#!/usr/bin/env bash
# Gauntlet — Run full task suite against the agent
#
# Usage: ./scripts/run-suite.sh [--profile NAME] [--model MODEL]
#
# Defaults:
#   Profile: gauntlet
#   Model: (uses profile default from openclaw.json)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GAUNTLET_DIR="$(dirname "$SCRIPT_DIR")"
PROFILE="${1:-gauntlet}"
RESULTS_DIR="$GAUNTLET_DIR/results"
LATEST_DIR="$RESULTS_DIR/latest"
TASKS_DIR="$GAUNTLET_DIR/tasks"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================"
echo "  THE GAUNTLET — Task Suite Runner"
echo "  Profile: $PROFILE"
echo "  Tasks:   $TASKS_DIR"
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
  openclaw --profile "$PROFILE" gateway call sessions.reset \
    --params "{\"key\":\"gauntlet:$task_name\"}" \
    >/dev/null 2>&1 || true

  # Send task to agent via gateway
  RESPONSE=$(openclaw --profile "$PROFILE" agent \
    --message "$INSTRUCTION" \
    --json 2>/dev/null || echo '{"error": "agent call failed"}')

  # Extract response text
  RESPONSE_TEXT=$(echo "$RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    # Try common response fields
    for key in ['text', 'content', 'message', 'response', 'result']:
        if key in data:
            print(data[key])
            sys.exit(0)
    # Fallback: dump the whole thing
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

  # Score (deterministic check result for now; LLM judge can be added)
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

  # Add to JSON array
  [ "$TOTAL" -gt 1 ] && RESULTS_JSON+=","
  RESULTS_JSON+="{\"task\":\"$task_name\",\"score\":$SCORE}"
done

RESULTS_JSON+="]"

# Calculate average
AVG_SCORE=$(echo "scale=2; $SUM_SCORE / $TOTAL" | bc)

# Write summary
cat > "$RESULTS_DIR/latest.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "profile": "$PROFILE",
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
