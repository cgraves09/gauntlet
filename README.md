# The Gauntlet

**Autonomous agent-level optimization for [OpenClaw](https://openclaw.ai).** Hill-climb on whole-agent quality by iteratively improving workspace files, skills, and knowledge bases against real task suites.

Like [AutoSkill](https://github.com/cgraves09/autoskill) but for **whole agents**, not just individual skill prompts. Like [AutoAgent](https://github.com/kevinrgu/autoagent) but for **domain-specific production agents**, not coding benchmarks.

---

## The Problem

You build an AI agent. It has a personality (SOUL.md), skills (SKILL.md files), a knowledge base, and helper scripts. Some of it works. Some doesn't. You manually tweak things, test by chatting with it, and hope for the best.

This doesn't scale. And you can never be sure which change actually helped.

## The Solution

The Gauntlet treats an agent's workspace as DNA and applies hill-climbing optimization:

1. Define a **task suite** — real tasks the agent should handle well
2. Define **scoring** — deterministic checks + LLM judge rubrics
3. Let a **meta-agent** iteratively mutate the workspace and measure the impact
4. **Keep** mutations that improve scores, **discard** those that don't
5. Git tracks every experiment so you know exactly what worked and why

One metric decides. Git tracks winners. The agent gets better autonomously.

---

## How It Works

```
                    ┌──────────────────────────┐
                    │     The Gauntlet Loop     │
                    └──────────┬───────────────┘
                               │
                    ┌──────────▼───────────────┐
                    │  1. Run task suite        │
                    │     against the agent     │
                    └──────────┬───────────────┘
                               │
                    ┌──────────▼───────────────┐
                    │  2. Score responses       │
                    │     (checks + LLM judge)  │
                    └──────────┬───────────────┘
                               │
                    ┌──────────▼───────────────┐
                    │  3. Diagnose failures     │
                    │     (read actual output)  │
                    └──────────┬───────────────┘
                               │
                    ┌──────────▼───────────────┐
                    │  4. Mutate ONE thing      │
                    │     in the workspace      │
                    └──────────┬───────────────┘
                               │
                    ┌──────────▼───────────────┐
                    │  5. Rerun + compare       │
                    │     Keep or discard?      │
                    └──────────┬───────────────┘
                               │
                               └──────── loop ──┘
```

The meta-agent (Claude Code with the gauntlet persona) runs this loop autonomously. It reads responses, diagnoses root causes, applies surgical mutations, and tracks every experiment in git history and a results TSV.

---

## Quick Start

### Prerequisites

- [OpenClaw](https://openclaw.ai) installed (`openclaw` CLI available)
- [Claude Code](https://claude.ai/code) installed (`claude` CLI available)
- An Anthropic API key

### 1. Clone the Gauntlet

```bash
git clone https://github.com/cgraves09/gauntlet.git
cd gauntlet
```

### 2. Set Up an Isolated OpenClaw Profile

The Gauntlet runs agents on an isolated profile so it never touches your production fleet.

```bash
# Create a new profile with its own gateway
openclaw --profile gauntlet configure

# Install and start the gateway on a dedicated port
openclaw --profile gauntlet gateway install --port 19701
openclaw --profile gauntlet gateway start

# Verify it's running
openclaw --profile gauntlet health
```

### 3. Install Your Agent

Copy your agent's workspace files into the `workspace/` directory:

```bash
# If starting from an existing agent
cp -r ~/.openclaw/workspace-my-agent/* workspace/

# Or create workspace/ with your SOUL.md, skills/, knowledge/, etc.
mkdir -p workspace/{skills,knowledge}
```

Then symlink or copy the workspace to the profile:

```bash
# Point the gauntlet profile to use workspace/ as its workspace
# Option A: Copy
cp -r workspace/ ~/.openclaw/workspace-gauntlet/

# Option B: Symlink (changes in workspace/ are live)
ln -sf "$(pwd)/workspace" ~/.openclaw/workspace-gauntlet
```

### 4. Write Tasks

Create task directories in `tasks/`:

```bash
mkdir -p tasks/my-first-task
```

Each task needs at minimum an `instruction.md`:

```markdown
# tasks/my-first-task/instruction.md
Write a LinkedIn post about how running AI agents in production
is different from running them in demos. Be specific and draw
from real experience.
```

Add deterministic checks (`checks.sh`):

```bash
#!/usr/bin/env bash
# tasks/my-first-task/checks.sh
RESPONSE=$(cat "$1")
FAILED=0

# No em dashes
echo "$RESPONSE" | grep -q '—' && echo "FAIL: em dash" && FAILED=1

# Must be 100-500 words
WC=$(echo "$RESPONSE" | wc -w | tr -d ' ')
[ "$WC" -lt 100 ] && echo "FAIL: too short ($WC words)" && FAILED=1
[ "$WC" -gt 500 ] && echo "FAIL: too long ($WC words)" && FAILED=1

exit $FAILED
```

Add an LLM judge rubric (`judge.md`):

```markdown
# tasks/my-first-task/judge.md
Score 0.0 to 1.0 on each dimension. Average for final score.

## Voice (0.0 - 1.0)
- 1.0: Sounds like a real person. Varied sentence lengths. No AI smell.
- 0.0: Obviously AI-generated. Corporate. Template-y.

## Value (0.0 - 1.0)
- 1.0: Reader walks away with a specific, actionable insight.
- 0.0: Generic advice that could apply to anything.
```

### 5. Run the Baseline

```bash
./scripts/run-suite.sh
```

This sends every task to the agent, collects responses, runs checks, and saves scores to `results/`.

### 6. Start the Optimization Loop

Launch Claude Code with the gauntlet persona:

```bash
# If you set up the persona command (see below)
persona gauntlet

# Or directly
claude --append-system-prompt-file ~/.claude/personas/gauntlet.md
```

Then tell it:

```
Read program.md and start the optimization loop.
The agent workspace is in workspace/.
Target: 80% pass rate.
```

The meta-agent will autonomously:
- Read the scores and responses
- Diagnose why tasks failed
- Mutate one thing in the workspace
- Commit, rerun, compare
- Keep or discard
- Repeat

---

## Project Structure

```
gauntlet/
├── README.md               # You are here
├── program.md              # Meta-agent instructions (the optimization loop)
│
├── workspace/              # THE AGENT (git-tracked, mutated by meta-agent)
│   ├── SOUL.md             #   Identity, workflow, rules
│   ├── IDENTITY.md         #   Name, emoji, vibe
│   ├── USER.md             #   Who the agent serves
│   ├── AGENTS.md           #   Governance, boundaries
│   ├── HEARTBEAT.md        #   Periodic tasks (if applicable)
│   ├── TOOLS.md            #   Environment config
│   ├── skills/             #   Skill definitions
│   │   └── skill-name/
│   │       ├── SKILL.md
│   │       ├── references/
│   │       └── scripts/
│   └── knowledge/          #   Domain knowledge base
│       ├── foundations/
│       └── [domain]/
│
├── tasks/                  # FIXED BENCHMARK (never modified during optimization)
│   └── task-name/
│       ├── instruction.md  #   Task prompt sent to agent
│       ├── checks.sh       #   Deterministic scoring (exit 0=pass, 1=fail)
│       ├── judge.md        #   LLM scoring rubric
│       └── context/        #   Optional: files for task context
│
├── scripts/
│   ├── run-suite.sh        # Run all tasks, collect scores
│   └── run-task.sh         # Run/debug a single task
│
└── results/
    ├── latest.json         # Per-task scores from most recent run
    ├── latest/             # Raw responses + per-task scores
    │   ├── task-name.response.md
    │   └── task-name.score.json
    └── history.tsv         # Score trajectory across all iterations
```

---

## Concepts

### What Gets Optimized vs. What's Fixed

| Mutable (`workspace/`)        | Fixed (`tasks/`)         |
|-------------------------------|--------------------------|
| SOUL.md (identity, workflow)  | instruction.md (prompts) |
| Skills (SKILL.md, references) | checks.sh (scoring)      |
| Knowledge base files          | judge.md (rubrics)       |
| Helper scripts                |                          |
| Config (IDENTITY, TOOLS, etc) |                          |

The meta-agent can change anything in `workspace/`. Tasks and scoring are the fixed benchmark — changing them during optimization would be cheating.

### Mutation Types

Ordered by typical impact on agent quality:

| # | Mutation | What It Does | Example |
|---|----------|-------------|---------|
| 1 | **add_knowledge** | Add or improve a knowledge base file | Add `knowledge/linkedin/algorithm-2026.md` |
| 2 | **add_gate** | Add a "STOP AND CHECK" step to the workflow | "Before replying, verify you checked the knowledge base" |
| 3 | **tighten_language** | Change "should" to "MUST", add negative examples | "You MUST end with a question" (not "try to end with...") |
| 4 | **add_script** | Create a helper for deterministic operations | `scripts/word-count.sh` for format validation |
| 5 | **restructure** | Reorganize SOUL.md sections for clarity | Move rules closer to where they're needed in the workflow |
| 6 | **add_negative_example** | Show what WRONG looks like | "DON'T start with 'I've been thinking about...'" |
| 7 | **remove_bloat** | Delete redundant instructions | Remove 3 paragraphs that say the same thing differently |
| 8 | **adjust_config** | Change model or agent settings | Switch from Sonnet to Opus for complex reasoning tasks |

### Scoring

Each task is scored **0.0 to 1.0** using two layers:

**Layer 1: Deterministic Checks** (`checks.sh`)
- Fast, reliable, binary
- Grep for required keywords, check word count, verify format, detect forbidden patterns
- If checks fail → score is 0.0, skip the LLM judge

**Layer 2: LLM Judge** (`judge.md`)
- Nuanced quality evaluation
- Multi-dimensional rubric (voice, value, relevance, etc.)
- Each dimension scored 0.0-1.0, averaged for final score

**Aggregate metrics:**
- `passed` — number of tasks scoring 1.0 (primary, used for keep/discard)
- `avg_score` — mean across all tasks (secondary, tracks gradual improvement)

### Keep/Discard Rules

After every mutation + rerun:

| Condition | Decision |
|-----------|----------|
| `passed` increased | **Keep** |
| `passed` same, workspace is simpler | **Keep** |
| `passed` decreased | **Discard** (`git revert HEAD`) |

### The Overfitting Test

Before committing any mutation, the meta-agent asks:

> *"If this exact task disappeared from the suite, would this still be a worthwhile improvement?"*

- **Good:** "Agent should always check knowledge base before giving domain advice"
- **Bad:** "When asked about LinkedIn hooks, always mention the 49-character rule"

---

## Writing Good Tasks

The quality of your task suite determines the quality of optimization. Here's how to write effective tasks:

### Task Distribution

Aim for coverage across the agent's responsibilities:

```
40% — Core competency (the thing the agent does most)
20% — Edge cases (unusual requests, ambiguous instructions)
20% — Negative cases (things the agent should refuse or redirect)
10% — Style/voice (correct tone and format)
10% — Complex scenarios (multi-step reasoning, context-dependent)
```

### Deterministic Checks (`checks.sh`)

Start with these — they're fast, reliable, and catch the obvious failures:

```bash
#!/usr/bin/env bash
RESPONSE=$(cat "$1")
FAILED=0

# Format checks
echo "$RESPONSE" | grep -q '—' && FAILED=1          # No em dashes
echo "$RESPONSE" | grep -qiE 'delve|tapestry' && FAILED=1  # No AI vocab

# Length checks  
WC=$(echo "$RESPONSE" | wc -w | tr -d ' ')
[ "$WC" -lt 100 ] && FAILED=1
[ "$WC" -gt 500 ] && FAILED=1

# Content checks
echo "$RESPONSE" | grep -qi 'specific keyword' || FAILED=1  # Must mention X

exit $FAILED
```

### LLM Judge Rubrics (`judge.md`)

Be specific about what each score means:

```markdown
## Dimension Name (0.0 - 1.0)
- 1.0: [Exact description of what excellence looks like]
- 0.7: [What "good but not great" looks like]
- 0.3: [What "mediocre" looks like]
- 0.0: [What "failure" looks like — be specific]
```

Bad: "Is the quality good?" (subjective, inconsistent)
Good: "Does the first line contain a specific number, contradiction, or question?" (observable, binary)

---

## The Full Pipeline

The Gauntlet is one piece of a three-stage agent development pipeline:

```
┌────────────────────┐     ┌────────────────────┐     ┌────────────────────┐
│   Agent Builder    │     │    The Gauntlet     │     │   Production       │
│                    │     │                     │     │                    │
│  Research domain   │────▶│  Run task suite     │────▶│  Copy workspace    │
│  Build knowledge   │     │  Score responses    │     │  to production     │
│  Create skills     │     │  Diagnose failures  │     │  profile           │
│  Write workspace   │     │  Mutate + measure   │     │                    │
│  files             │     │  Hill-climb to      │     │  Agent is live     │
│                    │     │  target score       │     │                    │
└────────────────────┘     └────────────────────┘     └────────────────────┘
```

### With AutoSkill

For individual skills that need deep optimization, use [AutoSkill](https://github.com/cgraves09/autoskill) inside the Gauntlet loop:

```
Gauntlet diagnoses: "content-reviewer skill isn't catching AI patterns"
    │
    ▼
AutoSkill: Optimize content-reviewer SKILL.md independently
    (generates test_cases.json, runs eval loop, improves pass rate)
    │
    ▼
Gauntlet: Rerun full suite with improved skill → score improved? Keep.
```

AutoSkill optimizes a **single prompt**. The Gauntlet optimizes the **whole system**.

---

## Example: Optimizing a LinkedIn Content Writer

Here's a real optimization run for a LinkedIn content writer agent:

### Task Suite (5 tasks)

| Task | Tests | What It Measures |
|------|-------|-----------------|
| `linkedin-hook` | First line under 60 chars, no links, ends with question | Hook quality + format |
| `linkedin-voice` | No AI vocab, no em dashes, sentence length variation | Voice authenticity |
| `linkedin-contrarian` | Takes a specific position, references production experience | Depth of thinking |
| `linkedin-news-react` | Second-order analysis, not just summary | Domain expertise |
| `linkedin-negative` | Refuses off-brand request appropriately | Boundaries |

### Optimization Trajectory

```
Iter  Commit   Score  Passed  Status   Mutation          Description
───────────────────────────────────────────────────────────────────────
1     abc123   0.40   2/5     baseline (initial run)
2     def456   0.50   3/5     keep     add_knowledge     Added algorithm-2026 strategy doc
3     ghi789   0.45   2/5     discard  tighten           Made SOUL.md rules stricter (too rigid)
4     jkl012   0.60   3/5     keep     add_gate          Added "check knowledge base" pre-step
5     mno345   0.70   4/5     keep     add_neg_example   Added "DON'T start with..." examples
6     pqr678   0.65   3/5     discard  restructure       Reorganized sections (broke flow)
7     stu901   0.80   4/5     keep     add_knowledge     Added swipe file with real examples
8     vwx234   0.90   5/5     keep     tighten           Added sentence length variation rule
```

8 iterations. From 40% to 90%. The agent now consistently produces LinkedIn posts that pass format checks AND quality evaluation.

---

## Setting Up the `persona` Command

Add this to your `~/.bashrc` or `~/.zshrc`:

```bash
PERSONA_DIR="$HOME/.claude/personas"

persona() {
  if [ $# -eq 0 ]; then
    echo "Available personas:"
    echo ""
    for f in "$PERSONA_DIR"/*.md; do
      [ -f "$f" ] || continue
      local name=$(basename "$f" .md)
      local desc=$(head -1 "$f" | sed 's/^# //')
      printf "  %-20s %s\n" "$name" "$desc"
    done
    echo ""
    echo "Usage: persona <name> [claude args...]"
    return 0
  fi

  local name="$1"; shift
  local file="$PERSONA_DIR/$name.md"

  if [ ! -f "$file" ]; then
    echo "Persona '$name' not found."
    return 1
  fi

  echo "Loading persona: $name"
  claude --append-system-prompt-file "$file" "$@"
}
```

Then create `~/.claude/personas/gauntlet.md` with the meta-agent instructions (see `program.md` for the full loop).

---

## OpenClaw Integration

The Gauntlet uses OpenClaw's gateway as the test harness. No custom adapter needed — OpenClaw already provides everything:

```bash
# Send a task to the agent
openclaw --profile gauntlet agent --message "task instruction" --json

# Reset session between tasks (clean slate)
openclaw --profile gauntlet gateway call sessions.reset \
  --params '{"key":"gauntlet:task-name"}'

# Check agent health
openclaw --profile gauntlet health

# View session logs
openclaw --profile gauntlet gateway call sessions.list --json
```

### Why an Isolated Profile?

The Gauntlet creates an isolated OpenClaw profile (`--profile gauntlet`) so optimization never touches your production agents. It has its own:
- Gateway on a dedicated port
- State directory (`~/.openclaw-gauntlet/`)
- Workspace (symlinked from `gauntlet/workspace/`)
- Session storage
- Credentials

---

## Learnings from AutoSkill

These patterns, discovered during [AutoSkill](https://github.com/cgraves09/autoskill) development (45% → 90% skill reliability), apply directly to agent-level optimization:

1. **"STOP AND CHECK" gates are the single most effective pattern.** One self-question before every reply beats every longer, more detailed instruction.

2. **"MUST" beats "should."** Absolute language correlates with compliance. Vague instructions get ignored at the agent level too.

3. **Structure > length.** A well-organized 60-line SOUL.md outperforms a verbose 150-line one.

4. **Unstructured rewrites destroy progress.** Named mutation operators (add_gate, tighten_language) force surgical changes. Letting the optimizer freely rewrite files produces regressions.

5. **The same agent scores differently each run.** Expect 5-10% variance. Use the `passed` count (binary) as primary metric — it's more stable than `avg_score`.

6. **Plateau breaking requires structural shifts.** After 5 stale iterations, don't tweak wording — restructure the workflow or add a new knowledge source.

7. **Deterministic checks first, LLM judge second.** Grep is faster and more reliable than asking an LLM "was this good?"

8. **Separate the optimizer and the agent.** When Claude improves an agent AND judges the result, it grades charitably. The task suite + scoring must be fixed.

---

## Contributing

PRs welcome. The most valuable contributions:

1. **Task suites** — Pre-built task suites for common agent types (content writer, research assistant, customer support, etc.)
2. **Scoring improvements** — Better deterministic checks, more reliable LLM judge patterns
3. **Mutation strategies** — New mutation types that produce high-impact improvements
4. **Adapters** — Support for runtimes beyond OpenClaw (Claude Code, custom agents)

---

## Related Projects

| Project | Scope | Optimizes |
|---------|-------|-----------|
| [autoresearch](https://github.com/karpathy/autoresearch) | Research papers | Research direction + methodology |
| [AutoSkill](https://github.com/cgraves09/autoskill) | Single skill prompt | SKILL.md wording + structure |
| [AutoAgent](https://github.com/kevinrgu/autoagent) | Coding agent harness | Agent tools + system prompt |
| **The Gauntlet** | Complete production agent | Workspace + skills + knowledge + scripts |

The Gauntlet sits at the top of the stack — it optimizes the entire agent system, calling AutoSkill when individual skills need deep work.

---

## License

MIT
