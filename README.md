# Claude Lean

A token-safe Claude Code setup: one Opus coordinator, Haiku subagents for code search, Sonnet subagents for code review and research, an Opus worker for building, and the Opus advisor for plans. `/ship` runs a feature through spec, build and review.

![Lean Claude agent map](docs/infographic.png)

The source of the infographic is [docs/infographic.html](docs/infographic.html).

## How it works

| Role | Model | Effort | Job |
|---|---|---|---|
| Root / coordinator | Opus | high | Plans, delegates only wide sweeps, integrates and verifies |
| `explorer` | Haiku | low | Read-only code search, returns `file:line` summaries |
| `worker` | Opus | medium | Implements one bounded task and runs its tests; reports `STATUS: READY` or `BLOCKED` |
| `reviewer` | Sonnet | medium | Read-only review of a change; reports `VERDICT: PASS` or `CHANGES` with `path:line` findings |
| `researcher` | Sonnet | medium | Outside docs, APIs and versions, with sources |
| Advisor | Opus | n/a | Independent review before a big plan and on a repeated error |

One task, one owner. Delegate only when it pays off: each subagent starts cold, so a few direct greps in the main session are cheaper than spawning one for a narrow lookup.

## Shipping a feature

Type `/ship <feature>` in any git repo:

```
spec (coordinator) -> you approve -> worker builds in its worktree -> reviewer
                                         ^                              |
                                         +--- CHANGES (max 2 resumes) --+
                                                                        v PASS
                                         gate: READY or ESCALATE -> ready for /ship approve (or merged with --merge)
```

- The coordinator writes `spec.md` with acceptance criteria and waits for your approval before any code is written.
- Each job gets its own git worktree at `../<repo>-ship/<job-id>/` on a `ship/<job-id>` branch, so your checkout is never switched and you can keep working. Open several sessions and run `/ship` in each to build features in parallel. A job starts from the last commit on your branch, without your uncommitted changes.
- The worker builds and tests in the worktree. The reviewer checks the diff against the spec. On `CHANGES` the same worker is resumed, at most twice.
- The worker records evidence for every acceptance criterion in `build.md`; the reviewer re-runs at least one. At the gate, the coordinator checks that evidence, re-runs one criterion itself, and checks the branch merges cleanly with `git merge-tree`.
- The gate escalates changes to payments, auth, secrets, deploy or CI config, schemas, production data or dependencies. Otherwise the job stops at `ready`; `--merge` merges it into your branch straight away. Merging needs your checkout clean and on that branch, and removes the worktree afterwards. It never pushes.
- When a job is `ready` or needs you:

  ```
  /ship approve <job-id>           merge it into the branch it started from
  /ship rework <job-id> <note>     send it back to a fresh worker with your feedback
  ```

  `approve` asks you to confirm first if the gate escalated or the build never reached READY. `rework` also recovers a job whose session ended mid-run, after you confirm nothing else is working on it. Run `/ship` from your main checkout, not from inside a worktree.

  To throw a job away: `git worktree remove --force <worktree> && git branch -D ship/<job-id>`.
- Job files live in `.lean/jobs/<job-id>/` (state in `job.json`), which `/ship` adds to `.git/info/exclude`, so they are never committed.
- Agents read build, test and lint commands from the repo's `CLAUDE.md` or `AGENTS.md`, so make sure those are written down.
- Only you can start `/ship`; Claude never runs it on its own (`disable-model-invocation`). Check its resident cost with `/context` after installing.

## What's included

```
claude/
  CLAUDE.md            global rules: plan, verify, subagent limits, token safety, compact
  settings.json        model, effortLevel, modelSettings, advisorModel
  agents/
    explorer.md
    researcher.md
    worker.md
    reviewer.md
  skills/
    ship/SKILL.md      /ship: spec, build, review, gate
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

`install.sh` copies the files into `~/.claude` and backs up anything it changes to `~/.claude/backup-<timestamp>/`. Files that are already up to date are skipped, so running it again is safe. For `settings.json` it only adds `model`, `effortLevel`, `modelSettings` and `advisorModel`, and keeps all your other settings. `modelSettings` is merged entry by entry, so your other models' entries stay. If you already set one of these, it keeps your value and tells you; run `./install.sh --force` to use the setup's values instead. If `settings.json` is not valid JSON, the installer stops before changing anything.

It replaces `~/.claude/CLAUDE.md`. If you had your own rules, merge them back from the backup folder.

To install into another folder, set `CLAUDE_HOME`:

```bash
CLAUDE_HOME=/path/to/.claude ./install.sh
```

### Manual install

Copy `claude/agents/*.md` into `~/.claude/agents/` and `claude/skills/ship/` into `~/.claude/skills/ship/`, add the rules from `claude/CLAUDE.md` to `~/.claude/CLAUDE.md`, and add the four keys from `claude/settings.json` to `~/.claude/settings.json`.

### One project only

Put the same files in a repo instead of your home folder: `.claude/agents/`, `.claude/skills/`, `CLAUDE.md` at the repo root, and `.claude/settings.json`. Everyone who works in that repo gets the setup.

## Tips

- Start a new session after installing. Settings and rules are read at startup.
- The coordinator runs Opus 5.5 at `high` effort; `medium` made it skip planning and lesson capture. Opus 5.5 doesn't use the top-level `effortLevel`, so its level is set under `modelSettings` (Claude Code v2.1.251 or later). Type `/effort medium` in a session for cheap, routine work.
- The `haiku` alias means Haiku 5.5 on the Anthropic API with Claude Code v2.1.293 or later. On Bedrock, Google Cloud, Foundry and Claude Platform on AWS it means Haiku 4.5.
- Run `/usage` after a session to see cost per model. The `explorer` agent should show up as a Haiku line.
- The built-in `Explore` agent is left alone, so plan mode's research keeps its full model. Earlier versions replaced it with a Haiku copy; `install.sh` removes that copy.
- The advisor sends the whole conversation to Opus on each call, so keep it to the two moments above. Use the `reviewer` to check finished code.
