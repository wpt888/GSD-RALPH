# GSD Autonomous Agent Instructions

You are running inside an autonomous loop. Each iteration you get fresh context.
There is NO human present. You cannot ask questions or wait for input.
Follow these steps EXACTLY.

## Step 1: Read State

Read these files to understand where the project is:
1. `.planning/STATE.md` — your current position (phase, plan, status, blockers)
2. `.planning/ROADMAP.md` — all phases and their status
3. `progress.txt` (if it exists) — learnings from previous iterations

## Step 2: Determine Next Action

Based on STATE.md and ROADMAP.md, determine which step is needed:

Based on STATE.md, determine the phase number N and run the EXACT command:

- If the phase has NO `*-PLAN.md` files in `.planning/phases/`: Run `/gsd:plan-phase N`
- If the phase HAS `*-PLAN.md` files but NO matching `*-SUMMARY.md` files: Run `/gsd:execute-phase N`
- If the phase has all plans executed (matching summaries): Update STATE.md to phase N+1, then STOP
- If all phases are complete: Output MILESTONE_COMPLETE signal

FORBIDDEN COMMANDS (these wait for human input and will hang):
- `/gsd:discuss-phase` — NEVER use this
- `/gsd:verify-work` — NEVER use this
- `/gsd:progress` — NEVER use this

ONLY use `/gsd:plan-phase N` or `/gsd:execute-phase N`. Nothing else.

## Step 3: Quality Check

After making code changes, ALWAYS run:
```bash
npm run build
```

If the build fails, fix the errors before committing. Do NOT commit broken code.

## Step 4: Commit and Push

If you made code changes and the build passes:
```bash
git add <specific-files>
git commit -m "feat(NN-MM): description"
git push
```

## Step 5: Update Progress

Append a brief summary to `progress.txt`:
```
## Iteration [N] - [timestamp]
- Phase: N
- Action: what you did
- Files changed: list
- Decisions made: any choices you made autonomously
- Learnings: anything the next iteration should know
- Status: completed / partial / error
```

## Step 6: Output Completion Signal

End your response with EXACTLY ONE of these signals on its own line:

- `<signal>PHASE_STEP_DONE</signal>` — completed one step, more work in this phase
- `<signal>PHASE_COMPLETE</signal>` — entire phase is done (all plans executed)
- `<signal>MILESTONE_COMPLETE</signal>` — all phases done, milestone finished
- `<signal>BLOCKED</signal>` — cannot proceed (missing API keys, external dependency, etc.)

You MUST output exactly one signal. The loop depends on it.

## Rules

- You are AUTONOMOUS. Never wait for human input. Make decisions yourself.
- ONE lifecycle step per iteration (plan OR execute, not both)
- STOP after completing the step — the loop will spawn you again
- ALWAYS read STATE.md first — never assume you know the current position
- ALWAYS update progress.txt before finishing
- NEVER skip the build check after code changes
- If something fails, describe what happened in progress.txt so the next iteration can try differently
- If you see the same error in progress.txt from a previous iteration, try a DIFFERENT approach
