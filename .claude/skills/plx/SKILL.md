---
name: plx
description: >
  Expert guide for writing PLX — a transpiler language that compiles to PL/pgSQL.
  Use this skill whenever you're working on a PLX module: creating entities, writing
  functions, adding validation rules, state machines, events, i18n, or tests.
  Also use it when applying, testing, or checking the status of a PLX module via
  MCP tools (plx_apply, plx_test, plx_status). If someone asks how to define an
  entity, add a state transition, emit an event, write a PLX test, or work with
  the SDUI/HATEOAS contract — this skill is the right one. Trigger on any `.plx`
  file reference, any mention of "entity", "trait", "states", "emit", "plx_apply".
  Also trigger when migrating a legacy module to PLX, using strategies, hooks,
  or discussing the PLX manifest (PlxModuleManifest).
---

# PLX — Language & Workflow Guide

## Reference documentation

Before assuming a feature is missing from PLX, read these docs:

| File | Content |
|------|---------|
| `docs/PLX-SYNTAX.md` | Full syntax reference (layers 1-3) |
| `docs/plx/GUIDELINES.md` | When to stay declarative, when to use extension points, when to accept manual SQL |
| `docs/plx/PATTERNS.md` | Concrete recipes: expose:false, before_create, strategies, post_apply, rejet manuel |
| `docs/plx/MIGRATION.md` | Method for porting legacy modules to PLX |

## What PLX is

PLX is a **transpiler**. You write `.plx` source files; the compiler generates PL/pgSQL functions and DDL artifacts. You never edit generated SQL directly — `build/*.func.sql` and `build/*.ddl.sql` are outputs (gitignored), not sources.

```
.plx source  →  PLX compiler  →  PL/pgSQL + DDL
                                        ↓
                               PostgreSQL (via plx_apply)
```

The `.plx` file is always the source of truth. To change behavior: edit the `.plx`, then `plx_apply`.

---

## PLX-first manifest

PLX modules use `PlxModuleManifest` — a minimal manifest where schemas and build targets are derived from the module name by convention.

```json
{
  "name": "expense",
  "version": "0.1.0",
  "description": "Expense reports — travel, purchases, reimbursements",
  "plx": { "entry": "plx/expense.plx", "seed": "plx/seed.sql", "post_apply": "plx/post_apply.sql" },
  "grants": { "anon": ["expense"] }
}
```

No `schemas`, `sql`, `assets`, or `dependencies` fields needed for PLX modules. The compiler derives everything from the module name.

| Field | Purpose |
|-------|---------|
| `plx.entry` | PLX entry point |
| `plx.seed` | SQL file executed after apply (seed data) |
| `plx.post_apply` | SQL file for DDL the compiler can't generate (GENERATED columns, custom indexes) |

---

## Module structure

```plx
module mymodule

include "./entity.plx"
include "./entity.spec.plx"
include "./helpers.plx"

export mymodule.entity_name

fn mymodule.brand() -> text [stable]:
  return i18n.t('mymodule.brand')
```

```
modules/{name}/
├── module.json          # PlxModuleManifest
├── plx/                 # PLX source files
│   ├── {name}.plx       # Entry point
│   ├── {name}.i18n      # Translations sidecar
│   ├── {entity}.plx     # Entity definitions
│   ├── {entity}.spec.plx # Tests
│   ├── helpers.plx      # Custom functions
│   ├── seed.sql         # Dev seed data (DO $$ block)
│   └── post_apply.sql   # DDL complement (GENERATED columns, indexes)
├── build/               # Generated SQL (gitignored)
└── legacy/              # Legacy SQL files for migration reference
```

---

## Decision framework

Follow this hierarchy — don't jump to manual SQL if a declarative or extension point exists:

1. **Declarative first** — fields, payload, states, view, form, actions, validate, before create/update
2. **Extension points** — strategies (read.query, read.hateoas, list.query), hooks
3. **Manual SQL** — only when structurally out of scope of the generated code

