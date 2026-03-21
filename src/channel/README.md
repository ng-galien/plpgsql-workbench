# Workbench Channel — Claude Code integration

Push events from PG and the browser into your Claude Code session.

## Setup

```bash
# Start Claude Code with the channel
claude --dangerously-load-development-channels server:workbench-channel
```

Add to `.mcp.json`:
```json
{
  "mcpServers": {
    "workbench-channel": {
      "command": "npx",
      "args": ["tsx", "src/channel/workbench-channel.ts"],
      "env": {
        "PLPGSQL_CONNECTION": "postgresql://postgres:postgres@localhost:5433/postgres",
        "CHANNEL_PORT": "8789"
      }
    }
  }
}
```

## Events

### PG messages (agent → lead)

When an agent sends `pg_msg` to the lead, PG emits `NOTIFY workbench_channel`.
The channel pushes it into the Claude Code session:

```
<channel source="workbench" type="pg_msg" from="document" priority="high">
  CRUD Charte completed — 33 tests pass
</channel>
```

No more `tmux send-keys -t agent "go" Enter`.

### Browser annotations (user → Claude)

The browser POSTs to `http://localhost:8789`:

```bash
curl -X POST localhost:8789 -H "Content-Type: application/json" \
  -d '{"element_id":"title","page":"/docs/document/42","message":"Make this bigger"}'
```

Claude receives:
```
<channel source="workbench" type="annotation" element_id="title" page="/docs/document/42">
  Make this bigger
</channel>
```

### Reply (Claude → browser)

Claude uses the `broadcast` tool to send toasts/navigation to the browser
via Supabase Realtime.

## Architecture

```
PG (pg_msg INSERT) → NOTIFY workbench_channel → Channel → Claude Code session
Browser (POST)     → HTTP :8789               → Channel → Claude Code session
Claude Code        → broadcast tool            → PG NOTIFY → MCP server → Supabase Broadcast → Browser
```
