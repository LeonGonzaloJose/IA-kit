---
description: Revisa el cambio pendiente antes de commitear con 1 a 4 lentes de solo lectura según el riesgo
argument-hint: "[passive | medium | high]"
model: sonnet
---
Read-only and informational: never edit, commit or push; the developer decides. Differs from `/code-review` (generic, whole PR) and `/auditar` (whole project): this reviews the PENDING diff with lenses chosen by risk.

1. **Freeze the change.** `git diff HEAD` (plus untracked files from `git status --short`) saved to `.claude/review/<branch>.diff`; add `.claude/review/` to `.git/info/exclude` if missing. Never include `.env*`, keys or credentials: drop those paths and tell the developer.
2. **Pick the depth** from risk and understanding, not from the line count (only a hint). The developer can force it: `$ARGUMENTS` or "review high" in the message.
   - **passive**: docs, comments, formatting, config text only → no agents; say nothing needs review.
   - **medium**: small change (< ~150 changed lines, 1-3 files, none of the risky areas below) → ONE lens: `review-reliability` for logic, `review-readability` for refactors.
   - **high**: larger change, or it touches auth/permissions, SQL/migrations/sqlc queries, secrets/config, HTTP/S3/SQS clients, dependencies, Docker/CI → ALL four lenses in parallel: `review-risk`, `review-resilience`, `review-readability`, `review-reliability`.
   If `docs/plans/` has a plan for this work, pass it to the agents so they flag uncovered acceptance criteria.
3. **Run** the chosen agents in ONE message, passing the diff path, the changed files and the stack (`go`, `vue`, `sql`). Do not launch them if the context is above the compaction threshold: save to Engram and continue after compaction.
4. **Consolidate**: merge duplicates, order by severity, drop anything about untouched legacy code. Present a short table `severity | file:line | problem | fix` and the depth used. Never claim a clean review when an agent failed; name the lens that did not run.
5. When blockers are resolved or consciously accepted, suggest `/commit` (commit-commands).
