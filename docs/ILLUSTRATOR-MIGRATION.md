# Illustrator → Workbench Migration Plan

## Architecture cible

Illustrator devient un **pack MCP** (`src/core/packs/illustrator.ts`) dans le workbench.
Le stockage repose sur **CAD 2D** (PostgreSQL). Le client web est hébergé sur **Supabase**.
La collaboration passe par **Supabase Realtime** au lieu de WebSocket custom.

```
┌────────────────────────────────────────────────────────┐
│ Claude (Desktop / claude.ai)                           │
│ MCP Streamable HTTP → Edge Function                    │
└────────────┬───────────────────────────────────────────┘
             │
┌────────────▼───────────────────────────────────────────┐
│ Supabase Edge Function                                 │
│ packs/illustrator.ts — 36 outils DSL agent             │
│ ├── positionnement relatif (below, center_h, gap)      │
│ ├── batch operations (batch_add, batch_update)         │
│ ├── layout analysis (check_layout)                     │
│ ├── text measurement (opentype.js)                     │
│ └── exports (SVG, PNG, DOCX)                           │
├────────────┬───────────────────────────────────────────┤
│            │ SQL (postgres.js)                          │
│ PostgreSQL │                                           │
│ ├── cad.drawing (document canvas)                      │
│ ├── cad.shape (éléments: text, image, rect, line)      │
│ ├── cad.layer (calques)                                │
│ ├── illustrator.asset (métadonnées images)             │
│ └── cad.render_svg() (rendu serveur)                   │
├────────────┼───────────────────────────────────────────┤
│ Realtime   │ Postgres Changes → push au client         │
│            │ Broadcast → toasts, selection sync         │
├────────────┼───────────────────────────────────────────┤
│ Storage    │ Bucket "assets" (images utilisateur)       │
│            │ Bucket "exports" (PDF, SVG, DOCX temp)     │
├────────────┼───────────────────────────────────────────┤
│ Auth       │ OAuth 2.0 (Claude Directory)              │
└────────────┴───────────────────────────────────────────┘
             │
┌────────────▼───────────────────────────────────────────┐
│ Client Web (Supabase static / Vercel)                  │
│ ├── D3 SVG canvas (drag, snap, selection)              │
│ ├── Image editor modal (crop, filters)                 │
│ ├── Asset library panel (photothèque)                  │
│ ├── Undo/redo manager                                  │
│ ├── State machine (phases: idle → selected → dragging) │
│ └── supabase-js (Realtime subscribe + Storage URLs)    │
└────────────────────────────────────────────────────────┘
```

## Les 5 piliers à préserver

### 1. Collaboration bidirectionnelle

**Aujourd'hui** : WebSocket custom + `requestFromClient()` (request/response over WS).
Claude envoie un message typé au client, le client répond avec `_reqId`.

**Cible** : Supabase Realtime (Broadcast channel).
- Canal `doc-{drawingId}` : Postgres Changes sur cad.drawing + cad.shape
- Canal `collab-{drawingId}` : Broadcast pour selection sync, toasts, inspect

**Équivalences** :

| Aujourd'hui (WS) | Cible (Realtime) |
|-------------------|------------------|
| `{ type: "state", doc, docList }` | Postgres Changes sur drawing/shape |
| `{ type: "select_element", id }` | Broadcast `{ event: "select", elementId }` |
| `{ type: "select_asset", path }` | Broadcast `{ event: "select_asset", path }` |
| `{ type: "toast", text, level }` | Broadcast `{ event: "toast", text, level }` |
| `requestFromClient("inspect")` | Broadcast request + response pattern |
| `requestFromClient("dispatch")` | Broadcast `{ event: "dispatch", payload }` |
| `{ type: "reload" }` | N/A (pas de hot reload en prod) |

### 2. Éditeur complet standalone

Le client D3/SVG reste quasi-identique. Changements :
- **WS → supabase-js Realtime** : remplacer `ws.send()` par `channel.send()`
- **State sync** : le client écoute Postgres Changes au lieu de `{ type: "state" }`
- **Mutations** : le client appelle PostgREST (`/rpc/add_shape`, `/rpc/move_shape`) au lieu de WS
- **Assets** : `fetch("/api/assets")` → `supabase.storage.from("assets").list()`

### 3. Asset management intelligent

**Principe fondamental** : les images (blobs) ne transitent **jamais** par le MCP.
Le MCP ne manipule que des IDs, URLs signées, et métadonnées texte (~100-500 bytes/appel).

**Aujourd'hui** : `assets/` filesystem + `metadata.json` statique.

