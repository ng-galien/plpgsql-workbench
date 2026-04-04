# PLX Syntax Reference

PLX compiles to PL/pgSQL. Three layers, one multi-line rule.

## Layer 1 — Directives

One line, no colon. Module-level declarations.

`export schema.name` at module root defines the public contract. Inline `export fn ...` is tolerated in the current compiler but is not part of the target syntax.

Comments use SQL-style line comments: `-- comment`.

```plx
module invoice
depends crm, catalog
import pgv.t as t
import jsonb_build_object as obj
include "./line.plx"
include "./line.spec.plx"
export invoice.total
export invoice.line
```

Module translations live in a sidecar `*.i18n` file placed next to the entry `.plx` file and loaded automatically when present.

```ini
[fr]
invoice.brand = Facturation
invoice.entity_invoice = Facture

[en]
invoice.brand = Billing
invoice.entity_invoice = Invoice
```

## Layer 2 — Declarative (entity, trait)

Structure, metadata, contracts. `validate:` may embed boolean SQL rules, but declarative blocks do not contain imperative control flow.

### Entity — row storage (classic)

```plx
entity crm.client uses auditable:
  table: crm.client
  uri: 'crm://client'
  icon: 'U'
  label: 'crm.entity_client'
  list_order: 'name'

  fields:
    name text required
    email text? unique
    phone text?
    siret text?
    status text default('active')

  validate:
    name_present: coalesce(p_input->>'name', '') != ''
    email_format: """
      coalesce(p_input->>'email', '') = ''
      or p_input->>'email' ~ '^[^@]+@[^@]+\.[^@]+$'
    """

  states active -> archived:
    archive(active -> archived)

  view:
    compact: [name, email, status]
    standard:
      fields: [name, email, phone, siret, status]
      stats:
        {key: total_invoices, label: crm.stat_invoices}
      related:
        {entity: invoice, label: crm.rel_invoices, filter: client_id}
    expanded: [name, email, phone, siret, status, created_at, updated_at]
    form:
      'crm.section_identity':
        {key: name, type: text, label: crm.field_name, required: true}
        {key: email, type: text, label: crm.field_email}
        {key: phone, type: text, label: crm.field_phone}
      'crm.section_company':
        {key: siret, type: text, label: crm.field_siret}

  actions:
    edit: {label: crm.action_edit, icon: 'E', variant: muted}
    archive: {label: crm.action_archive, variant: warning, confirm: crm.confirm_archive}
    delete: {label: crm.action_delete, icon: 'X', variant: danger, confirm: crm.confirm_delete}
```

### Entity — hybrid storage (columns + payload)

`columns:` hold relational, indexed, or foreign-key-backed data. `payload:` holds flexible document data stored in `jsonb`.

```plx
entity project.task:
  table: project.task
  uri: 'project://task'
  label: 'project.entity_task'
  list_order: 'created_at desc'

  columns:
    project_id int ref(project.project)
    assignee_id int? ref(hr.employee)
    due_date date?
    status text default('todo')

  payload:
    title text required
    description text?
    priority text? default('normal')
    tags text[]?

  validate:
    title_present: coalesce(p_input->>'title', '') != ''
    priority_valid: """
      coalesce(p_input->>'priority', 'normal') in ('low', 'normal', 'high', 'urgent')
    """
    project_exists: """
      exists(
        select 1 from project.project
        where id = (p_input->>'project_id')::int
      )
    """

  states todo -> in_progress -> done -> archived:
    start(todo -> in_progress)
    complete(in_progress -> done)
    reopen(done -> in_progress)
    archive(done -> archived)

  view:
    compact: [title, priority, status, due_date]
    standard: [title, description, priority, status, due_date, assignee_id]
    expanded: [title, description, priority, status, due_date, assignee_id, tags, created_at, updated_at]
    form:
      'project.section_task':
        {key: title, type: text, label: project.field_title, required: true}
        {key: description, type: textarea, label: project.field_description}
        {key: priority, type: select, label: project.field_priority}
        {key: due_date, type: date, label: project.field_due_date}
      'project.section_assignment':
        {key: project_id, type: select, label: project.field_project, required: true}
        {key: assignee_id, type: select, label: project.field_assignee}

  actions:
    edit: {label: project.action_edit, icon: 'E', variant: muted}
    delete: {label: project.action_delete, icon: 'X', variant: danger, confirm: project.confirm_delete}
```

### Trait

```plx
trait auditable:
  fields:
    created_at timestamptz default(now())
    updated_at timestamptz default(now())
```

