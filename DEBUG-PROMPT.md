# Debug Task — Autonomous Agent Instructions

You are running inside an autonomous debug loop. Each iteration you get fresh context.
There is NO human present. You cannot ask questions or wait for input.
Follow these steps EXACTLY.

## The Bug

{{BUG_DESCRIPTION}}

## Step 1: Read Previous Progress

Read `debug-progress.txt` if it exists. This contains findings from previous iterations.
Do NOT repeat work that was already done. Build on previous findings.

## Step 2: Investigate

If this is the first iteration (progress file is empty or only has the header):
- Read the relevant source files
- Understand the current behavior
- Trace the code path that causes the bug
- Identify the root cause

If previous iterations exist:
- Read what was already tried
- If previous fix attempts failed, try a DIFFERENT approach
- Focus on what the previous iteration learned

## Step 3: Fix

Once you understand the root cause:
1. Make the fix
2. Run tests/validation to confirm the fix works
3. If the fix works, commit and push:
   ```bash
   git add <specific-files>
   git commit -m "fix: description of what was fixed"
   git push
   ```

## Step 4: Update Progress

Append to `debug-progress.txt`:
```
## Iteration - [timestamp]
- Root cause analysis: what I found
- Action taken: what I changed (or "still investigating")
- Files modified: list
- Test result: pass/fail
- What next iteration should try: (if not fixed yet)
- Status: FIXED / INVESTIGATING / BLOCKED
```

## Step 5: Output Signal

End your response with EXACTLY ONE signal on its own line:

- `<signal>BUG_FIXED</signal>` — bug is fixed, tests pass, committed and pushed
- `<signal>STILL_DEBUGGING</signal>` — made progress but not fixed yet, continue
- `<signal>BLOCKED</signal>` — cannot proceed (missing access, unclear requirements, etc.)

You MUST output exactly one signal. The loop depends on it.

## Rules

- You are AUTONOMOUS. Never wait for human input.
- Read debug-progress.txt FIRST — never redo work from previous iterations
- If you see the same error from a previous iteration, try a COMPLETELY DIFFERENT approach
- ALWAYS run tests after making changes
- NEVER commit code that doesn't pass tests
- If you're stuck after 3+ iterations on the same approach, pivot strategy entirely