**Cible** : Supabase Storage (blobs) + table PG (métadonnées) + classification par Claude (vision).

#### Flux upload & classification

```
1. UPLOAD (client web → Supabase, sans MCP)
   Client web → Supabase Storage (upload direct, signed URL)
   Client web → INSERT illustrator.asset (filename, path, status: 'to_classify')
   L'image lourde ne passe que entre le navigateur et Storage.

2. CLASSIFICATION (Claude via MCP, texte léger uniquement)
   Claude → list_assets status:'to_classify'          (~100 bytes/asset)
   Claude → get_asset_url id:123                       → URL signée (~200 bytes)
   Claude → [vision multimodale] regarde l'image via l'URL
   Claude → classify_asset id:123                      (~500 bytes)
            tags:['jazz','concert'] description:'Saxophoniste sur scène'
            width:1920 height:1080 orientation:'paysage'

3. UTILISATION (Claude via MCP, référence par ID)
   Claude → add_image asset_id:123 below:title center_h
   PG stocke la référence (asset_id FK), pas le blob.
   Le client web charge l'image depuis Storage via URL signée.

4. BROWSE (client web, sans MCP)
   Client web → SELECT * FROM illustrator.asset WHERE user_id = $1
   Client web → Supabase Storage thumbnails (Image Transformation API)
   L'utilisateur browse, sélectionne → état sync via Realtime → Claude le voit.
```

#### Outils MCP asset

| Outil | Input | Output | Taille |
|-------|-------|--------|--------|
| `list_assets` | status, tags[], q (FTS) | id, filename, tags, description, dimensions | ~100 bytes/asset |
| `get_asset_url` | asset_id | URL signée temporaire (60min) | ~200 bytes |
| `classify_asset` | asset_id, tags, description, etc. | confirmation | ~100 bytes |
| `delete_asset` | asset_id | confirmation | ~50 bytes |

**Zéro blob dans le contexte MCP. Jamais.**

#### Schéma PG

```sql
CREATE TABLE illustrator.asset (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  path        TEXT NOT NULL,              -- Storage bucket path
  filename    TEXT NOT NULL,
  mime_type   TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'to_classify'
              CHECK (status IN ('to_classify', 'classified', 'archived')),
  -- Dimensions (remplies à l'upload par le client ou à la classification)
  width       INTEGER,
  height      INTEGER,
  orientation TEXT,                        -- portrait/paysage
  -- Métadonnées (remplies par Claude via classify_asset)
  title       TEXT,
  description TEXT,
  tags        TEXT[],
  credit      TEXT,
  saison      TEXT,                        -- printemps/été/automne/hiver
  usage_hint  TEXT,                        -- affiche, tract, bulletin, web
  colors      TEXT[],                      -- couleurs dominantes extraites
  -- Timestamps
  created_at  TIMESTAMPTZ DEFAULT now(),
  classified_at TIMESTAMPTZ
);

-- RLS
ALTER TABLE illustrator.asset ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own assets" ON illustrator.asset
  FOR ALL USING (auth.uid() = user_id);

-- FTS sur description + tags
ALTER TABLE illustrator.asset ADD COLUMN search_vec tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('pgv_search', coalesce(title,'')), 'A') ||
    setweight(to_tsvector('pgv_search', coalesce(description,'')), 'B') ||
    setweight(to_tsvector('pgv_search', coalesce(array_to_string(tags,' '),'')), 'A')
  ) STORED;
CREATE INDEX idx_asset_search ON illustrator.asset USING GIN(search_vec);
CREATE INDEX idx_asset_user ON illustrator.asset(user_id);
CREATE INDEX idx_asset_status ON illustrator.asset(user_id, status);
CREATE INDEX idx_asset_tags ON illustrator.asset USING GIN(tags);
```

#### L'utilisateur Claude Desktop

L'utilisateur dans Claude Desktop peut aussi fournir des images directement dans le chat :
- Claude reçoit l'image en base64 dans le message (géré par Claude Desktop, pas par le MCP)
- Claude appelle un outil `upload_from_chat` qui prend le base64, le push dans Storage + crée l'entrée PG
- Exception : c'est le seul cas où un blob transite via le MCP, mais c'est Claude Desktop qui le gère nativement

```
Utilisateur : "Voici le logo" [upload image dans Claude Desktop]
Claude : → upload_from_chat(base64, filename:"logo.png")
         → classify_asset(tags:['logo','festival'], ...)
         → add_image(asset_id:456, center_h:true, y:20)
```

### 4. DSL agent (pack illustrator.ts)

