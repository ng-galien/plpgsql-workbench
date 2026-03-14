# Illustrator Frontend — Scope des modifications

Source : `modules/document/frontend/illustrator/` (copie brute de mcp-illustrator/client/)

## Fichiers à garder tels quels

| Fichier | Lignes | Raison |
|---------|--------|--------|
| `render.ts` | 580 | D3 canvas, drag, snap, selection handles — le cœur |
| `snap.ts` | 109 | Snap magnétique — pure math, aucune dépendance serveur |
| `image-editor.ts` | 370 | Modal crop/filters — DOM pur |
| `text.ts` | ~50 | Inline text editing — DOM pur |
| `helpers.ts` | ~30 | Utilitaires DOM |
| `utils.ts` | ~20 | escape HTML, etc. |
| `clipboard.ts` | ~40 | Copy/paste — adapte juste les appels serveur |
| `history.ts` | ~50 | Undo/redo manager — local, pas de serveur |
| `types.ts` | ~30 | Types client (AppPhase, etc.) |
| **Styles (11 CSS)** | ~2000 | Tous gardés tels quels |

## Fichiers à remplacer

### `store/` → Zustand

**Avant** (7 fichiers, ~450 lignes) : Redux-like custom (Store class, reducers, guards, middleware, events, subscribe, logger)

**Après** (1 fichier, ~80 lignes) : Zustand vanilla store

```typescript
// store.ts
import { createStore } from 'zustand/vanilla';

export const store = createStore((set, get) => ({
  // Persistent (synced from PG)
  canvas: null,
  elements: [],

  // Ephemeral (synced to PG UNLOGGED session)
  selectedIds: [],
  phase: 'idle',
  zoom: 1,

  // Actions
  setCanvas: (c) => set({ canvas: c }),
  setElements: (els) => set({ elements: els }),
  addElement: (el) => set(s => ({ elements: [...s.elements, el] })),
  updateElement: (id, props) => set(s => ({
    elements: s.elements.map(e => e.id === id ? { ...e, ...props } : e)
  })),
  removeElement: (id) => set(s => ({
    elements: s.elements.filter(e => e.id !== id)
  })),
  selectElement: (id) => set({ selectedIds: [id], phase: 'selected' }),
  clearSelection: () => set({ selectedIds: [], phase: 'idle' }),
  setPhase: (p) => set({ phase: p }),
  setZoom: (z) => set({ zoom: z }),
}));
```

### `ws.ts` → `supabase-realtime.ts`

**Avant** (124 lignes) : WebSocket custom, `requestFromClient`, `wsSend`

**Après** (~60 lignes) : Supabase Realtime + PostgREST

```typescript
// supabase-realtime.ts
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Subscribe to element changes for a canvas
export function subscribeToCanvas(canvasId: string) {
  return supabase
    .channel(`canvas-${canvasId}`)
    .on('postgres_changes', {
      event: '*',
      schema: 'document',
      table: 'element',
      filter: `canvas_id=eq.${canvasId}`,
    }, (payload) => {
      if (payload.eventType === 'INSERT') store.getState().addElement(payload.new);
      if (payload.eventType === 'UPDATE') store.getState().updateElement(payload.new.id, payload.new);
      if (payload.eventType === 'DELETE') store.getState().removeElement(payload.old.id);
    })
    .subscribe();
}

// Write ephemeral state to PG UNLOGGED session
export function syncSession(canvasId: string) {
  const { selectedIds, phase, zoom } = store.getState();
  supabase.from('session').upsert({
    canvas_id: canvasId,
    selected_ids: selectedIds,
    phase,
    zoom,
  });
}

// CRUD via PostgREST
export async function addElement(canvasId, type, props) {
  return supabase.rpc('element_add', { p_canvas_id: canvasId, p_type: type, p_props: props });
}

export async function updateElement(id, props) {
  return supabase.rpc('element_update', { p_element_id: id, p_props_patch: props });
}
```

### `photos.ts` → adapté pour Supabase Storage

**Avant** : `fetch('/api/assets')`, `fetch('/api/upload')`

**Après** : `supabase.from('asset').select()`, `supabase.storage.from('assets').upload()`

### `props.ts` → adapté pour PostgREST

**Avant** : `wsSend({ type: 'update_element', id, props })`

**Après** : `supabase.rpc('element_update', { p_element_id: id, p_props_patch: props })`

### `events.ts` → adapté pour Zustand

**Avant** : `dispatch({ type: 'SELECT_ELEMENT', id })`

**Après** : `store.getState().selectElement(id)`

### `ui.ts` → adapté pour Zustand

**Avant** : `store.state.ui.showNames`, `dispatch({ type: 'TOGGLE_SHOW_NAMES' })`

**Après** : `store.getState().showNames`, `store.setState({ showNames: !get().showNames })`

### `toast.ts` → poll PG session au lieu de WS

**Avant** : WS `{ type: "toast", text, level }`

**Après** : `setInterval(() => supabase.from('session').select('toast')..., 2000)`

### `zoom.ts` → inchangé (D3 behavior, local)

### `app.ts` → point d'entrée simplifié

**Avant** : importe store Redux, guards, middleware, WS

**Après** : importe Zustand store, Supabase client, subscribe

### `index.html` → adapté pour le shell pgView

**Avant** : standalone HTML avec tous les CDN

**Après** : intégré dans le shell pgView (Alpine nav, PicoCSS) OU standalone sur Cloudflare Pages

## Ordre d'implémentation

1. **Zustand store** (remplace store/) — 1 fichier
2. **supabase-realtime.ts** (remplace ws.ts) — 1 fichier
3. **app.ts** rewrite — point d'entrée avec Zustand + Supabase
4. **render.ts** adapter les imports (store.state → store.getState())
5. **events.ts** adapter les dispatch → Zustand actions
6. **props.ts** adapter wsSend → PostgREST
7. **photos.ts** adapter fetch → supabase-js
8. **toast.ts** adapter WS → session poll
9. **ui.ts** adapter dispatch → Zustand
10. **Build** — Vite ou esbuild → bundle pour Cloudflare Pages
11. **Test** — ouvrir le canvas, Claude compose, user drag

## Estimation

| Tâche | Effort |
|-------|--------|
| Zustand store | 1h |
| Supabase Realtime | 2h |
| Adapter render/events/props | 3h |
| Adapter photos/toast/ui | 2h |
| Build pipeline | 1h |
| Test + debug | 2h |
| **Total** | **~11h** |

## Ce qui NE CHANGE PAS

- D3 canvas rendering (580 lignes)
- Snap system (109 lignes)
- Image editor modal (370 lignes)
- Tous les CSS (2000 lignes)
- Undo/redo manager
- Text inline editing
- Le modèle de données (Element types)
