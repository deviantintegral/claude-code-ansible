#!/bin/bash
# Stop hook: send a webhook notification with enough context
# to identify which session/host finished.
#
# Managed by ansible (claude-code role). The webhook URL is loaded from
# ~/.claude/hooks/notify.env, which is rendered from the
# claude_code_notifications_webhook_url variable. If the env file is
# missing or empty, the hook exits silently so a misconfiguration never
# blocks the next turn.

set -u

WEBHOOK_URL=""
if [ -r "$HOME/.claude/hooks/notify.env" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.claude/hooks/notify.env"
fi
[ -z "$WEBHOOK_URL" ] && exit 0

# Read the JSON payload Claude Code pipes in on stdin.
input=$(cat)

transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')

host=$(hostname -s 2>/dev/null || hostname)
project=$(basename "${cwd:-$PWD}")
short_session=${session_id:0:8}

# Pull the most recent assistant text message out of the JSONL transcript
# so the notification body says what was actually finished.
#
# Timing note: the Stop hook can fire before the final assistant text block
# has been flushed to the JSONL file. Wait briefly for the file mtime to
# stop changing so we read a settled transcript.
last_msg=""
if [ -n "$transcript" ] && [ -r "$transcript" ]; then
  prev_mtime=0
  for _ in 1 2 3 4 5 6 7 8; do
    cur_mtime=$(stat -c %Y "$transcript" 2>/dev/null || echo 0)
    [ "$cur_mtime" = "$prev_mtime" ] && [ "$cur_mtime" != "0" ] && break
    prev_mtime=$cur_mtime
    sleep 0.15
  done

  last_msg=$(tac "$transcript" 2>/dev/null \
    | jq -rc 'select(.message.role=="assistant") | [.message.content[]? | select(.type=="text") | .text] | select(length > 0) | .[-1]' 2>/dev/null \
    | head -n 1 \
    | tr '\n\r\t' '   ' \
    | awk '{n=length($0); if (n>240) print substr($0, n-239); else print}')
  # Fall back to the most recent tool use if the last assistant turn was
  # tool-use only (no text blocks).
  if [ -z "$last_msg" ]; then
    last_tool=$(tac "$transcript" 2>/dev/null \
      | jq -rc 'select(.message.role=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' 2>/dev/null \
      | head -n 1)
    [ -n "$last_tool" ] && last_msg="ran ${last_tool}"
  fi
fi
[ -z "$last_msg" ] && last_msg="Task complete"

title="Claude on ${host}: ${project}"
message="${last_msg}"
tag="claude-${host}-${short_session}"

# Build the JSON body with jq so quoting is always correct.
payload=$(jq -nc \
  --arg t "$title" \
  --arg m "$message" \
  --arg tag "$tag" \
  '{title: $t, message: $m, tag: $tag}')

# Debug log (last 500 lines kept) so we can diagnose bad captures.
debug_log="$HOME/.claude/hooks/notify-stop.debug.log"
{
  printf '=== %s session=%s ===\n' "$(date -Is)" "$short_session"
  printf 'picked: %s\n' "$last_msg"
  printf 'mtime_iters: initial_mtime_differs=%s final_mtime=%s\n' "$prev_mtime" "$cur_mtime"
} >> "$debug_log" 2>/dev/null || true
# Rotate: keep last 500 lines.
if [ -f "$debug_log" ]; then
  tail -n 500 "$debug_log" > "$debug_log.tmp" 2>/dev/null && mv "$debug_log.tmp" "$debug_log" 2>/dev/null || true
fi

# Fire and forget — short timeout so a flaky webhook never blocks the next turn.
curl -sS --max-time 5 -X POST \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "$WEBHOOK_URL" >/dev/null 2>&1 || true

exit 0
