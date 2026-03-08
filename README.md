# plpgsql-workbench MCP Server

MCP server for navigating, editing, and testing PL/pgSQL code in PostgreSQL.

## Quick Start

```bash
# Install
cd mcp-server && npm install

# Start (dev with auto-reload)
PLPGSQL_CONNECTION=postgresql://postgres:postgres@localhost:5433/postgres npx tsx watch src/index.ts

# Claude Code config (.mcp.json at project root)
{
  "mcpServers": {
    "plpgsql-workbench": {
      "type": "http",
      "url": "http://localhost:3100/mcp"
    }
  }
}
```

## Tools

| Tool | Purpose |
|------|---------|
| `get` | Navigate the database by URI. Returns LMNAV format with navigable URIs |
| `search` | Find objects by name pattern or body content |
| `edit` | Patch a function body (old/new replacements) |
| `set` | Deploy full SQL (CREATE OR REPLACE, DDL) |
| `test` | Run pgTAP tests manually |
| `explain` | EXPLAIN ANALYZE on a query |
| `query` | Execute raw SQL |
| `coverage` | Code coverage analysis (block + branch) |

## URI Scheme

```
plpgsql://                          catalog (all schemas)
plpgsql://{schema}                  schema overview
plpgsql://{schema}/function/{name}  function detail
plpgsql://{schema}/table/{name}     table detail
plpgsql://{schema}/trigger/{name}   trigger detail
plpgsql://{schema}/type/{name}      type detail
plpgsql://{schema}/function/*       batch (all functions in schema)
```

## Deploy Pipeline

When you `set` or `edit` a function, the pipeline runs automatically:

```
deploy -> plpgsql_check -> auto-run unit tests -> result
```

1. **Deploy** — `CREATE OR REPLACE FUNCTION` in a transaction
2. **plpgsql_check** — static analysis (catches missing columns, type errors, etc.)
3. **Auto-run tests** — if `<schema>_ut.test_<name>()` exists, runs it via pgTAP
4. **Result** — validation status + deployed state + test report

If plpgsql_check finds errors, the deploy is **rolled back**. Warnings pass through.

### Example

```
> edit plpgsql://public/function/hello  old:"old code"  new:"new code"

✓ plpgsql_check passed
---
public.hello(name text) -> text
  vars: none
  calls: none
  callers: public_ut.test_hello
  tables: none
  body:
    1| BEGIN
    2|   RETURN 'Hello ' || name;
    3| END;
---
✓ 2 passed, 0 failed, 2 total

  ✓ hello with name
  ✓ hello with empty string
```

## Testing with pgTAP

### Convention

Tests are PL/pgSQL functions that return `SETOF TEXT` and use pgTAP assertions.

| Schema | Purpose | Triggered by |
|--------|---------|--------------|
| `<schema>_ut` | Unit tests | Auto-run on `set`/`edit` |
| `<schema>_it` | Integration tests | Manual via `test` tool |

A unit test for `public.hello()` lives in `public_ut.test_hello()`.
An integration test for the `public` schema lives in `public_it.test_<name>()`.

### Search path

Tests are executed with `SET search_path TO <test_schema>, <source_schema>, public`.
This means test functions can call source functions **without schema qualification**:

```sql
-- In public_ut.test_hello(): call hello() not public.hello()
RETURN NEXT is(hello('world'), 'Hello world', 'hello with name');
```

### Writing a unit test

```sql
CREATE OR REPLACE FUNCTION public_ut.test_hello()
RETURNS SETOF TEXT LANGUAGE plpgsql AS $$
BEGIN
  RETURN NEXT is(hello('world'), 'Hello world', 'hello with name');
  RETURN NEXT is(hello(''), 'Hello ', 'hello with empty string');
  RETURN NEXT is(hello(NULL), NULL, 'hello with null');
END;
$$;
```

