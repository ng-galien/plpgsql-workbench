# ops — Agent Dashboard

Dashboard temps réel pour piloter les agents Claude Code. Historique par agent, messages pg_msg, remontées des hooks, terminaux xterm.js embarqués.

**Dépend de :** `pgv` (primitives UI)

## Schemas

| Schema | Role |
|--------|------|
| `ops` | Pages dashboard |
| `ops_ut` | pgTAP tests |

## Layout

```
build/ops.ddl.sql         # Schemas + grants (tables dans workbench, pas dans ops)
build/ops.func.sql        # pg_pack output (ops + ops_ut)
src/ops/*.sql             # Function sources
src/ops_ut/test_*.sql     # Tests
frontend/ops.js           # xterm.js integration, Alpine.js components
frontend/ops.css          # Dashboard layout styles
```

## Architecture

Le module ops **ne possède pas de tables**. Il lit les tables `workbench.*` :

| Table | Contenu | Alimenté par |
|-------|---------|-------------|
| `workbench.agent_message` | Messages pg_msg entre agents | pg_msg tool |
| `workbench.hook_log` | Événements hooks (allow/deny) | `/hooks/:module` endpoint |
| `workbench.agent_session` | Sessions agents (start/end/status) | WebSocket terminal endpoint |

## Backend (déjà implémenté dans src/index.ts)

### WebSocket Terminal
- **Endpoint** : `ws://localhost:3100/ws/terminal/:module`
- Spawn un shell dans `modules/:module/` via node-pty
- xterm-256color, 120×40 par défaut
- Resize via message JSON `{"type":"resize","cols":N,"rows":N}`
- Terminal persistant — survit à la déconnexion du client
- Plusieurs clients peuvent observer le même terminal

