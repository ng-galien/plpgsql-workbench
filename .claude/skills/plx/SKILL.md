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
---

# PLX — Language & Workflow Guide

## What PLX is

PLX is a **transpiler**. You write `.plx` source files; the compiler generates PL/pgSQL functions and DDL artifacts. You never edit generated SQL directly — `build/*.func.sql` and `build/*.ddl.sql` are outputs, not sources.

```
.plx source  →  PLX compiler  →  PL/pgSQL + DDL
                                        ↓
                               PostgreSQL (via plx_apply)
```

The `.plx` file is always the source of truth. To change behavior: edit the `.plx`, then `plx_apply`.

---

## Module structure

```plx
module mymodule
depends pgv                    -- required for pgv helpers / i18n

include "./entity.plx"         -- split across files with include
include "./entity.spec.plx"    -- tests in separate spec files

export mymodule.entity_name    -- public contract

fn mymodule.health() -> jsonb [stable]:
  return {name: "mymodule", status: "ok"}
```

A module entry point (`mymodule.plx`) declares dependencies, includes sub-files, and exports public contracts. Keep entities and their tests in separate files for readability.

---

## Entities — the core abstraction

An `entity` generates the full CRUD stack automatically:

| Generated function | Role |
|-------------------|------|
| `entity_view()` | Static UI schema — called once, cached by client |
| `entity_list(filter?)` | Browse list — data only |
| `entity_read(id)` | Single record + available HATEOAS actions |
| `entity_create(data)` | Insert |
| `entity_update(id, data)` | Partial update |
| `entity_delete(id)` | Delete |

### Row storage (flat columns)

Use when all fields are relational, indexed, or have foreign keys.

```plx
entity mymodule.client uses auditable:
  table: mymodule.client
  uri: 'mymodule://client'
  icon: 'C'
  label: 'mymodule.entity_client'
  list_order: 'name'

  fields:
    name text required
    email text? unique
    phone text?
    status text default('active')
```

### Hybrid storage (columns + payload)

Use when some fields need relational constraints (FK, indexes) and others are flexible document data.

```plx
entity mymodule.task uses auditable:
  table: mymodule.task
  uri: 'mymodule://task'
  label: 'mymodule.entity_task'
  list_order: 'created_at desc'

  columns:
    project_id int ref(mymodule.project)   -- FK, indexed
    assignee_id int? ref(hr.employee)
    status text default('todo')

  payload:
    title text required                    -- stored in jsonb column
    description text?
    priority text? default('normal')
```

**Rule**: if you need to JOIN or filter on a field → `columns:`. If it's document data not queried directly → `payload:`.

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

## Validation

`validate:` rules run on create and update, evaluated against `p_input` (the jsonb input).
`validate delete:` is also supported for delete-time checks.

```plx
  validate:
    budget_positive: coalesce((p_input->>'budget')::numeric, 0) >= 0
    priority_valid: """
      coalesce(p_input->>'priority', 'normal') in ('low', 'normal', 'high')
    """
```

- Single-line: inline expression
- Multi-line: `"""..."""` triple-quoted SQL block
- If any rule returns false → exception raised, transaction rolled back

```plx
  validate delete:
    not_archived: current->>'status' != 'archived'
```

---

## State machines

```plx
  states draft -> active -> completed -> archived:
    column: status                          -- which column holds the state

    activate(draft -> active):
      guard: coalesce((v_row->>'budget')::numeric, 0) > 0 and v_row->>'owner' is not null

    complete(active -> completed)           -- no guard = always allowed

    archive(completed -> archived)

  update_states: [draft, active]            -- only these states allow update
```

Each transition generates a function: `entity_activate(id)`, `entity_complete(id)`, etc.

`guard:` is a SQL expression evaluated against `v_row` (the current row as jsonb). If it returns false → exception.

`update_states:` restricts which states allow `entity_update()`.

---

## Events (cross-module reactions)

Events decouple producers from consumers. The producer declares the event; consumers subscribe without the producer knowing about them.

### Producer side

```plx
entity mymodule.project:
  ...
  event activated(project_id int)           -- declare the event contract

  on update(new, old):                      -- internal lifecycle hook
    if new.status = 'active' and old.status = 'draft':
      emit activated(new.id)                -- fire the event
```

### Consumer side (in a different module)

```plx
module stock
depends mymodule

on mymodule.project.activated(project_id):
  stock.create_initial_inventory(project_id)
```

Rules:
- `event` declares a typed contract on the entity
- `on insert(new)`, `on update(new, old)`, `on delete(old)` are internal hooks only
- `emit` is only valid inside those hooks
- `on schema.entity.event(...)` is a module-level subscription
- The compiler lowers this to a PostgreSQL transactional outbox (trigger → outbox row → dispatcher → handler)

