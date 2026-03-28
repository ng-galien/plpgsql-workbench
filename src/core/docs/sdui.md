---
topic: sdui
---
# SDUI — Server-Driven UI

## Overview

The React shell consumes `api(verb, uri)` for data and `{entity}_view()` for presentation templates. PG composes the structure (fields, layout, actions), React renders. Zero business logic on the client.

## Architecture

Two separate concerns:
- **Data** — `_list()`, `_read()`, `_create()`, `_update()`, `_delete()` via api
- **Presentation** — `_view()` returns the template (how to display, not what to display)

The React shell combines both: fetches the template once, fetches data as needed, renders cards at the appropriate density level.

## The _view() Contract

Each module entity exposes `{entity}_view() RETURNS jsonb`:

    {
      "uri": "crm://client",
      "icon": "◎",
      "label": "crm.entity_client",

      "template": {
        "compact": {
          "fields": ["name", "city", "tier"]
        },
        "standard": {
          "fields": ["name", "email", "phone", "city", "postal_code"],
          "stats": [
            { "key": "quote_count", "label": "crm.stat_quotes" },
            { "key": "total_revenue", "label": "crm.stat_revenue" },
            { "key": "pending_amount", "label": "crm.stat_pending", "variant": "warning" }
          ],
          "related": [
            { "entity": "quote://devis", "label": "crm.rel_quotes", "filter": "client_id={id}" },
            { "entity": "quote://facture", "label": "crm.rel_invoices", "filter": "client_id={id}" }
          ]
        },
        "expanded": {
          "fields": ["name", "type", "email", "phone", "address", "city", "postal_code", "tier", "tags", "notes"],
          "stats": [...],
          "related": [...]
        },
        "form": {
          "sections": [
            {
              "label": "crm.section_identity",
              "fields": [
                { "key": "type", "type": "select", "label": "crm.field_type", "required": true, "options": "crm.client_type_options" },
                { "key": "name", "type": "text", "label": "crm.field_name", "required": true },
                { "key": "tier", "type": "select", "label": "crm.field_tier", "options": "crm.client_tier_options" }
              ]
            },
            {
              "label": "crm.section_contact",
              "fields": [
                { "key": "email", "type": "email", "label": "crm.field_email" },
                { "key": "phone", "type": "tel", "label": "crm.field_phone" }
              ]
            }
          ]
        }
      },

      "actions": {
        "archive":  { "label": "crm.action_archive", "icon": "▾", "variant": "muted" },
        "activate": { "label": "crm.action_activate", "icon": "▴", "variant": "primary" },
        "delete":   { "label": "crm.action_delete", "icon": "×", "variant": "danger", "confirm": "crm.confirm_delete" }
      }
    }

## Template Levels

Four density levels for the same entity:

- **compact** — one line: icon + name + key fields. Used in overlay lists, related entity links, peek cards.
- **standard** — full card: fields + stats + related entities. Used when pinned on the canvas workspace.
- **expanded** — everything: all fields + stats + related + history. Used for detailed view / editing.
- **form** — create and update form with typed fields and sections. React decides verb (set vs patch) based on context.

## Field Types

Form fields support these types:

    text, email, tel, number, date, select, textarea, checkbox, combobox

### Combobox (search + autocomplete)

For FK fields, use combobox with a source URI:

    { "key": "client_id", "type": "combobox", "label": "mod.field_client",
      "source": "crm://client", "display": "name",
      "filter": "active=true;supplier_id={supplier_id}" }

- `source` — api URI to fetch options
- `display` — field name to show as label
- `filter` — RSQL filter, supports {field} interpolation from other form fields (re-fetches on change)

## Actions — HATEOAS

The _view() template declares the CATALOG of all possible actions (labels, icons, variants, confirm messages).

The _read() response includes a HATEOAS `actions` array with the currently AVAILABLE actions based on entity state:

    // _read() returns:
    {
      "id": 1, "name": "Martin", "status": "active", ...
      "actions": [
        { "method": "archive", "uri": "crm://client/1/archive" },
        { "method": "delete", "uri": "crm://client/1/delete" }
      ]
    }

React matches HATEOAS methods against the _view() actions catalog to render buttons with the right labels and styles.

## Stats

