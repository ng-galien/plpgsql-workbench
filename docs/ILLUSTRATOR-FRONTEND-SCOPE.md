# Illustrator Frontend — Scope v2 (Alpine.js rewrite)

## Leçon apprise

Le port "adapter les fichiers existants" ne marche pas — trop de DOM manipulation à la main (`getElementById`, `innerHTML`, `createElement`), trop fragile, trop de patches. Mieux vaut repartir propre avec Alpine.js pour le chrome UI.

## Architecture

```
┌────────────────────────────────────────────────────┐
│ Alpine.js shell (chrome UI)                         │
│ ├── x-data="illustrator"  → Zustand bridge         │
│ ├── Toolbar         @click, x-show                  │
│ ├── Doc selector    x-for, @click=loadDoc           │
│ ├── Layers tree     x-for recursive, x-show         │
│ ├── Props panel     x-model, @input=updateElement   │
│ ├── Photo library   x-for, @click=selectAsset       │
│ ├── Toast           x-show, x-transition            │
│ └── Image editor    x-show (modal)                  │
│                                                      │
│ ┌──────────────────────────────────────────────┐    │
│ │ D3.js SVG canvas (inchangé)                  │    │
│ │ ├── render.ts — éléments, sélection, snap    │    │
│ │ ├── zoom.ts — D3 zoom behavior               │    │
│ │ └── snap.ts — calcul magnétique              │    │
│ └──────────────────────────────────────────────┘    │
│                                                      │
│ Zustand store (source de vérité)                    │
│ ├── canvas, elements, selectedIds, phase            │
│ └── synced via Supabase RPC + Realtime              │
└────────────────────────────────────────────────────┘
```

## Ce qu'on garde du legacy

| Fichier | Lignes | Raison |
|---------|--------|--------|
| `store.ts` | 200 | Zustand store — déjà réécrit, on le garde |
| `render.ts` | 580 | D3 canvas — le cœur, inchangé |
| `snap.ts` | 109 | Snap magnétique — pure math |
| `zoom.ts` | ~80 | D3 zoom behavior |
| `image-editor.ts` | 370 | Modal crop/filters — à migrer vers Alpine progressivement |
| `history.ts` | ~50 | Undo/redo — logique pure |
| CSS (11 fichiers) | ~2000 | Gardés, réutilisés |

## Ce qu'on supprime (remplacé par Alpine)

| Fichier | Lignes | Remplacé par |
|---------|--------|-------------|
| `ui.ts` | 187 | Alpine template déclaratif |
| `props.ts` | 363 | Alpine `x-model` + `@input` |
| `photos.ts` | 98 | Alpine `x-for` |
| `toast.ts` | ~40 | Alpine `x-show` + `x-transition` |
| `events.ts` | 336 | Alpine `@keydown.window` + render.ts |
| `clipboard.ts` | ~40 | Alpine + RPC |
| `ws.ts` | ~90 | `supabase-sync.ts` (déjà réécrit) |
| `store/index.ts` | ~130 | Plus besoin du bridge — Alpine lit Zustand direct |
| `app.ts` | ~40 | Alpine `x-init` |

## Toutes les requêtes via RPC

Plus de `supabase.from("table").select()` — tout passe par les procédures stockées du module document :

| Action | Avant (SELECT direct) | Après (RPC) |
|--------|----------------------|-------------|
| Charger canvas + elements | `.from("canvas").select()` + `.from("element").select()` | `rpc("canvas_get_state")` |
| Sync session | `.from("session").upsert()` | `rpc("session_sync")` |
| Ajouter élément | `.rpc("element_add")` | `rpc("element_add")` ✅ déjà |
| Modifier élément | `.rpc("element_update")` | `rpc("element_update")` ✅ déjà |
| Supprimer élément | `.rpc("element_delete")` | `rpc("element_delete")` ✅ déjà |
| Charger doc list | `.from("canvas").select("id,name")` | `rpc("list_canvases")` ou data_canvases |
| Charger assets | `fetch("/rest/v1/asset")` | `rpc("search")` schema asset |
| Toast | `.from("session").update({toast})` | `rpc("session_toast")` |

## Le HTML Alpine

Un seul fichier HTML avec tout le markup déclaratif :

```html
<div x-data="illustrator" x-init="init()">

  <!-- Toolbar -->
  <header class="menu-bar">
    <button @click="undo()">Undo</button>
    <button @click="redo()">Redo</button>
    <span x-text="canvas?.name ?? 'Aucun document'"></span>
    <span x-text="Math.round(zoom * 100) + '%'"></span>
  </header>

  <!-- Workspace -->
  <div class="workspace">
    <!-- Layers -->
    <aside x-show="!layersPanelCollapsed">
      <template x-for="el in elements" :key="el.id">
        <div @click="selectElement(el.id)"
             :class="{ active: selectedIds.includes(el.id) }"
             x-text="el.name ?? el.type"></div>
      </template>
    </aside>

    <!-- Canvas (D3 — pas Alpine) -->
    <svg id="canvas"></svg>

    <!-- Props -->
    <aside x-show="selectedIds.length > 0">
      <template x-if="selectedElement">
        <div>
          <label>X <input type="number" x-model.number="selectedElement.x"
                          @input="updateElement(selectedElement.id, {x: $event.target.value})"></label>
          <label>Fill <input type="color" x-model="selectedElement.fill"
                             @input="updateElement(selectedElement.id, {fill: $event.target.value})"></label>
        </div>
      </template>
    </aside>
  </div>

  <!-- Toast -->
  <div x-show="toast" x-transition class="toast" x-text="toast?.text"></div>
</div>
```

## Alpine ↔ Zustand bridge

```javascript
Alpine.data("illustrator", () => ({
  // Reactive getters from Zustand
  get canvas() { return store.getState().canvas; },
  get elements() { return store.getState().elements; },
  get selectedIds() { return store.getState().selectedIds; },
  get phase() { return store.getState().phase; },
  get zoom() { return store.getState().zoom; },
  get toast() { return store.getState().toast; },

  get selectedElement() {
    const ids = this.selectedIds;
    return ids.length === 1 ? this.elements.find(e => e.id === ids[0]) : null;
  },

  // Init: subscribe Zustand → Alpine reactivity
  init() {
    store.subscribe(() => { this.$nextTick(() => {}); }); // force Alpine update
    initSupabaseSync(canvasId);
    initD3Canvas(); // render.ts
  },

  // Actions → Zustand → PG
  selectElement(id) { store.getState().selectElement(id); },
  updateElement(id, props) { supabase.rpc("element_update", {...}); },
  loadDoc(id) { /* switch canvas */ },
  undo() { undoManager.undo(); },
  redo() { undoManager.redo(); },
}));
```

## Estimation

| Tâche | Effort |
|-------|--------|
| HTML Alpine (toolbar + panels + tree + props) | 3h |
| Alpine ↔ Zustand bridge | 1h |
| RPC pour toutes les requêtes | 1h |
| Intégration D3 render.ts | 1h |
| Image editor Alpine migration | 2h |
| CSS adaptation | 1h |
| Test + debug | 2h |
| **Total** | **~11h** |

## Ce qui NE CHANGE PAS

- D3 canvas rendering (render.ts, 580 lignes)
- Snap system (snap.ts, 109 lignes)
- Zoom (zoom.ts)
- Zustand store (store.ts)
- Supabase Realtime sync (supabase-sync.ts — adapté pour RPC)
- Undo/redo (history.ts)
- Tous les CSS