---

## Traits

Traits inject shared fields and behaviors into multiple entities.

```plx
trait auditable:
  fields:
    created_at timestamptz default(now())
    updated_at timestamptz default(now())

trait soft_delete:
  fields:
    deleted_at timestamptz?
  default_scope: 'deleted_at is null'    -- auto-added to list/read queries
```

Usage: `entity mymodule.client uses auditable, soft_delete:`

---

## Functions (`fn`)

When entity CRUD isn't enough, write custom functions.

```plx
-- Simple
fn mymodule.brand() -> text [stable]:
  return t('mymodule.brand')

-- With SQL
fn mymodule.count_active(p_client_id int) -> int [stable]:
  n := select count(*) from mymodule.project
       where client_id = p_client_id and status = 'active'
  return n

-- Multi-line SQL block
fn mymodule.stats(p_id int) -> jsonb [stable]:
  result := """
    select jsonb_build_object(
      'total', count(*),
      'active', count(*) filter (where status = 'active')
    )
    from mymodule.project
    where client_id = p_id
  """
  return result

-- DML statement (bare triple-quoted block)
fn mymodule.archive_old() -> void [definer]:
  """
    update mymodule.project
    set status = 'archived'
    where deadline < now() - interval '1 year'
      and status != 'archived'
  """
  return
```

### Function attributes

| Attribute | Meaning |
|-----------|---------|
| `[stable]` | STABLE — no side effects, same inputs = same output |
| `[definer]` | SECURITY DEFINER |
| `[definer, stable]` | Both |

### Loops and control flow

```plx
fn mymodule.recalculate(p_client_id int) -> int:
  count := 0
  for proj in select id, budget from mymodule.project
               where client_id = p_client_id:
    """
      update mymodule.project
      set cached_budget = proj.budget * 1.1
      where id = proj.id
    """
    count := count + 1
  return count
```

---

## i18n sidecar

Place a `.i18n` file next to your entry `.plx` file (same name). It auto-generates `mymodule.i18n_seed()`.

```ini
[fr]
mymodule.brand = Mon Module
mymodule.entity_project = Projet
mymodule.entity_task = Tâche
mymodule.field_name = Nom
mymodule.action_activate = Activer
mymodule.confirm_delete = Supprimer cet élément ?
mymodule.stat_task_count = Tâches

[en]
mymodule.brand = My Module
mymodule.entity_project = Project
```

Key conventions: `module.entity_xxx`, `module.field_xxx`, `module.action_xxx`, `module.confirm_xxx`, `module.stat_xxx`, `module.section_xxx`.

All user-facing labels in `view:` and `actions:` reference i18n keys — never hardcode strings.

---

## SDUI contract (what entities generate)

The SDUI pattern strictly separates *how to render* (schema, static) from *what to render* (data, dynamic).

### `_view()` — static schema, cached once

```json
{
  "uri": "mymodule://client",
  "label": "mymodule.entity_client",
  "template": {
    "compact":   { "fields": ["name", "status"] },
    "standard":  { "fields": ["name", "email", "phone", "status"] },
    "expanded":  { "fields": ["name", "email", "phone", "status", "created_at"] },
    "form":      { "sections": [{ "label": "mymodule.section_identity", "fields": [...] }] }
  },
  "actions": {
    "edit":   { "label": "mymodule.action_edit", "variant": "muted" },
    "delete": { "label": "mymodule.action_delete", "variant": "danger", "confirm": "mymodule.confirm_delete" }
  }
}
```

### `_read(id)` — data + HATEOAS actions

```json
{
  "id": 42,
  "name": "Acme Corp",
  "status": "active",
  "actions": ["edit", "delete"]     ← runtime, based on current state
}
```

The `actions` array in `_read()` is the *runtime* list of what's currently available (depends on state). The `actions` dict in `_view()` is the *static catalog* of all possible actions with their labels/variants.

**Critical rule**: `_view()` never contains data. `_list()` and `_read()` never contain schema. The client joins them.

---

## The `view:` block

```plx
  view:
    compact: [name, status]
    standard:
      fields: [name, email, status]
      stats:
        {key: project_count, label: mymodule.stat_projects}
      related:
        {entity: project, label: mymodule.rel_projects, filter: client_id}
    expanded: [name, email, phone, status, created_at, updated_at]
    form:
      'mymodule.section_identity':
        {key: name, type: text, label: mymodule.field_name, required: true}
        {key: email, type: text, label: mymodule.field_email}
        {key: status, type: select, label: mymodule.field_status}

  actions:
    edit:   {label: mymodule.action_edit, icon: 'E', variant: muted}
    delete: {label: mymodule.action_delete, icon: 'X', variant: danger, confirm: mymodule.confirm_delete}
```