Stats are computed by _read() and returned as extra fields in the data. The template only declares which keys to display and how:

    "stats": [
      { "key": "quote_count", "label": "crm.stat_quotes" },
      { "key": "total_revenue", "label": "crm.stat_revenue" },
      { "key": "pending_amount", "label": "crm.stat_pending", "variant": "warning" }
    ]

## Related Entities

Related entities reference other entities by URI with dynamic filters:

    "related": [
      { "entity": "quote://devis", "label": "crm.rel_quotes", "filter": "client_id={id}" }
    ]

The {id} is interpolated from the current entity data. React fetches via api with the resolved filter.

## Language Rules

ALL labels in _view() MUST be i18n keys resolved via pgv.t(). Never hardcode text in any language.

    GOOD: "label": "crm.field_name"
    BAD:  "label": "Nom"
    BAD:  "label": "Name"

## Nav Items

nav_items() must include `uri` and `entity` for each CRUD item:

    jsonb_build_object('href', '/clients', 'label', pgv.t('crm.nav_clients'), 'icon', 'users', 'entity', 'client', 'uri', 'crm://client')

The URI is the single key linking navigation, templates, and data.

## Entity Types

Two kinds of entities:

- **crud** (default) — full lifecycle: create, read, update, delete. Has form section in _view().
- **event** — immutable records (stock.mouvement, ledger.entry_line). No form, no edit, no delete. Add `"readonly": true` at top level of _view(). Shell renders as timeline, not editable cards.

## Two-Step Forms

Some entities need "create header first, then add children" (ledger.journal_entry, quote.devis).
The form section in _view() handles the header. Children (lines) are added via ui_line_items after creation.
The shell detects this pattern when the _view() has both form.sections AND a line_items reference in expanded.

## Deprecated

`_ui()` is deprecated. Use `_view()` instead.

## Primitives pgv.ui_*

### Tier 1 — Universal (RFC-001 approved)

    pgv.ui_timeline(events jsonb) -> {"type":"timeline","events":[{"date":"...","label":"...","variant":"info"}]}
    Chronological event list. Used by: CRM, Quote, Stock, HR, Project, Workbench.

    pgv.ui_currency(amount numeric, currency text DEFAULT 'EUR') -> {"type":"currency","amount":5200.00,"currency":"EUR"}
    Locale-aware monetary display. Used by: Quote, Ledger, Purchase, Expense, Catalog.

    pgv.ui_workflow(states text[], current text) -> {"type":"workflow","states":["brouillon","envoye","accepte"],"current":"envoye"}
    Visual state machine stepper. Used by: Quote, Expense, Purchase, Project.

    pgv.ui_line_items(source text, columns jsonb, totals jsonb) -> {"type":"line_items","source":"lignes","columns":[...],"totals":{"ht":...,"tva":...,"ttc":...}}
    Child table with summary footer. Used by: Quote, Purchase, Expense.

### Display
    pgv.ui_text(value) -> {"type":"text","value":"..."}
    pgv.ui_heading(text, level?) -> {"type":"heading","text":"...","level":2}
    pgv.ui_link(text, href) -> {"type":"link","text":"...","href":"..."}
    pgv.ui_badge(text, variant?) -> {"type":"badge","text":"...","variant":"success"}
    pgv.ui_color(value) -> {"type":"color","value":"#hex"}
    pgv.ui_md(content) -> {"type":"md","content":"**markdown**"}
    pgv.ui_stat(value, label, variant?) -> {"type":"stat","value":"12","label":"..."}

### Layout
    pgv.ui_column(VARIADIC children) -> {"type":"column","children":[...]}
    pgv.ui_row(VARIADIC children) -> {"type":"row","children":[...]}
    pgv.ui_section(label, VARIADIC children) -> {"type":"section","label":"...","children":[...]}

### Form
    pgv.ui_form(uri, verb, fields) -> {"type":"form","uri":"...","verb":"set","fields":[...]}
    pgv.ui_field(key, type, label, required?, options?) -> {"type":"field",...}
    Field types: text, email, tel, number, date, select, textarea, checkbox, combobox

### Connected
    pgv.ui_table(source, columns) -> connected to datasource
    pgv.ui_col(key, label, cell?) -> table column definition
    pgv.ui_detail(source, fields) -> connected detail view
    pgv.ui_datasource(uri, page_size?, searchable?, default_sort?) -> datasource config
    pgv.ui_action(label, verb, uri, variant?, confirm?) -> action button