```plx
trait soft_delete:
  fields:
    deleted_at timestamptz?
  default_scope: 'deleted_at is null'
```

### Events

PLX events model cross-module reactions without hard-coding consumers in the producer. The producer owns the internal lifecycle hooks. Consumers only see named business events with typed payloads.

```plx
module purchase
depends pgv

export entity purchase.receipt:
  fields:
    supplier_id int
    status text
    cancel_reason text?

  event received(receipt_id int, supplier_id int)
  event cancelled(receipt_id int, reason text?)

  on update(new, old):
    if old.status = 'draft' and new.status = 'received':
      emit received(new.id, new.supplier_id)

    if old.status != 'cancelled' and new.status = 'cancelled':
      emit cancelled(new.id, new.cancel_reason)
```

```plx
module stock
depends purchase

on purchase.receipt.received(receipt_id, supplier_id):
  stock.create_movement(receipt_id, supplier_id)
```

Rules:

- `event ...` declares a typed contract on an entity.
- `on insert(new)`, `on update(new, old)`, `on delete(old)` are internal entity hooks only.
- `emit ...` is only valid inside those entity lifecycle hooks.
- `on schema.entity.event(...)` declares a module-level subscription.
- Cross-module subscriptions require `depends producer_module`.
- The compiler lowers this to a transactional PostgreSQL outbox: entity trigger -> outbox row -> dispatcher trigger -> subscribed handlers.

## Layer 3 — Imperative (fn, test)

Python-like bodies with SQL passthrough.

### Functions — simple

```plx
fn invoice.brand() -> text [stable]:
  return t('invoice.brand')

fn invoice.nav_items() -> jsonb [stable]:
  return arr(
    obj('href', '/invoices', 'label', t('invoice.nav_list'), 'icon', 'F'),
    obj('href', '/invoices/new', 'label', t('invoice.nav_new'), 'icon', '+')
  )
```

### Functions — with SQL inline

```plx
fn invoice.count_pending(p_client_id int) -> int [stable]:
  n := select count(*) from invoice.invoice where client_id = p_client_id and status = 'draft'
  return n

fn catalog.product_exists(p_id int) -> boolean [stable]:
  found := select exists(select 1 from catalog.product where id = p_id)
  return found
```

### Functions — with SQL multi-line (`"""..."""`)

```plx
fn invoice.total(p_id int) -> numeric [stable]:
  result := """
    select coalesce(sum(
      l.quantity * p.price * (1 - coalesce(l.discount, 0))
    ), 0)
    from invoice.line l
    join catalog.product p on p.id = l.product_id
    where l.invoice_id = p_id
  """
  return result

fn invoice.detailed_report(p_id int) -> setof jsonb:
  return """
    select to_jsonb(r)
    from (
      select
        l.id,
        l.quantity,
        p.name as product_name,
        p.price,
        l.quantity * p.price * (1 - coalesce(l.discount, 0)) as line_total
      from invoice.line l
      join catalog.product p on p.id = l.product_id
      where l.invoice_id = p_id
      order by l.id
    ) r
  """
```

### Functions — control flow

```plx
fn invoice.archive(p_id int) -> jsonb:
  row := select * from invoice.invoice where id = p_id
  if row is null:
    raise 'invoice.err_not_found'
  if row.status = 'draft':
    raise 'invoice.err_cannot_archive_draft'
  """
    update invoice.invoice
    set status = 'archived', updated_at = now()
    where id = p_id
  """
  return {id: p_id, status: 'archived'}

fn invoice.apply_discount(p_id int, p_rate numeric) -> jsonb:
  total := invoice.total(p_id)
  if total = 0:
    return {id: p_id, discount: 0}
  new_total := total * (1 - p_rate)
  return {id: p_id, original: total, discounted: new_total, rate: p_rate}
```

### Functions — loops

```plx
fn invoice.recalculate_all(p_client_id int) -> int:
  count := 0
  for inv in select id from invoice.invoice where client_id = p_client_id:
    old := invoice.total(inv.id)
    """
      update invoice.invoice
      set cached_total = invoice.total(id)
      where id = inv.id
    """
    count := count + 1
  return count
```

### Functions — export vs internal

```plx
-- Public API (visible to other modules)
export fn invoice.total(p_id int) -> numeric [stable]:
  return invoice._sum_lines(p_id)

-- Internal helper (module-private, underscore convention)
fn invoice._sum_lines(p_id int) -> numeric [stable]:
  result := """
    select coalesce(sum(l.quantity * p.price), 0)
    from invoice.line l
    join catalog.product p on p.id = l.product_id
    where l.invoice_id = p_id
  """
  return result
```

