#!/bin/sh
# PostToolUse hook: run tsc after editing .ts/.tsx files
FILE=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')
if echo "$FILE" | grep -qE '\.(ts|tsx)$'; then
  cd /Users/alexandreboyer/dev/projects/plpgsql-workbench/app && npx tsc --noEmit 2>&1 | head -5
fi
