# pgv Architecture

`pgv` is no longer an HTML SSR module.

The remaining backend should be read in four zones:

## Layout

Source layout is now responsibility-first:

- `src/core/`
- `src/query/`
- `src/facade/`
- `src/quarantine/`
- `src/tooling/`
- `tests/core/`
- `tests/query/`
- `tests/facade/`
- `tests/quarantine/`
- `tests/tooling/`

## Core

Keep in the runtime nucleus:

- i18n: `t`, `i18n_bundle`, `i18n_seed`
- errors: `throw_invalid`, `throw_not_found`
- generic helpers: `esc`, `md_esc`, `slugify`, `money`, `filesize`
- SDUI primitives: all `ui_*`
- SDUI contract: `view_schema`

Physical paths:

- `src/core/i18n/`
- `src/core/helpers/`
- `src/core/sdui/`

## Facade

Keep as entrypoint, but treat as a facade layer, not the core:

- `api`
- `_parse_uri`
- `app_nav`
- `nav_schema`
- `post_issue_report`

The facade may depend on core and, temporarily, on quarantined introspection helpers.

Physical path:

- `src/facade/`

## Quarantine

Requires a later design pass before any migration or rename:

- `schema_catalog`
- `schema_discover`
- `schema_table`
- `schema_inspect`
- `schema_comments`

These functions are useful, but their responsibility is not yet settled.

Physical path:

- `src/quarantine/`

## Tooling

Not part of the runtime contract anymore:

- `check_crud`
- `check_nav`
- `check_view`

These functions may remain available during transition, but they should not drive the target architecture.

Physical path:

- `src/tooling/`

## Legacy

Removed already:

- HTML frontend shell
- `pgv_qa` showcase app
- route/page/toast/redirect test surface
- `html_audit`

Still under review:

- `post_issue_report` behavior and placement
- `legacy/frontend/i18n/` as a leftover asset bucket, not a runtime frontend

## Tests

Tests now follow the same responsibility split under `tests/`.

This is intentional: `pgv` is being restructured as architecture-first source code, not as a tooling-shaped flat folder.
