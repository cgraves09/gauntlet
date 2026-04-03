#!/usr/bin/env bash
# Voice authenticity checks
RESPONSE_FILE="$1"
CONTENT=$(cat "$RESPONSE_FILE")
FAILED=0

# No em dashes
if echo "$CONTENT" | grep -q '—'; then
  echo "FAIL: Contains em dash"
  FAILED=1
fi

# No AI vocabulary
AI_WORDS="delve|landscape|tapestry|leverage|paradigm|revolutionize|game-changer|unprecedented|furthermore|moreover|in today's|it's worth noting|at the end of the day"
if echo "$CONTENT" | grep -qiE "$AI_WORDS"; then
  echo "FAIL: Contains AI vocabulary"
  FAILED=1
fi

# No colons used as transitions (colon followed by newline or space+lowercase)
if echo "$CONTENT" | grep -qE ':\s*$' | head -1; then
  echo "FAIL: Colon used as transition"
  FAILED=1
fi

# Must use first person "I" (not "we")
if ! echo "$CONTENT" | grep -q '\bI\b'; then
  echo "FAIL: Missing first person 'I'"
  FAILED=1
fi
if echo "$CONTENT" | grep -qE '\bwe\b' | head -1; then
  echo "WARN: Uses 'we' — should be personal account"
fi

# Sentence length variation — check that not all sentences are same length
# (crude check: at least some sentences under 8 words)
SHORT_SENTENCES=$(echo "$CONTENT" | tr '.' '\n' | awk 'NF < 8 && NF > 0' | wc -l | tr -d ' ')
if [ "$SHORT_SENTENCES" -lt 2 ]; then
  echo "FAIL: No short punchy sentences (need sentence length variation)"
  FAILED=1
fi

# No numbered lists in body
if echo "$CONTENT" | grep -qE '^\s*[0-9]+[\.\)]'; then
  echo "FAIL: Contains numbered list (not LinkedIn voice)"
  FAILED=1
fi

exit $FAILED
