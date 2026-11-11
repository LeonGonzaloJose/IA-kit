# Global rules

## Language
- Reply in the language the user writes in (default Spanish). Everything Claude consumes (this file, hooks, agents, profiles, memory) is English; slash-command `description` fields stay Spanish.
- Code, identifiers, comments and commit messages in English. Comment only a non-obvious why, one line. Conventional commits.

## How to work
- Be brief: shortest useful answer; expand only when asked or required. One question at a time, then stop and wait.
- Authorize: a question, review or analysis is read-only; change files only when asked to change something.
- Size by understanding, risk and resumability, never by line count:
  - **Small** (understood, local, resumable from the diff): do it inline, no plan file, no subagents.
  - **Large** (several sessions, external waits, requirements that would not survive compaction): `/plan` first, then work step by step.
  - **Always large**, whatever the size: auth/permissions, payments, SQL/migrations, secrets/config, HTTP/S3/SQS clients, dependencies, CI/Docker. Plan with acceptance criteria and run `/revisar` high.
- "Done" needs evidence (passing test, command output, checked screen). Report what was implemented, what was verified and what is pending. Never claim verification without it.
- Ambiguity: name it in one sentence, offer 2-3 options with trade-offs, ask. Never assume silently. Verify technical claims before stating them; if the user is wrong, explain why with evidence.
- Never run raw `git push`, `--amend`, `--no-verify` or force flags: they need the developer's approval. Stage explicit paths, never `git add -A`.

## Models
Default session model is Sonnet. Haiku for mechanical/read-only work, Opus for planning and architecture (table in tools.md). Escalate to Opus when the same problem fails twice or a decision is architectural; tell the user to run `/model opus` if the current command does not switch it. Never downgrade a task silently.

## Secrets
Never read, print or commit `.env*` (except `.env.example`), keys, credentials or real config values; the env-guard hook blocks the common cases. If a repo already commits secrets, report it without copying values anywhere.

## APIs
OpenAPI (`api/openapi.yaml`) is the source of truth. API manual = Scalar (template `kit/root/templates/go-docs`), never swaggo/Swagger UI unless the user asks for it in that project.

## Tokens
- Auto-compact at 250k tokens (settings). Hooks ask to save to Engram at 200k and resume after compaction: when that happens, continue the task without asking for confirmation.
- Do not re-read files already read; read only needed ranges; `rg` before opening. Summarize long outputs, never paste them.
- Delegate to read-only subagents only for a stated reason: broad exploration, parallel writers on disjoint files, independent review, or protecting a context near the threshold. Say the reason. Consume their summary, not their dumps.
- Memory is Engram (`mem_*`): `mem_context` at session start, `mem_save` after each decision/bug/convention, `mem_session_summary` before finishing.

@tools.md
