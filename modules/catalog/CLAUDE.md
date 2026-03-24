# catalog — Product/Service Catalog

Product catalog module: articles, services, pricing, categories, units of measure.

## Language Rules (STRICT)

- **Code** — ALL code in English: function names, parameter names, variable names, column names, JSON keys, comments. No exceptions.
- **Labels** — ALL user-facing text via `pgv.t('module.key')`. Never hardcode French (or any language) strings in functions. Labels live in `i18n_seed()` only.
- **CLAUDE.md** — English only.
- **Commits** — English only.
- **Examples**: `client_list` not `liste_clients`, `pgv.t('crm.action_send')` not `'Envoyer'`, `status = 'draft'` not `'brouillon'`

**Depends on:** pgv (UI framework)

**Consumed by:** quote (invoice/quote lines), stock (articles), purchase (order lines)

**Schemas:** `catalog` (public), `catalog_ut` (tests), `catalog_qa` (seed data)

## Data Model

- `catalog.categorie` — tree-structured categories (parent_id)
- `catalog.unite` — units of measure (m, m2, kg, h, u, forfait...)
- `catalog.article` — products/services with reference, designation, sale/purchase price HT, VAT, unit, category

## Pages (pgView legacy)

- `get_index()` — dashboard: stats (nb articles, categories), search, article list with filters
- `get_article(p_id)` — article detail: info, edit, disable/enable
- `get_categories()` — category management with tree display
- `get_article_form(p_params jsonb)` — create/edit article form
- `post_article_creer(p_params jsonb)` — create article
- `post_article_modifier(p_params jsonb)` — update article
- `post_categorie_creer(p_params jsonb)` — create category

## CRUD Functions (route_crud)

Standard CRUD for each entity, consumed by `route_crud(verb, uri)`:
- `article_list/read/create/update/delete`
- `categorie_list/read/create/update/delete`

SDUI views:
- `article_ui(p_slug)` — list mode (table+datasource) + detail mode (static components)
- `categorie_ui(p_slug)` — list mode (table+datasource) + detail mode (static components)

## Router Convention

**IMPORTANT:** `pgv.route()` supports max 1 argument per function. Use `jsonb` for functions with multiple filters/parameters:
```sql
CREATE FUNCTION catalog.get_index(p_params jsonb DEFAULT '{}'::jsonb) RETURNS text
-- p_params->>'q' for search, p_params->>'categorie_id' for filter
```

## Cross-Module Integration

Other modules call catalog via dynamic EXECUTE (no hard dependency):
```sql
-- Example in quote or purchase
IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'catalog') THEN
  EXECUTE 'SELECT catalog.article_options()' INTO v_options;
END IF;
```

## Dev Workflow (STRICT)

1. DDL → Write to `build/catalog.ddl.sql` → `pg_schema` to apply
2. Functions → `pg_func_set` to create/modify + `pg_test` to validate
3. Export → `pg_pack` (→ `build/catalog.func.sql`) + `pg_func_save` (→ `src/`)
4. `pg_query` → SELECT/DML only, NEVER DDL or CREATE FUNCTION
5. NEVER write functions in SQL files

## pgView Conventions

- Tables via `<md>` blocks, NEVER raw `<table>` HTML
- CSS classes `pgv-*`, NEVER `style="..."`
- Primitives: `pgv.toast()`, `pgv.redirect()`, `pgv.form()`, `pgv.sel()`, `pgv.stat()`, `pgv.badge()`, `pgv.grid()`, `pgv.empty()`, `pgv.action()`
- POST returns raw HTML (toast/redirect via primitives), never wrapped in `page()`

## Inter-Module Communication

- `pg_msg_inbox module:catalog` → read incoming messages
- `pg_msg` → send message to another module
- **feature_request / bug_report → ALWAYS via issue_report**: never send feature_request or bug_report directly to another module. Create an issue: `INSERT INTO workbench.issue_report(issue_type, module, description) VALUES ('enhancement|bug', '<target_module>', '<description>')`. The lead will be notified and decide dispatch.
- Each module is autonomous — never modify another module's functions

## i18n

The framework uses `pgv.t(key)` for internationalization. Each module must:
1. Create `catalog.i18n_seed()` — INSERT INTO pgv.i18n(lang, key, value) with translations
2. Namespaced keys: `catalog.nav_xxx`, `catalog.title_xxx`, `catalog.btn_xxx`, etc.
3. Use `pgv.t('catalog.xxx')` in nav_items(), brand(), and all get_*/post_* functions
4. `ON CONFLICT DO NOTHING` in the seed

## QA Seed Data

Schema `catalog_qa` contains only `seed()` and `clean()` — NO pages.
- `catalog_qa.seed()` — INSERT realistic demo data
- `catalog_qa.clean()` — DELETE in reverse FK order
- `ON CONFLICT DO NOTHING`, consider multi-tenant (`current_setting('app.tenant_id', true)`)

## Agent Workflow

1. On startup or when told "go": **always read `pg_msg_inbox module:catalog`**
2. Process messages by priority (HIGH first)
3. Do not resolve a message until the task is verified
4. After each task: `pg_pack schemas: catalog,catalog_ut,catalog_qa` (all 3 schemas)
5. Then `pg_func_save target: plpgsql://catalog` + `plpgsql://catalog_ut` + `plpgsql://catalog_qa`

## Built-in Documentation

The workbench embeds documentation accessible via `pg_doc`:
- `pg_doc topic:testing` — pgTAP guide: test_*() conventions, assertions, patterns
- `pg_doc topic:data-convention` — data_*() convention: cursor pagination, FTS, pgv.table()
- `pg_doc topic:coverage` — Code coverage guide

## Gotchas

- **tenant_id**: always `PERFORM set_config('app.tenant_id', 'test', true)` at the start of each test
- **pg_test**: discovers `test_*()` functions in the `_ut` schema
- **You are the catalog agent, NOT the lead.** Never use `ws_health` to find your tasks — it shows ALL workspace tasks. Use only `pg_msg_inbox module:catalog` to read YOUR messages. Only process messages addressed to `catalog`.