Le pack TypeScript porte la logique métier qui ne peut pas être en PG :
- `positioning.ts` — positionnement relatif (below, right_of, center_h, gap)
- `fonts.ts` — mesure texte (opentype.js, pas de WASM en PG)
- `layout.ts` — check_layout (overlaps, bleed, spacing, color warnings)
- `tree.ts` — traversée arbre éléments
- Exports : SVG (peut être en PG via cad.render_svg), PNG (resvg), DOCX (npm:docx)

Mapping outils → implémentation :

| Outil | Logique | Stockage |
|-------|---------|----------|
| `doc_new` | Pack: format/orientation defaults | PG: `INSERT INTO cad.drawing` |
| `add_text` | Pack: positioning + font measure | PG: `cad.add_shape(type:'text', props)` |
| `add_image` | Pack: positioning + dimensions | PG: `cad.add_shape(type:'image', props)` + Storage |
| `update_element` | Pack: validate props | PG: `UPDATE cad.shape SET props = ...` |
| `align` / `distribute` | Pack: compute deltas | PG: batch `UPDATE cad.shape` |
| `get_state` | Pack: compact format | PG: `SELECT * FROM cad.shape WHERE drawing_id = $1` |
| `check_layout` | Pack: analyse complète | PG: read shapes |
| `measure_text` | Pack: opentype.js | Aucun |
| `snapshot` | Pack: resvg | PG: `cad.render_svg()` |
| `export_svg` | PG ou Pack | PG: `cad.render_svg()` |
| `list_assets` | PG | PG: `SELECT * FROM illustrator.asset` |
| `inspect_store` | Realtime | Broadcast request/response |
| `show_message` | Realtime | Broadcast toast |

### 5. Export pipeline

| Format | Aujourd'hui | Cible |
|--------|------------|-------|
| SVG | `buildSVG()` TS | `cad.render_svg()` PG (enrichi pour illustrator) |
| PNG | resvg (Bun native) | resvg (npm:@resvg/resvg-js) — à tester en Edge |
| PDF | Puppeteer headless | pdf-lib pur (pas de Chrome) ou service externe |
| DOCX | npm:docx | npm:docx (compatible Deno) |

## Phases de migration

### Phase 0 — Préparation CAD 2D (1-2j)
- Étendre `cad.shape.props` pour supporter les propriétés illustrator (font, crop, filters, shadow)
- Ajouter les types shape manquants : `text` enrichi (fontSize, fontFamily, maxWidth, textAnchor), `image` (crop, filters, border, shadow)
- Tester `cad.render_svg()` avec les nouveaux types
- Créer `illustrator.asset` table + DDL

### Phase 1 — Pack illustrator minimal (2-3j)
- `src/core/packs/illustrator.ts` — Awilix pack
- Porter `types.ts`, `tree.ts`, `positioning.ts`, `fonts.ts` dans `src/core/tools/illustrator/`
- Implémenter les 10 outils de base : `doc_new`, `doc_list`, `doc_load`, `doc_save`, `doc_delete`, `add_text`, `add_rect`, `add_image`, `update_element`, `get_state`
- Monter dans l'Edge Function + tester via Claude Desktop

### Phase 2 — Outils complets (2-3j)
- Porter les 26 outils restants (batch, align, distribute, group, reorder, export, etc.)
- Porter `layout.ts` (check_layout)
- Porter `svg.ts` ou adapter `cad.render_svg()`
- `list_assets` via `illustrator.asset` table
- Snapshot via resvg (si compatible Edge) ou fallback PG

### Phase 3 — Client web (3-5j)
- Porter le client D3/SVG (quasi-identique)
- Remplacer WS par supabase-js Realtime
- Remplacer fetch API par PostgREST / supabase-js
- Assets depuis Supabase Storage (URLs signées)
- Image editor modal (inchangé)
- Deploy sur Supabase static hosting

### Phase 4 — Collaboration (1-2j)
- Selection sync via Broadcast channel
- Toast via Broadcast
- `requestFromClient()` pattern via Broadcast request/response
- `inspect_store`, `dispatch_event`, `get_event_log` adaptés

### Phase 5 — Auth + Billing (2-3j)
- Supabase Auth OAuth 2.0 (Claude Directory)
- RLS sur drawing, shape, asset
- Stripe integration (checkout, webhook, portal)
- Quotas (doc_limit, pdf_exports, storage)

### Phase 6 — Publication (1-2j)
- Documentation (3 exemples d'usage)
- Privacy policy
- Compte test
- Soumission Claude Connectors Directory
- Open MCP Registry

### Total estimé : 12-20 jours
