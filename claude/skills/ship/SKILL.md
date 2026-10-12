---
name: ship
description: Take a feature through spec, build and review in its own git worktree. Use when the user types /ship <feature> [--merge], /ship approve <job-id>, or /ship rework <job-id> <note>.
disable-model-invocation: true
---

# Ship

You are the coordinator for one job. You write the spec yourself, then spawn the `worker` to build it and the `reviewer` to check it. You never write the code or the reviews.

```
spec (you) -> user approves -> worker builds -> reviewer -> any CHANGES: resume worker (max 2) -> gate
```

`MAX_RESUMES = 2`: one worker can be resumed at most twice. `N` is the last completed review round: 0 before the first.

| Command | Does |
|---|---|
| `/ship <feature>` | Run a new job; stop at a ready branch |
| `/ship <feature> --merge` | Same, and merge into `<base>` if the gate says READY |
| `/ship approve <job-id>` | Merge a `ready` or `needs-human` job |
| `/ship rework <job-id> <note>` | Send a `ready` or `needs-human` job back to a fresh worker with your note |

## Where things live

Each job builds in its own git worktree on its own branch, so the user's checkout is never switched, and several sessions can each run a job at once.

```
<repo>/.lean/jobs/<job-id>/            job state, in the main checkout, never committed
  job.json                             you write it; the only file the commands below trust
  spec.md                              you write it; the user approves it
  build.md                             the worker writes it; first line STATUS: READY | BLOCKED
  round-<R>/review-code.md             the reviewer writes it; first line VERDICT: PASS | CHANGES
  decision.md                          you write it at the gate; first line READY | ESCALATE
  rework-<k>.md                        you write it from /ship rework
<repo>/../<name>-ship/<job-id>/        the worktree, on branch ship/<job-id>
```

`<repo>` is `git rev-parse --show-toplevel` from your session and `<name>` is its folder name. Your session stays in the main checkout. Run commands that need the job's code as `cd <worktree> && ...`; git commands that only read refs (`merge-tree`, `diff <base>...ship/<job-id>`) work from either.

`job.json` (rewrite the whole file on every change; `worktree` is an absolute path):

```json
{ "id": "004-csv-export", "feature": "Export the report as CSV", "base": "main",
  "branch": "ship/004-csv-export", "worktree": "/Users/you/code/app-ship/004-csv-export",
  "stage": "review", "round": 1, "resumes": 0 }
```

`stage` is one of `spec`, `build`, `review`, `gate`, `ready`, `merged`, `needs-human`. `round` is N. `resumes` counts resumes of the current worker.

Agents get context from the job files, not from the conversation. Read only the first line of each to decide the next step; open the rest only to report or when something is wrong.

Every agent prompt starts with the paths sentence, called `<paths>` below:
`Job folder: <repo>/.lean/jobs/<job-id>/. Worktree: <worktree>. Branch: ship/<job-id>. Base: <base>.`

## /ship <feature>

### 1. Set up

