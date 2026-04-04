# CLAUDE.md

## Project Overview

PL/pgSQL Workbench is a development platform built as an MCP server. It provides tools for building PostgreSQL applications using **PLX** (a language that compiles to PL/pgSQL) and a **runtime** layer of hand-written SQL schemas.

PostgreSQL is the sole application runtime. Each application = PostgreSQL schemas + MCP tools. Frontend: React canvas workspace (`app/`) with SDUI pattern (server-driven UI).

## Stack

**Supabase** is the only dev stack. No docker-compose, no custom pg-workbench image.

```bash
supabase start           # Start local stack (db:54322, api:54321)
supabase stop            # Stop
supabase db reset        # Reset database
npm run dev              # MCP server (port 3100) + React frontend (port 5173)
```

**Connection:** `postgresql://postgres:postgres@localhost:54322/postgres`

**Supabase config:** `supabase/config.toml` — schemas exposed via API are listed there. No `_ut`/`_qa` schemas in config (not deployed).

## Build & Test

```bash
npm run build            # tsc -> dist/
npm test                 # vitest run
npm run test:watch       # vitest watch
npm run lint             # biome check
npm run lint:fix         # biome check --fix
npm run coverage:plx     # vitest PLX tests with coverage

# PLX transpiler
plx build modules/crm/plx/crm.plx       # Compile .plx to PL/pgSQL
plx check modules/crm/plx/crm.plx       # Syntax check only
plx check file.plx --validate            # Also validate via PG parser WASM
```

**PLX fixtures:** `fixtures/plx/` — 12 `.plx` files for compiler testing.

## Two Deployment Paths

Everything in the database comes from one of two sources:

### 1. PLX Modules (`modules/`)

Modules are defined in `.plx` files. The PLX compiler generates all SQL (DDL, functions, tests, i18n). Managed via `plx_*` MCP tools.

```
modules/{name}/
├── module.json          # Manifest (schemas, dependencies, plx.entry)
├── plx/                 # PLX source files
│   ├── {name}.plx       # Entry point (module, depends, includes)
│   ├── {name}.i18n      # Translations sidecar
│   ├── {entity}.plx     # Entity definitions
│   └── {entity}.spec.plx # Tests
├── build/               # Generated SQL (committed, output of plx build)
│   ├── {schema}.ddl.sql
│   └── {schema}.func.sql
└── src/                 # Legacy individual function files (being replaced by plx/)
```

**module.json** declares `plx.entry` pointing to the PLX entry file:
```json
{
  "name": "crm",
  "schemas": { "public": "crm", "test": "crm_ut", "qa": "crm_qa" },
  "plx": { "entry": "plx/crm.plx" }
}
```

**MCP tools:**

| Tool | Purpose |
|------|---------|
| `plx_status` | Inspect module: entrypoint, fragments, contract, build freshness, apply state |
| `plx_apply` | Build PLX + incremental apply to DB (dry-run by default, `apply:true` to execute) |
| `plx_drop` | Drop module schemas from DB (dry-run by default) |
| `plx_test` | Run module pgTAP tests (unit or integration suite) |

**Workflow:** Edit `.plx` -> `plx_apply module:crm apply:true` -> `plx_test module:crm` -> commit.

### 2. Runtime (`runtime/`)

Hand-written SQL organized by responsibility. Replaces the legacy `pgv` schema. Managed via `runtime_*` MCP tools.

```
runtime/
├── sdui/       # SDUI JSON primitives, api, view_schema, navigation
├── i18n/       # Translation storage, lookup, bundle export
├── util/       # Generic helpers (slugify, money, esc, throw_*)
├── query/      # RSQL parsing, query filtering
├── catalog/    # Schema discovery and introspection (quarantine)
└── dev/        # Dev-only: contract checks, diagnostics
```

Each target follows the same layout:
```
runtime/{target}/
├── build/      # DDL (CREATE SCHEMA, tables, grants)
├── src/        # Functions (hand-written SQL)
└── tests/      # pgTAP tests ({target}_ut schema)
```

**MCP tools:**

| Tool | Purpose |
|------|---------|
| `runtime_status` | Inspect target: files, build freshness, incremental apply state |
| `runtime_apply` | Apply target to DB incrementally (dry-run by default, `apply:true` to execute) |
| `runtime_test` | Run pgTAP tests for a target |

**Workflow:** Edit SQL in `runtime/{target}/` -> `runtime_apply target:sdui apply:true` -> `runtime_test target:sdui`.

## PLX Language

PLX compiles `.plx` files to PL/pgSQL. Zero runtime dependency — pure static transpilation. Full syntax reference: `docs/PLX-SYNTAX.md`.

### Compiler Pipeline (`src/core/plx/`)

