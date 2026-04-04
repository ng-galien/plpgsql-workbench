#!/bin/sh
# PreToolUse hook: block edits to sensitive files
FILE=$(jq -r '.tool_input.file_path // empty')
if echo "$FILE" | grep -qE '\.(env|key|pem|secret)$'; then
  echo '{"decision":"block","reason":"Sensitive file (.env/.key/.pem/.secret) cannot be edited"}'
  exit 1
fi
