#!/bin/bash
# debug-loop.sh - Autonomous debug loop
# Spawns fresh Claude Code instances to debug a specific problem
# Keeps going until the bug is fixed or max iterations exhausted
#
# Usage: ./debug-loop.sh "bug description" [max_iterations] [sleep_seconds]
# Run from your project directory — nothing gets copied, just like gsd-loop.sh
#
# Example:
#   /path/to/GSD-RALPH/debug-loop.sh "OP matching pe eMag P2 nu funcționează în facturi.py, fix-ul din commit a08214a nu a rezolvat" 30 5

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUG_DESCRIPTION="${1:?Usage: debug-loop.sh \"bug description\" [max_iterations] [sleep_seconds]}"
MAX_ITERATIONS=${2:-50}
SLEEP_SECONDS=${3:-5}
LOG_FILE="debug-loop.log"
PROGRESS_FILE="debug-progress.txt"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Header
echo ""
log "${CYAN}══════════════════════════════════════════════════════════${NC}"
log "${CYAN}  GSD-RALPH Debug Loop${NC}"
log "${CYAN}  Autonomous bug hunting until fixed${NC}"
log "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo ""

# Preflight checks
if ! command -v claude &> /dev/null; then
  log "${RED}ERROR: claude CLI not found${NC}"
  exit 1
fi

if [ ! -f "$SCRIPT_DIR/DEBUG-PROMPT.md" ]; then
  log "${RED}ERROR: DEBUG-PROMPT.md not found in $SCRIPT_DIR${NC}"
  exit 1
fi

# Initialize progress file if missing
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Debug Progress Log" > "$PROGRESS_FILE"
  echo "# Learnings accumulate here across iterations" >> "$PROGRESS_FILE"
  echo "" >> "$PROGRESS_FILE"
fi

log "Working directory: $(pwd)"
log "Bug: $BUG_DESCRIPTION"
log "Max iterations: $MAX_ITERATIONS"
log "Sleep between: ${SLEEP_SECONDS}s"
echo ""

TOTAL_COMMITS=0

for i in $(seq 1 $MAX_ITERATIONS); do
  log "${YELLOW}──────────────────────────────────────────────────────${NC}"
  log "${YELLOW}  Debug Iteration $i/$MAX_ITERATIONS${NC}"
  log "${YELLOW}──────────────────────────────────────────────────────${NC}"

  START_COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo "0")

  # Build prompt: template + bug description injected
  PROMPT_TMP=$(mktemp)
  sed "s|{{BUG_DESCRIPTION}}|$BUG_DESCRIPTION|g" "$SCRIPT_DIR/DEBUG-PROMPT.md" > "$PROMPT_TMP"

  # Spawn fresh Claude instance
  ITER_LOG=$(mktemp)
  claude \
    --dangerously-skip-permissions \
    --print \
    < "$PROMPT_TMP" 2>&1 | tee "$ITER_LOG" || true

  rm -f "$PROMPT_TMP"

  # Save to main log
  cat "$ITER_LOG" >> "$LOG_FILE"
  OUTPUT=$(cat "$ITER_LOG")
  rm -f "$ITER_LOG"

  # Rate limit detection
  if echo "$OUTPUT" | grep -qi "hit your limit\|rate.limit\|too many requests"; then
    RESET_INFO=$(echo "$OUTPUT" | grep -oi "resets [0-9]*[ap]m[^)]*" | head -1)
    log "${YELLOW}  Rate limited. ${RESET_INFO:-Waiting 30 minutes...}${NC}"
    sleep 1800
    continue
  fi

  # Count commits
  END_COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo "0")
  NEW_COMMITS=$((END_COMMITS - START_COMMITS))
  TOTAL_COMMITS=$((TOTAL_COMMITS + NEW_COMMITS))

  if [ $NEW_COMMITS -gt 0 ]; then
    log "${GREEN}  +$NEW_COMMITS commit(s) this iteration${NC}"
  fi

  # Check completion signals
  if echo "$OUTPUT" | grep -q "<signal>BUG_FIXED</signal>"; then
    log ""
    log "${GREEN}══════════════════════════════════════════════════════════${NC}"
    log "${GREEN}  BUG FIXED!${NC}"
    log "${GREEN}  Iterations: $i | Commits: $TOTAL_COMMITS${NC}"
    log "${GREEN}══════════════════════════════════════════════════════════${NC}"
    exit 0
  fi

  if echo "$OUTPUT" | grep -q "<signal>BLOCKED</signal>"; then
    log ""
    log "${RED}══════════════════════════════════════════════════════════${NC}"
    log "${RED}  BLOCKED - Check debug-progress.txt for details${NC}"
    log "${RED}  Iterations: $i | Commits: $TOTAL_COMMITS${NC}"
    log "${RED}══════════════════════════════════════════════════════════${NC}"
    exit 1
  fi

  if echo "$OUTPUT" | grep -q "<signal>STILL_DEBUGGING</signal>"; then
    log "${CYAN}  Still investigating, continuing...${NC}"
  fi

  # Sleep before next iteration
  if [ $i -lt $MAX_ITERATIONS ]; then
    log "  Next iteration in ${SLEEP_SECONDS}s..."
    sleep "$SLEEP_SECONDS"
  fi
done

log ""
log "${YELLOW}══════════════════════════════════════════════════════════${NC}"
log "${YELLOW}  Max iterations reached — bug not yet fixed${NC}"
log "${YELLOW}  Commits: $TOTAL_COMMITS${NC}"
log "${YELLOW}  Check debug-progress.txt for current state${NC}"
log "${YELLOW}══════════════════════════════════════════════════════════${NC}"
exit 1
