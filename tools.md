# Kit tools (always in context)

## Stack
Go (backend) + Vue 3 (frontend), client-server, Postgres, everything in Docker. Contract `api/openapi.yaml` (oapi-codegen for Go, openapi-typescript for Vue). SQL with sqlc + goose migrations, no ORM. Manual: Scalar at `/docs` (dev only). Security: `govulncheck`, `gosec`. A post-edit hook formats/lints Go and Vue; a guard hook asks before dependencies, migrations, CI edits and `docker compose down -v`.

**Stack profiles** (`kit/root/profiles/`): read ONCE per session, only when relevant — `go.md` (backend), `vue.md` (frontend), `postgres.md` (anything under `db/`). The repo's own CLAUDE.md wins over them.

## Which tool, when (choose without being asked)
- Fuzzy idea or new project → `/nuevo-proyecto` (interview → decisions → staged roadmap → generated base). Never skip the definition.
- Defined task → `/plan` → OK → `/implementar`. Trivial changes (typo, one line) go straight in.
- Bug → superpowers systematic-debugging before touching code.
- Before committing → `/revisar` (lenses by risk). PR or whole diff → `/code-review`. Before publishing → `/auditar`.
- External API/library → context7 first. Decision or finding → `mem_save`.
- Long exploration or many files → read-only subagent (Explore, auditor-seguridad).
- Commits/PRs → commit-commands. Kit health → `/kit-doctor`. Study mode → `/estudio`.

## Models per task (latest stable aliases: haiku = Haiku 5.5, sonnet = Sonnet 5.5, opus = Opus 5.5)
| Model | Use for |
|---|---|
| **haiku** | Read-only/mechanical: `review-readability` lens, Explore searches, `/kit-help`, `/kit-doctor`, formatting, summaries, simple lookups |
| **sonnet** (default) | Daily work: writing code and tests, `/implementar`, `/revisar` and its lenses risk/resilience/reliability, `/auditar` (`auditor-seguridad`), `/setup-kit`, `/estudio`, routine debugging, commits |
| **opus** | Thinking work: `/nuevo-proyecto`, `/plan`, architecture/trade-off decisions, planning "always large" areas (auth, payments, migrations), debugging that failed twice, ambiguous requirements |
Commands and agents pin their model in frontmatter (`model:`), so costs stay predictable even if the session default changes. Subagents that are not pinned inherit the session model: prefer Explore (haiku) for searches.

## Plugins
- **engram**: persistent memory (see Tokens rules).
- **superpowers**: brainstorm → plan → TDD workflow skills; invoke the matching skill BEFORE acting.
- **context7**: up-to-date library docs. **security-guidance**: warns on insecure patterns while editing; respect it.
- **commit-commands**: `/commit`, `/commit-push-pr`, `/clean_gone`. **code-review**: generic PR/diff review. **claude-md-management**: keep CLAUDE.md files short and current.
- **octo**: multi-model orchestration (Codex, Gemini, …); providers/accounts configured with `/octo:setup`.
- **ponytail**: write less code; reuse existing code and the stdlib first.
- **vibe-wise** (study mode): learn while Claude writes. Start a message with `estudio:` (or `/estudio`) to enable, `trabajo:` (or `/estudio off`) to pause. While active the user leads the design and `/plan`/`/implementar` defer to its loop. Needs python3.

## CLI
- **rtk**: output-compressing proxy for shell commands (automatic Bash hook). Use `rtk proxy <cmd>` only to debug. See @RTK.md.
- Prefer `bat`, `rg`, `fd`, `eza` over cat/grep/find/ls.

## Docker services (`kit/root/services/`)
- **postgres** (5432): the database of every project.
- **redis** (6379): only for caching, sessions, rate limiting, light queues, locks. **elasticsearch** (9200, dev only, ~1 GB RAM): only for text search/facets. If Postgres is enough, do not add them.
- **floci** (4566): local AWS emulator for S3/SQS in development. Partial coverage: validate critical paths against real AWS.

## Kit commands
`/setup-kit` configure the kit (repeatable) · `/kit-help` explain it · `/kit-doctor` health check · `/estudio` study mode · `/nuevo-proyecto` define + generate a project · `/plan` · `/implementar` · `/revisar` pre-commit review by risk · `/auditar` whole-project audit (agent `auditor-seguridad`).
Project generator: `kit/root/bin/new-project.sh <name> [--services …] [--no-harness]` (deterministic; used by `/nuevo-proyecto`). Projects with Postgres get an integration harness (`make test-integration`); the kit itself is checked with `bash tests/harness.sh`.

## Profiles (only if the project asks)
- **backend → gopls-lsp**. **front → typescript-lsp, taste-skill, web-design-guidelines** (UI quality for front projects only).
