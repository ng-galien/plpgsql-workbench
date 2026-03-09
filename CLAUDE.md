# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PL/pgSQL Workbench is a development platform built as an MCP (Model Context Protocol) server. It provides tools for navigating, editing, testing, and analyzing PL/pgSQL code in PostgreSQL. It runs as an HTTP server (default port 3100) exposing MCP tools at `/mcp`.

The workbench is the foundation for building all applications with PostgreSQL as sole runtime (see `docs/PGAPP.md`). Each application is a set of PostgreSQL schemas + MCP tools, packaged via toolboxes for commercial distribution.

## Build & Run Commands

```bash
# Start dev database (Supabase PostgreSQL 17)
docker compose up -d

# Dev with auto-reload (connection string is set in npm script)
npm run dev

# Build
npm run build          # tsc -> dist/

# Start built version
PLPGSQL_CONNECTION=postgresql://postgres:postgres@localhost:5433/postgres npm start

# Bootstrap seed data (extensions + test schemas are auto-created by Docker init)
# For application data, use:
#   pg_apply path:sql/migrations
#   pg_apply path:sql/functions
```

No test framework is configured in this repo — testing happens via pgTAP inside PostgreSQL.

### Dev Database

The dev database uses `supabase/postgres:17.6.1.093` (same as production target).

```bash
docker compose up -d     # Start (port 5433)
docker compose down      # Stop (data persists in pgdata volume)
docker compose down -v   # Stop + wipe data (triggers fresh initdb on next up)
```

**Connection:** `postgresql://postgres:postgres@localhost:5433/postgres`

**Auto-initialized on first start** (via `sql/seed/` mounted into `init-scripts/`):
- `plpgsql_check` + `pgtap` extensions
- `workbench` schema (toolbox, toolbox_tool, tenant tables)

**Sync tools to DB** (after code changes):
```bash
npm run sync-tools    # Populates workbench.toolbox_tool from code registry
```

**Supabase extensions available** (pre-installed in image): `pgcrypto`, `uuid-ossp`, `pg_graphql`, `pg_net`, `pg_cron`, `pgjwt`, `supabase_vault`, `pg_stat_statements`, and more.

### Demo

```bash
cd demo && docker compose up -d
# PostgreSQL on port 5434, PostgREST on port 3000, Frontend on port 8080
# Then run the MCP server with:
PLPGSQL_CONNECTION=postgresql://postgres:postgres@localhost:5434/postgres npx tsx watch src/index.ts
```

The demo is a shop e-commerce app with two frontends:
- `demo/frontend/index.html` — SPA calling PostgREST RPC directly
- `demo/frontend/pgview.html` — pgView client (DB generates HTML, frontend is ~100 lines)

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

### Packs (`src/packs/`)

Each pack registers infrastructure + tools into the Awilix container:

| Pack | File | What it registers |
|------|------|-------------------|
| plpgsql | `packs/plpgsql.ts` | `pool`, `withClient`, shared services, 11 pg_* tools |
| docstore | `packs/docstore.ts` | 4 fs_* tools (depends on plpgsql's `withClient`) |
| google | `packs/google.ts` | `googleAuthConfig`, `gmailClient`, 3 gmail_* tools |

### Tools (`src/tools/`)

Each tool file exports a factory function `createXxxTool(deps) -> ToolHandler`. Dependencies are declared as named destructured parameters, resolved by Awilix. Tools use Zod for parameter validation.

**plpgsql tools** (`src/tools/plpgsql/`):

| Tool | File | Purpose |
|------|------|---------|
| `pg_get` | `get.ts` | Navigate database by `plpgsql://` URI |
| `pg_search` | `search.ts` | Find objects by name pattern or body regex |
| `pg_set` | `set.ts` | Deploy SQL (CREATE OR REPLACE) with plpgsql_check + auto-test pipeline |
| `pg_edit` | `edit.ts` | Patch function body via old->new replacements |
| `pg_query` | `query.ts` | Execute raw SQL (SELECT returns rows, DML returns count) |
| `pg_explain` | `explain.ts` | EXPLAIN ANALYZE on a query (wrapped in ROLLBACK transaction) |
| `pg_test` | `test.ts` | Run pgTAP tests (by target URI or schema) |
| `pg_coverage` | `coverage.ts` | Code coverage via AST instrumentation |
| `pg_dump` | `dump.ts` | Export functions to `.sql` files on disk |
| `pg_apply` | `apply.ts` | Apply `.sql` files with migration tracking |
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

### Deploy Pipeline

When `pg_set` or `pg_edit` is called on a function:
1. `CREATE OR REPLACE FUNCTION` in transaction
2. `plpgsql_check` static analysis (rolls back on error)
3. Auto-run `{schema}_ut.test_{name}()` if it exists
4. Return result with validation status + test report

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

Server-Side Rendering in PL/pgSQL (see `docs/PGAPP.md`, demo in `demo/init/05-pgview.sql`):

- PostgreSQL generates HTML directly via `page(path, body) -> text`
- PostgREST exposes it as `POST /rpc/page`
- Frontend shell is ~50 lines: `go(path)`, `post(path, body)`, `render(html)`
- `<md>` blocks for Markdown tables (converted client-side by marked.js)
- HTML helpers: `esc()` (XSS), `pgv_badge()`, `pgv_money()`, `pgv_status()`, `pgv_nav()`
- `<!-- redirect:/path -->` convention for POST->redirect

## SQL (`sql/`)

- `sql/seed/` — Bootstrap DDL, auto-run by Docker on first start: extensions + workbench schema
- `sql/migrations/` — Application DDL (example: banking, shop schemas)
- `sql/functions/` — Application functions organized by schema

Applied via: `pg_apply path:sql/migrations` then `pg_apply path:sql/functions`.

Note: `sql/migrations/` and `sql/functions/` contain demo/example content (banking, shop). These are illustrative and not part of the platform itself.

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
| `docs/PGAPP.md` | Full platform vision: API router, pgView SSR, schema=module, VS Code extension, pgv primitives |
| `docs/BUSINESS.md` | Business plan for SaaS artisan ERP + toolbox packaging model |
| `docs/AI-INTEGRATION.md` | 3-level AI integration: MCP (done), chat widget, autonomous agent |
| `docs/PRIMITIVE.md` | Original spec for MCP tool primitives (some aspirational) |
| `src/docs/testing.md` | pgTAP testing guide (loaded into workbench DB as built-in doc) |
| `src/docs/coverage.md` | Coverage tool guide (loaded into workbench DB as built-in doc) |
