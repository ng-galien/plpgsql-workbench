# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PL/pgSQL Workbench is an MCP (Model Context Protocol) server that provides tools for navigating, editing, testing, and analyzing PL/pgSQL code in PostgreSQL. It runs as an HTTP server (default port 3100) exposing MCP tools at `/mcp`.

Part of a broader vision: building full applications with PostgreSQL as sole runtime (see `docs/PGAPP.md`).

## Build & Run Commands

```bash
# Build
npm run build          # tsc → dist/

# Dev with auto-reload
PLPGSQL_CONNECTION=postgresql://postgres:postgres@localhost:5433/postgres npx tsx watch src/index.ts

# Start built version
PLPGSQL_CONNECTION=postgresql://postgres:postgres@localhost:5433/postgres npm start
```

No test framework is configured in this repo — testing happens via pgTAP inside PostgreSQL.

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

## Environment Variables

- `PLPGSQL_CONNECTION` / `DATABASE_URL` — PostgreSQL connection string (default: `postgresql://postgres@localhost:5432/postgres`)
- `MCP_PORT` — HTTP port (default: `3100`)

## Architecture

### Entry Point & Server Lifecycle

`src/index.ts` — Creates an Express server with a `/mcp` POST endpoint. Each request gets a fresh `McpServer` + transport instance (stateless per-request design). All 11 tools are registered here.

### Core Modules

- **`connection.ts`** — pg connection pool (max 5). Exports `DbClient` type.
- **`uri.ts`** — Parses `plpgsql://` URIs into `{ schema, kind, name }`. Four levels: catalog → schema → resource → batch (`*`).
- **`helpers.ts`** — `withClient()` for pool-safe DB calls, `text()` for MCP tool results, `wrap()` for formatted output with next-step URIs, `formatErrorTriplet()` for PostgreSQL error formatting.
- **`workbench.ts`** — Creates `workbench` schema + `workbench.doc` table. Loads markdown docs from `src/docs/`.
- **`docs.ts`** — Reads markdown files with frontmatter from `src/docs/`.

### Tools (`src/tools/`)

Each tool file exports a registration function called from `index.ts`. Tools use Zod for parameter validation.

| Tool | File | Purpose |
|------|------|---------|
| `get` | `get.ts` | Navigate database by `plpgsql://` URI |
| `search` | `search.ts` | Find objects by name pattern or body regex |
| `set` | `set.ts` | Deploy SQL (CREATE OR REPLACE) with plpgsql_check + auto-test pipeline |
| `edit` | `edit.ts` | Patch function body via old→new replacements |
| `query` | `query.ts` | Execute raw SQL (SELECT returns rows, DML returns count) |
| `explain` | `explain.ts` | EXPLAIN ANALYZE on a query |
| `test` | `test.ts` | Run pgTAP tests (by target URI or schema) |
| `coverage` | `coverage.ts` | Code coverage via AST instrumentation |
| `dump` | `dump.ts` | Export functions to `.sql` files on disk |
| `apply` | `apply.ts` | Apply `.sql` files with migration tracking |
| `doc` | `doc.ts` | Generate Mermaid dependency graphs via plpgsql_check |

### Resources (`src/resources/`)

Each resource module follows a **query + format** pattern:
- `queryResource(client, ...)` — executes SQL, returns typed data
- `formatResource(data)` — renders to compact text with navigable URIs

Modules: `catalog.ts`, `schema.ts`, `function.ts`, `table.ts`, `trigger.ts`, `type.ts`.

### Code Coverage Engine (`src/instrument/`)

- **`visitor.ts`** — Uses `@libpg-query/parser` to walk PL/pgSQL AST and extract block/branch coverage points. Generates injection instructions (before, inject_else, inject_after_loop).
- **`coverage.ts`** — Orchestrates: instrument function → deploy → run tests → capture `RAISE WARNING` notices → restore original → persist results in `workbench.cov_run`/`workbench.cov_point` tables.

### Deploy Pipeline

When `set` or `edit` is called on a function:
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

- PostgreSQL generates HTML directly via `page(path, body) → text`
- PostgREST exposes it as `POST /rpc/page`
- Frontend shell is ~50 lines: `go(path)`, `post(path, body)`, `render(html)`
- `<md>` blocks for Markdown tables (converted client-side by marked.js)
- HTML helpers: `esc()` (XSS), `pgv_badge()`, `pgv_money()`, `pgv_status()`, `pgv_nav()`
- `<!-- redirect:/path -->` convention for POST→redirect

## Example SQL (`sql/`)

Sample SQL files used with the `apply` tool, organized for the three example schemas:

- `sql/seed/` — Bootstrap: extensions (plpgsql_check, pgtap) and test schemas (public_ut, public_it)
- `sql/migrations/` — DDL: banking schema (accounts, transactions) and shop schema
- `sql/functions/` — Functions organized by schema (`public/`, `public_ut/`, `banking/`, `banking_ut/`, `shop/`, `shop_ut/`). Includes simple examples (hello, add_numbers, classify) and full business logic (transfer, place_order)

Applied via: `apply path:sql/seed track:false` then `apply path:sql/migrations` then `apply path:sql/functions`.

## Key Conventions

- **ESM project** — `"type": "module"` in package.json, `Node16` module resolution
- **pgTAP test naming** — Unit tests: `{schema}_ut.test_{name}()`, Integration tests: `{schema}_it.test_{name}()`
- **Schema = Module (DDD)** — Each PostgreSQL schema is a bounded context with its own tables, functions, router, and tests
- **PostgreSQL extensions** — `plpgsql_check` (static analysis), `pgtap` (testing) — both optional, server degrades gracefully

## Documentation Map

| File | Content |
|------|---------|
| `docs/LMNAV.md` | Output format specification with examples for every tool |
| `docs/PGAPP.md` | Full platform vision: API router, pgView SSR, schema=module, VS Code extension, pgv primitives |
| `docs/BUSINESS.md` | Business plan for SaaS artisan ERP built on pgView |
| `docs/AI-INTEGRATION.md` | 3-level AI integration: MCP (done), chat widget, autonomous agent |
| `docs/PRIMITIVE.md` | Original spec for MCP tool primitives (some aspirational) |
| `src/docs/testing.md` | pgTAP testing guide (loaded into workbench DB as built-in doc) |
| `src/docs/coverage.md` | Coverage tool guide (loaded into workbench DB as built-in doc) |
