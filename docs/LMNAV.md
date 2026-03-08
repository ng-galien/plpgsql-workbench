# LMNAV — LM-Navigable Output Format

LMNAV is a compact text format designed for LLM tool outputs. Every result contains **navigable URIs** that point to the next possible action, turning tool output into a browsable graph.

## Why not JSON?

JSON wastes 40-70% of tokens on syntax (`{}`, `""`, repeated keys). Benchmark data ([ImprovingAgents, 2025](https://www.improvingagents.com/blog/best-input-data-format-for-llms/)) shows Markdown-KV achieves 60.7% comprehension accuracy vs 52.3% for JSON and 41.1% for pipe-delimited tables.

LMNAV builds on Markdown-KV with one addition: **every output contains URIs to drill deeper**.

## Principles

1. **Key: value pairs** — no braces, no quotes, indentation for hierarchy
2. **Navigable URIs** — every entity links to its detail view
3. **Line numbers in code** — `N|` prefix for body lines
4. **Explicit empty sections** — `calls: none` not omitted. Absence could mean "not computed" vs "empty"
5. **Truncation signals** — `(20+)` when results are capped
6. **`->` not `→`** — ASCII arrow is 1 token, Unicode arrow is 3
7. **Completeness signal** — `completeness: full|partial` header on every response
8. **Next actions** — `next:` section with suggested follow-up tool calls
9. **Error triplet** — errors use `problem/where/fix_hint` structure

## URI Scheme

```
plpgsql://                          catalog (all schemas)
plpgsql://{schema}                  schema overview
plpgsql://{schema}/function/{name}  function detail
plpgsql://{schema}/table/{name}     table detail
plpgsql://{schema}/trigger/{name}   trigger detail
plpgsql://{schema}/type/{name}      type detail
plpgsql://{schema}/function/*       batch (all functions)
```

## Output envelope

Every tool response is wrapped with metadata headers:

```
uri: plpgsql://public/function/create_order
completeness: full

<body>

next:
  - get plpgsql://public/table/orders
  - get plpgsql://public/function/validate_customer
```

- **uri** — the resolved resource URI
- **completeness** — `full` (all data returned) or `partial` (results truncated, narrow your query)
- **next** — suggested follow-up `get` or `search` calls to continue exploration

## Format by level

### Catalog — `get plpgsql://`

One line per schema. Counts skip zeros. URI to drill into each schema.

```
uri: plpgsql://
completeness: full

public   2 functions, 3 tables   plpgsql://public
banking  5 functions, 1 trigger  plpgsql://banking

next:
  - get plpgsql://public
  - get plpgsql://banking
```

### Schema — `get plpgsql://public`

Sections by object type. Each entry has a URI. Empty sections explicit.

```
uri: plpgsql://public
completeness: full

tables:
  orders (id integer PK, amount numeric, customer_id integer FK->public.customers.id)  plpgsql://public/table/orders
  customers (id integer PK, name text)  plpgsql://public/table/customers
functions:
  create_order(customer_id integer, amount numeric) -> integer  plpgsql://public/function/create_order
  hello(name text) -> text  plpgsql://public/function/hello
triggers: none

next:
  - get plpgsql://public/function/*
  - get plpgsql://public/table/*
```

### Function — `get plpgsql://public/function/create_order`

Signature, all metadata sections (explicit `none`), numbered body.

```
uri: plpgsql://public/function/create_order
completeness: full

public.create_order(customer_id integer, amount numeric) -> integer
  vars: new_id integer
  calls: validate_customer
  callers: public.process_batch
  tables: orders(W) plpgsql://public/table/orders, customers(R) plpgsql://public/table/customers
  body:
    1| DECLARE
    2|   new_id integer;
    3| BEGIN
    4|   PERFORM validate_customer(customer_id);
    5|   INSERT INTO orders (customer_id, amount) VALUES (customer_id, amount) RETURNING id INTO new_id;
    6|   RETURN new_id;
    7| END;

next:
  - get plpgsql://public/table/orders
  - get plpgsql://public/function/validate_customer
```

### Table — `get plpgsql://public/table/orders`

Columns with constraints, indexes, referencing functions. Empty sections explicit.

```
uri: plpgsql://public/table/orders
completeness: full

public.orders
  id           integer      PK
  amount       numeric      NOT NULL
  customer_id  integer      FK -> public.customers.id
  created_at   timestamptz  DEFAULT now()
  indexes: orders_amount_idx
  used_by: create_order(W), get_orders(R)

next:
  - get plpgsql://public/function/create_order
  - get plpgsql://public/function/get_orders
```

### Search — `search name:%order% content:INSERT`

Grouped by object type. Count with `+` when truncated. Completeness header.

```
completeness: full

functions (3):
  create_order(customer_id integer, amount numeric) -> integer  plpgsql://public/function/create_order
      5| INSERT INTO orders (customer_id, amount) VALUES (customer_id, amount) RETURNING id INTO new_id;
  bulk_import(data jsonb) -> integer  plpgsql://public/function/bulk_import
      12| INSERT INTO orders SELECT * FROM jsonb_populate_recordset(null::orders, data);
  archive_orders(before_date date) -> integer  plpgsql://public/function/archive_orders
      8| INSERT INTO orders_archive SELECT * FROM orders WHERE created_at < before_date;

tables (2):
  orders          plpgsql://public/table/orders
  orders_archive  plpgsql://public/table/orders_archive
```

When truncated:

```
completeness: partial

functions (20+):
  ...

next:
  - narrow with schema: or kind: to see all results
```

### Query — `query SELECT ...`

Uniform format: `completeness` header, `columns:` header, `row N:` key-value blocks.

```
completeness: full
columns: schema, name, args

row 1:
  schema: public
  name: create_order
  args: customer_id integer, amount numeric
row 2:
  schema: public
  name: hello
  args: name text
(2 rows, 4ms)
```

DML (no rows):

```
OK (3 rows affected, 12ms)
```

### Edit — `edit plpgsql://public/function/hello`

Patches a function via old/new replacements. Runs the full deploy pipeline.

```
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

On patch error:

```
✗ edit 1 failed
problem: old string not found
where: public.hello
```

### Set — `set plpgsql://public/function/hello`

Deploys full SQL. Same pipeline as `edit`: plpgsql_check + auto-run tests.

```
✓ plpgsql_check passed
---
public.hello(name text) -> text
  ...
---
✓ 2 passed, 0 failed, 2 total
  ...
```

On deploy error — **error triplet** format (`problem/where/fix_hint`):

```
✗ deploy failed
problem: syntax error at or near "SELEC"
where: line 4, col 4
```

On validation error (deploy rolled back):

```
✗ plpgsql_check:
  [error]
  problem: relation "nonexistent_table" does not exist
  where: line 3
  statement: SQL statement

deploy rolled back (fix errors and retry)
```

On validation warning (deploy succeeds):

```
⚠ plpgsql_check:
  [warning]
  problem: unused variable "tmp"
  where: line 2
  statement: DECLARE
---
public.hello(name text) -> text
  ...
```

### Test — `test target:plpgsql://public/function/hello`

Runs pgTAP tests. Convention: `<schema>_ut` for unit tests, `<schema>_it` for integration.

Passing:

```
✓ 2 passed, 0 failed, 2 total

  ✓ hello with name
  ✓ hello with empty string
```

Failing (with have/want diagnostics):

```
✗ 0 passed, 2 failed, 2 total

  ✗ hello with name
    have: Broken world
    want: Hello world
  ✗ hello with empty string
    have: Broken
    want: Hello
```

### Coverage — `coverage target:plpgsql://public/function/classify`

Instruments function, runs unit tests, restores original. Reports block + branch coverage.

```
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

Full coverage:

```
✓ public.hello: 100% coverage (1/1 points)
run: 743259e4

blocks: 1/1
  ✓ line 3: return
```

Results persisted in `workbench.cov_run` + `workbench.cov_point` tables.

### Explain — `explain SELECT ...`

Raw PostgreSQL EXPLAIN ANALYZE output, unmodified.

```
Result  (cost=0.00..0.26 rows=1 width=4) (actual time=0.505..0.506 rows=1 loops=1)
Planning Time: 0.054 ms
Execution Time: 0.931 ms
```

## Design rationale

| Decision | Why |
|----------|-----|
| `key: value` not JSON | 60.7% vs 52.3% LLM accuracy ([benchmark](https://www.improvingagents.com/blog/best-input-data-format-for-llms/)) |
| URIs in output | Agent can chain `get` calls without guessing paths |
| `N\|` line numbers | Cross-reference with plpgsql_check errors, set breakpoints |
| Explicit `none` sections | `calls: none` removes ambiguity — absence could mean "not computed" |
| `completeness: full\|partial` | Agent knows if data is complete or needs narrowing |
| `next:` suggestions | Reduces guesswork, agent knows what to call next |
| Error triplet `problem/where/fix_hint` | Structured errors are easier to act on than raw messages |
| `20+` truncation | Agent knows to narrow search instead of assuming complete |
| `->` not `→` | 1 token vs 3 tokens |
| No padding in KV | Padding wastes tokens, alignment is for humans |

## References

- [Which Table Format Do LLMs Understand Best?](https://www.improvingagents.com/blog/best-input-data-format-for-llms/) — Markdown-KV wins at 60.7%
- [TOON Format](https://toonformat.dev/) — Token-Oriented Object Notation, 30-60% savings vs JSON
- [Block's Playbook for Designing MCP Servers](https://engineering.block.xyz/blog/blocks-playbook-for-designing-mcp-servers) — Output guard rails, tool descriptions as prompts
