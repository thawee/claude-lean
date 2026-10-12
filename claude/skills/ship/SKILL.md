---
name: ship
description: Take a feature through spec, build and review on its own branch. Use when the user types /ship <feature> or /ship <feature> --merge.
disable-model-invocation: true
---

# Ship

You are the coordinator for one job. You write the spec yourself, then spawn the `worker` to build it and the `reviewer` to check it. You never write the code or the reviews.

```
spec (you) -> user approves -> worker builds -> reviewer -> any CHANGES: resume worker (max 2) -> gate
```

`MAX_RESUMES = 2`: after round 1 the worker can be resumed at most twice, so a job has at most 3 review rounds. `N` is the last completed review round: 0 before the first.

## Files

Job state lives in `<repo>/.lean/jobs/<job-id>/`, never committed:

```
spec.md                     you write it; the user approves it
build.md                    the worker writes it; first line STATUS: READY | BLOCKED
round-<N>/review-code.md    the reviewer writes it; first line VERDICT: PASS | CHANGES
decision.md                 you write it at the gate; first line READY | ESCALATE
```

Agents get context from these files, not from the conversation. Read only the first line of each to decide the next step; open the rest only to report or when something is wrong.

Every agent prompt starts with the paths sentence, called `<paths>` below:
`Job folder: <repo>/.lean/jobs/<job-id>/. Branch: ship/<job-id>. Base: <base>.`

## 1. Set up

1. `git status --porcelain` must print nothing. If it doesn't, stop and ask the user to commit or stash first.
2. `<base>` is `git branch --show-current`. If it prints nothing (detached HEAD), stop and ask the user to check out a branch. `<repo>` is `git rev-parse --show-toplevel`.
3. Make sure `.lean/` is ignored: if `git check-ignore -q .lean/x` fails, append `.lean/` to the file `git rev-parse --git-path info/exclude` prints (never edit the repo's `.gitignore`).
4. Pick the job id: the next 3-digit number after the highest folder in `.lean/jobs/` (`001` if none), plus a 2-4 word kebab-case slug of the feature, for example `004-csv-export`. Create the folder.

## 2. Spec

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

## 3. Build

Create the branch: `git switch -c ship/<job-id>`. Spawn `worker` with:
`<paths> Build round 1: implement spec.md, with tests for each acceptance criterion, and record the evidence for every criterion in build.md. Commit on the branch.`
Keep the agent ID from the spawn result; you resume this same worker later.

When it finishes, read the first line of `build.md`:
- `STATUS: READY`: start review round N+1.
- `STATUS: BLOCKED`: go to **Needs human**.

## 4. Review round R

`R` is the round being run, N+1.

1. Create `round-<R>/`. Spawn `reviewer` with:
   `<paths> Review round R. Compare <base>...ship/<job-id> against spec.md. Write round-<R>/review-code.md.`
   From round 2 on, append ` Your previous review is round-<R-1>/review-code.md; check each finding was fixed.`
2. When it finishes, check that `round-<R>/review-code.md` exists and its first line is a verdict. If not, stop and tell the user. Round R is now complete, so N = R.
3. Decide:
   - **PASS**: go to **Gate**.
   - **CHANGES, resumes left** (N < 3): resume the worker with `SendMessage` to its agent ID:
     `Round N review is in round-<N>/review-code.md. Address every finding, commit, and update build.md for round N+1, refreshing the Acceptance criteria evidence.`
     Then go back to the `build.md` check in step 3.
   - **CHANGES, no resumes left** (N = 3): go to **Needs human**, citing the open findings.

## 5. Gate

Run three checks first:

1. **Evidence**: the `## Acceptance criteria` section of `build.md` lists every criterion in `spec.md`, each marked `[x]` with a named test or command and its result.
2. **Spot check**: pick one criterion other than the one in the final review's `## Re-run` (any one if there is only one), and run its evidence yourself on the branch. It must pass.
3. **Conflicts**: `git merge-tree --write-tree <base> ship/<job-id>` exits 0. Any non-zero exit fails the check: 1 means the branch conflicts with `<base>`; anything else means the command could not run (it needs git 2.38 or later).

Then look at `git diff --stat <base>...ship/<job-id>` and the changed paths. Write `decision.md` with `ESCALATE` on the first line if any check fails, or if the change:

- touches money, access or identity: payments, auth, permissions, secrets;
- changes deploy, CI or build config, or the scripts they run;
- migrates a schema, sends email, writes production data, or adds a dependency;
- rests on an Assumption in `spec.md` that is really a product decision.

Otherwise write `READY`. Follow the first line with a `## Why` of two or three sentences and a `## Checks` list giving the result of each of the three checks. On ESCALATE, add `## For the human`: the exact decision or check you need, and the files to look at.

- `ESCALATE`: go to **Needs human**.
- `READY` without `--merge`: switch back with `git switch <base>` and tell the user the branch is ready to merge.
- `READY` with `--merge`: `git switch <base>`, then `git merge --no-ff ship/<job-id> -m "Merge ship/<job-id>"`, then `git branch -d ship/<job-id>`. If the merge fails, run `git merge --abort` and go to **Needs human**. Never push.

## Needs human

Switch back with `git switch <base>` (the branch keeps the work). Tell the user which job is waiting, the branch name, and quote the reason: the `## Blocked` section of `build.md`, the open findings, or `decision.md`.

## Reporting

One short line per transition, for example `004-csv-export: round 2 CHANGES (2 findings) -> resuming worker`. At the end, say whether the branch is ready, merged, or needs a human, and why.
