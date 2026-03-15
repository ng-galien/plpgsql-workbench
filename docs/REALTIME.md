# Realtime — AI-Native Communication

## Architecture

Three channels connect Claude (MCP), the browser (pgView shell), and PostgreSQL:

```
┌─────────────────────────────────────────────────────────┐
│                    Supabase                              │
│                                                          │
│  ┌──────────┐   Realtime CDC    ┌──────────────────┐    │
│  │ PG Tables │ ──── WAL ──────→ │ Realtime Server  │    │
│  └──────────┘                   │                  │    │
│                                 │  Broadcast bus   │    │
│  ┌──────────┐                   │                  │    │
│  │ UNLOGGED │ (no WAL, no RT)   └────────┬─────────┘    │
│  └──────────┘                            │               │
└──────────────────────────────────────────│───────────────┘
                                           │
          ┌────────────────────────────────┤
          │                                │
    ┌─────▼──────┐                  ┌──────▼──────┐
    │   Browser   │                  │  MCP Worker  │
    │  pgView     │                  │  (Claude)    │
    │  shell      │                  │              │
    └─────────────┘                  └──────────────┘
```

## Channels

### 1. Data Sync — PG → Browser (Realtime CDC)

**Purpose:** Live data updates when tables change (INSERT/UPDATE/DELETE).

**Mechanism:** Supabase Realtime reads PostgreSQL WAL (logical replication).

**Setup required per table:**
```sql
-- Add to publication
ALTER PUBLICATION supabase_realtime ADD TABLE schema.table_name;

-- RLS policy for anon (Realtime respects RLS)
CREATE POLICY realtime_read ON schema.table_name
  FOR SELECT TO anon USING (true);
```

**Browser (automatic):** The shell subscribes to the current schema on navigation. INSERT events show a toast with a link:

```
User navigates to /crm/ → shell subscribes to crm.*
Claude inserts a client → toast: "Acme Corp" [Ouvrir →]
```

**Convention:** Toast link = `/{schema}/{table}?p_id={id}`

**Limitations:**
- Only works on LOGGED tables (WAL required)
- Tables must be in `supabase_realtime` publication
- RLS policies filter events per connected role

### 2. AI Activity — MCP → Browser (Broadcast)

**Purpose:** Claude sends live feedback to the user — progress, messages, navigation commands.

**Mechanism:** Supabase Realtime Broadcast (ephemeral, no persistence, no WAL).

**Channel:** `ai-activity`

**Message format:**
```typescript
interface AIBroadcast {
  msg?: string;      // Toast title
  detail?: string;   // Toast subtitle
  href?: string;     // Navigation link ("Ouvrir →")
  action?: string;   // "navigate" = auto-navigate without toast
}
```

**From MCP (server-side):**
```typescript
const channel = supabase.channel("ai-activity");
await channel.subscribe();
await channel.send({
  type: "broadcast",
  event: "activity",
  payload: { msg: "Devis généré", href: "/quote/devis?p_id=42" }
});
```

**Actions:**

| Action | Behavior |
|--------|----------|
| (none) | Toast notification with optional "Ouvrir" link |
| `navigate` | SPA navigation to `href`, no toast |

**Use cases:**
- Progress updates: "Importing 50 contacts... 23/50"
- Resource creation: "Client créé" → [Ouvrir]
- Navigation control: Claude guides user to a page
- Status: "Analyse terminée" with link to results

### 3. UI State — Browser → MCP (PG Session Table)

**Purpose:** Claude reads what the user sees — current selection, active page, viewport.

**Mechanism:** Browser writes to PG UNLOGGED table. Claude reads on demand (pull, not push).

**Table:** `document.session` (UNLOGGED — zero WAL, zero Realtime)

```sql
CREATE UNLOGGED TABLE document.session (
  canvas_id    UUID PRIMARY KEY,
  tenant_id    TEXT NOT NULL,
  selected_ids JSONB DEFAULT '[]',
  phase        TEXT DEFAULT 'idle',
  zoom         REAL DEFAULT 1,
  toast        JSONB DEFAULT NULL,
  updated_at   TIMESTAMPTZ DEFAULT now()
);
```

**Browser writes:** Selection, phase, zoom — throttled (500ms debounce).

**Claude reads:** `ill_get_state` → SELECT session + elements.

**Why UNLOGGED:** Ephemeral state. If PG restarts, sessions are lost — that's fine. No WAL overhead for high-frequency writes (drag, zoom).

## Integration in MCP Tools

### broadcast() helper

Available to all MCP tools via the DI container:

```typescript
// In any tool handler:
await broadcast({
  msg: "Client créé",
  detail: row.name,
  href: `/crm/client?p_id=${row.id}`
});
```

### Auto-broadcast on mutations

Tools that modify data can broadcast automatically:
- `pg_func_set` → "Function deployed: schema.func_name"
- `pg_query` (DML) → "N rows affected"
- `ill_add` → "Element added: {type}"

### pg_broadcast tool

Explicit broadcast for custom messages:
```
pg_broadcast msg: "Import terminé" detail: "50 contacts importés" href: "/crm/"
```

## Shell Integration

### pgView kernel (`cloudflare/pages/src/`)

**realtime.ts** — Supabase client singleton + `pgListen()` for CDC
**shell.ts** — `_watchSchema()` subscribes on navigation + `ai-activity` channel on boot

### Toast with link

```html
<div x-show="toast.show" x-transition>
  <div x-text="toast.msg"></div>
  <div x-text="toast.detail"></div>
  <a x-show="toast.href" @click.prevent="go(toast.href)">Ouvrir →</a>
</div>
```

## Supabase Publication Setup

All app tables that should trigger browser notifications must be added to the publication. Add to `seed_bootstrap.sql`:

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE
  crm.client,
  crm.interaction,
  quote.devis,
  quote.facture,
  project.project,
  document.canvas,
  document.element,
  -- ... all app tables
;
```

## Cost

| Action | Realtime messages | Quota impact |
|--------|-------------------|--------------|
| Broadcast (toast) | 1 | Minimal |
| INSERT (CDC) | 1 per row | Low |
| Session write (UNLOGGED) | 0 | Zero |
| Session read (SELECT) | 0 | Zero |

Typical session: ~100 messages. 500 users × 5 sessions/month = 250K messages.
Supabase Pro quota = 5M. Margin ×20.
