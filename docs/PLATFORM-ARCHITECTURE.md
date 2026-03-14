# Platform Architecture — Unified Deployment

## Principe

Une seule plateforme, trois services Cloudflare + Supabase.

```
Cloudflare Pages (front unifié)
├── Shell pgView (Alpine.js + PicoCSS + marked.js)
│   ├── /crm/*          → ERP pages (HTML depuis PostgREST)
│   ├── /quote/*         → ERP pages
│   ├── /document/*      → Canvas list, détail SVG
│   ├── /document/edit   → Plugin pgvIllustrator (D3 canvas)
│   ├── /asset/*         → Photothèque
│   └── /*               → Toutes les pages ERP (14 modules)
├── Alpine.js            → UI déclaratif
├── D3.js                → Canvas SVG interactif
├── Zustand              → State management (bundlé dans le plugin)
├── supabase-js          → Auth + PostgREST + Realtime + Storage
├── PicoCSS + pgview.css → Styles
└── marked.js            → Tables markdown

Cloudflare Worker (MCP + billing)
├── POST /               → MCP Streamable HTTP (Claude Directory)
├── HEAD /               → MCP-Protocol-Version header
├── POST /checkout       → Stripe Checkout
├── POST /portal         → Stripe Customer Portal
└── POST /webhook        → Stripe webhook

Supabase (backend)
├── PostgreSQL           → Toutes les données (ERP + document + asset)
│   ├── pgv.route()      → SSR HTML pour les pages ERP
│   ├── document.*       → Canvas, elements, gradients, session
│   ├── asset.*          → Métadonnées images
│   └── crm.*, quote.*, etc. → Modules ERP
├── PostgREST            → API REST auto-générée
├── Auth (GoTrue)        → Google OAuth, JWT
├── Realtime             → Postgres Changes (canvas sync)
├── Storage              → Images, PDF exports
└── pg_cron              → Jobs planifiés (reset compteurs)
```

## Flux applicatifs

### Page ERP (devis, factures, etc.)

```
Browser → Cloudflare Pages (shell Alpine)
  → go("/quote/devis?p_id=42")
  → fetch("https://xxx.supabase.co/rest/v1/rpc/route", {
      method: "POST",
      headers: { "Content-Profile": "quote", Authorization: "Bearer <jwt>" },
      body: { p_schema: "quote", p_path: "/devis", p_method: "GET", p_params: {p_id: 42} }
    })
  → PostgREST → pgv.route() → quote.get_devis(42) → HTML
  → Shell injecte le HTML dans <main>
```

### Illustrator (édition canvas)

```
Browser → Cloudflare Pages (shell Alpine)
  → go("/document/edit?id=xxx")
  → Plugin pgvIllustrator s'initialise
  → supabase.rpc("canvas_get_state", {p_canvas_id: xxx})
  → Zustand store ← state
  → D3 render canvas
  → Supabase Realtime subscribe → live updates
```

### Claude compose via MCP

```
Claude Desktop → Cloudflare Worker (MCP)
  → ill_add(canvas_id, "text", {x:105, y:30, content:"Hello"})
  → Worker → postgres.js → INSERT document.element
  → Supabase Realtime → Browser Zustand → D3 re-render
  → L'utilisateur voit l'élément apparaître
```

## Shell pgView — évolutions

### Aujourd'hui (dev)
```
nginx
├── Sert index.html + CSS + JS + images
└── Proxy /rpc/ → PostgREST local (port 3000)
```

### Demain (prod)
```
Cloudflare Pages
├── Sert index.html + CSS + JS + images (CDN global)
└── Shell Alpine fetch → Supabase PostgREST (HTTPS direct, CORS configuré)
```

### Ce qui change dans le shell

```javascript
// Aujourd'hui
const POSTGREST_URL = "/rpc";  // nginx proxy

// Demain
const POSTGREST_URL = "https://xxx.supabase.co/rest/v1/rpc";  // direct
const SUPABASE_KEY = "sb_publishable_...";

// Le go() function ajoute les headers
async function go(path) {
  const res = await fetch(POSTGREST_URL + "/route", {
    method: "POST",
    headers: {
      "Content-Profile": schema,
      "Authorization": "Bearer " + jwt,
      "apikey": SUPABASE_KEY,
    },
    body: JSON.stringify({ p_schema, p_path, p_method, p_params }),
  });
  // ... inject HTML
}
```

### CORS Supabase

```sql
-- Supabase dashboard → Settings → API → CORS
-- Ajouter le domaine Cloudflare Pages
-- https://illustrator.pages.dev
-- https://app.myfrenchtour.com
```

## Plugin pgvIllustrator

Un composant Alpine auto-contenu dans le shell pgView :

```html
<!-- Page document.get_canvas() retourne : -->
<div x-data="pgvIllustrator" data-canvas-id="xxx"></div>
```

Le plugin :
- Initialise Zustand store
- Charge le canvas via RPC
- Subscribe Realtime
- Rend le canvas D3
- Gère les panels (layers, props, photos) en Alpine

C'est le même pattern que `pgvTable` — un composant Alpine déclaratif qui encapsule toute la logique.

## Build & Deploy

```bash
# Dev
make dev-up              # PG + PostgREST + nginx (port 8080)
npm run dev              # MCP server Node (port 3100)
make watch-illustrator   # esbuild watch → live reload

# Prod
make build-illustrator   # esbuild → dist/
wrangler pages deploy modules/document/frontend/illustrator/dist  # → Cloudflare Pages
cd cloudflare/mcp-worker && wrangler deploy  # → Cloudflare Worker
pgm supabase sync asset document && supabase db push  # → Supabase PG
```

## Coûts

| Service | Free tier | ~500 users |
|---------|-----------|------------|
| Cloudflare Pages | Illimité | 0$ |
| Cloudflare Worker | 100K req/jour | ~5$/mois |
| Supabase Pro | — | 25$/mois |
| Stripe fees | — | ~3% revenu |
| **Total** | **0$** | **~30$/mois** |