1. If `git rev-parse --absolute-git-dir` differs from `git rev-parse --path-format=absolute --git-common-dir`, this session is inside a linked worktree: stop and ask the user to run `/ship` from the main checkout. Otherwise `cd <repo>`; every later step runs from there.
2. `<base>` is `git branch --show-current`. If it prints nothing (detached HEAD), stop and ask the user to check out a branch.
3. If `git status --porcelain` prints anything, tell the user the job starts from the last commit on `<base>` and does not include their uncommitted changes, then continue.
4. Make sure `.lean/` is ignored: if `git check-ignore -q .lean/x` fails, append `.lean/` to the file `git rev-parse --git-path info/exclude` prints (never edit the repo's `.gitignore`).
5. Claim a job id: the next 3-digit number after the highest folder in `<repo>/.lean/jobs/` (`001` if none), plus a 2-4 word kebab-case slug of the feature, for example `004-csv-export`. Run `mkdir -p <repo>/.lean/jobs`, then `mkdir <repo>/.lean/jobs/<job-id>` (no `-p`). If that fails because another session took the number, take the next number and try again.
6. The worktree path is `$(cd <repo>/.. && pwd)/<name>-ship/<job-id>`. Write `job.json` with `stage: "spec"`, `round: 0`, `resumes: 0`.

### 2. Spec

Read only what you need to pin the feature down: the repo's `CLAUDE.md` or `AGENTS.md`, and the code the feature touches. Write `spec.md`:

```markdown
# <title>

## Goal
One or two sentences.

## Acceptance criteria
1. <observable behavior, testable by a command or a test>

## Scope
Files or areas expected to change. Out of scope: what this job must not touch.

## Assumptions
Anything you decided that the user did not say.
```

Show the user the acceptance criteria and assumptions, and ask them to approve or correct the spec. Do not continue until they approve. Fold any correction into `spec.md`.

### 3. Worktree

```bash
git worktree add -b ship/<job-id> <worktree> <base>
```

If it fails (the path already exists, for example), go to **Needs human** with git's message. Then, in the worktree, run the setup the repo's `CLAUDE.md` or `AGENTS.md` gives for a fresh checkout (installing dependencies, for example). If any of it fails, go to **Needs human**.

### 4. Build

Set `stage: "build"`. Spawn `worker` with:
`<paths> Build round 1: implement spec.md, with tests for each acceptance criterion, and record the evidence for every criterion in build.md. Commit on the branch.`
Keep the agent ID from the spawn result; you resume this same worker later.

Then go to **Build check**.

### Build check

The worker's reply is its status line. Compare it with the first line of `build.md`; the two must match, so a stale `build.md` from an earlier round can't pass as new work.
- Both `STATUS: READY`: run review round N+1.
- Both `STATUS: BLOCKED`: go to **Needs human**.
- They differ, `build.md` is missing, or either is not a `STATUS:` line: go to **Needs human**, saying what you found.

### Review round R

`R` is the round being run, N+1.

1. Set `stage: "review"`. Create `round-<R>/`. Spawn `reviewer` with:
   `<paths> Review round R. Compare <base>...ship/<job-id> against spec.md. Write round-<R>/review-code.md.`
   From round 2 on, append ` Your previous review is round-<R-1>/review-code.md; check each finding was fixed.`
2. When it finishes, check that `round-<R>/review-code.md` exists and its first line is a verdict. If not, go to **Needs human**, saying what you found. Round R is now complete: set `round` to R.
3. Decide:
   - **PASS**: go to **Gate**.
   - **CHANGES, resumes left** (`resumes` < 2): add 1 to `resumes`, set `stage: "build"`, and resume the worker with `SendMessage` to its agent ID:
     `Round N review is in round-<N>/review-code.md. Address every finding, commit, and update build.md for round N+1, refreshing the Acceptance criteria evidence.`
     Then go to **Build check**.
   - **CHANGES, no resumes left**: go to **Needs human**, citing the open findings.

### Gate

Set `stage: "gate"`. Run three checks first:

1. **Evidence**: the `## Acceptance criteria` section of `build.md` lists every criterion in `spec.md`, each marked `[x]` with a named test or command and its result.
2. **Spot check**: pick one criterion other than the one in the final review's `## Re-run` (any one if there is only one), and run its evidence yourself in the worktree. It must pass.
3. **Conflicts**: `git merge-tree --write-tree <base> ship/<job-id>` exits 0. Any non-zero exit fails the check: 1 means the branch conflicts with `<base>`; anything else means the command could not run (it needs git 2.38 or later).

Then look at `git diff --stat <base>...ship/<job-id>` and the changed paths. Write `decision.md` with `ESCALATE` on the first line if any check fails, or if the change:

- touches money, access or identity: payments, auth, permissions, secrets;
- changes deploy, CI or build config, or the scripts they run;
- migrates a schema, sends email, writes production data, or adds a dependency;
- rests on an Assumption in `spec.md` that is really a product decision.

Otherwise write `READY`. Follow the first line with a `## Why` of two or three sentences and a `## Checks` list giving the result of each of the three checks. On ESCALATE, add `## For the human`: the exact decision or check you need, and the files to look at.

- `ESCALATE`: go to **Needs human**.
- `READY` with `--merge`: go to **Merge**.
- `READY` without `--merge`: set `stage: "ready"`. Tell the user the branch and worktree, and that `/ship approve <job-id>` merges it.

### Merge

The merge happens in the main checkout, so it must be on `<base>` and clean: `git branch --show-current` prints `<base>` and `git status --porcelain` prints nothing (`.lean/` is ignored, so job files don't count). If not, don't merge and don't touch `needs-human`: coming from the gate, set `stage: "ready"`; coming from `/ship approve`, leave the stage as it was. Tell the user their checkout is busy and to run `/ship approve <job-id>` once it is clean. Otherwise:

```bash
git merge --no-ff ship/<job-id> -m "Merge ship/<job-id>"
git worktree remove <worktree>
git branch -d ship/<job-id>
```

If the merge fails, run `git merge --abort` (when a merge is in progress), set `stage: "needs-human"` and tell the user why. Once the merge succeeds, set `stage: "merged"`; the job counts as merged even if cleanup fails:

- If `git worktree remove` fails, skip `git branch -d` (the branch is still checked out there). Tell the user what git printed and the two commands to finish cleanup: `git worktree remove --force <worktree>` and `git branch -d ship/<job-id>`.
- If `git branch -d` fails, tell the user what git printed; the branch is kept.

Never push.

### Needs human

Set `stage: "needs-human"`. The branch and worktree stay for the user to inspect. Tell the user which job is waiting, the worktree path, and quote the reason: the `## Blocked` section of `build.md`, the open findings, or `decision.md`. Name the next steps: `/ship approve <job-id>` to merge as is, `/ship rework <job-id> <note>` to send it back, or `git worktree remove --force <worktree> && git branch -D ship/<job-id>` to throw it away. If the worktree was never created, none of these applies: say the job folder `.lean/jobs/<job-id>/` can simply be deleted.

## /ship approve <job-id>

`cd <repo>`, then read `.lean/jobs/<job-id>/job.json`. Its `stage` must be `ready` or `needs-human`, its worktree must exist, and `build.md` must exist; otherwise say why and stop (there is nothing built to merge).

If the first line of `decision.md` is not `READY` (it is `ESCALATE`, or there is no `decision.md` because the build was blocked or review rounds ran out), quote the reason to the user and ask them to confirm they want to merge anyway. Do not merge until they confirm.

Then run **Merge**, using `base`, `branch` and `worktree` from `job.json`.

## /ship rework <job-id> <note>

`cd <repo>`, then read `.lean/jobs/<job-id>/job.json`. Its worktree must still exist, and its `stage` must be `ready` or `needs-human`. A `build`, `review` or `gate` stage means a session is running the job or one ended mid-job: ask the user to confirm no other session is still working on it before continuing. Stop for `spec` (nothing built yet; start a new `/ship` instead) and `merged`.

1. Write the note, verbatim, to `.lean/jobs/<job-id>/rework-<k>.md`, where `k` is the next unused number. If `decision.md` exists, rename it to `decision-<k>.md`, so `decision.md` only ever describes the current attempt.
2. Set `stage: "build"` and `resumes: 0`.
3. Spawn a fresh `worker` with:
   `<paths> Rework: read rework-<k>.md and address it. Also read spec.md, build.md if it exists, and every round folder for the history. Commit on the branch, and write build.md for round N+1, refreshing the Acceptance criteria evidence.`
   Keep its agent ID; this is the worker you resume from now on.
4. Continue from **Build check**, exactly like a new job. A rework never merges on its own: at a READY gate it stops at `ready` for `/ship approve`.

## Reporting

One short line per transition, for example `004-csv-export: round 2 CHANGES (2 findings) -> resuming worker`. At the end, say whether the branch is ready, merged, or needs a human, and why.
