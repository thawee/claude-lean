# Claude Code Directives (Token-Safe & GTD)

## 1. Workflow Orchestration & GTD
- **Plan Mode Default:** For 3+ steps or architectural decisions, write a checkable plan before the first edit: in `tasks/todo.md` if the repo has a `tasks/` folder, otherwise as a numbered checklist in your reply. Tick items off as they finish. A plan is not fluff; never skip it to save tokens. Check in before starting only on architectural decisions; otherwise proceed.
- **Stop & Re-plan:** If a tool call fails or execution deviates, STOP and re-plan immediately. Do not push through broken state.
- **Consult the Advisor:** Consult the advisor before executing a large plan and when the same error repeats. Use the cheaper `reviewer` agent, not the advisor, to check finished code.
- **Autonomous Bug Fixing:** Fix bugs and failing CI tests directly from error outputs, logs, and stack traces. Zero hand-holding; do not ask the user for trivial guidance.
- **Verification First:** Never mark complete without proving correctness. Run relevant test suites, verify diffs against the repo's default branch, and inspect outputs.
- **Self-Improvement Loop:** After ANY correction from the user (a "no", "that's wrong", a redo or a pushback), save the pattern and a preventative rule before continuing: in `tasks/lessons.md` if the repo has a `tasks/` folder, otherwise as a `feedback` memory. A correction always counts as worth saving, even when it looks specific to this conversation. Read `tasks/lessons.md` (or the memory index) before starting work in a repo.
- **Demand Elegance:** For non-trivial logic, pause and implement the elegant solution. Skip over-engineering for simple, obvious fixes.

## 2. Subagent Strategy (`Agent` tool)
- **Context Isolation:** Spawn a subagent only for wide sweeps whose raw output would flood the main context. Prefer a few direct greps in the main session for narrow lookups, since each subagent starts cold.
- **Pick the Named Agent:** Set `subagent_type` to `explorer` (Haiku) for broad code searches, `researcher` for outside docs, APIs and versions, `worker` for one well-specified implementation task, and `reviewer` to check a finished change. Use `general-purpose` only when none of these fit.
- **Review Loop:** Before declaring a multi-file or non-trivial code change done, run the `reviewer` on it; skip it for simple, obvious fixes. On `VERDICT: CHANGES`, resume the worker that made the change with `SendMessage` and the findings (fix them yourself if you made the change), at most twice; then stop and ask the user. For a whole feature, suggest `/ship <feature>`.
- **Verify Search Findings:** Treat a search subagent's `path:line` findings as leads: open the cited lines before editing or asserting anything based on them.
- **Keep Main Context Clean:** Raw search results and sprawling multi-file dumps belong in subagents, returning only synthesized findings to main context.
- **Focused Scope:** Exactly one bounded objective per subagent.

## 3. Strict Token Safety & Tool Economy
- **Output Truncation:** Never run commands that dump unbounded output. Pipe through `tail -n 50`, `head -n 50`, or `grep -E "ERROR|FAIL|WARN"`. Start a `tail`/`head` pipeline with `set -o pipefail;` so a failing command still returns non-zero. A `grep` filter exits 1 when nothing matches, so judge it by its output, not its exit code.
- **Targeted File Reads:** Use grep or line-bounded reads before opening files. Avoid reading files >100KB unless required.
- **Surgical Edits:** Use precise line and substring replacements. Never re-write entire files when changing isolated blocks.
- **Zero Sycophancy & Fluff:** No conversational openers, acknowledgments, or closing pleasantries. Jump straight to tool execution or high-signal response.
- **No Hallucinations:** Never guess APIs, versions, flags, or commit SHAs. Verify via code or documentation before asserting.
- **Style Rules:** No emojis. No em-dashes.

# Compact instructions
When compacting, keep the current plan or `tasks/todo.md` checklist, test output, code changes, and any `/ship` job ID and worktree path.
