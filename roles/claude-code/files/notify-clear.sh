#!/bin/bash
# UserPromptSubmit / SessionEnd hook: clear any pending "task complete"
# notification for this session by re-sending with message=clear_notification
# and the same tag.
#
# Managed by ansible (claude-code role). The webhook URL is loaded from
# ~/.claude/hooks/notify.env, which is rendered from the
# claude_code_notifications_webhook_url variable. If the env file is
# missing or empty, the hook exits silently.

set -u

WEBHOOK_URL=""
if [ -r "$HOME/.claude/hooks/notify.env" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.claude/hooks/notify.env"
fi
[ -z "$WEBHOOK_URL" ] && exit 0

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')

host=$(hostname -s 2>/dev/null || hostname)
short_session=${session_id:0:8}
tag="claude-${host}-${short_session}"

# Home Assistant Companion: message=clear_notification + matching tag
# dismisses the prior notification. Title is ignored for the clear action
# but we send one so the HA automation has consistent fields to map.
payload=$(jq -nc \
  --arg m "clear_notification" \
  --arg tag "$tag" \
  '{title: "", message: $m, tag: $tag}')

curl -sS --max-time 5 -X POST \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "$WEBHOOK_URL" >/dev/null 2>&1 || true

exit 0
