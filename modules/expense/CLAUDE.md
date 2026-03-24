# expense — Expense Reports

Expense report module: travel, purchases, meals, reimbursements.

## Language Rules (STRICT)

- **Code** — ALL code in English: function names, parameter names, variable names, column names, JSON keys, comments. No exceptions.
- **Labels** — ALL user-facing text via `pgv.t('module.key')`. Never hardcode French (or any language) strings in functions. Labels live in `i18n_seed()` only.
- **CLAUDE.md** — English only.
- **Commits** — English only.
- **Examples**: `client_list` not `liste_clients`, `pgv.t('crm.action_send')` not `'Envoyer'`, `status = 'draft'` not `'brouillon'`

**Depends on:** pgv (UI framework)

**Related to:** ledger (accounting entry on reimbursement), project (expenses linked to a job site)

**Schemas:** `expense` (public), `expense_ut` (tests), `expense_qa` (seed data)

## Data Model

- `expense.categorie` — expense categories with accounting code (travel, meals, tools...)
- `expense.note` — expense report = grouping of lines with workflow status (brouillon → soumise → validée → remboursée)
- `expense.ligne` — expense line: date, category, amount HT/TVA/TTC, km if travel, receipt

## Pages (pgView legacy)

- `get_index()` — dashboard: stats (current total, note count, avg amount), recent notes list
- `get_note(p_id)` — note detail: info, lines, totals, workflow buttons (submit/validate/reimburse)
- `get_note_form(p_params jsonb)` — create/edit note form
- `get_notes(p_params jsonb)` — list filtered by status, author, period
- `post_note_creer(p_params jsonb)` — create a note
- `post_ligne_ajouter(p_params jsonb)` — add a line to a note
- `post_note_soumettre(p_params jsonb)` — transition brouillon → soumise
- `post_note_valider(p_params jsonb)` — transition soumise → validée
- `post_note_rembourser(p_params jsonb)` — transition validée → remboursée (+ ledger entry if available)

## CRUD Functions

- `note_list/read/create/update/delete` — standard CRUD, consumed by `route_crud`
- `categorie_list/read/create/update/delete` — standard CRUD
- `note_ui(p_slug)` / `categorie_ui(p_slug)` — SDUI views (list + detail modes)

## Router Convention

**IMPORTANT:** `pgv.route()` supports max 1 argument per function. Use `jsonb` for functions with multiple filters/parameters.

## Cross-Module Integration

- **ledger**: on reimbursement, create accounting entry via dynamic EXECUTE if ledger exists
- **project**: optional — link a note to a job site (nullable chantier_id column)

## Dev Workflow (STRICT)

1. DDL → Write to `build/expense.ddl.sql` → `pg_schema` to apply
2. Functions → `pg_func_set` to create/modify + `pg_test` to validate
3. Export → `pg_pack` (→ `build/expense.func.sql`) + `pg_func_save` (→ `src/`)
4. `pg_query` → SELECT/DML only, NEVER DDL or CREATE FUNCTION

## pgView Conventions

- Tables via `<md>` blocks, NEVER `<table>` HTML
- CSS classes `pgv-*`, NEVER `style="..."`
- Primitives: `pgv.stat()`, `pgv.badge()`, `pgv.card()`, `pgv.grid()`, `pgv.empty()`, `pgv.action()`
- POST returns raw HTML (toast/redirect), never wrapped in `page()`

## Inter-Module Communication

- `pg_msg_inbox module:expense` → read incoming messages
- `pg_msg` → send a message to another module
- **feature_request / bug_report → ALWAYS via issue_report**: never send feature_request or bug_report directly to another module. Create an issue: `INSERT INTO workbench.issue_report(issue_type, module, description) VALUES ('enhancement|bug', '<target_module>', '<description>')`. The lead will be notified and decide on dispatch.
- Each module is autonomous — never modify another module's functions

## i18n

The framework uses `pgv.t(key)` for internationalization. Each module must:
1. Create `expense.i18n_seed()` — INSERT INTO pgv.i18n(lang, key, value) with translations
2. Namespaced keys: `expense.nav_xxx`, `expense.title_xxx`, `expense.btn_xxx`, etc.
3. Use `pgv.t('expense.xxx')` in nav_items(), brand(), and all get_*/post_* functions
4. `ON CONFLICT DO NOTHING` in the seed

## QA Seed Data

Schema `expense_qa` contains only `seed()` and `clean()` — NO pages.
- `expense_qa.seed()` — INSERT realistic demo data
- `expense_qa.clean()` — DELETE in reverse FK order
- `ON CONFLICT DO NOTHING`, consider multi-tenant (`current_setting('app.tenant_id', true)`)

## Agent Workflow

1. On startup or when told "go": **always read `pg_msg_inbox module:expense`**
2. Process messages by priority (HIGH first)
3. Do not resolve a message until the task is verified
4. After each task: `pg_pack schemas: expense,expense_ut,expense_qa` (all 3 schemas)
5. Then `pg_func_save target: plpgsql://expense` + `plpgsql://expense_ut` + `plpgsql://expense_qa`

## Built-in Documentation

The workbench embeds documentation accessible via `pg_doc`:
- `pg_doc topic:testing` — pgTAP guide: test_*() conventions, assertions, patterns
- `pg_doc topic:data-convention` — data_*() convention: cursor pagination, FTS, pgv.table()
- `pg_doc topic:coverage` — Code coverage guide

## Gotchas

- **tenant_id**: always `PERFORM set_config('app.tenant_id', 'test', true)` at the start of each test
- **pg_test**: discovers `test_*()` functions in the `_ut` schema
- **You are the expense agent, NOT the lead.** Never use `ws_health` to find your tasks — it shows ALL workspace tasks. Only use `pg_msg_inbox module:expense` to read YOUR messages. Only process messages addressed to `expense`.