### REST API
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/agents` | GET | Liste des sessions (+ `has_terminal` live) |
| `/api/hooks` | GET | Hook log (filtrable `?module=X`) |
| `/api/messages` | GET | Messages pg_msg (filtrable `?module=X`) |
| `/api/agents/:module/spawn` | POST | Prépare le spawn (terminal créé au 1er WebSocket) |
| `/api/agents/:module/kill` | POST | Kill le terminal d'un agent |

### Hook Logging
Chaque appel à `/hooks/:module` est loggué dans `workbench.hook_log` :
- `module` — qui a déclenché
- `tool` — quel tool MCP
- `action` — détail (SQL tronqué, filepath, schema)
- `allowed` — true/false
- `reason` — motif si bloqué

## Pages

| Fonction | Route | Description |
|----------|-------|-------------|
| `ops.get_index()` | `/` | Dashboard principal — grille d'agents, stats globales |
| `ops.get_agent(p_module text)` | `/agent?module=X` | Vue agent : terminal xterm.js + messages + hooks |
| `ops.get_messages()` | `/messages` | Tous les messages pg_msg, filtrables |
| `ops.get_hooks()` | `/hooks` | Tous les hook events, filtrables |

### Dashboard (`get_index`)
- **Grille d'agents** : une card par module connu (pgv, cad, crm, quote, ledger)
  - Status badge (running/idle/done/error)
  - Nombre de fonctions (pg_proc)
  - Messages non lus (workbench.agent_message status='new')
  - Dernière activité hook
  - Bouton "Ouvrir" → `/agent?module=X`
  - Bouton "Spawn" / "Kill" selon état
- **Stats globales** : messages total/new/resolved, hooks allow/deny ratio
- **Timeline** : derniers événements (messages + hooks) intercalés chronologiquement

### Vue Agent (`get_agent`)
- **Terminal xterm.js** (60% de la page) : connecté via WebSocket
- **Panel latéral** (40%) :
  - Messages entrants/sortants pour ce module
  - Hook log filtré (derniers 20 events, badges allow/deny)
  - Stats : fonctions count, tests passants

### Messages (`get_messages`)
- md_table paginée : from, to, type badge, subject, status badge, date
- Filtre par module (query param)

### Hooks (`get_hooks`)
- md_table paginée : module, tool, action, allowed badge, reason, date
- Filtre par module, par allowed/denied

## Frontend (ops.js)

### xterm.js Integration
```javascript
// Alpine.js component
Alpine.data('agentTerminal', (module) => ({
  term: null,
  ws: null,
  init() {
    this.term = new Terminal({ cursorBlink: true, fontSize: 13 });
    this.term.open(this.$refs.terminal);
    const fitAddon = new FitAddon();
    this.term.loadAddon(fitAddon);
    this.ws = new WebSocket(`ws://${location.hostname}:3100/ws/terminal/${module}`);
    this.ws.onmessage = (e) => this.term.write(e.data);
    this.term.onData((data) => this.ws.send(data));
    fitAddon.fit();
    // Resize
    this.term.onResize(({cols, rows}) => {
      this.ws.send(JSON.stringify({type:'resize', cols, rows}));
    });
  }
}));
```

### CDN Dependencies
- xterm.js 5.x : `@xterm/xterm` (terminal)
- `@xterm/addon-fit` (auto-resize)

### Real-time Updates
Polling `/api/agents`, `/api/hooks`, `/api/messages` toutes les 5s pour mettre à jour les badges et stats.

## Primitives pgView

| Primitive | Usage |
|-----------|-------|
| `pgv.page()` | Layout dashboard |
| `pgv.stat()` | KPIs globaux (agents actifs, messages, hooks) |
| `pgv.badge()` | Status agents, type messages, allow/deny hooks |
| `pgv.card()` | Agent cards dans la grille |
| `pgv.md_table()` | Listes messages et hooks |
| `pgv.grid()` | Grille d'agents |
| `pgv.tabs()` | Vue agent (terminal / messages / hooks) |
| `pgv.alert()` | Alertes (agent stuck, messages non lus) |
| `pgv.empty()` | Aucun agent, aucun message |

## Conventions

- **UI :** French — Agent, Terminal, Messages, Événements, Actif, Arrêté, Bloqué
- **Pages GET** : `get_*()` retournent `"text/html"`, wrappées dans `pgv.page()`
- **Navigation** : `nav_items()` retourne `TABLE(label, href, icon)`, `brand()` retourne text
- **Pas de POST** : le dashboard est read-only côté PL/pgSQL. Les actions (spawn/kill) passent par l'API REST.
- **Helpers privés** : préfixe `_`

## Module Discovery

Les modules sont découverts dynamiquement via :
```sql
SELECT DISTINCT schema_name
FROM workbench.toolbox_tool t
JOIN information_schema.schemata s ON s.schema_name = split_part(t.tool_name, '_', 1)
```
Ou plus simplement : liste hardcodée des modules connus + détection via `pg_namespace`.

## File Export

- `ops`, `ops_ut` → `src/`
- **pg_pack :** `ops,ops_ut`

## Testing

```
pg_test target: "plpgsql://ops_ut"
```

## Review UI/UX

Quand les pages sont fonctionnelles :
```
pg_msg from:ops to:pgv type:question subject:"Review UI/UX pages Ops Dashboard"
```

## Gotchas

- **Tables dans workbench, pas dans ops** — Le module ops ne possède aucune table. Il lit `workbench.agent_message`, `workbench.hook_log`, `workbench.agent_session`.
- **WebSocket sur port MCP (3100)** — Les terminaux passent par le même serveur Express, pas par PostgREST. L'URL WebSocket est `ws://localhost:3100/ws/terminal/:module`.
- **Terminal persistant** — Le terminal survit à la fermeture de l'onglet dashboard. Il faut explicitement kill via l'API.
- **Dev mode only** — Tous les endpoints `/api/*` et `/ws/*` sont bloqués si `WORKBENCH_MODE !== 'dev'`.
- **node-pty natif** — Nécessite un compilateur C++ (inclus sur macOS avec Xcode CLI tools).
- **xterm.js depuis CDN** — Pas de bundler, chargé via `<script>` comme Three.js dans cad.
