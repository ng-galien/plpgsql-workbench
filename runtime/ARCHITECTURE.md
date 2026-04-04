# Runtime Architecture

The legacy `pgv` schema is being retired.

The replacement architecture is split by responsibility, not by historical implementation.

## Schemas

### `i18n`

Purpose:

- translation storage
- translation lookup
- translation bundle export
- seed helpers

Receives:

- `pgv.t` -> `i18n.t`
- `pgv.i18n_bundle` -> `i18n.bundle`
- `pgv.i18n_seed` -> `i18n.seed`

### `sdui`

Purpose:

- SDUI JSON primitives
- SDUI contracts
- SDUI entry facade
- navigation aggregation when still needed

Receives:

- `pgv.ui_*` -> `sdui.ui_*`
- `pgv.view_schema` -> `sdui.view_schema`
- `pgv.api` -> `sdui.api`
- `pgv._parse_uri` -> `sdui._parse_uri`
- `pgv.app_nav` -> `sdui.app_nav`
- `pgv.nav_schema` -> `sdui.nav_schema`
- `pgv.ui_form_for` -> `sdui.ui_form_for`

### `query`

Purpose:

- request/query filtering helpers
- RSQL parsing and SQL emission

Receives:

- `pgv.rsql_validate` -> `query.rsql_validate`
- `pgv.rsql_to_where` -> `query.rsql_to_where`
- `pgv._rsql_compare` -> `query._rsql_compare`

### `util`

Purpose:

- generic helpers not specific to SDUI
- formatting
- escaping
- generic exceptions

Receives:

- `pgv.esc` -> `util.esc`
- `pgv.md_esc` -> `util.md_esc`
- `pgv.slugify` -> `util.slugify`
- `pgv.money` -> `util.money`
- `pgv.filesize` -> `util.filesize`
- `pgv.throw_invalid` -> `util.throw_invalid`
- `pgv.throw_not_found` -> `util.throw_not_found`

### `catalog`

Purpose:

- schema discovery
- schema introspection
- catalog navigation

Status:

- quarantine zone
- not part of the stable runtime contract yet

Receives:

- `pgv.schema_catalog` -> `catalog.schema_catalog`
- `pgv.schema_discover` -> `catalog.schema_discover`
- `pgv.schema_table` -> `catalog.schema_table`
- `pgv.schema_inspect` -> `catalog.schema_inspect`
- `pgv.schema_comments` -> `catalog.schema_comments`

### `dev`

Purpose:

- tooling-only runtime helpers
- contract checks and diagnostics

Status:

- not used by PLX as the primary contract anymore
- kept only as dev/runtime tooling

Receives:

- `pgv.check_crud` -> `dev.check_crud`
- `pgv.check_nav` -> `dev.check_nav`
- `pgv.check_view` -> `dev.check_view`
- `pgv.post_issue_report` -> `dev.post_issue_report`

## Explicit non-goals

- keeping the `pgv` schema alive
- keeping `runtime/` inside `modules/`
- preserving old SSR naming
- aligning tools before the architecture is clean

## Transitional note

`dev.post_issue_report` is parked in `dev` only to complete the removal of `pgv`.

Its long-term home may still be outside the runtime split.
