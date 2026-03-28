# pgv -- SDUI Framework

PostgreSQL SDUI framework. `route_crud()` dispatcher, `_view()` contract, i18n, UI primitives `pgv.ui_*`.

**Dependencies:** none (foundation module)
**Schemas:** `pgv`, `pgv_ut` (tests), `pgv_qa` (demo app)

**Special role:** SDUI reference for all modules (contract validation via `check_view()`)

## SDUI -- Server-Driven UI

Two separate concerns, joined only on the client:

### 1. Schema (static) -- how to render

Each entity declares `{entity}_view() RETURNS jsonb`. Called **once** at app startup, **cached** client-side. Never bundled with data.

```json
{
  "uri": "schema://entity",
  "icon": "icon",
  "label": "module.entity_label",
  "template": {
    "compact":   { "fields": ["name", "city"] },
    "standard":  { "fields": [...], "stats": [...], "related": [...] },
    "expanded":  { "fields": [...all...], "stats": [...], "related": [...] },
    "form":      { "sections": [{ "label": "i18n.key", "fields": [...] }] }
  },
  "actions": {
    "send":   { "label": "module.action_send", "icon": "->", "variant": "primary" },
    "delete": { "label": "module.action_delete", "icon": "x", "variant": "danger", "confirm": "module.confirm_delete" }
  }
}
```

Key rules:
- **ALL labels are i18n keys** -- `pgv.t()` server-side. NEVER hardcoded text.
- **compact/standard/expanded** = card density levels for canvas workspace
- **form** = create + update (React decides verb based on context)
- **actions** = catalog of all possible actions. HATEOAS in `_read()` says which are active.
- **{field} interpolation** in `related[].filter` and `combobox.filter`
- **Stats computed by _read()** -- template only declares display keys
- Form field types: text, number, textarea, checkbox, date, select, combobox (with source URI)

### 2. Data (dynamic) -- what to render

`pgv.route_crud(verb, uri, data)` dispatches CRUD operations. Returns **only** `{data, uri, actions}` -- no schema.

| Verb | URI | Dispatches to | Returns |
|------|-----|--------------|---------|
| `get` | `crm://client` | `client_list()` | `{data: [...], uri}` |
| `get` | `crm://client/1` | `client_read(1)` | `{data: {...}, uri, actions: [...]}` |
| `set` | `crm://client` | `client_create(data)` | `{data: {...}, uri}` |
| `patch` | `crm://client/1` | `client_update(data)` | `{data: {...}, uri}` |
| `delete` | `crm://client/1` | `client_delete(1)` | `{data: {...}, uri}` |
| `post` | `crm://client/1/archive` | `client_archive(1)` | `{data: {...}, uri}` |

### 3. Client joins schema + data

```
startup:  _view() -> viewCache (one call per entity type, cached forever)
browse:   route_crud('get', uri) -> data only -> render with cached view
pin:      route_crud('get', uri/id) -> data + HATEOAS actions -> render card
action:   route_crud('post', uri/id/method) -> refresh data
create:   route_crud('set', uri, formData) -> new row
```

The client (React) is the **only** place where schema and data meet. The server never bundles them.

### UI Primitives (pgv.ui_*)

| Function | Returns | Usage |
|----------|---------|-------|
| `pgv.ui_text(value)` | `{"type":"text","value":"..."}` | Plain text |
| `pgv.ui_link(text, href)` | `{"type":"link","text":"...","href":"..."}` | Navigable link |
| `pgv.ui_badge(text, variant?)` | `{"type":"badge","text":"..."}` | Colored badge |
| `pgv.ui_color(value)` | `{"type":"color","value":"#hex"}` | Color swatch |
| `pgv.ui_heading(text, level?)` | `{"type":"heading","text":"...","level":2}` | Heading h1-h6 |
| `pgv.ui_column(VARIADIC children)` | Vertical layout | Vertical component stack |
| `pgv.ui_row(VARIADIC children)` | Horizontal layout | Horizontal component stack |
| `pgv.ui_table(source, columns)` | Connected table | Table bound to a datasource |
| `pgv.ui_col(key, label, cell?)` | Column definition | Table column (cell = renderer) |
| `pgv.ui_detail(source, fields)` | Detail view | Detail view connected to a datasource |
| `pgv.ui_action(label, verb, uri, variant?, confirm?)` | Action button | Triggers a route_crud verb |
| `pgv.ui_datasource(uri, page_size?, searchable?, default_sort?)` | Datasource | Data source for table/detail |
| `pgv.ui_card(entity_uri, level, header, body?, related?, actions?)` | Card | 3 levels: compact/standard/expanded |
| `pgv.ui_card_header(icon, title, VARIADIC badges)` | Card header | Reusable header |
| `pgv.ui_stat(value, label, variant?)` | Stat | Stat for card body |
| `pgv.ui_form_for(schema, entity, verb?)` | Auto-form | Introspects PG types -> SDUI form |

