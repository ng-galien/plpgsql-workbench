# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PL/pgSQL Workbench is a development platform built as an MCP (Model Context Protocol) server. It provides tools for navigating, editing, testing, and analyzing PL/pgSQL code in PostgreSQL. It runs as an HTTP server (default port 3100) exposing MCP tools at `/mcp`.

The workbench is the foundation for building all applications with PostgreSQL as sole runtime. Each application is a set of PostgreSQL schemas + MCP tools, packaged via toolboxes for commercial distribution. Frontend: React canvas workspace (`app/`) with SDUI pattern (server-driven UI).

## Role: Lead / Orchestrator

Quand tu travailles depuis la racine du repo, ton role est celui d'un **lead** — tu diagnostiques, tu coordonnes, tu delegues. Tu ne modifies pas directement le code des modules.

- **Diagnostiquer** — Utiliser les MCP tools (`pg_get`, `pg_search`, `pg_query`, `pg_test`) et le navigateur pour identifier les problemes
- **Deleguer** — Envoyer les actions a faire aux agents modules via `pg_msg` (from: `lead`, to: `<module>`)
- **Verifier** — Apres que l'agent module a travaille, verifier que le fix est correct (tests, frontend)
- **Ne pas toucher** — Ne pas modifier les fichiers dans `modules/*/` directement. Chaque module a son propre agent qui connait son contexte

Les agents modules lisent leurs instructions via `pg_msg_inbox module:<name>`. Ils ont chacun leur propre CLAUDE.md avec le framework, les gotchas, et le workflow dev.

### Agent Management Pattern

- **Assign**: `pg_msg` with `msg_type: task`, `priority: high|normal`, `from: lead`, `to: <module>`
- **Monitor**: `ws_health` (tasks, coherence, git status) — run periodically
- **Ping**: `make team-ping` (all) or `make member-ping M=<name>` — accepts `MSG="custom message"`, defaults to "go"
- **No idle agents**: every agent should have an active task — feature-dev or review/polish when backlog is empty
- **Commit in waves**: batch multiple module changes into single commits, not micro-commits

### Issue Dispatch (STRICT)

When dispatching an `issue_report` to a module agent, **never paraphrase or interpret** the issue content. The message must:
1. Reference the issue by ID: "Issue #N à traiter"
2. Include the SQL to read it: `SELECT * FROM workbench.issue_report WHERE id = N`
3. Explicitly ask the agent to read the issue (description + context with path, errors, actions)
4. Add supplementary context only if needed — never replace the original issue content

## Build & Run Commands

```bash
# Start dev database (Supabase PostgreSQL 17)
make dev-up              # or: docker compose up -d
make dev-init            # loads pgv into dev DB (after fresh start)

# Dev MCP server (all packs, dev DB on 5433)
npm run dev

# Build
npm run build            # tsc -> dist/

# Scaffold a new module
pgm module new mymod

# PLX transpiler
plx build modules/expense/expense.plx    # Compile .plx to PL/pgSQL
plx check modules/expense/expense.plx    # Syntax check only
```

## Testing

- **PL/pgSQL tests** — pgTAP inside PostgreSQL, run via `pg_test` MCP tool
- **TypeScript tests** — `npm test` (vitest), `npm run test:watch` for watch mode
- **PLX E2E** — `src/core/plx/__tests__/entity-e2e.test.ts` uses testcontainers (needs Docker)
- **PLX fixtures** — `for f in fixtures/plx/*.plx; do plx check --no-validate "$f"; done`

### Dev Stack

Shared dev environment for module development. Custom image `pg-workbench` based on `postgres:17` (native ARM64/Apple Silicon) with PostGIS + SFCGAL from Debian packages, `plpgsql_check` + `pgtap` built from source.

```bash
make dev-up              # Start stack (postgres:5433, postgrest:3000)
make dev-down            # Stop (data persists in data/pgdata/)
make dev-clean           # Stop containers (data preserved — delete manually if needed)
make dev-init            # Start + deploy all modules into dev DB
cd app && npm run dev    # React frontend (port 5173)
```