Key rules:
- Function name: `test_<function_name>`
- Schema: `<source_schema>_ut` for unit, `<source_schema>_it` for integration
- Returns `SETOF TEXT`
- Use pgTAP assertions (`is`, `ok`, `throws_ok`, etc.)
- No plan needed — `runtests()` handles it

### pgTAP assertions cheat sheet

| Assertion | Usage |
|-----------|-------|
| `is(have, want, desc)` | Equality (NULL-safe) |
| `isnt(have, want, desc)` | Inequality |
| `ok(bool, desc)` | Boolean check |
| `lives_ok(sql, desc)` | SQL runs without error |
| `throws_ok(sql, errcode, msg, desc)` | SQL raises expected error |
| `results_eq(sql, sql, desc)` | Result sets match (ordered) |
| `bag_eq(sql, sql, desc)` | Result sets match (unordered) |
| `performs_ok(sql, ms, desc)` | SQL runs under time limit |

### Running tests

```
# Auto-run: edit or set a function — tests run automatically
> edit plpgsql://public/function/hello ...

# Manual: run a specific function's tests
> test target:plpgsql://public/function/hello

# Manual: run all unit tests in a schema
> test schema:public_ut

# Manual: run integration tests
> test schema:public_it

# Manual: filter by pattern
> test schema:public_ut pattern:^test_hello$
```

### Test output

Passing:
```
✓ 3 passed, 0 failed, 3 total

  ✓ basic addition
  ✓ zero plus zero
  ✓ negative plus positive
```

Failing (with diagnostics):
```
✗ 1 passed, 2 failed, 3 total

  ✓ basic addition
  ✗ hello with name
    have: Broken world
    want: Hello world
  ✗ hello with empty string
    have: Broken
    want: Hello
```

## Code Coverage

The `coverage` tool instruments a PL/pgSQL function, runs its unit tests, then restores the original.

```
> coverage target:plpgsql://public/function/classify

✗ public.classify: 67% coverage (4/6 points)
run: a637870b

blocks: 2/3
  ✓ line 4: return
  ✓ line 6: return
  ✗ line 8: return

branches: 2/3
  ✓ line 4: IF true @3
  ✓ line 6: ELSIF true @5
  ✗ line 8: ELSE @3
```

### How it works

1. **Parse** — `parsePlPgSQL()` (libpg-query WASM) extracts the AST
2. **Detect** — AST visitor identifies block and branch coverage points (IF/ELSIF/ELSE, CASE/WHEN, LOOP, EXCEPTION)
3. **Instrument** — injects `RAISE WARNING` markers before each coverage point (non-transactional, survives pgTAP rollback)
4. **Run** — executes `<schema>_ut.test_<name>` via pgTAP, captures notices via node-pg
5. **Restore** — deploys original DDL back (always, even on error)
6. **Persist** — stores results in `workbench.cov_run` + `workbench.cov_point` tables
7. **Report** — block and branch coverage with per-line hit/miss

Results are queryable in the database for comparison across runs:

```sql
SELECT p.line, p.kind, p.label, p.hit
FROM workbench.cov_point p
WHERE p.run_id = 'a637870b'
ORDER BY p.line;
```

## Prerequisites

The PostgreSQL server must have these extensions:

```sql
CREATE EXTENSION IF NOT EXISTS plpgsql_check;  -- static analysis
CREATE EXTENSION IF NOT EXISTS pgtap;           -- unit testing
```

Both are optional — the server degrades gracefully:
- Without plpgsql_check: `set`/`edit` deploys without static analysis
- Without pgTAP: `set`/`edit` deploys without auto-running tests

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PLPGSQL_CONNECTION` | `postgresql://postgres@localhost:5432/postgres` | PostgreSQL connection string |
| `DATABASE_URL` | (fallback for above) | Alternative connection string |
| `MCP_PORT` | `3100` | HTTP server port |

## Output Format

See [LMNAV specification](../docs/LMNAV.md) for the full format documentation.