### Contract Validation

- `pgv.view_schema()` -- JSON Schema for the `_view()` contract
- `pgv.check_view(schema, entity)` -- Validate that `{entity}_view()` output conforms to the contract

### i18n

- `pgv.i18n_bundle(lang)` -- returns all translations as `{key: value}`
- `pgv.t(key)` -- resolve a single translation key server-side
- React `useT()` hook resolves keys client-side
- Field labels follow convention `{schema}.field_{key}`

### Reference

- Full SDUI doc: `pg_doc topic:sdui`
- Examples: `docs.document_view()`, `docs.charter_view()`

## Language Rules (STRICT)

- **Code** -- ALL code in English: function names, parameter names, variable names, column names, JSON keys, comments. No exceptions.
- **Labels** -- ALL user-facing text via `pgv.t('pgv.key')`. Never hardcode French (or any language) strings in functions. Labels live in `i18n_seed()` only.
- **CLAUDE.md** -- English only.
- **Commits** -- English only.

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
- `src/` -> individual versioned sources (pg_func_save)
- `_ut` schemas -> pgTAP tests (`test_*()`)
- `_qa` schemas -> seed data only (`seed()`, `clean()`), NO routing

## DDL Content -- STRICT

DDL (`build/{schema}.ddl.sql`) contains **structure only**:

**MUST contain:** CREATE SCHEMA, CREATE TABLE, CREATE INDEX, constraints, RLS policies

**MUST NOT contain:**
- `CREATE FUNCTION` -> pg_func_set then pg_pack
- `CREATE TRIGGER` -> pg_pack attaches triggers to functions
- `GRANT` -> pg_pack adds them in .func.sql
- `INSERT INTO` (seed data) -> `build/{schema}.seed.sql` or `{schema}_qa.seed()`

## Inter-module Communication

- `pg_msg_inbox module:pgv` -> read incoming messages
- `pg_msg` -> send a message to another module
- **feature_request / bug_report -> ALWAYS via issue_report**: never send feature_request or bug_report directly to another module. Create an issue: `INSERT INTO workbench.issue_report(issue_type, module, description) VALUES ('enhancement|bug', '<target_module>', '<description>')`. The lead will be notified and decide dispatch.
- Each module is autonomous -- never modify another module's functions

## QA Seed Data

The `pgv_qa` schema is the **design system showcase** -- it contains demo data for pgv primitives:
- `seed()` / `clean()` -- demo data for QA

## Agent Workflow

1. On startup or when told "go": **always read `pg_msg_inbox module:pgv`**
2. Process messages by priority (HIGH first)
3. Do not resolve a message until the task is verified
4. After each task: `pg_pack schemas: pgv,pgv_ut,pgv_qa` (all 3 schemas)
5. Then `pg_func_save target: plpgsql://pgv` + `plpgsql://pgv_ut` + `plpgsql://pgv_qa`

## Built-in Documentation

- `pg_doc topic:testing` -- pgTAP guide: test_*() conventions, assertions, patterns
- `pg_doc topic:coverage` -- Code coverage guide
- `pg_doc topic:sdui` -- SDUI contract: _view() template, route_crud, entity types, form fields

## Gotchas

- **tenant_id**: always `PERFORM set_config('app.tenant_id', 'test', true)` at the start of each test
- **pg_test**: discovers `test_*()` functions in the `_ut` schema
- **You are the pgv agent, NOT the lead.** Never use `ws_health` to find your tasks -- it shows ALL workspace tasks. Use only `pg_msg_inbox module:pgv` to read YOUR messages. Only process messages addressed to `pgv`.
- PostgREST content negotiation -- use domain `"text/html"` for pages
