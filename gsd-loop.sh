#!/bin/bash
# gsd-loop.sh - Autonomous GSD execution loop
# Spawns fresh Claude Code instances to drive GSD workflow
#
# Usage: ./gsd-loop.sh [max_iterations] [sleep_seconds] [iter_timeout_seconds]
# Run from your project directory (must have .planning/)
#
# Inspired by: https://github.com/snarktank/ralph
# Workflow:    https://github.com/glittercowboy/get-shit-done

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_ITERATIONS=${1:-50}
SLEEP_SECONDS=${2:-5}
ITER_TIMEOUT=${3:-3600}  # Max seconds per claude invocation (default: 60 min)
LOG_FILE="gsd-loop.log"
PROGRESS_FILE="progress.txt"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Filter stream-json into human-readable output
# Uses external awk script for performance (bash chokes on 60KB+ JSON lines)
format_stream() {
  awk -f "$SCRIPT_DIR/format-stream.awk"
}

# Header
echo ""
log "${CYAN}══════════════════════════════════════════════════════════${NC}"
log "${CYAN}  GSD-RALPH Autonomous Loop v2.0${NC}"
log "${CYAN}  Claude Code + GSD = Overnight Development${NC}"
log "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo ""

# Preflight checks
if [ ! -d ".planning" ]; then
  log "${RED}ERROR: .planning/ not found. Is GSD initialized?${NC}"
  log "Run: claude \"/gsd:new-project\" first"
  exit 1
fi

if ! command -v claude &> /dev/null; then
  log "${RED}ERROR: claude CLI not found${NC}"
  exit 1
fi

if [ ! -f "$SCRIPT_DIR/PROMPT.md" ]; then
  log "${RED}ERROR: PROMPT.md not found in $SCRIPT_DIR${NC}"
  exit 1
fi

# Initialize progress file if missing
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# GSD-RALPH Progress Log" > "$PROGRESS_FILE"
  echo "# Learnings accumulate here across iterations" >> "$PROGRESS_FILE"
  echo "" >> "$PROGRESS_FILE"
fi

log "Working directory: $(pwd)"
log "Prompt file: $SCRIPT_DIR/PROMPT.md"
log "Max iterations: $MAX_ITERATIONS"
log "Sleep between: ${SLEEP_SECONDS}s"
log "Iteration timeout: ${ITER_TIMEOUT}s"
echo ""

TOTAL_COMMITS=0
COMPLETED_PHASES=0
EMPTY_COUNT=0
ITER_LOG=""

# Cleanup temp file on exit/interrupt
cleanup() { rm -f "$ITER_LOG"; }
trap cleanup EXIT INT TERM

