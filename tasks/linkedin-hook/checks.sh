#!/usr/bin/env bash
# Deterministic checks for linkedin-hook task
RESPONSE_FILE="$1"
CONTENT=$(cat "$RESPONSE_FILE")
FAILED=0

# Hook must be under 50 characters (first line)
FIRST_LINE=$(echo "$CONTENT" | head -1)
FIRST_LINE_LEN=${#FIRST_LINE}
if [ "$FIRST_LINE_LEN" -gt 60 ]; then
  echo "FAIL: First line is $FIRST_LINE_LEN chars (max 60)"
  FAILED=1
fi

# No external links in body
if echo "$CONTENT" | grep -qiE 'https?://'; then
  echo "FAIL: Contains external link"
  FAILED=1
fi

# No em dashes
if echo "$CONTENT" | grep -q '—'; then
  echo "FAIL: Contains em dash"
  FAILED=1
fi

# Must mention something specific (Mac Mini, 3 agents, or concrete detail)
if ! echo "$CONTENT" | grep -qiE 'mac mini|three agents|3 agents|openclaw|morning'; then
  echo "FAIL: Missing specific concrete details"
  FAILED=1
fi

# Word count between 150-500
WORD_COUNT=$(echo "$CONTENT" | wc -w | tr -d ' ')
if [ "$WORD_COUNT" -lt 100 ]; then
  echo "FAIL: Too short ($WORD_COUNT words, min 100)"
  FAILED=1
fi
if [ "$WORD_COUNT" -gt 600 ]; then
  echo "FAIL: Too long ($WORD_COUNT words, max 600)"
  FAILED=1
fi

# Must end with a question
LAST_LINE=$(echo "$CONTENT" | tail -1 | tr -d '[:space:]')
if [[ ! "$LAST_LINE" == *"?" ]]; then
  # Check second-to-last if last is empty
  LAST_LINE=$(echo "$CONTENT" | grep -v '^$' | tail -1)
  if [[ ! "$LAST_LINE" == *"?" ]]; then
    echo "FAIL: Doesn't end with a question"
    FAILED=1
  fi
fi

exit $FAILED