| File | Role |
|------|------|
| `ast.ts` | AST node types (PlxModule, PlxFunction, PlxEntity, PlxTrait, Statement, Expression) |
| `ast-builders.ts` | AST node factory functions |
| `lexer.ts` | Indentation-aware tokenizer, SQL passthrough, operators |
| `parser.ts` | Recursive descent parser (fn, if, for, match, case, return query/execute) |
| `parse-context.ts` | Core parsing engine: token navigation, expressions, statements |
| `parser-helpers.ts` | Shared parser helper functions |
| `entity-parser.ts` | Entity-specific parsing (fields, states, view, actions, events) |
| `codegen.ts` | AST -> PL/pgSQL (DECLARE inference, SELECT INTO, JSON literals, CASE) |
| `compiler.ts` | Pipeline orchestrator (lex -> parse -> codegen), optional PG WASM validation |
| `entity-expander.ts` | Expand entity blocks into PlxFunction[] + DDL |
| `entity-ddl.ts` | Entity DDL generation (CREATE TABLE, triggers, indexes) |
| `entity-sql.ts` | Entity SQL generation (CRUD functions) |
| `test-expander.ts` | Expand PlxTest[] into pgTAP PlxFunction[] |
| `event-expander.ts` | Expand event declarations into outbox + trigger + handler |
| `i18n-expander.ts` | Process `.i18n` sidecar files into i18n_seed() |
| `module-loader.ts` | Multi-file module loading (include/depends resolution) |
| `composition.ts` | Module composition and merging |
| `contract.ts` | Public contract validation (export declarations) |
| `semantic.ts` | Type inference, import checks, SQL safety warnings, diagnostics |
| `walker.ts` | AST walker/visitor |
| `util.ts` | Shared utilities (sqlEscape) |
| `cli.ts` | CLI: `plx build` / `plx check` |

### Key Syntax

```plx
module crm
depends catalog
import sdui.ui_field as field
include "./client.plx"
include "./client.spec.plx"
export crm.client_view

entity crm.client uses auditable:
  table: crm.client
  uri: 'crm://client'
  fields:
    name text required
    email text? unique
    status text default('active')
  states active -> archived:
    archive(active -> archived)
  view:
    compact: [name, email, status]
    form:
      'crm.section_identity':
        {key: name, type: text, label: crm.field_name, required: true}

fn crm.brand() -> text [stable]:
  return t('crm.brand')

test "client crud":
  c := crm.client_create({name: 'Test'})
  assert c->>'name' = 'Test'
```

## SDUI — Server-Driven UI

Two separate concerns, joined only on the client:

**Schema (static):** Each entity declares `{entity}_view() RETURNS jsonb` — called once at startup, cached. Templates: compact, standard, expanded, form. Actions catalog: edit, archive, delete, etc.

**Data (dynamic):** `sdui.api(verb, uri, data)` dispatches CRUD. Returns `{data, uri, actions}` only — no schema.

| Verb | URI | Dispatches to |
|------|-----|--------------|
| `get` | `crm://client` | `client_list()` |
| `get` | `crm://client/1` | `client_read(1)` |
| `set` | `crm://client` | `client_create(data)` |
| `patch` | `crm://client/1` | `client_update(data)` |
| `delete` | `crm://client/1` | `client_delete(1)` |
| `post` | `crm://client/1/archive` | `client_archive(1)` |

HATEOAS: `_read()` returns available actions based on entity state. The client joins schema + data at render time.

## Architecture (TypeScript)

### Plugin System

The MCP server uses an explicit plugin architecture. Plugins register services and tools into an Awilix DI container.

- `src/core/plugin.ts` — Plugin contract (id, name, requires, capabilities, register, hooks)
- `src/core/plugin-registry.ts` — Build container from plugins, collect hook rules
- `src/core/container.ts` — Core types (ToolHandler, WithClient, ToolExtra), mountTools()
- `src/plugins/index.ts` — ALL_PLUGINS in dependency-safe order

### Entry Point

`src/index.ts` — Express server with `/mcp` POST endpoint. Stateless per-request: each request gets fresh McpServer + transport. Loads all plugins, resolves manifest from config.

### Source Layout

```
src/
├── index.ts                 # Entry point
├── plugins/                 # Plugin declarations (register tools + services)
├── commands/                # Tool implementations
│   ├── plpgsql/             # pg_* tools (legacy, still functional)
│   ├── pgm/                 # plx_* tools (module management)
│   └── runtime/             # runtime_* tools
├── integrations/            # External service tools
│   ├── illustrator/         # ill_* tools
│   ├── docman/              # doc_* tools
│   ├── docstore/            # fs_* tools
│   └── google/              # gmail_* tools
├── core/
│   ├── plx/                 # PLX compiler
│   ├── pgm/                 # Module manager (registry, deployer, workflow)
│   ├── runtime/             # Runtime workflow engine
│   ├── resources/           # DB resource formatters (catalog, schema, function, table, type, trigger)
│   ├── instrument/          # Code coverage engine
│   ├── tooling/primitives/  # Shared tooling primitives (applied-artifacts, transaction, read, postgrest)
│   ├── plugin.ts            # Plugin contract
│   ├── plugin-registry.ts   # Plugin container builder
│   ├── container.ts         # Core DI types + mountTools
│   ├── connection.ts        # DbClient type
│   ├── helpers.ts           # text(), wrap(), formatErrorTriplet()
│   ├── pool.ts              # Pool creation + error handling
│   ├── sql.ts               # SQL utilities (quoteIdent, etc.)
│   └── uri.ts               # URI parsing
├── server/
│   ├── config.ts            # App config + plugin manifest resolution
│   ├── dev.ts               # Dev-mode endpoints
│   ├── hooks.ts             # Hook enforcement endpoint (/hooks/:module)
│   └── terminal.ts          # Terminal/xterm WebSocket support
└── channel/                 # Workbench messaging channel
```