i=1
while [ "$i" -le "$MAX_ITERATIONS" ]; do
  log "${YELLOW}──────────────────────────────────────────────────────${NC}"
  log "${YELLOW}  Iteration $i/$MAX_ITERATIONS${NC}"
  log "${YELLOW}──────────────────────────────────────────────────────${NC}"

  START_COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo "0")

  # Spawn fresh Claude instance with PROMPT.md via stdin redirect
  # stream-json shows live activity, PIPESTATUS[0] captures real exit code
  ITER_LOG=$(mktemp)

  log "  Spawning claude (timeout: ${ITER_TIMEOUT}s)..."
  set +e
  timeout --kill-after=30 "$ITER_TIMEOUT" claude \
    --dangerously-skip-permissions \
    --print \
    --output-format stream-json \
    --verbose \
    < "$SCRIPT_DIR/PROMPT.md" 2>&1 | tee "$ITER_LOG" | format_stream
  CLAUDE_EXIT=${PIPESTATUS[0]}
  set -e

  # Extract final result text from stream-json for signal detection
  # The "type":"result" line contains the complete output in "result" field
  RESULT_TEXT=$(grep '"type":"result"' "$ITER_LOG" | sed 's/.*"result":"//' | sed 's/","stop_reason.*//' || true)

  # Save to main log
  cat "$ITER_LOG" >> "$LOG_FILE"
  OUTPUT="$RESULT_TEXT"
  rm -f "$ITER_LOG"

  if [ "$CLAUDE_EXIT" -eq 124 ]; then
    log "${RED}  Claude timed out (SIGTERM) after ${ITER_TIMEOUT}s${NC}"
  elif [ "$CLAUDE_EXIT" -eq 137 ]; then
    log "${RED}  Claude killed (SIGKILL) after timeout${NC}"
  elif [ "$CLAUDE_EXIT" -ne 0 ]; then
    log "${RED}  Claude exited with code $CLAUDE_EXIT${NC}"
  fi

  # Skip iteration if output is empty (claude crashed or timed out)
  if [ -z "$OUTPUT" ]; then
    EMPTY_COUNT=$((EMPTY_COUNT + 1))
    log "${YELLOW}  No output from claude ($EMPTY_COUNT consecutive)${NC}"
    if [ "$EMPTY_COUNT" -ge 3 ]; then
      log "${YELLOW}  3 consecutive empty outputs — possible rate limit. Sleeping 30 min...${NC}"
      sleep 1800
      EMPTY_COUNT=0
    fi
    i=$((i + 1))
    continue
  fi
  EMPTY_COUNT=0

  # Rate limit detection — wait until reset instead of burning iterations
  if echo "$OUTPUT" | grep -qi "hit your limit\|rate\.limit\|too many requests"; then
    # Try to extract reset time from output (e.g., "resets 5am")
    RESET_INFO=$(echo "$OUTPUT" | grep -oi "resets [0-9]*[ap]m[^)]*" | head -1 || true)
    log "${YELLOW}  Rate limited. ${RESET_INFO:-Waiting 30 minutes...}${NC}"
    log "${YELLOW}  Sleeping until limit resets...${NC}"
    sleep 1800  # 30 minutes
    # Do NOT increment i — retry the same iteration
    continue
  fi

  # Count commits
  END_COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo "0")
  NEW_COMMITS=$((END_COMMITS - START_COMMITS))
  TOTAL_COMMITS=$((TOTAL_COMMITS + NEW_COMMITS))

  if [ "$NEW_COMMITS" -gt 0 ]; then
    log "${GREEN}  +$NEW_COMMITS commit(s) this iteration${NC}"
  fi

  # Check completion signals
  if echo "$OUTPUT" | grep -q "<signal>MILESTONE_COMPLETE</signal>"; then
    log ""
    log "${GREEN}══════════════════════════════════════════════════════════${NC}"
    log "${GREEN}  MILESTONE COMPLETE${NC}"
    log "${GREEN}  Iterations: $i | Commits: $TOTAL_COMMITS | Phases: $COMPLETED_PHASES${NC}"
    log "${GREEN}══════════════════════════════════════════════════════════${NC}"
    exit 0
  fi

  if echo "$OUTPUT" | grep -q "<signal>PHASE_COMPLETE</signal>"; then
    COMPLETED_PHASES=$((COMPLETED_PHASES + 1))
    log "${GREEN}  Phase complete! (total: $COMPLETED_PHASES)${NC}"
  fi

  if echo "$OUTPUT" | grep -q "<signal>BLOCKED</signal>"; then
    log ""
    log "${RED}══════════════════════════════════════════════════════════${NC}"
    log "${RED}  BLOCKED - Check progress.txt for details${NC}"
    log "${RED}  Iterations: $i | Commits: $TOTAL_COMMITS${NC}"
    log "${RED}══════════════════════════════════════════════════════════${NC}"
    exit 1
  fi

  # Warn if no signal was detected at all
  if ! echo "$OUTPUT" | grep -q "<signal>.*</signal>"; then
    log "${YELLOW}  WARNING: No signal detected in output${NC}"
  fi

  # Sleep before next iteration
  if [ "$i" -lt "$MAX_ITERATIONS" ]; then
    log "  Next iteration in ${SLEEP_SECONDS}s..."
    sleep "$SLEEP_SECONDS"
  fi

  i=$((i + 1))
done

log ""
log "${YELLOW}══════════════════════════════════════════════════════════${NC}"
log "${YELLOW}  Max iterations reached${NC}"
log "${YELLOW}  Commits: $TOTAL_COMMITS | Phases: $COMPLETED_PHASES${NC}"
log "${YELLOW}══════════════════════════════════════════════════════════${NC}"
exit 1
