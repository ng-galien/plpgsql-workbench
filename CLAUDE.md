# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PL/pgSQL Workbench is a development platform built as an MCP (Model Context Protocol) server. It provides tools for navigating, editing, testing, and analyzing PL/pgSQL code in PostgreSQL. It runs as an HTTP server (default port 3100) exposing MCP tools at `/mcp`.

The workbench is the foundation for building all applications with PostgreSQL as sole runtime (see `docs/PGAPP.md`). Each application is a set of PostgreSQL schemas + MCP tools, packaged via toolboxes for commercial distribution.

## Build & Run Commands

```bash
# Start dev database (Supabase PostgreSQL 17)
make dev-up              # or: docker compose up -d
make dev-init            # loads pgv into dev DB (after fresh start)

# Dev MCP server (all packs, dev DB on 5433)
npm run dev

# Dev MCP server for a specific app
npm run dev:docman       # packs + DB from apps/docman/workbench.json, port 3103
npm run dev:uxlab        # packs + DB from apps/uxlab/workbench.json, port 3101

# Build
npm run build            # tsc -> dist/

# Scaffold a new app
mkdir apps/myapp && cd apps/myapp && pgm app init   # scaffold new app
pgm module new mymod                                # scaffold new module
```

No test framework is configured in this repo — testing happens via pgTAP inside PostgreSQL.

### Dev Stack

Shared dev environment for module development. Custom image `pg-workbench` based on `postgres:17` (native ARM64/Apple Silicon) with PostGIS + SFCGAL from Debian packages, `plpgsql_check` + `pgtap` built from source.

```bash
make dev-up              # Start stack (postgres:5433, postgrest:3000, nginx:8080)
make dev-down            # Stop (data persists in data/pgdata/)
make dev-clean           # Stop containers (data preserved — delete manually if needed)
make dev-init            # Start + deploy all modules into dev DB
make dev-sync            # Copy module frontend assets into dev/frontend/
```

**Local persistence:** Data is stored in `./data/pgdata/` (bind mount, not Docker volume). Never auto-deleted — safety first. Delete manually with `rm -rf data/pgdata/` only after `docker compose down`.

**Dynamic PostgREST schemas:** `make dev-up` generates `.env` with `PGRST_DB_SCHEMAS` extracted from `modules/*/module.json` schemas.

**Connection:** `postgresql://postgres:postgres@localhost:5433/postgres`

**Auto-initialized on first start** (via `seed/`):
- Extensions: `plpgsql_check`, `pgtap`, `postgis`, `postgis_sfcgal`
- Roles: `authenticator`, `web_anon`, domain `text/html`
- `workbench` schema (toolbox, toolbox_tool, tenant tables)
- Run `make dev-init` after fresh start to deploy all modules (pgv, cad3d, etc.)

**PostgREST** auto-reloads schema cache via `NOTIFY pgrst, 'reload schema'`.

**Sync tools to DB** (after code changes):
```bash
npm run sync-tools    # Populates workbench.toolbox_tool from code registry
```

### Apps

Apps live in `apps/`. Each has its own `docker-compose.yml`, `Makefile`, `sql/`, `frontend/`.

**Port convention** — app N: PG=5440+N, PostgREST=3000+N, HTTP=8080+N

| Directory | PG | PGRST | HTTP | MCP |
|-----------|-----|-------|------|-----|
| `apps/001-uxlab` | 5441 | 3001 | 8081 | 3101 |
| `apps/002-demo` | 5442 | 3002 | 8082 | 3102 |
| `apps/003-docman` | 5443 | 3003 | 8083 | 3103 |

```bash
cd apps/001-uxlab && make up         # Start app stack
npm run dev:uxlab                    # Start MCP for this app
mkdir apps/billing && cd apps/billing && pgm app init   # Scaffold new app
```

