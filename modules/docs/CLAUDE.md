# document -- XHTML Composition Engine

Visual document composition engine in XHTML. Design charters (design tokens), multi-page documents, charter validation, layout check. Backend for the standalone product **Maket**.

**Depends on:** `pgv`, `asset`
**Schemas:** `docs`, `docs_ut` (tests), `docs_qa` (seed data)

## SDUI Convention

Each entity exposes these functions consumed by `route_crud(verb, uri)`:

| Function | Purpose | Returns |
|----------|---------|---------|
| `{entity}_view()` | UI schema (static, cached by client) | jsonb |
| `{entity}_list(filter?)` | Browse list | SETOF jsonb |
| `{entity}_read(id)` | Single entity + HATEOAS actions | jsonb |
| `{entity}_create(record)` | Create | jsonb |
| `{entity}_update(record)` | Update | jsonb |
| `{entity}_delete(id)` | Delete | jsonb |

**CRITICAL separation:** `_view()` is schema (how to render). `_list()/_read()` is data (what to render). They are NEVER bundled together. The client caches `_view()` once and fetches data separately.

HATEOAS: `_read()` returns available actions based on entity state. The `_view()` actions catalog declares labels/variants/confirm -- it is the static catalog. The `_read()` actions array is the runtime list of what is currently available.

Entities: `charter`, `document`, `library`

## Domain

### Design Charter (Charte)

Design token system to ensure visual consistency. One charter = one brand identity.

**Mandatory color base (6 tokens):**

| Token | Role | Proportion |
|-------|------|------------|
| `color_bg` | Page background | ~60% |
| `color_main` | Headings, strong elements | ~30% |
| `color_accent` | CTA, highlights | ~10% |
| `color_text` | Body text | -- |
| `color_text_light` | Secondary text | -- |
| `color_border` | Lines, separators | -- |

Plus free-form tokens in `color_extra` jsonb (e.g. `{"ocean": "#2E7D9B", "olive": "#5C6B3C"}`).

**Font:** `font_heading` + `font_body` (Google Fonts, mandatory).

**Spacing:** `spacing_page`, `spacing_section`, `spacing_gap`, `spacing_card` (CSS values, e.g. `"12mm"`).

**Shadow / Radius:** `shadow_card`, `shadow_elevated`, `radius_card` (CSS values).

**Voice:** personality (text[]), formality, do/dont (text[]), vocabulary, examples (jsonb).

**Rules:** free-form design constraints (jsonb) -- what NOT to do with the charter.

**Revisions:** each token modification creates a snapshot in `charte_revision`.

### Document

Multi-page XHTML document with canvas (format, dimensions, background).

**Canvas:** format (`A4`, `A3`, `A5`, `HD`, `MACBOOK`, `IPAD`, `MOBILE`, `CUSTOM`), orientation, dimensions (mm for print, px for screen), background, text margin.

**Pages:** each page has its HTML and an optional canvas override (different format per page). Pages are indexed (`page_index`).

**Linked charter:** a document optionally references a charter. Any HTML mutation is validated against the charter (colors, fonts, shadows must use `var(--charte-*)`).

**Status:** `draft` -> `generated` -> `signed` -> `archived`.

**External ref:** `ref_module` + `ref_id` to link a document to a quote, invoice, project.

### XHTML

Page content is **strict XHTML** (well-formed XML). Conventions:

- Each visual element has a unique `data-id`
- Styles are **inline** (`style="..."`) because the document is self-contained (no external CSS)
- Colors/fonts/shadows use `var(--charte-*)` when a charter is active
- Dimensions in `mm` for print, `px` for screen
- XHTML is validated by `xmlparse()` on every mutation -- malformed = rejected

### Assets

Images are managed by the cross-module `asset` module. Supabase Storage + Image Transformations for on-the-fly resizing. Documents reference assets by relative path (`/assets/photo.jpg`).

## Tables

```
docs.charte           -- design tokens, voice, rules (6 colors NOT NULL)
docs.charte_revision  -- token snapshot per version
docs.company          -- issuer (company, for invoices/quotes)
docs.document         -- XHTML document (canvas, meta, charter ref, status)
docs.page             -- XHTML pages (html, optional canvas override)
docs.page_revision    -- HTML history per page
docs.library          -- asset library (grouped photo collections)
docs.library_asset    -- library <-> asset junction (role, caption, sort)
docs.session          -- UNLOGGED workspace (open docs, zoom, pan, pending)
```

## Functions

### Charter CRUD
- `charte_create(p_data)` -- INSERT with mandatory base validation + auto-slug
- `charte_read(p_id)` -- by id or slug, returns composite row
- `charte_list(p_filter)` -- list with preview tokens
- `charte_update(p_data)` -- partial update, recalculate slug on rename
- `charte_delete(p_id)` -- by id or slug
- `charte_tokens_to_css(p_charte_id)` -- generates `:root { --charte-*: value }` + Google Fonts @import

### Document CRUD
- `document_create(p_data)` -- CREATE document + first page, format->dimensions, auto-slug
- `document_read(p_id)` -- by id or slug
- `document_list(p_filter)` -- catalog grouped by category
- `document_update(p_data)` -- partial update
- `document_delete(p_id)` -- CASCADE pages + revisions
- `document_duplicate(p_id, p_name)` -- deep clone

