# Illustrator — Modèle de réactivité

## Acteurs

| Acteur | Rôle |
|--------|------|
| **Claude** (MCP) | Compose des documents via les outils ill_* (stateless, per-request) |
| **User** (Browser) | Édite directement : drag, sélection, resize, edit texte |
| **PG** | Source de vérité pour les données persistées |

## Principe

Le MCP est stateless. Le browser est stateful. PG est le pont.

- **Données persistées** (canvas, elements, assets) → PG tables normales
- **État éphémère** (sélection, phase, zoom, toast) → PG UNLOGGED table (mémoire pure)
- **Sync Claude → Browser** → Supabase Realtime Postgres Changes (push automatique)
- **Sync Browser → Claude** → Claude lit la session table quand il en a besoin (pull)

## Flux

### Claude compose → Browser voit

```
Claude → ill_add → Worker → INSERT element → PG
                                               │
                                    Realtime Postgres Change
                                               │
                                               ▼
                                    Browser Zustand store → D3 render
```

### User édite → PG persiste

```
User drag (local Zustand, 60fps, zéro PG)
User dragEnd → PostgREST UPDATE element SET x, y → PG
                                                    │
                                         Realtime (autres clients)
```

### User sélectionne → Claude peut lire

```
User sélectionne element → UPDATE document.session SET selected_ids → PG UNLOGGED
                           (zéro WAL, zéro Realtime, ~1ms)

Claude → ill_get_state → SELECT elements + SELECT session → voit la sélection
```

### Claude envoie un toast → User voit

```
Claude → ill_show_message → UPDATE document.session SET toast → PG UNLOGGED
Browser poll session toutes les 2s → affiche le toast
```

## Tables

### Persistées (WAL, Realtime)

```sql
document.canvas   — format, dimensions, background, meta
document.element  — type, geometry, props, parent_id, sort_order
document.gradient — définitions gradient
asset.asset       — images, métadonnées
```

### Éphémères (UNLOGGED, zéro WAL, zéro Realtime)

```sql
CREATE UNLOGGED TABLE document.session (
  canvas_id    UUID PRIMARY KEY REFERENCES document.canvas(id) ON DELETE CASCADE,
  tenant_id    TEXT NOT NULL DEFAULT current_setting('app.tenant_id', true),
  selected_ids JSONB DEFAULT '[]',
  phase        TEXT DEFAULT 'idle',     -- idle | selected | dragging | editing_prop
  zoom         REAL DEFAULT 1,
  toast        JSONB DEFAULT NULL,      -- {text, level, duration} ou NULL
  updated_at   TIMESTAMPTZ DEFAULT now()
);
```

## Coût Realtime

| Action | Messages Realtime | Quota impact |
|--------|-------------------|-------------|
| Claude ill_add (1 élément) | 1 | Minimal |
| Claude ill_batch (10 éléments) | 10 | Faible |
| User dragEnd | 1 | Minimal |
| User sélection | 0 (UNLOGGED) | Zéro |
| Claude ill_get_state | 0 (SELECT) | Zéro |
| Claude ill_show_message | 0 (UNLOGGED) | Zéro |

Session typique : ~100 messages Realtime.
100 users × 5 sessions/mois = 50K messages. Quota Pro = 5M. Marge ×100.

## Gestion des conflits

**Last-write-wins.** Le dernier UPDATE sur un élément gagne.

- Pendant un drag, le browser ignore les Realtime updates sur l'élément en cours de drag
- À dragEnd, le browser écrit sa position → écrase celle de Claude si Claude a modifié entre-temps
- Acceptable pour 1 user + AI. Pour multi-user futur → CRDT ou OT

## Stack client

```
Zustand (store)
├── canvas: Canvas          ← PG initial load + Realtime updates
├── elements: Element[]     ← PG initial load + Realtime updates
├── selectedIds: string[]   ← local + PG UNLOGGED sync
├── phase: AppPhase         ← local + PG UNLOGGED sync
├── zoom: number            ← local only

D3.js (canvas SVG)
├── Render depuis Zustand state
├── Drag handlers → Zustand optimistic → PG au dragEnd
├── Snap system (local)

supabase-js (transport)
├── Realtime subscribe → Zustand mutations
├── PostgREST → CRUD element/canvas
├── Auth → JWT
```