The pgView framework and other modules live in `modules/` and are distributed to apps via `pgm app install`. See `docs/PGM.md`.

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
| plpgsql | `packs/plpgsql.ts` | `pool`, `withClient`, shared services, 13 pg_* tools |
| docstore | `packs/docstore.ts` | 4 fs_* tools (depends on plpgsql's `withClient`) |
| google | `packs/google.ts` | `googleAuthConfig`, `gmailClient`, 3 gmail_* tools |

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
| `pg_doc` | `doc.ts` | Generate Mermaid dependency graphs via plpgsql_check |

**docstore tools** (`src/tools/docstore/`):

| Tool | File | Purpose |
|------|------|---------|
| `fs_scan` | `scan.ts` | Scan directory, register files in docstore.file |
| `fs_sync` | `sync.ts` | Compare filesystem with DB index |
| `fs_peek` | `peek.ts` | Read file content with pagination, PDF support |
| `fs_open` | `open.ts` | Open file/directory with system default app |

**google tools** (`src/tools/google/`):

| Tool | File | Purpose |
|------|------|---------|
| `gmail_search` | `gmail-search.ts` | Search Gmail with query syntax |
| `gmail_read` | `gmail-read.ts` | Read full message by ID |
| `gmail_attachment` | `gmail-attachment.ts` | Download attachment to disk |

Shared: `auth.ts` (OAuth2 service), `utils.ts` (docstore utilities).

### Resources (`src/resources/`)

Each resource module follows a **query + format** pattern:
- `queryResource(client, ...)` — executes SQL, returns typed data
- `formatResource(data)` — renders to compact text with navigable URIs

Modules: `catalog.ts`, `schema.ts`, `function.ts`, `table.ts`, `trigger.ts`, `type.ts`.

### Code Coverage Engine (`src/instrument/`)

- **`visitor.ts`** — Uses `@libpg-query/parser` to walk PL/pgSQL AST and extract block/branch coverage points. Generates injection instructions (before, inject_else, inject_after_loop).
- **`coverage.ts`** — Orchestrates: instrument function -> deploy -> run tests -> capture `RAISE WARNING` notices -> restore original -> persist results in `workbench.cov_run`/`workbench.cov_point` tables.

### Module Registry (`src/pgm/registry.ts`)

Maps schemas to modules for automatic path resolution. Tools like `pg_pack`, `pg_func_save`, and `pg_func_load` use the registry to find the correct module directory — no manual `path` parameter needed.

- `pg_pack schemas: "cad,cad_ut"` -> auto-resolves to `modules/cad3d/build/cad.func.sql`
- `pg_func_save target: "plpgsql://cad"` -> auto-resolves to `modules/cad3d/src/`
- `pg_func_load target: "plpgsql://cad"` -> auto-resolves to `modules/cad3d/src/`

### Module Layout

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
├── frontend/            # Static assets (HTML, CSS, JS)
├── .mcp.json            # MCP config pointing to dev server
└── .claude/             # Claude Code settings + hooks
```

- `build/` = what `pgm install` copies to apps. Generated by `pg_pack` (functions) or hand-written (DDL).
- `src/` = individual function files for version control. Generated by `pg_func_save`.

### Deploy Pipeline

When `pg_func_set` or `pg_func_edit` is called on a function:
1. `CREATE OR REPLACE FUNCTION` in transaction
2. `plpgsql_check` static analysis (rolls back on error)
3. Auto-run `{schema}_ut.test_{name}()` if it exists
4. Return result with validation status + test report

### Deployer (`src/pgm/deployer.ts`)

`pgm deploy` applies module SQL to a live database in dependency-resolved order:
- Auto-installs extensions declared in `module.json` (`CREATE EXTENSION IF NOT EXISTS`)
- Checks schema/extension dependencies before deploying
- Stops on first failure (downstream modules depend on earlier ones)

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

## pgView Pattern

Server-Side Rendering in PL/pgSQL (see `docs/PGAPP.md`, canonical source in `modules/pgv/`):

- PostgreSQL generates HTML via `page(path, body) -> "text/html"` domain
- PostgREST serves raw HTML (`Content-Type: text/html`) via domain trick
- **Alpine.js** shell (~150 lines) handles routing, events, toast, dialogs
- **PicoCSS** classless styling, **marked.js** for Markdown tables in `<md>` blocks
- `pgv.*` schema = reusable UI primitives styled via `pgview.css`

### pgView Conventions (ENFORCED)

**1. data-\* contract** — PL/pgSQL generates pure HTML + `data-*` attributes. Shell interprets them.

| Pattern | Who generates | Shell action |
|---------|--------------|--------------|
| `<a href="/path">` | PL/pgSQL | `go(path)` navigation |
| `<form data-rpc="fn">` | PL/pgSQL | `post(fn, formData)` |
| `<button data-rpc="fn" data-params='{}' data-confirm="msg">` | `pgv.action()` | `post(fn, params)` |
| `<template data-toast="success\|error">msg</template>` | action return | Toast notification |
| `<template data-redirect="/path"></template>` | action return | `go(path)` redirect |
| `<button data-dialog="name" data-src="url" data-target="id">` | PL/pgSQL | Open dialog |
| `<button data-toggle-theme>` | `pgv.nav()` | Flip light/dark theme |

**2. CSS classes, NEVER inline styles** — pgv primitives output `class="pgv-*"`, all styling lives in `pgview.css` with `--pgv-*` CSS custom properties. Light/dark themes via `[data-theme]` selectors. NEVER generate `style="..."` in pgv functions.

**3. Tables via Markdown** — Use `<md>` blocks for tables, NOT raw `<table>` HTML. The shell converts via marked.js and adds sort + pagination automatically.
- `<md>` = table with sortable columns
- `<md data-page="10">` = table with pagination (10 rows/page)
- HTML inline (badges, etc.) works inside markdown cells

**4. pgv primitives are platform** — `pgv.*` functions live in `modules/pgv/build/pgv.func.sql` (canonical source, exported via `pg_pack`). They are shared infrastructure, not app code. Each app gets pgv files via `pgm install`.

### pgView Files

| File | Role |
|------|------|
| `modules/pgv/frontend/index.html` | Alpine.js shell (routing, events, toast, dialog, table enhance) |
| `modules/pgv/frontend/pgview.css` | CSS tokens + component styles + light/dark themes |
| `modules/pgv/build/pgv.func.sql` | pgv + pgv_ut schemas (pg_pack output) |
| `modules/pgv/src/pgv/*.sql` | Individual function sources (pg_func_save output) |

## SQL

**Dev DB** (`sql/seed/`) — workbench-only bootstrap (extensions, roles, workbench schema). Auto-run by Docker init on port 5433.

**pgv framework** (`modules/pgv/build/pgv.func.sql`) — canonical source for `pgv.*` + `pgv_ut.*` schemas. Exported via `pg_pack`, distributed to apps via `pgm install`.

**Apps** (`apps/*/sql/`) — each app has its own SQL init files, managed by `pgm install`:
- `00-{module}-extensions.sql` — from pgv module
- `01-roles.sql` — app-specific roles and permissions
- `02-{module}-{file}.sql` — from pgv module (slot 02)
- `05-{module}-{file}.sql` — from other modules (slot 05+)
- App-specific files: `03-ddl.sql`, `04-functions.sql`, etc.

## Key Conventions

- **ESM project** — `"type": "module"` in package.json, `Node16` module resolution
- **Awilix DI** — Tool factories declare deps as named params, resolved by container. Registration names ending in `Tool` are auto-discovered.
- **pgTAP test naming** — Unit tests: `{schema}_ut.test_{name}()`, Integration tests: `{schema}_it.test_{name}()`
- **Schema = Module (DDD)** — Each PostgreSQL schema is a bounded context with its own tables, functions, router, and tests
- **PostgreSQL extensions** — `plpgsql_check` (static analysis), `pgtap` (testing) — both optional, server degrades gracefully
- **Tool naming** — `{domain}_{action}`: `pg_*` (PostgreSQL), `fs_*` (filesystem/docstore), `gmail_*` (Google)
- **Zero inline SQL in app tools** — App tools (doc_*, etc.) MUST NOT contain raw SQL. Business logic lives in PL/pgSQL functions deployed in the app schema (e.g. `docman.import()`, `docman.classify()`). App MCP tools are thin orchestrators: they read config from DB, call platform primitives (fs_*, gmail_*), and call app PL/pgSQL functions via `withClient`. SQL in TypeScript = bug.
- **Zero process.env for app config** — Only infra bootstrap uses env vars (PLPGSQL_CONNECTION, MCP_PORT, LOG_LEVEL, WORKBENCH_MODE). All app config lives in `workbench.config(app, key, value)` and is read from DB at request time. No defaults, no fallbacks.

## Documentation Map

| File | Content |
|------|---------|
| `docs/LMNAV.md` | Output format specification with examples for every tool |
| `docs/PGAPP.md` | Platform architecture: API router, pgView SSR, schema=module, VS Code extension, pgv primitives |
| `docs/FRONTEND.md` | **UI/UX stack reference**: Alpine.js + PicoCSS + PostgREST + pgView primitives, shell, data-\* contract |
| `docs/BUSINESS.md` | Business plan for SaaS artisan ERP + toolbox packaging model |
| `docs/AI-INTEGRATION.md` | 3-level AI integration: MCP (done), chat widget, autonomous agent |
| `docs/PGM.md` | PostgreSQL Module Manager: module.json spec, pgm CLI, install/deploy workflow |
| `docs/PRIMITIVE.md` | Original spec for MCP tool primitives (some aspirational) |
| `src/docs/testing.md` | pgTAP testing guide (loaded into workbench DB as built-in doc) |
| `src/docs/coverage.md` | Coverage tool guide (loaded into workbench DB as built-in doc) |
