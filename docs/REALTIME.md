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
ALTER PUBLICATION supabase_realtime ADD TABLE schema.table_name;

-- RLS policy (Realtime respects RLS)
CREATE POLICY realtime_read ON schema.table_name
  FOR SELECT TO anon USING (true);
```

**Browser (automatic):** The shell subscribes to the current schema on navigation. INSERT events show a toast with a link.

**Convention:** Toast link = `/{schema}/{table}?p_id={id}`

**Limitations:**
- Only LOGGED tables (WAL required)
- Tables must be in `supabase_realtime` publication
- RLS policies filter events per connected role

### 2. AI Activity — MCP → Browser (Broadcast)

**Purpose:** Claude sends live feedback — progress, messages, navigation, UI primitives.

**Mechanism:** Supabase Realtime Broadcast (ephemeral, no persistence, no WAL).

**Channel:** `ai-activity`

**Persistence:** Broadcast = live delivery. `workbench.agent_message` = history. Both use the same payload format. The shell renders both with the same pgView primitives.

### 3. UI State — Browser → MCP (PG Session Table)

**Purpose:** Claude reads what the user sees — current page, selection, viewport.

**Mechanism:** Browser writes to PG UNLOGGED table. Claude reads on demand (pull).

**Why UNLOGGED:** Ephemeral state. No WAL overhead for high-frequency writes.

## Broadcast API

### Message Format

```typescript
interface AIBroadcast {
  // Display
  type?: "toast" | "card" | "progress" | "dialog";
  msg: string;
  detail?: string;
  level?: "info" | "success" | "warning" | "error";

  // Navigation
  href?: string;          // Link in notification ("Ouvrir →")
  action?: "navigate";    // Auto-navigate, no notification

  // pgView primitives (structured rendering)
  badge?: string;         // pgv.badge() label
  badgeVariant?: "success" | "danger" | "warning" | "info" | "primary";
  icon?: string;          // Emoji or HTML icon
  progress?: number;      // 0-100, renders progress bar

  // Actions (buttons in notification)
  actions?: {
    label: string;
    href?: string;        // Navigation on click
    rpc?: string;         // PostgREST RPC call on click
    params?: Record<string, unknown>;
    variant?: "primary" | "secondary" | "danger";
  }[];

  // Persistence
  persist?: boolean;      // Also INSERT into workbench.agent_message
}
```

### From MCP (server-side)

```typescript
// Simple toast
await broadcast({ msg: "Client créé", href: "/crm/client?p_id=42" });

// Progress bar
await broadcast({ type: "progress", msg: "Import contacts", progress: 45, detail: "23/50" });

// Card with badge and actions
await broadcast({
  type: "card",
  msg: "Devis #2026-042",
  detail: "Acme Corp — 12 450 € HT",
  badge: "En attente",
  badgeVariant: "warning",
  actions: [
    { label: "Voir le devis", href: "/quote/devis?p_id=42" },
    { label: "Envoyer", rpc: "quote.post_send_devis", params: { p_id: 42 }, variant: "primary" }
  ]
});

// Navigation control
await broadcast({ action: "navigate", href: "/document/editor?p_id=abc-123" });

// With persistence (also stored in agent_message)
await broadcast({
  msg: "Analyse terminée",
  detail: "3 anomalies détectées",
  href: "/ledger/anomalies",
  badge: "3",
  badgeVariant: "danger",
  persist: true
});
```

## Scenarios

### 1. Resource Creation — Toast with Link

```
User: "Crée un client Acme Corp"
Claude → pg_query INSERT → PG
Claude → broadcast({ msg: "Acme Corp", detail: "Client créé", href: "/crm/client?p_id=42", badge: "company" })
Browser → toast: [company] Acme Corp — Client créé [Ouvrir →]
```

### 2. Batch Import — Progress Bar

```
User: "Importe ce fichier CSV de 200 contacts"
Claude → loop 200 rows:
  → pg_query INSERT
  → broadcast({ type: "progress", msg: "Import contacts", progress: i/200*100, detail: `${i}/200` })