### Tests

```plx
test "invoice total":
  inv := invoice.invoice_create({client_id: 1, status: 'draft'})
  invoice.line_create({invoice_id: (inv->>'id')::int, product_id: 1, quantity: 3})
  invoice.line_create({invoice_id: (inv->>'id')::int, product_id: 2, quantity: 1})
  t := invoice.total((inv->>'id')::int)
  assert t > 0

test "archive requires non-draft":
  inv := invoice.invoice_create({client_id: 1, status: 'draft'})
  -- This should fail:
  -- invoice.archive((inv->>'id')::int)
  assert inv->>'status' = 'draft'

test "line count after create":
  inv := invoice.invoice_create({client_id: 1})
  invoice.line_create({invoice_id: (inv->>'id')::int, product_id: 1, quantity: 5})
  invoice.line_create({invoice_id: (inv->>'id')::int, product_id: 2, quantity: 2})
  assert """
    select count(*) = 2
    from invoice.line
    where invoice_id = (inv->>'id')::int
  """

test "product validation":
  assert """
    exists(
      select 1 from catalog.product
      where active = true
    )
  """
```

## Multi-line SQL: `"""..."""`

One rule for all multi-line SQL: **triple-quoted blocks**.

```plx
-- Assign
result := """
  select coalesce(sum(l.quantity * p.price), 0)
  from invoice.line l
  where l.invoice_id = p_id
"""

-- Return
return """
  select to_jsonb(r)
  from (select l.*, p.name from invoice.line l
        join catalog.product p on p.id = l.product_id
        where l.invoice_id = p_id) r
"""

-- Assert (test)
assert """
  select count(*) = 1
  from invoice.line
  where invoice_id = (inv->>'id')::int
"""

-- Validate (entity)
validate:
  product_active: """
    exists(
      select 1 from catalog.product
      where id = (p_input->>'product_id')::int
      and active = true
    )
  """

-- Statement (DML)
"""
  update invoice.invoice
  set status = 'archived', updated_at = now()
  where id = p_id
"""
```

Rules:
- `"""` opening is always at end of line
- `"""` closing is alone on its line, at the statement's indentation level
- Content between is raw SQL — not parsed, not interpreted, passed to PostgreSQL
- Variables are resolved by PL/pgSQL at runtime (not by PLX)
- Inline one-liner SQL after `:=` remains valid: `x := select count(*) from t`
- A bare `""" ... """` block in a function or test body is executed as a SQL statement
- `validate:` is create/update-time validation in the target syntax; rules evaluate against `p_input`

| Context | Inline (one line) | Multi-line |
|---------|-------------------|------------|
| Assign | `x := select count(*) from t` | `x := """` ... `"""` |
| Return | `return expr` | `return """` ... `"""` |
| Assert | `assert expr` | `assert """` ... `"""` |
| Validate | `name: expr` | `name: """` ... `"""` |
| Statement | `update t set x = 1 where id = p_id` | `"""` ... `"""` |

## Quick Reference

| Element | Syntax |
|---------|--------|
| Module | `module name` |
| Dependency | `depends a, b, c` |
| Import | `import schema.func as alias` |
| Include | `include "./file.plx"` |
| i18n sidecar | `module.i18n` with `[fr]` then `module.key = Valeur` |
| Export | `export schema.name` |
| Comment | `-- comment` |
| Entity | `entity schema.name uses trait:` |
| Row field | `name type modifiers` (`required`, `unique`, `?`, `default(...)`, `ref(...)`) |
| Column (hybrid) | Same as row field, inside `columns:` |
| Payload (hybrid) | Same as row field, inside `payload:` |
| Function | `[export] fn schema.name(params) -> type [attrs]:` |
| Test | `test "name":` |
| Assign | `x := expr` or `x := select ...` or `x := """` multi-line `"""` |
| Return | `return expr` or `return """` multi-line `"""` |
| If | `if cond:` / `elsif cond:` / `else:` |
| For | `for var in select ...:` |
| Raise | `raise 'message'` |
| Assert | `assert expr` or `assert expr, message` or `assert """` multi-line `"""` |
| SQL block | `"""` multi-line SQL `"""` |
| Validate | `validate:` + `name: expr` or `name: """` multi-line `"""` |
| JSON literal | `{key: value, key2: value2}` |
| Array literal | `[a, b, c]` |
| String interp | `"text #{expr} text"` |
| Type cast | `expr::type` |
| JSON access | `expr->>'key'` or `expr->'key'` |
