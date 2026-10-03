# Claude Lean

A token-safe Claude Code setup: one Opus coordinator, cheaper Sonnet subagents for wide sweeps, an Opus worker for building, and the Opus advisor for review.

![Lean Claude agent map](docs/infographic.png)

The source of the infographic is [docs/infographic.html](docs/infographic.html).

## How it works

| Role | Model | Effort | Job |
|---|---|---|---|
| Root / coordinator | Opus | medium | Plans, delegates only wide sweeps, integrates and verifies |
| `explorer` | Sonnet | medium | Read-only code search, returns `file:line` summaries |
| `worker` | Opus | medium | Implements one bounded task and runs its tests |
| `researcher` | Sonnet | medium | Outside docs, APIs and versions, with sources |
| Advisor | Opus | n/a | Independent review before a big plan, on a repeated error, and before closing a task |

One task, one owner. Delegate only when it pays off: each subagent starts cold, so a few direct greps in the main session are cheaper than spawning one for a narrow lookup.

## What's included

```
claude/
  CLAUDE.md            global rules: plan, verify, subagent limits, token safety
  settings.json        model, effortLevel, advisorModel
  agents/
    explorer.md
    researcher.md
    worker.md
docs/
  infographic.html
  infographic.png
install.sh
```

## Install

```bash
git clone <this repo> claude-lean
cd claude-lean
./install.sh
```

`install.sh` copies the files into `~/.claude` and backs up anything it replaces to `~/.claude/backup-<timestamp>/`. For `settings.json` it only sets `model`, `effortLevel` and `advisorModel`, and keeps all your other settings.

It replaces `~/.claude/CLAUDE.md`. If you had your own rules, merge them back from the backup folder.

To install into another folder, set `CLAUDE_HOME`:

```bash
CLAUDE_HOME=/path/to/.claude ./install.sh
```

### Manual install

Copy `claude/agents/*.md` into `~/.claude/agents/`, add the rules from `claude/CLAUDE.md` to `~/.claude/CLAUDE.md`, and add the three keys from `claude/settings.json` to `~/.claude/settings.json`.

### One project only

Put the same files in a repo instead of your home folder: `.claude/agents/`, `CLAUDE.md` at the repo root, and `.claude/settings.json`. Everyone who works in that repo gets the setup.

## Tips

- Start a new session after installing. Settings and rules are read at startup.
- Effort is `medium` by default. Type `/effort high` in a session for a hard task.
- The advisor sends the whole conversation to Opus on each call, so keep it to the three moments above.