Form field types: `text`, `textarea`, `number`, `date`, `select`, `checkbox`.

---

## Tests

Tests compile to pgTAP functions. Write them in `*.spec.plx` files included from the module entry point.

```plx
test "entity crud lifecycle":
  c := mymodule.client_create({name: 'Acme', email: 'acme@test.com'})
  assert c->>'name' = 'Acme'
  assert c->>'status' = 'active'

  r := mymodule.client_read(c->>'id')
  assert r->>'actions' != 'null'

  u := mymodule.client_update(c->>'id', {email: 'new@test.com'})
  assert u->>'email' = 'new@test.com'

  d := mymodule.client_delete(c->>'id')
  assert d->>'name' = 'Acme'

test "validation rejects bad data":
  blocked := false
  try:
    mymodule.client_create({name: ''})     -- required field empty
  catch:
    blocked := true
  assert blocked = true

test "state transition with guard":
  p := mymodule.project_create({name: 'X', code: 'X'})
  assert p->>'status' = 'draft'

  -- guard requires budget > 0 and owner set
  blocked := false
  try:
    mymodule.project_activate(p->>'id')
  catch:
    blocked := true
  assert blocked = true

  mymodule.project_update(p->>'id', {budget: 1000, owner: 'Alice'})
  a := mymodule.project_activate(p->>'id')
  assert a->>'status' = 'active'

test "inline SQL assertion":
  mymodule.client_create({name: 'Listed'})
  assert """
    select count(*) >= 1
    from mymodule.client
    where name = 'Listed'
  """
```

Each `test` block is executed in an isolated test context and should not leave persistent data behind.

---

## MCP dev workflow

These are the MCP tools for the PLX development loop:

### Apply a module

```
plx_apply module:mymodule apply:true
```

Compiles the `.plx` source → generates DDL + functions → applies to DB incrementally. Only changed artifacts are re-applied. After apply, `i18n_seed()` runs automatically if present.

### Run tests

```
plx_test module:mymodule suite:unit
```

Compiles and runs all `test` blocks in the module. Returns pass/fail with diagnostics.

### Check status

```
plx_status module:mymodule
```

Shows what's applied, what's pending, which artifacts are out of sync with the DB.

### Drop a module

```
plx_drop module:mymodule apply:true
```

Removes all generated functions and DDL from the DB. Use before a full rebuild or to clean up.

### Typical iteration loop

1. Edit `.plx` source
2. `plx_apply module:mymodule apply:true` — apply to DB
3. `plx_test module:mymodule suite:unit` — run tests
4. If tests pass → iterate; if not → fix `.plx` and repeat

Never use `pg_func_set` or `pg_schema` to edit what PLX manages — always go through `plx_apply`.

---

## Quick reference

| Concept | Syntax |
|---------|--------|
| Module | `module name` / `depends a, b` / `include "./file.plx"` |
| Entity | `entity schema.name uses trait:` |
| Row fields | `fields:` → `name type [modifiers]` |
| Hybrid | `columns:` (relational) + `payload:` (jsonb) |
| Validation | `validate:` / `validate delete:` → `rule_name: sql_expression` |
| States | `states a -> b -> c:` + `transition(from -> to):` |
| Guard | `guard: sql_expression` (evaluated against `v_row`) |
| Update lock | `update_states: [a, b]` |
| Event declare | `event name(param type)` |
| Event emit | `on update(new, old):` + `emit name(value)` |
| Event subscribe | `on schema.entity.event(params):` |
| Trait | `trait name:` + `fields:` |
| Function | `[export] fn schema.name(params) -> type [attrs]:` |
| Assign | `x := expr` or `x := select ...` |
| Multi-line SQL | `x := """` ... `"""` or bare `"""` ... `"""` for DML |
| Loop | `for row in select ...:` |
| If | `if cond:` / `elsif cond:` / `else:` |
| Try/catch | `try:` / `catch:` |
| Raise | `raise 'message'` |
| Test | `test "name":` + `assert expr` |
| i18n sidecar | `module.i18n` → `[lang]` + `module.key = Label` |

---

## Current PLX rules

- CRUD input is unified on `p_input` for generated `create` and `update` functions.
- `validate:` runs against `p_input`; `validate delete:` is the targeted delete hook.
- `plx_apply` deploys generated SQL and auto-runs `schema.i18n_seed()` when present.
- Missing i18n keys referenced by entities/views/actions are reported as build warnings.
- Cross-module usage is governed by `export` + `depends`; do not reach into non-exported symbols.
