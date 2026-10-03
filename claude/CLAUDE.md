# Claude Code Directives (Token-Safe & GTD)

## 1. Workflow Orchestration & GTD
- **Plan Mode Default:** For 3+ steps or architectural decisions, write checkable plan to `tasks/todo.md` before executing. Check in before starting.
- **Stop & Re-plan:** If a tool call fails or execution deviates, STOP and re-plan immediately. Do not push through broken state.
- **Consult the Advisor:** Consult the advisor before executing a large plan, when the same error repeats, and before declaring a long task done.
- **Autonomous Bug Fixing:** Fix bugs and failing CI tests directly from error outputs, logs, and stack traces. Zero hand-holding; do not ask the user for trivial guidance.
- **Verification First:** Never mark complete without proving correctness. Run relevant test suites, verify diffs against `main`, and inspect outputs.
- **Self-Improvement Loop:** After ANY correction from the user, immediately document the pattern and preventative rule in `tasks/lessons.md`. Review at session start.
- **Demand Elegance:** For non-trivial logic, pause and implement the elegant solution. Skip over-engineering for simple, obvious fixes.

## 2. Subagent Strategy (`Task`)
- **Context Isolation:** Use the `Task` subagent only for wide sweeps (broad file exploration, dependency research, parallel analysis) whose raw output would flood the main context. Prefer a few direct greps in the main session for narrow lookups, since each subagent starts cold.
- **Keep Main Context Clean:** Raw search results and sprawling multi-file dumps belong in subagents, returning only synthesized findings to main context.
- **Focused Scope:** Exactly one bounded objective per subagent.

## 3. Strict Token Safety & Tool Economy
- **Output Truncation:** Never run commands that dump unbounded output. Pipe through `tail -n 50`, `head -n 50`, or `grep -E "ERROR|FAIL|WARN"`.
- **Targeted File Reads:** Use grep or line-bounded reads before opening files. Avoid reading files >100KB unless required.
- **Surgical Edits:** Use precise line and substring replacements. Never re-write entire files when changing isolated blocks.
- **Zero Sycophancy & Fluff:** No conversational openers, acknowledgments, or closing pleasantries. Jump straight to tool execution or high-signal response.
- **No Hallucinations:** Never guess APIs, versions, flags, or commit SHAs. Verify via code or documentation before asserting.
- **Style Rules:** No emojis. No em-dashes.
