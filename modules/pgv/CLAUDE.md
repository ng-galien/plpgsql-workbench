# pgv — pgView SSR Framework

Server-Side Rendering framework for PostgreSQL apps. Alpine.js shell + PicoCSS + PostgREST + `pgv.*` UI primitives. Zero dependencies — foundational module for all apps.

## Schemas

| Schema | Role | Functions |
|--------|------|-----------|
| `pgv` | UI primitives + router | 36 |
| `pgv_ut` | Unit tests + `assert_page()` helper | 23 |
| `pgv_qa` | Demo app showcasing all primitives | 18 |

## Layout

```
build/pgv.func.sql      # pg_pack output (pgv + pgv_ut, dependency-sorted)
build/pgv_qa.ddl.sql     # QA schema DDL (item table + test data)
src/pgv/*.sql            # 21 primitive sources (pg_func_save)
src/pgv_ut/*.sql         # 16 test sources (pg_func_save)
qa/pgv_qa/*.sql          # 18 demo page sources (pg_func_save — _qa suffix → qa/)
frontend/index.html      # Alpine.js shell (routing, events, toast, dialog)
frontend/pgview.css      # Design tokens + component styles + light/dark themes
```

## Key Primitives

| Function | Purpose |
|----------|---------|
| `route(schema, path, method, params)` | Generic dispatcher — pg_proc introspection, zero config |
| `page(brand, title, path, nav, body)` | Layout wrapper (nav + content) |
| `nav(brand, path, nav_items, options)` | Navigation bar + theme toggle |
| `call_ref(fname, params)` | Verified internal links (schema-aware, URL-encoded) |
| `href(url)` | External-only URL whitelist (https, mailto, tel) |
| `esc(text)` | HTML escape (&, <, >, ", ') — use for ALL user text |
| `card(title, body, footer)` | Article card |
| `badge(text, variant)` | Inline label (success/danger/warning/info/primary) |
| `stat(label, value, detail)` | KPI card |
| `action(rpc, label, params, confirm, variant)` | Button with `data-rpc` contract |
| `input/sel/textarea(...)` | Form fields |
| `grid(items[])` | CSS grid wrapper |
| `dl(VARIADIC pairs[])` | Definition list |
| `md_table(headers[], rows[])` | Markdown table via `<md>` block |
| `money(n)` / `filesize(n)` | Formatting helpers |
| `error(status, title, detail, hint)` | Error display |
| `svg_canvas(svg, w, h)` | SVG viewport with panzoom.js |

## Router Dispatch

`pgv.route()` introspects the target function signature and adapts:

| Signature | Example | Dispatch |
|-----------|---------|----------|
| 0 args | `get_index()` | Direct call |
| jsonb | `get_page(p_params jsonb)` | Pass full query params |
| scalar | `get_drawing(p_id integer)` | Cast `params->key::type` |
| composite | `get_form(p_rec my_type)` | `jsonb_populate_record()` |

- GET -> wrapped in `pgv.page()` layout
- POST -> raw return (toast/redirect templates)
- Errors: GET -> error page, POST -> `<template data-toast="error">`

## Rôle : Reviewer UI/UX

L'agent pgv est le **référent UI/UX** pour tous les modules. Quand un module a terminé ses pages, il doit demander une review à pgv :

```
pg_msg from:<module> to:pgv type:question subject:"Review UI/UX pages <module>"
```

L'agent pgv vérifiera :
- `diagnose('schema', '*')` — les 8 checks automatiques
- Cohérence des primitives (bon usage de dl, card, tabs, badge, etc.)
- Ergonomie navigation (breadcrumb, liens, retours)
- Respect des conventions (esc, call_ref, pas de style inline, md pour tables)

## Module Contract

Any schema using `pgv.route()` MUST provide:

```sql
{schema}.nav_items() -> jsonb    -- [{"href":"/path","label":"Label"}, ...]
{schema}.get_index() -> text     -- Home page (GET /)
```

Optional: `{schema}.brand() -> text`, `{schema}.nav_options() -> jsonb`

## Conventions (ENFORCED by tests + hooks)

1. **No inline styles** — `class="pgv-*"` only, styling in `pgview.css`. Test: `test_page_no_inline_style()`
2. **No HTMX** — Alpine.js + fetch only, zero `hx-*` attributes. Test: `test_no_htmx()`
3. **Always `pgv.esc()`** — For any user-facing text (badges, stats, labels, dl keys)
4. **`call_ref()` for internal links** — Never `href()` for in-app navigation
5. **`href()` for external only** — Whitelists https://, http://, mailto:, tel:
6. **Query params, not path segments** — `/page?id=42` not `/page/42`
7. **Markdown tables over HTML** — `<md>` blocks with auto-sort/pagination, not raw `<table>`
8. **POST returns** — `<template data-toast="level">msg</template>` or `<template data-redirect="/path">`

## Search Convention

- Type : `pgv.search_result` (href, icon, kind, label, detail, score)
- Chaque module cherchable implémente `{schema}.search(p_query text, p_limit int, p_offset int) → SETOF pgv.search_result`
- Dispatcher : `pgv.search(p_query, p_schema, p_limit, p_offset)` → HTML
- Shell : Cmd+K overlay, debounce 200ms, navigation clavier ↑↓, Enter = navigate
- Scoring libre par module (ILIKE, trigram, ts_vector). Le dispatcher trie par score DESC.

## diagnose() — Validation HTML

`pgv.diagnose(p_schema text, p_func text)` — 8 checks :
1. Inline styles (`style="..."`)
2. HTMX (`hx-*`)
3. Raw `<table>` sans `<md>`
4. RPC targets (`data-rpc` → fonction existe)
5. Internal hrefs (lien → get_xxx() existe)
6. Markdown blocks (`<md>` header valide)
7. Form signatures (champs vs paramètres fonction)
8. CSS classes (pgv-* connus dans le registre)

Batch : `diagnose('schema', '*')` scanne toutes les pages nav_items.

## Shell Architecture (index.html)

- Event delegation sur `#app` (pas de listeners individuels)
- `_enhance()` post-process après chaque render : markdown, tables sort+pagination, scripts, lazy
- `_listen()` capture : links internes, data-rpc buttons, theme toggle, data-dialog
- Lazy : `data-lazy="rpc"` + IntersectionObserver

## CSS Tokens

| Token | Light | Dark |
|-------|-------|------|
| `--pgv-bg` | #faf9f6 | #0c0a09 |
| `--pgv-surface` | #ffffff | #1c1917 |
| `--pgv-text` | #1c1917 | #e7e5e4 |
| `--pgv-muted` | #78716c | #a8a29e |
| `--pgv-accent` | #b45309 | #d97706 |

## Testing

```
pg_test target: "plpgsql://pgv_ut"    # Run all 16 tests
```

Key test: `pgv_ut.assert_page(html, schema)` — validates HTML contract (no styles, RPCs exist, hrefs resolve, md blocks valid). Use it in consumer modules.

## File Export Convention

`pg_func_save` auto-resolves output directories via module registry:
- `pgv`, `pgv_ut` schemas → **`src/`** (`src/pgv/*.sql`, `src/pgv_ut/*.sql`)
- `pgv_qa` schema → **`qa/`** (`qa/pgv_qa/*.sql`)

NEVER move QA files from `qa/` to `src/`. The registry decides based on schema suffix `_qa`.

## Gotchas

- `call_ref()` only works inside `route()` context (needs `pgv.route_prefix` setting)
- `route()` auto-prefixes nav hrefs with `/{schema}` — don't double-prefix in `nav_items()`
- `<md>` blocks need valid markdown header + separator row
- POST error from RAISE EXCEPTION -> only message shown in toast (HINT not visible)
- `pgv_qa` is demo-only — has its own `item` table, don't deploy as real app
- **PicoCSS specificity** — PicoCSS utilise des sélecteurs haute spécificité (`nav[aria-label="breadcrumb"] li::after`). Les `.pgv-*` seuls perdent. Solution : matcher leur pattern (`nav.pgv-breadcrumb[aria-label]`)
- **PostgREST content negotiation** — `RETURNS text` + `Accept: text/html` → PGRST107. Utiliser le domaine `"text/html"` pour les pages, `text` + `Accept: application/json` pour les utilitaires
- **Inline styles interdit, dynamique via data-*** — `style="height:300px"` bloqué par hooks. Solution : `data-height="300"` + JS dans `_enhance()` qui lit `dataset.height`
- **Alpine x-ref dans x-if** — `<template x-if>` retire le DOM → `$refs.xxx` undefined. Toujours `$nextTick()` après avoir mis la condition à true
- **pg_pack après pg_func_save** — Si les deux tournent en parallèle, le coherence check peut échouer. Toujours re-pack APRÈS save
- **POST vs GET response** — GET → wrappé dans `page()`. POST → raw HTML (`<template data-toast>` / `<template data-redirect>`). Ne JAMAIS wrapper un POST dans page()