**Local persistence:** Data is stored in `./data/pgdata/` (bind mount, not Docker volume). Never auto-deleted — safety first. Delete manually with `rm -rf data/pgdata/` only after `docker compose down`.

**Dynamic PostgREST schemas:** `make dev-up` generates `.env` with `PGRST_DB_SCHEMAS` extracted from `modules/*/module.json` schemas.

**Connection:** `postgresql://postgres:postgres@localhost:5433/postgres`

**Frontend:** React app in `app/` (Vite + Tailwind + Zustand + Supabase client). Admin console with messages, issues, and team terminal views via xterm.js.

**Auto-initialized on first start** (via `seed/` at repo root):
- Extensions: `plpgsql_check`, `pgtap`, `postgis`, `postgis_sfcgal`
- Roles: `authenticator`, `anon`, domain `text/html`
- `workbench` schema (toolbox, toolbox_tool, tenant tables)
- Run `make dev-init` after fresh start to deploy all modules (pgv, cad, etc.)

**PostgREST** auto-reloads schema cache via `NOTIFY pgrst, 'reload schema'`.

**Sync tools to DB** (after code changes):
```bash
npm run sync-tools    # Populates workbench.toolbox_tool from code registry
```

## Environment Variables (infra bootstrap only)

- `PLPGSQL_CONNECTION` / `DATABASE_URL` — PostgreSQL connection string (default: `postgresql://postgres@localhost:5432/postgres`)
- `MCP_PORT` — HTTP port (default: `3100`)
- `LOG_LEVEL` — Pino log level (default: `info`)
- `WORKBENCH_MODE` — `dev` = mount all tools without toolbox filtering (set in `npm run dev`)

**All application config** (Google credentials, document paths, etc.) is stored in `workbench.config(app, key, value)` and read from DB at each MCP request. Zero env vars for app config.

## Architecture

### DI Container (Awilix)

The project uses **Awilix** dependency injection with PROXY mode. All services and tools are registered in a container and resolved by parameter name.

- **`container.ts`** — Core types (`ToolHandler`, `ToolPack`, `WithClient`, `ToolExtra`), `buildContainer()` (resolves `*Tool` registrations), `mountTools()` (reads toolbox from DB, mounts authorized tools onto McpServer)
- **`connection.ts`** — Exports `DbClient` type alias (`PoolClient`)
- **`helpers.ts`** — `text()` for MCP tool results, `wrap()` for formatted output with next-step URIs, `formatErrorTriplet()` for PostgreSQL error formatting

### Entry Point & Server Lifecycle

`src/index.ts` — Creates an Express server with a `/mcp` POST endpoint. Each request gets a fresh `McpServer` + transport instance (stateless per-request design). All packs are always loaded. Tools are mounted via `mountTools(server, container)`.

Also hosts the `/hooks/:module` endpoint for Claude Code workflow enforcement (see Hooks section below).

### Packs (`src/packs/`)

Each pack registers infrastructure + tools into the Awilix container:

