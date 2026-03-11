# pgv — pgView SSR Framework

Server-Side Rendering framework for PostgreSQL apps. Alpine.js shell + PicoCSS + PostgREST + `pgv.*` UI primitives. Zero dependencies — foundational module for all apps.

## Schemas

| Schema | Role | Functions |
|--------|------|-----------|
| `pgv` | UI primitives + router | 21 |
| `pgv_ut` | Unit tests + `assert_page()` helper | 16 |
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