If a contournement recurs across modules, it should become a compiler feature.

---

## Entities

An `entity` generates the full CRUD stack automatically (view, list, read, create, update, delete + state transitions).

### Public entity (default)

```plx
entity mymodule.client uses auditable:
  table: mymodule.client
  uri: 'mymodule://client'
  label: 'mymodule.entity_client'
  list_order: 'name'

  fields:
    name text required
    email text? unique
    status text default('active')
```

### Internal entity (no CRUD surface)

Use `expose: false` for child tables, technical tables, or data managed only through a parent entity.

```plx
entity expense.line:
  table: expense.line
  uri: 'expense://line'
  expose: false

  fields:
    report_id int required ref(expense.expense_report)
    description text required
    amount numeric required
```

What you keep: DDL, RLS, tenant isolation. What disappears: _view, _list, _read, _create, _update, _delete.

### Hybrid storage (fields + payload)

```plx
entity mymodule.task uses auditable:
  fields:
    project_id int ref(mymodule.project)
    status text default('todo')

  payload:
    title text required
    description text?
    priority text? default('normal')
```

`fields:` = relational (FK, indexes). `payload:` = flexible document (jsonb).

### Field modifiers

| Modifier | Meaning |
|----------|---------|
| `required` | NOT NULL, validated on create |
| `?` | nullable |
| `unique` | UNIQUE constraint |
| `default(val)` | DEFAULT value |
| `ref(schema.table)` | FK constraint |
| `create_only` | Cannot be updated after creation |

---

## Lifecycle hooks

Hooks inject logic into the generated CRUD without replacing it.

### before create

Runs after `jsonb_populate_record` — operates on `p_row` (the populated record).

```plx
  before create:
    if p_row.reference is null:
      p_row := jsonb_populate_record(p_row, jsonb_build_object('reference', expense._next_reference()))
```

Use for: auto-generated references, derived values, conditional pre-filling.

### before update

Same pattern, operates on `p_row` after merge with `p_input`.

### validate

```plx
  validate:
    date_order: """
      (p_input->>'end_date')::date >= (p_input->>'start_date')::date
    """
```

---

## Strategies — enriching read and list

Strategies replace specific parts of the generated flow without rewriting everything. The compiler handles auth, tenant, validation — strategies handle business projections and actions.

### read.query — enriched detail

Replace the default `SELECT to_jsonb(row)` with a custom read model.

```plx
  strategies:
    read.query: expense._report_read_query
```

```plx
fn expense._report_read_query(p_id text) -> jsonb [stable]:
  return """
    select to_jsonb(r) || jsonb_build_object(
      'lines', coalesce((select jsonb_agg(...) from expense.line ...), '[]'),
      'total_excl_tax', coalesce((select sum(amount) from expense.line ...), 0),
      'line_count', (select count(*) from expense.line ...)::int
    )
    from expense.expense_report r
    where r.id = p_id::int
  """
```

Use for: embedded children, computed aggregates, read-model projections.

### read.hateoas — conditional actions

Replace the default HATEOAS action builder. Receives the already-read result, returns just the actions array.

```plx
  strategies:
    read.hateoas: expense._report_hateoas
```

```plx
fn expense._report_hateoas(p_result jsonb) -> jsonb [stable]:
  return """
    select case p_result->>'status'
      when 'draft' then jsonb_build_array(
        jsonb_build_object('method', 'edit', 'uri', ...),
        jsonb_build_object('method', 'submit', 'uri', ...)
      )
      when 'submitted' then jsonb_build_array(...)
      else '[]'::jsonb
    end
  """
```

Use for: actions conditional on status + data (e.g., submit only if lines > 0).

### list.query — aggregated list

Replace the default `SELECT to_jsonb(row)` list with aggregated projections.

```plx
  strategies:
    list.query: expense._report_list_query
```

Use for: LATERAL JOIN aggregates, counts, sums, optimized compact projections.

---

## State machines

