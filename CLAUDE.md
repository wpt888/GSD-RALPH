# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

GSD-RALPH is a bash-based autonomous loop that spawns fresh Claude Code instances (via `claude --print`) to drive the [GSD](https://github.com/glittercowboy/get-shit-done) workflow without human intervention. It is **not** a library or application — it's an orchestration tool that runs *in the user's project directory*.

## Architecture

There are only three files that matter:

- **`gsd-loop.sh`** — The loop. Spawns `claude --print < PROMPT.md` repeatedly, detects completion signals in stdout, tracks commits, and handles rate limiting. Runs in the user's project directory, not in this repo.
- **`PROMPT.md`** — Instructions piped to each Claude instance. Tells Claude to read `.planning/STATE.md`, determine the next GSD lifecycle step, execute it, then emit a signal.
- **`test-project/`** — A minimal Node.js project used to validate the loop works. Not part of the tool itself.

## How the Loop Works

Each iteration spawns a fresh Claude with no memory of prior iterations. Inter-iteration state is maintained through:
1. `.planning/STATE.md` — GSD tracks current phase/plan/status
2. `.planning/ROADMAP.md` — GSD tracks all phases
3. `progress.txt` — Learnings appended by each iteration (created in the user's project)
4. `gsd-loop.log` — Full output log (created in the user's project)

The lifecycle per phase: `plan → execute → advance to next phase`. PROMPT.md explicitly forbids interactive GSD commands (`/gsd:discuss-phase`, `/gsd:verify-work`, `/gsd:progress`) because they require human input and would hang `--print` mode.

## Signal Protocol

The loop detects these signals in Claude's output to control flow:
- `<signal>PHASE_STEP_DONE</signal>` — Continue looping
- `<signal>PHASE_COMPLETE</signal>` — Increment phase counter, continue
- `<signal>MILESTONE_COMPLETE</signal>` — Exit 0 (success)
- `<signal>BLOCKED</signal>` — Exit 1 (failure)

Rate limit detection (`hit your limit`, `rate.limit`, `too many requests`) triggers a 30-minute sleep rather than burning iterations.

## Running

```bash
# From the user's project directory (must have .planning/ from GSD init):
/path/to/GSD-RALPH/gsd-loop.sh [max_iterations] [sleep_seconds]

# Defaults: 50 iterations, 5s sleep
```

## Modifying PROMPT.md

PROMPT.md is the most sensitive file. Changes affect every autonomous iteration. Key constraints:
- Must work with `claude --print` (non-interactive, stdin-only)
- Must instruct Claude to emit exactly one signal per iteration
- Must not reference interactive GSD commands
- Should instruct Claude to run `npm run build` after code changes
- Should instruct Claude to update `progress.txt` for cross-iteration learning