Browser → progress bar updates in real-time
Claude → broadcast({ msg: "Import terminé", detail: "200 contacts", href: "/crm/", level: "success" })
```

### 3. Document Generation — Live Composition

```
User: "Génère le devis pour le projet Maison Martin"
Claude → ill_doc new → canvas created
Claude → broadcast({ action: "navigate", href: "/document/editor?p_id=abc" })
Browser → navigates to illustrator
Claude → ill_add text "DEVIS" → PG INSERT → Realtime CDC → element appears on canvas
Claude → ill_add rect (header bg) → appears
Claude → ill_add text (client info) → appears
...user watches the document build itself...
Claude → broadcast({ msg: "Devis terminé", level: "success", actions: [
  { label: "Télécharger PDF", href: "/api/export-pdf?id=abc" },
  { label: "Envoyer au client", rpc: "quote.post_send", params: { p_id: 42 }, variant: "primary" }
]})
```

### 4. Contextual Suggestion — Claude Reads UI State

```
User navigates to /crm/client?p_id=42 (Acme Corp page)
Browser → writes current page to session table
Claude → ill_get_state / reads session → sees user is viewing Acme Corp
Claude → broadcast({
  msg: "Actions pour Acme Corp",
  actions: [
    { label: "Nouveau devis", rpc: "quote.post_create", params: { client_id: 42 } },
    { label: "Voir historique", href: "/crm/interactions?client_id=42" },
    { label: "Planifier RDV", href: "/planning/?client_id=42" }
  ]
})
Browser → notification with action buttons
```

### 5. Error Detection — Proactive Fix

```
User navigates to a page → 500 error displayed
Browser → writes error to session
Claude → reads session → detects error
Claude → broadcast({
  msg: "Erreur détectée",
  detail: "La fonction get_report manque dans le schema project",
  level: "warning",
  actions: [
    { label: "Corriger", rpc: "workbench.post_fix_issue", params: { fn: "project.get_report" }, variant: "primary" },
    { label: "Signaler", href: "/workbench/issues" }
  ]
})
```

### 6. Approval Workflow — Claude Asks, User Decides

```
Claude → analyzes data, finds something to do
Claude → broadcast({
  type: "dialog",
  msg: "Supprimer les 12 doublons ?",
  detail: "12 contacts en doublon détectés dans le CRM",
  level: "warning",
  actions: [
    { label: "Supprimer", rpc: "crm.post_deduplicate", variant: "danger" },
    { label: "Voir la liste", href: "/crm/?filter=duplicates" },
    { label: "Annuler", variant: "secondary" }
  ]
})
Browser → dialog with choices → user clicks → action executed
```

### 7. Multi-step Wizard — Guided Flow

```
User: "Aide-moi à configurer le module comptabilité"
Claude → broadcast({ msg: "Configuration Comptabilité", detail: "Étape 1/4 — Plan comptable", progress: 25,
  actions: [{ label: "Importer le plan standard", rpc: "ledger.post_import_plan", variant: "primary" }]
})
User clicks → plan imported
Claude → broadcast({ msg: "Configuration Comptabilité", detail: "Étape 2/4 — Comptes bancaires", progress: 50,
  actions: [{ label: "Ajouter un compte", href: "/ledger/account_form" }]
})
...
```

### 8. Chat-like Panel — Activity Feed

```
The shell renders broadcasts in a side panel (not just toasts):
- Persistent history from workbench.agent_message
- Live updates from broadcast channel
- Each message rendered with pgView primitives (cards, badges, actions)
- Clickable links for navigation
- Like a Slack-style activity feed, but AI-native
```

## Shell Rendering

### pgView Primitives in Notifications

The shell renders broadcast payloads using the same primitives as pages:

| Broadcast field | pgView primitive | Rendering |
|----------------|-----------------|-----------|
| `msg` | Text | Bold title |
| `detail` | Small text | Subtitle in muted color |
| `badge` + `badgeVariant` | `pgv.badge()` | Colored label |
| `progress` | `pgv.progress()` | Progress bar |
| `actions[]` | `pgv.action()` | Buttons row |
| `href` | Link | "Ouvrir →" anchor |
| `icon` | Inline | Prefix icon |
| `type: "card"` | `pgv.card()` | Full card layout |
| `type: "dialog"` | `<dialog>` | Modal with actions |

### Notification Panel (future)

A persistent side panel that shows the activity feed:
- Recent broadcasts (ephemeral, in memory)
- Persisted messages from `workbench.agent_message`
- Grouped by time (today, yesterday, this week)
- Each rendered with pgView primitives
- Filter by module, type, priority

## MCP Integration

### broadcast() helper — Awilix service

```typescript
// Registered in container as 'broadcast'
export function createBroadcastService({ supabaseClient }: { supabaseClient: SupabaseClient }) {
  let channel: RealtimeChannel | null = null;

  return async function broadcast(payload: AIBroadcast): Promise<void> {
    // 1. Live broadcast
    if (!channel) {
      channel = supabaseClient.channel("ai-activity");
      await channel.subscribe();
    }
    await channel.send({ type: "broadcast", event: "activity", payload });

    // 2. Persist if requested
    if (payload.persist) {
      await supabaseClient.from("agent_message").insert({
        from_module: "ai",
        to_module: "user",
        msg_type: "notification",
        subject: payload.msg,
        body: payload.detail,
        payload: payload,
      });
    }
  };
}
```

### pg_broadcast tool

```
pg_broadcast msg: "Import terminé" detail: "50 contacts" href: "/crm/" persist: true
```

### Auto-broadcast in existing tools

Tools can opt-in to broadcast on mutations:
- `pg_func_set` → success toast with function name
- `ill_add` → element type + canvas link
- `pg_query` DML → row count + schema link

## Supabase Publication Setup

Add to `seed_bootstrap.sql`:

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE
  crm.client, crm.interaction,
  quote.devis, quote.devis_ligne, quote.facture,
  project.project, project.phase,
  planning.event,
  stock.article, stock.movement,
  purchase.order_header, purchase.order_line,
  catalog.article,
  ledger.entry,
  expense.note, expense.line,
  hr.employee,
  document.canvas, document.element;
```

## Cost

| Action | Realtime messages | Quota impact |
|--------|-------------------|--------------|
| Broadcast (toast/card) | 1 | Minimal |
| INSERT CDC | 1 per row | Low |
| Progress (100 updates) | 100 | Low |
| Session write (UNLOGGED) | 0 | Zero |

Typical session: ~200 messages. 500 users x 5 sessions/month = 500K.
Supabase Pro = 5M. Margin x10.
