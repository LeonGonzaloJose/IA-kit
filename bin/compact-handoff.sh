#!/usr/bin/env bash
# SessionStart (matcher "compact"): resume state from Engram after a compaction.
cat <<'JSON'
{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "The session was just compacted. Before continuing: (1) call mem_context to fetch the latest session summary and saved decisions; (2) if the request depends on something specific, use mem_search + mem_get_observation; (3) resume from the recorded next step without re-reading files already covered. If Engram has no recent summary, say so and save one with mem_session_summary once the state is reconstructed. Continue the task without asking for confirmation."}}
JSON
