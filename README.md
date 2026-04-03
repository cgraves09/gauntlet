# The Gauntlet

Autonomous agent-level optimization for OpenClaw. Like [AutoSkill](https://github.com/cgraves09/autoskill) but for **whole agents**, not just individual skills.

AutoSkill optimizes a single SKILL.md prompt. The Gauntlet optimizes the complete agent — SOUL.md, skills, knowledge base, scripts, and how they all work together — by running real tasks against a live OpenClaw gateway and hill-climbing on quality scores.

## How It Works

```
1. Agent Builder creates an agent (workspace + skills + knowledge)
2. Gauntlet installs it on an isolated OpenClaw profile
3. Sends a task suite through the gateway
4. Scores responses (deterministic checks + LLM judge)
5. Meta-agent diagnoses failures and mutates ONE thing
6. Reruns suite → score improved? Keep. Not? Discard.
7. Repeat until target score or plateau.
```

## Quick Start

```bash
# 1. Set up an isolated OpenClaw profile for testing
openclaw --profile gauntlet configure

# 2. Install your agent's workspace files
cp -r my-agent-workspace/ ~/.openclaw/workspace-gauntlet/

# 3. Start the gateway
openclaw --profile gauntlet gateway install --port 19701
openclaw --profile gauntlet gateway start

# 4. Run the task suite
./scripts/run-suite.sh

# 5. Launch the meta-agent to start optimizing
persona gauntlet
# Then: "Read program.md and start the optimization loop"
```

## Project Structure

```
gauntlet/
├── program.md              # Meta-agent instructions (the optimization loop)
├── README.md               # You are here
├── workspace/              # The agent being trained (git-tracked, mutated)
│   ├── SOUL.md
│   ├── skills/
│   ├── knowledge/
│   └── ...
├── tasks/                  # Fixed benchmark (DO NOT modify during optimization)
│   └── task-name/
│       ├── instruction.md  # Task prompt sent to agent
│       ├── checks.sh       # Deterministic scoring (grep, word count, format)
│       └── judge.md        # LLM scoring rubric
├── scripts/
│   ├── run-suite.sh        # Run all tasks, collect scores
│   └── run-task.sh         # Run a single task (debugging)
└── results/
    ├── latest.json         # Most recent scores
    ├── latest/             # Raw responses + per-task scores
    └── history.tsv         # Score trajectory across iterations
```

## The Pipeline

```
Agent Builder → creates agent → Gauntlet → optimizes agent → Graduate to production
   (persona)                      (this)                        (copy to fleet)
```

## What Gets Optimized vs. What's Fixed

| Mutable (workspace/) | Fixed (tasks/) |
|---|---|
| SOUL.md | instruction.md |
| Skills (SKILL.md, references/) | checks.sh |
| Knowledge base | judge.md |
| Scripts | |
| IDENTITY.md, TOOLS.md, etc. | |

## Mutation Types

Ordered by typical impact:

1. **add_knowledge** — Add or improve a knowledge base file
2. **add_gate** — Add a "STOP AND CHECK" step to the workflow
3. **tighten_language** — Change "should" to "MUST", add negative examples
4. **add_script** — Create a helper script for deterministic operations
5. **restructure** — Reorganize SOUL.md for clarity
6. **add_negative_example** — Show what WRONG looks like
7. **remove_bloat** — Delete redundant instructions
8. **adjust_config** — Change model or agent configuration

## Scoring

Each task gets 0.0 to 1.0:
- **Deterministic checks** run first (fast, reliable — grep, word count, format)
- **LLM judge** runs second (nuanced quality evaluation using judge.md rubric)
- Deterministic failure = 0.0 score (no LLM judge needed)

**Keep/discard rules:**
- Score improved → keep
- Score same + simpler workspace → keep
- Score decreased → `git revert HEAD`

## Related Projects

- [AutoSkill](https://github.com/cgraves09/autoskill) — Skill-level prompt optimization
- [AutoAgent](https://github.com/kevinrgu/autoagent) — Inspiration for the container-based training loop
- [autoresearch](https://github.com/karpathy/autoresearch) — The original hill-climbing concept