## Modules

Modules are being migrated to PLX. Current state:

| Module | Schemas | PLX | Purpose |
|--------|---------|-----|---------|
| crm | crm, crm_ut, crm_qa | **yes** | Clients, contacts, interactions |
| plxdemo | plxdemo, plxdemo_qa | **yes** | PLX demo/dogfood |
| cad | cad, _cad, cad_qa | pending | CAD 3D wood structures (PostGIS/SFCGAL) |
| quote | quote, quote_qa | pending | Quotes & invoices |
| catalog | catalog, catalog_ut, catalog_qa | pending | Shared product catalog |
| stock | stock, stock_ut, stock_qa | pending | Stock management |
| purchase | purchase, purchase_ut, purchase_qa | pending | Purchase orders |
| project | project, project_ut, project_qa | pending | Project tracking |
| planning | planning, planning_ut, planning_qa | pending | Scheduling |
| ledger | ledger, ledger_ut, ledger_qa | pending | Accounting |
| expense | expense, expense_ut, expense_qa | pending | Expense reports |
| hr | hr, hr_ut, hr_qa | pending | HR: employees, absences |
| asset | asset, asset_ut, asset_qa | pending | Asset management |
| docs | docs, docs_ut, docs_qa | pending | Document management |
| workbench | workbench | no | Platform infra (tenants, messaging, sessions) |
| qa | qa, qa_qa | pending | QA tooling |

## Environment Variables

Only infra bootstrap uses env vars:

- `PLPGSQL_CONNECTION` / `DATABASE_URL` — PostgreSQL connection string
- `MCP_PORT` — HTTP port (default: 3100)
- `LOG_LEVEL` — Pino log level (default: info)
- `WORKBENCH_MODE` — `dev` = mount all tools without toolbox filtering
- `WORKBENCH_CONFIG` — Path to app config JSON (e.g. `apps/001-uxlab/workbench.json`)

All application config lives in `workbench.config(app, key, value)` — read from DB at request time. Zero env vars for app config.

## Language Rules (STRICT)

- **Code** — ALL code in English: function names, parameters, variables, columns, JSON keys, comments. No exceptions.
- **Labels** — ALL user-facing text via `i18n.t('module.key')`. Never hardcode strings. Labels live in `.i18n` sidecar files.
- **CLAUDE.md** — English.
- **Commits** — English.

## Key Conventions

- **ESM project** — `"type": "module"` in package.json, `Node16` module resolution
- **Strict TypeScript** — `noUncheckedIndexedAccess: true`. Array indexing returns `T | undefined`. Use `!` when value is guaranteed.
- **Awilix DI** — Tool factories declare deps as named params, resolved by container. Registration names ending in `Tool` are auto-discovered.
- **pgTAP test naming** — Unit: `{schema}_ut.test_{name}()`, Integration: `{schema}_it.test_{name}()`
- **Schema = bounded context** — Each schema is a DDD bounded context with its own tables, functions, tests.
- **Incremental apply** — Both `plx_apply` and `runtime_apply` use content-hash tracking. Only changed artifacts are applied. State stored in `workbench.applied_*` tables.
- **Dry-run by default** — Both apply tools show a plan without executing. Pass `apply:true` to execute.
- **PostgREST grants** — Each DDL must include `GRANT USAGE ON SCHEMA`, `GRANT EXECUTE ON ALL FUNCTIONS`, `GRANT SELECT ON ALL TABLES` to `anon`.

## Documentation Map

| File | Content |
|------|---------|
| `docs/PLX-SYNTAX.md` | PLX language full syntax reference |
| `docs/LMNAV.md` | MCP output format specification |
| `docs/PGM.md` | Module manager: module.json spec, pgm CLI |
| `docs/ILLUSTRATOR.md` | Illustrator integration architecture |
| `docs/BUSINESS.md` | Business plan: SaaS artisan ERP + toolbox model |
| `docs/P3-MVP.md` | P3 MVP scope |
| `docs/REALTIME.md` | Realtime architecture |
| `docs/TOOLING-CATALOG.md` | Tooling catalog |
| `runtime/ARCHITECTURE.md` | Runtime schema split (pgv retirement) |
| `src/core/docs/sdui.md` | SDUI contract: _view(), api, entity types |
| `src/core/docs/testing.md` | pgTAP testing guide |
| `src/core/docs/coverage.md` | Coverage tool guide |
