# GSD-RALPH: Autonomous Overnight Development

Bash loop that spawns fresh Claude Code instances to drive the [GSD](https://github.com/glittercowboy/get-shit-done) workflow autonomously. Inspired by [Ralph](https://github.com/snarktank/ralph).

```
gsd-loop.sh (stupid bash loop)
  │
  ├── Iteration 1: claude --print < PROMPT.md
  │   └── Claude reads STATE.md → runs /gsd:discuss-phase 9
  │
  ├── Iteration 2: claude --print < PROMPT.md
  │   └── Claude reads STATE.md → runs /gsd:plan-phase 9
  │
  ├── Iteration 3: claude --print < PROMPT.md
  │   └── Claude reads STATE.md → runs /gsd:execute-phase 9
  │
  ├── Iteration 4: claude --print < PROMPT.md
  │   └── Claude reads STATE.md → runs /gsd:verify-work 9
  │
  ├── Iteration 5: claude --print < PROMPT.md
  │   └── Claude reads STATE.md → phase 10 next → /gsd:discuss-phase 10
  │
  └── ... until MILESTONE_COMPLETE
```

## How It Works

1. **`gsd-loop.sh`** — spawns `claude --print < PROMPT.md` in a loop
2. **`PROMPT.md`** — instructions telling Claude to read STATE.md and execute the next GSD step
3. **`progress.txt`** — learnings accumulate across iterations (created automatically)
4. **GSD** — already installed in your project, handles all the actual planning/execution

The bash script knows nothing about your project. The prompt tells Claude to read `.planning/STATE.md` and figure out what's next. GSD does the rest.

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- [GSD](https://github.com/glittercowboy/get-shit-done) installed in your project
- Project initialized with `/gsd:new-project`

## Quick Start

```bash
# 1. Go to your project
cd /path/to/your/project

# 2. Run the loop
/path/to/GSD-RALPH/gsd-loop.sh
```

## Usage

```bash
./gsd-loop.sh [max_iterations] [sleep_seconds]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| max_iterations | 50 | Maximum loop iterations |
| sleep_seconds | 5 | Pause between iterations |

### Examples

```bash
# Quick test (3 iterations)
./gsd-loop.sh 3

# Normal session
./gsd-loop.sh 50 5

# Overnight run
./gsd-loop.sh 200 10

# Overnight (background)
nohup ./gsd-loop.sh 200 10 &

# With tmux
tmux new -s gsd
./gsd-loop.sh 200 10
# Ctrl+B, D to detach
# tmux attach -t gsd to reattach
```

## Files

```
GSD-RALPH/
├── gsd-loop.sh     # The loop (bash)
├── PROMPT.md       # Instructions for Claude (piped via stdin)
└── README.md       # This file

Created in your project by the loop:
├── progress.txt    # Inter-iteration memory
└── gsd-loop.log    # Full output log
```

## Monitoring

```bash
# Live output (already visible in terminal via tee)

# Check log file
tail -f gsd-loop.log

# Check progress/learnings
cat progress.txt

# Check git commits made
git log --oneline -20
```

## Completion Signals

| Signal | Meaning | Exit Code |
|--------|---------|-----------|
| `MILESTONE_COMPLETE` | All phases done | 0 |
| `PHASE_COMPLETE` | One phase done, continues | — |
| `BLOCKED` | Cannot proceed | 1 |
| Max iterations | Loop exhausted | 1 |

## GSD Phase Lifecycle

Each phase goes through 4 steps. The loop handles one step per iteration:

```
discuss → plan → execute → verify → next phase
```

PROMPT.md tells Claude to read STATE.md, determine which step is needed, and execute it.

## Credits

- Loop pattern: [Ralph](https://github.com/snarktank/ralph) by snarktank
- Workflow: [GSD](https://github.com/glittercowboy/get-shit-done) by glittercowboy