```plx
  states draft -> submitted -> validated -> reimbursed:
    submit(draft -> submitted)
    validate(submitted -> validated)
    reimburse(validated -> reimbursed)
```

Each transition generates a function. States are linear chains. For branches (e.g., rejected from submitted), use a manual function:

```plx
fn expense.expense_report_reject(p_id text) -> jsonb [definer]:
  """
    update expense.expense_report
    set status = 'rejected', updated_at = now()
    where id = p_id::int and status = 'submitted'
  """
  ...
```

---

## Events (cross-module)

```plx
entity mymodule.project:
  event activated(project_id int)

  on update(new, old):
    if new.status = 'active' and old.status = 'draft':
      emit activated(new.id)
```

```plx
module stock
depends mymodule

on mymodule.project.activated(project_id):
  stock.create_initial_inventory(project_id)
```

Compiler lowers to a transactional PostgreSQL outbox.

---

## Functions

```plx
fn mymodule.brand() -> text [stable]:
  return i18n.t('mymodule.brand')

fn mymodule.stats(p_id int) -> jsonb [stable]:
  result := """
    select jsonb_build_object('total', count(*))
    from mymodule.project where client_id = p_id
  """
  return result
```

For complex SQL with pagination, filtering, aggregation — use CTE in triple-quoted blocks. The SQL manages its own types, avoiding PLX type inference issues.

---

## SDUI form fields

Form fields are validated against the SDUI schema at compile time (`src/core/plx/sdui-schema.ts`).

```plx
  form:
    'mymodule.section_info':
      {key: name, type: text, label: mymodule.field_name, required: true}
      {key: status, type: select, label: mymodule.field_status, options: mymodule.status_options}
      {key: client_id, type: select, label: mymodule.field_client, search: true, options: {source: 'crm://client', display: name}}
```

- `type: select` — dropdown or autocomplete (`search: true`)
- `options` as string with `.` → function call resolved in `_view()` (static options inline)
- `options` as object `{source, display, filter?}` → RPC, renderer fetches at runtime
- No `combobox` type — use `select` with `search: true`

---

## Tests

```plx
test "entity crud":
  c := mymodule.client_create({name: 'Acme'})
  assert c->>'name' = 'Acme'

  r := mymodule.client_read(c->>'id')
  assert r->>'actions' != 'null'

  d := mymodule.client_delete(c->>'id')
  assert d->>'name' = 'Acme'
```

Named args are supported: `asset.classify(p_id := id, p_title := 'Test')`.
Casts work: `(c->>'id')::int`, `'{a,b}'::text[]`.

---

## post_apply — DDL complement

For what the compiler can't generate yet:

```sql
-- GENERATED column
ALTER TABLE asset.asset
  ADD COLUMN IF NOT EXISTS search_vec tsvector
  GENERATED ALWAYS AS (...) STORED;

-- Custom indexes
CREATE INDEX IF NOT EXISTS idx_asset_search ON asset.asset USING gin (search_vec);
```

---

## MCP workflow

```
plx_apply module:mymodule apply:true    # Build + incremental apply + seed + post_apply
plx_test module:mymodule                # Run pgTAP tests
plx_status module:mymodule              # Check build freshness + apply state
plx_drop module:mymodule apply:true     # Drop schemas + clear tracking
```

Typical loop: edit `.plx` → `plx_apply apply:true` → `plx_test` → iterate.

---

## Migration method (from docs/plx/MIGRATION.md)

1. Identify entities and their public boundary
2. Migrate structural model to PLX
3. Get CRUD and standard views from the compiler
4. Reconnect business invariants with hooks and validations
5. Reconnect read/list enrichments with `strategies.*`
6. Keep the rest in manual functions or `post_apply`

**Preserve**: business invariants, important transitions, useful read-models, aggregates.
**Simplify**: convenience handlers, non-critical projections, UI details that evolve with SDUI.
**Escalate to compiler**: if a workaround recurs across modules, is ugly, or harms readability.