| Pack | File | What it registers |
|------|------|-------------------|
| plpgsql | `packs/plpgsql.ts` | `pool`, `withClient`, shared services, 19 pg_*/ws_* tools |
| docstore | `packs/docstore.ts` | 4 fs_* tools (depends on plpgsql's `withClient`) |
| google | `packs/google.ts` | `googleAuthConfig`, `gmailClient`, 3 gmail_* tools |
| docman | `packs/docman.ts` | 17 doc_* tools (app layer on fs_*/gmail_*, zero inline SQL) |

### Tools (`src/tools/`)

Each tool file exports a factory function `createXxxTool(deps) -> ToolHandler`. Dependencies are declared as named destructured parameters, resolved by Awilix. Tools use Zod for parameter validation.

**plpgsql tools** (`src/tools/plpgsql/`):

| Tool | File | Purpose |
|------|------|---------|
| `pg_get` | `get.ts` | Navigate database by `plpgsql://` URI |
| `pg_search` | `search.ts` | Find objects by name pattern or body regex |
| `pg_func_set` | `func-set.ts` | Deploy function (CREATE OR REPLACE) with plpgsql_check + auto-test pipeline |
| `pg_func_edit` | `func-edit.ts` | Patch function body via old->new replacements |
| `pg_func_save` | `func-save.ts` | Save functions from DB to `src/` files (auto-resolved via module registry) |
| `pg_func_load` | `func-load.ts` | Load function `.sql` files from module `src/` to DB (auto-resolved via module registry) |
| `pg_schema` | `schema.ts` | Apply DDL migration files with tracking (run-once) |
| `pg_query` | `query.ts` | Execute raw SQL (SELECT returns rows, DML returns count) |
| `pg_explain` | `explain.ts` | EXPLAIN ANALYZE on a query (wrapped in ROLLBACK transaction) |
| `pg_test` | `test.ts` | Run pgTAP tests (by target URI or schema) |
| `pg_coverage` | `coverage.ts` | Code coverage via AST instrumentation |
| `pg_pack` | `pack.ts` | Consolidate functions into build/*.func.sql (dependency-sorted) + coherence check |
| `pg_doc` | `doc.ts` | Generate Mermaid dependency graphs via plpgsql_check |
| `pg_msg` | `msg.ts` | Send inter-module messages (task delegation, notifications) |
| `pg_msg_inbox` | `msg.ts` | Read incoming messages for a module |
| `pg_preview` | `preview.ts` | Preview rendered HTML pages via PostgREST |
| `ws_health` | `health.ts` | Workspace health: pending tasks, SQL coherence (DB vs src/), git status |
| `pg_visual` | `visual.ts` | Visual testing via Playwright: crawl pages, screenshots, POST actions, error detection |
| `pg_func_del` | `func-del.ts` | Drop a function from the database |

**Other tools**: `fs_scan`, `fs_sync`, `fs_peek`, `fs_open` (docstore), `gmail_search`, `gmail_read`, `gmail_attachment` (google), 17 `doc_*` tools (docman — import, classify, tag, link, relate, search, etc.).

### Resources (`src/resources/`)

Each resource module follows a **query + format** pattern:
- `queryResource(client, ...)` — executes SQL, returns typed data
- `formatResource(data)` — renders to compact text with navigable URIs

Modules: `catalog.ts`, `schema.ts`, `function.ts`, `table.ts`, `trigger.ts`, `type.ts`.

### Code Coverage Engine (`src/instrument/`)

- **`visitor.ts`** — Uses `@libpg-query/parser` to walk PL/pgSQL AST and extract block/branch coverage points. Generates injection instructions (before, inject_else, inject_after_loop).
- **`coverage.ts`** — Orchestrates: instrument function -> deploy -> run tests -> capture `RAISE WARNING` notices -> restore original -> persist results in `workbench.cov_run`/`workbench.cov_point` tables.

### pgm — PostgreSQL Module Manager (`src/pgm/`)

| File | Role |
|------|------|
| `cli.ts` | CLI entry point (`pgm app init\|install\|deploy\|remove\|list`, `pgm module new\|info\|list`) |
| `registry.ts` | Schema -> module path resolution (used by pg_pack, pg_func_save, pg_func_load) |
| `deployer.ts` | Apply module SQL to DB in dependency-resolved order |
| `installer.ts` | Copy module build/ files to app sql/ with slot convention |
| `resolver.ts` | Resolve module dependencies |
| `scaffold.ts` | Generate new module/app boilerplate |

Auto-resolution examples:
- `pg_pack schemas: "cad,cad_ut"` -> `modules/cad/build/cad.func.sql`

### PLX — Language Transpiler (`src/core/plx/`)

PLX compiles `.plx` files to PL/pgSQL. Zero runtime dependency — pure static transpilation.

| File | Role |
|------|------|
| `ast.ts` | AST node types (PlxModule, PlxFunction, PlxEntity, PlxTrait, Statement, Expression) |
| `lexer.ts` | Indentation-aware tokenizer, SQL passthrough, `::` / `->>` / `||` operators |
| `parser.ts` | Recursive descent parser (fn, if, for, match, case, return query/execute) |
| `codegen.ts` | AST -> PL/pgSQL (DECLARE inference, SELECT INTO, JSON literals, CASE expr) |
| `compiler.ts` | Pipeline orchestrator (lex -> parse -> codegen), optional PG WASM validation |
| `cli.ts` | `plx build <file>` / `plx check <file>` |
| `entity-expander.ts` | Expand entity blocks into PlxFunction[] + DDL (CRUD, states, traits, strategies) |
| `parse-context.ts` | Core parsing engine: token nav, expressions, statements, utilities |
| `entity-parser.ts` | Entity-specific parsing (standalone functions taking ParseContext) |
| `test-expander.ts` | Expand `PlxTest[]` into pgTAP `PlxFunction[]` (RETURNS SETOF text) |
| `semantic.ts` | Type inference, import checks, SQL safety warnings, structured diagnostics |
| `util.ts` | Shared `sqlEscape()` |

```bash
plx build file.plx              # Compile to .sql
plx build file.plx --stdout     # Print to stdout
plx check file.plx              # Check only, no output
plx check file.plx --validate   # Also validate via @libpg-query/parser WASM (needs 8GB heap)
```

**Key PLX syntax**: `fn schema.name(params) -> type [stable, definer]:`, `:=` assignment, `{k: v}` -> jsonb, `[]` -> jsonb, `"#{expr}"` interpolation, `case...when...end` inline, `return query`/`return execute` for SETOF, `import func as alias`, `entity schema.name uses trait:` (generates DDL + 6 CRUD + state transitions), `trait name:` (shared behaviors).

**Test syntax**: `test "name":` blocks with `assert` statements. Compiles to pgTAP (`RETURNS SETOF text`, `RETURN NEXT ok()/is()/isnt()`). Test functions go in `{schema}_ut`. Schema inferred from first qualified call. Fixture: `fixtures/plx/expense.spec.plx`.

**Test fixtures**: `fixtures/plx/` — 10 files, 59+ functions. `expense.plx` (fn dog-food), `entity_category.plx` (entity dog-food).
- `pg_func_save target: "plpgsql://cad"` -> `modules/cad/src/`

### Module Layout

**Active modules** (14):

| Module | Schemas | Purpose |
|--------|---------|---------|
| pgv | `pgv`, `pgv_ut`, `pgv_qa` | Framework: api, _view() contract, i18n, UI primitives |
| workbench | `workbench` | Platform infra: tenants, messaging, hooks, sessions, issues, UI dashboard |
| cad | `cad`, `cad_ut`, `cad_qa` | CAD 3D wood structures (PostGIS/SFCGAL, Three.js) |
| crm | `crm`, `crm_ut`, `crm_qa` | CRM: contacts, entreprises |
| quote | `quote`, `quote_ut`, `quote_qa` | Devis & factures (TVA, numérotation légale) |
| catalog | `catalog`, `catalog_ut` | Catalogue articles partagé (stock, purchase, quote) |
| stock | `stock`, `stock_ut`, `stock_qa` | Stock: articles, dépôts, mouvements |
| purchase | `purchase`, `purchase_ut`, `purchase_qa` | Achats: commandes fournisseur, réception |
| project | `project`, `project_ut`, `project_qa` | Projets: suivi chantier, phases |
| planning | `planning`, `planning_ut`, `planning_qa` | Planning: intervenants, événements |
| ledger | `ledger`, `ledger_ut`, `ledger_qa` | Comptabilité: plan comptable, écritures |
| expense | `expense`, `expense_ut` | Notes de frais |
| hr | `hr`, `hr_ut`, `hr_qa` | RH: salariés, absences, pointage |
| ops | `ops`, `ops_ut` | Ops: agents dashboard, terminaux tmux, tests runner |

Each module in `modules/` follows this structure:

```
modules/{name}/
├── module.json          # Manifest (name, version, schemas, dependencies, sql, assets, grants)
├── build/               # Deployment artifacts (generated, committed)
│   ├── {schema}.ddl.sql     # DDL: CREATE SCHEMA, tables, indexes, grants
│   └── {schema}.func.sql   # Functions: pg_pack output (dependency-sorted)
├── src/                 # Versioned function sources (pg_func_save output)
│   └── {schema}/
│       └── {function}.sql
├── qa/                  # QA seed data (pg_func_save output for _qa schemas)
│   └── {schema}_qa/
│       └── {function}.sql
├── frontend/            # Static assets (HTML, CSS, JS)
├── .mcp.json            # MCP config pointing to dev server
└── .claude/             # Claude Code settings + hooks
```

- `build/` = what `pgm install` copies to apps. Generated by `pg_pack` (functions) or hand-written (DDL).
- `src/` = individual function files for version control. Generated by `pg_func_save`.
- `qa/` = QA seed functions. `_qa` schemas are **data-only** (seed/clean), never routed by pgView.

### Deploy Pipeline

When `pg_func_set` or `pg_func_edit` is called on a function:
1. `CREATE OR REPLACE FUNCTION` in transaction
2. `plpgsql_check` static analysis (rolls back on error)
3. Auto-run `{schema}_ut.test_{name}()` if it exists
4. Return result with validation status + test report

### Hooks (`src/index.ts` — `/hooks/:module`)

The `/hooks/:module` endpoint enforces the dev workflow per module. Each module's `.claude/settings.local.json` points its Claude Code hooks here.

Rules enforced:
- **pg_query**: no DDL (`CREATE TABLE`, etc.) and no `CREATE FUNCTION` — use `pg_schema` for DDL, `pg_func_set` for functions
- **Write**: confined to module directory, no `.func.sql` files (generated by `pg_pack`), no `CREATE FUNCTION` in SQL files
- **pg_func_set**: only allowed on schemas owned by the module
- **pgv functions**: no inline `style="..."` (use `class="pgv-*"`)

## LMNAV Output Format

Tool outputs use LMNAV (LM-Navigable), a compact text format optimized for LLM comprehension (see `docs/LMNAV.md`). Key principles:

- **Key: value pairs** — no JSON braces/quotes (60.7% vs 52.3% LLM accuracy per benchmarks)
- **Navigable URIs** — every output contains `plpgsql://` URIs to drill deeper
- **`N|` line numbers** — for cross-reference with plpgsql_check errors
- **Explicit empty sections** — `calls: none` not omitted (absence = "not computed" vs "empty")
- **`completeness: full|partial`** — signals truncation
- **`next:` suggestions** — follow-up tool calls
- **Error triplet** — `problem/where/fix_hint` structure
- **`->` not `→`** — ASCII arrow is 1 token, Unicode is 3

## SDUI — Server-Driven UI

Two separate concerns, joined only on the client:

### 1. Schema (static) — how to render

Each entity declares `{entity}_view() RETURNS jsonb`. Called **once** at app startup, **cached** client-side. Never bundled with data.

```
{
  "uri": "crm://client",
  "label": "crm.entity_client",
  "template": {
    "compact":   { "fields": [...] },           -- overlay list items
    "standard":  { "fields": [...], "stats": [...], "related": [...] },  -- canvas cards
    "expanded":  { "fields": [...], "stats": [...], "related": [...] },  -- detail view
    "form":      { "sections": [{ "label": "...", "fields": [...] }] }   -- create/edit
  },
  "actions": {                                  -- catalog of possible actions
    "archive": { "label": "crm.action_archive", "variant": "warning", "confirm": "crm.confirm_archive" },
    "delete":  { "label": "crm.action_delete",  "variant": "danger",  "confirm": "crm.confirm_delete" }
  }
}
```

ViewField = `string` (key only) or `{ "key": "...", "type": "date|currency|status", "label": "i18n.key" }`.

### 2. Data (dynamic) — what to render

`pgv.api(verb, uri, data)` dispatches CRUD operations. Returns **only** `{data, uri, actions}` — no schema.

| Verb | URI | Dispatches to | Returns |
|------|-----|--------------|---------|
| `get` | `crm://client` | `client_list()` | `{data: [...], uri}` |
| `get` | `crm://client/1` | `client_read(1)` | `{data: {...}, uri, actions: [...]}` |
| `set` | `crm://client` | `client_create(data)` | `{data: {...}, uri}` |
| `patch` | `crm://client/1` | `client_update(data)` | `{data: {...}, uri}` |
| `delete` | `crm://client/1` | `client_delete(1)` | `{data: {...}, uri}` |
| `post` | `crm://client/1/archive` | `client_archive(1)` | `{data: {...}, uri}` |

HATEOAS: `_read()` returns available actions based on entity state (e.g. active client → archive/delete). These are **runtime** actions, not the static catalog from `_view()`.

### 3. Client joins schema + data

```
startup:  _view() → viewCache (one call per entity type, cached forever)
browse:   api('get', uri) → data only → render with cached view
pin:      api('get', uri/id) → data + HATEOAS actions → render card
action:   api('post', uri/id/method) → refresh data
create:   api('set', uri, formData) → new row
```

The client (React) is the **only** place where schema and data meet. The server never bundles them.

### CRUD Function Convention (per entity)

| Function | Purpose | Returns |
|----------|---------|---------|
| `{entity}_view()` | UI schema (static) | jsonb |
| `{entity}_list(filter?)` | Browse list | SETOF jsonb |
| `{entity}_read(id)` | Single entity + HATEOAS actions | jsonb |
| `{entity}_create(record)` | Create | jsonb (new row) |
| `{entity}_update(record)` | Update | jsonb (updated row) |
| `{entity}_delete(id)` | Delete | jsonb |
| `{entity}_{action}(id)` | Domain action (archive, send, etc.) | jsonb |

### i18n

`pgv.i18n_bundle(lang)` returns all translations as `{key: value}`. React `useT()` hook resolves keys. Field labels follow convention `{schema}.field_{key}`.

### Files

| Path | Role |
|------|------|
| `app/src/` | React frontend (canvas, overlay, admin) |
| `modules/pgv/src/pgv/` | Framework functions (api, i18n, schema_*, ui_*) |

## SQL

- **Dev DB** — `seed/` (repo root) — bootstrap extensions, roles, workbench schema. Auto-run by Docker init.
- **Workbench module** — `modules/workbench/` is a standard module managed via `pg_pack`/`pg_func_save` like all others. `seed/003_workbench.sql` is the **bootstrap seed** only (schema creation + tenant seed data). Functions live in `modules/workbench/build/workbench.func.sql` (pg_pack output) and `modules/workbench/src/workbench/` (pg_func_save output).
- **pgv framework** — `modules/pgv/build/pgv.func.sql` — canonical `pgv.*` + `pgv_ut.*`. Distributed via `pgm install`.
- **Apps** — `apps/*/sql/` — slot convention: 00=extensions, 01=roles, 02=pgv, 05+=modules, 03-04=app-specific.

## Language Rules (STRICT)

- **Code** — ALL code in English: function names, parameter names, variable names, column names, JSON keys, comments. No exceptions.
- **Labels** — ALL user-facing text via `pgv.t('module.key')`. Never hardcode French (or any language) strings in functions. Labels live in `i18n_seed()` only.
- **CLAUDE.md** — English.
- **Commits** — English.
- **Examples**: `client_list` (not `liste_clients`), `pgv.t('crm.action_send')` (not `'Envoyer'`), `status = 'draft'` (not `'brouillon'`)

## Key Conventions

- **ESM project** — `"type": "module"` in package.json, `Node16` module resolution
- **Strict TypeScript** — `noUncheckedIndexedAccess: true` in tsconfig. Array indexing and regex captures return `T | undefined`. Use `!` assertions when value is guaranteed (after length checks, inside loops, regex groups).
- **Awilix DI** — Tool factories declare deps as named params, resolved by container. Registration names ending in `Tool` are auto-discovered.
- **pgTAP test naming** — Unit tests: `{schema}_ut.test_{name}()`, Integration tests: `{schema}_it.test_{name}()`
- **Schema = Module (DDD)** — Each PostgreSQL schema is a bounded context with its own tables, functions, and tests. Each module provides `nav_items()`, `brand()`, and `get_*/post_*` page functions. The router `pgv.route()` dispatches automatically via pg_proc introspection.
- **QA schemas = data only, NO routing** — `{schema}_qa` contains only `seed()` and `clean()` functions for injecting/removing demo data into the main schema tables. QA schemas are NOT exposed in PGRST_DB_SCHEMAS, have NO `get_*()` pages, NO `nav_items()`, NO routing. To view QA data, run `{schema}_qa.seed()` then browse the main schema pages normally. QA schemas are NOT separate modules.
- **pgView function naming** — `get_*()` for pages (GET), `post_*()` for actions (POST). Parameters via query string (`/drawing?id=42`), not path segments. Function signature determines dispatch (0 args, jsonb, scalar, composite type).
- **PostgreSQL extensions** — `plpgsql_check` (static analysis), `pgtap` (testing) — both optional, server degrades gracefully
- **Tool naming** — `{domain}_{action}`: `pg_*` (PostgreSQL), `fs_*` (filesystem/docstore), `gmail_*` (Google)
- **Zero inline SQL in app tools** — App tools (doc_*, etc.) MUST NOT contain raw SQL. Business logic lives in PL/pgSQL functions deployed in the app schema (e.g. `docman.import()`, `docman.classify()`). App MCP tools are thin orchestrators: they read config from DB, call platform primitives (fs_*, gmail_*), and call app PL/pgSQL functions via `withClient`. SQL in TypeScript = bug.
- **Zero process.env for app config** — Only infra bootstrap uses env vars (PLPGSQL_CONNECTION, MCP_PORT, LOG_LEVEL, WORKBENCH_MODE). All app config lives in `workbench.config(app, key, value)` and is read from DB at request time. No defaults, no fallbacks.
- **PostgREST CRUD routing** — `pgv.api(verb, uri, data)` dispatches CRUD operations. Returns `{data, uri, actions}` only — never includes view schema. React calls via `pgv.rpc("api", ...)`.
- **PostgREST grants** — Each `build/{schema}.ddl.sql` MUST include `GRANT USAGE ON SCHEMA {schema} TO anon`, `GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA {schema} TO anon`, `GRANT SELECT ON ALL TABLES IN SCHEMA {schema} TO anon` — otherwise 500 in frontend via PostgREST

## Documentation Map

| File | Content |
|------|---------|
| `docs/LMNAV.md` | Output format specification with examples for every tool |
| `docs/PGM.md` | PostgreSQL Module Manager: module.json spec, pgm CLI, install/deploy workflow |
| `src/core/docs/sdui.md` | SDUI contract: _view() template, api, entity types, form fields |
| `docs/BUSINESS.md` | Business plan for SaaS artisan ERP + toolbox packaging model |
| `docs/AI-INTEGRATION.md` | 3-level AI integration: MCP (done), chat widget, autonomous agent |
| `docs/PRIMITIVE.md` | Original spec for MCP tool primitives (some aspirational) |
| `src/docs/testing.md` | pgTAP testing guide (loaded into workbench DB as built-in doc) |
| `src/docs/coverage.md` | Coverage tool guide (loaded into workbench DB as built-in doc) |