### Library CRUD
- `library_create(p_data)` -- CREATE library + auto-slug
- `library_read(p_id)` -- by id or slug
- `library_list(p_filter)` -- list all libraries
- `library_delete(p_id)` -- CASCADE assets, NULL document refs
- `library_add_asset(p_library_id, p_asset_id, p_role, p_caption, p_sort)` -- upsert
- `library_remove_asset(p_library_id, p_asset_id)` -- remove

### HTML / XHTML
- `page_set_html(doc_id, page_index, html)` -- replace HTML, validate charter + layout
- `xhtml_patch(html, ops)` -- surgical patch by data-id (style, content, insert, remove)
- `style_merge(existing, new_styles)` -- merge inline CSS (key-value, last-write-wins)
- `layout_check(html, width, height)` -- detect elements overflowing the canvas
- `charte_check(html, charte_id)` -- validate colors/fonts/shadows against tokens
- `normalize_color(raw)` -- normalize hex/rgb to #rrggbb for comparison
- `xhtml_validate(html)` -- verify HTML is well-formed XML

### Pages
- `page_add(doc_id, title, html)` -- add page, returns new index
- `page_remove(doc_id, page_index)` -- remove page, renumber remaining

## context_token Convention

Anti-cheat mechanism: Claude must read a charter (`charte_load`) before modifying a document that uses it. The token is an HMAC of the charter's tokens (via `pgcrypto`). If the charter changes, the token expires.

```sql
-- Generation
encode(hmac('charte:' || name || '|' || tokens_hash, secret, 'sha256'), 'hex')

-- Validation
The context_token passed by Claude is compared to the recalculated token.
```

## Maket Integration (standalone)

This module IS the Maket backend. The standalone product is an MCP packaging that connects to the same Supabase. The 4 MCP verbs (`get`, `set`, `patch`, `delete`) route to the PL/pgSQL functions of this module.

```
Maket standalone -> Supabase -> docs.* functions
Workbench ERP    -> PostgREST -> docs.* functions
```

## Language Rules (STRICT)

- **Code** -- ALL code in English: function names, parameter names, variable names, column names, JSON keys, comments. No exceptions.
- **Labels** -- ALL user-facing text via `pgv.t('docs.key')`. Never hardcode French (or any language) strings in functions. Labels live in `i18n_seed()` only.
- **CLAUDE.md** -- English only.
- **Commits** -- English only.
- **Examples**: `charte_list` not `liste_chartes`, `pgv.t('docs.nav_chartes')` not `'Chartes graphiques'`, `status = 'draft'` not `'brouillon'`

## Dev Workflow (STRICT)

1. **DDL** -> Write to `build/{schema}.ddl.sql` -> `pg_schema` to apply
2. **Functions** -> `pg_func_set` to create/modify + `pg_test` to validate
3. **Export** -> `pg_pack` (-> `build/{schema}.func.sql`) + `pg_func_save` (-> `src/`)
4. `pg_query` -> SELECT/DML only, NEVER DDL or CREATE FUNCTION
5. NEVER write functions in SQL files -- the workbench IS the dev tool
6. NEVER edit `build/*.func.sql` -- generated by `pg_pack`

## Module Structure

- `module.json` -> manifest (schemas, dependencies, extensions, sql, grants)
- `build/` -> deployment artifacts (DDL + packed functions)
- `src/` -> individually versioned sources (pg_func_save)
- `_ut` schemas -> pgTAP tests (`test_*()`)
- `_qa` schemas -> seed data only (`seed()`, `clean()`), NO routing

## DDL Content (`build/{schema}.ddl.sql`) -- STRICT

DDL contains **structure only**. Application order:
```
1. Extensions     -> global migration, NOT in module DDL
2. DDL            -> CREATE SCHEMA, CREATE TABLE, indexes, constraints, RLS
3. Functions      -> pg_pack generates build/{schema}.func.sql (+ triggers)
4. Grants         -> pg_pack appends them to each .func.sql
5. Reference seed -> reference data in build/{schema}.seed.sql
```

## Inter-module Communication

- `pg_msg_inbox module:docs` -> read incoming messages
- `pg_msg` -> send message to another module

## i18n

- `docs.i18n_seed()` -- INSERT INTO pgv.i18n(lang, key, value) with FR translations
- Namespaced keys: `docs.nav_xxx`, `docs.title_xxx`, `docs.btn_xxx`
- `ON CONFLICT DO NOTHING`

## Agent Workflow

1. On startup: **read `pg_msg_inbox module:docs`**
2. Process messages by priority (HIGH first)
3. After each task: `pg_pack schemas: docs,docs_ut,docs_qa`
4. Then `pg_func_save target: plpgsql://docs` + `plpgsql://docs_ut` + `plpgsql://docs_qa`

## Gotchas

- **tenant_id**: always `PERFORM set_config('app.tenant_id', 'test', true)` at the start of each test
- **XHTML strict**: `xmlparse(DOCUMENT html)` rejects malformed HTML -- always validate on input
- **Inline styles in XHTML pages**: document content uses `style="..."` (this is XHTML document content, not pgView)
- **pgcrypto**: required for context_token (HMAC) -- verify the extension is loaded
