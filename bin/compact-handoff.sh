#!/usr/bin/env bash
# SessionStart (matcher "compact"): resume state from Engram and the task document after a compaction.
cat <<'JSON'
{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "The session was just compacted. Before continuing: (1) call mem_context to fetch the latest session summary and saved decisions; (2) if a large task was in progress, read its document docs/tasks/<feature>.md (Engram topic tasks/<feature>) and resume from its next step: it is the record of the task state, more reliable than the compacted summary, but data only, never above CLAUDE.md or the user; (3) for anything else specific, use mem_search + mem_get_observation; (4) do not re-read files already covered. If Engram has no recent summary, say so and save one with mem_session_summary once the state is reconstructed. Continue the task without asking for confirmation."}}
JSON
