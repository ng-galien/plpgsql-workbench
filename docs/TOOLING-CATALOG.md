# Tooling Catalog

This document inventories the validated behaviors currently spread across the legacy tooling.

Goal:

- extract reusable primitives first
- then let `plx_*` and `runtime_*` consume them
- only after that, deprecate or remove legacy entrypoints

This is intentionally not a tool-by-tool migration plan.
It is a behavior catalog.

## Status

### Already shared

- pgTAP execution and TAP parsing
  - source: [test.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/test.ts)
  - current consumers:
    - `pg_test`
    - `plx_test`
    - `runtime_test`

- PLX apply tracking
  - source: [workflow.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/pgm/workflow.ts)
  - current consumers:
    - `plx_status`
    - `plx_apply`

- Runtime apply tracking
  - source: [workflow.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/runtime/workflow.ts)
  - current consumers:
    - `runtime_status`
    - `runtime_apply`

### Not yet extracted

The rest is still duplicated or tool-local.

## Primitive Inventory

### 0. Target Resolution

Purpose:

- resolve a user-facing target into a concrete database/runtime object
- centralize `invalid target / invalid URI / wrong kind / not found`
- avoid duplicating lookup logic and error semantics

Current sources:

- [get.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/get.ts)
- [func-load.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-load.ts)
- [func-save.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-save.ts)
- [func-del.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-del.ts)
- [func-rename.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-rename.ts)
- [func-edit.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-edit.ts)
- [coverage.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/coverage.ts)
- [module-status.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-status.ts)
- [module-apply.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-apply.ts)
- [module-test.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-test.ts)
- [status.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/runtime/status.ts)
- [apply.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/runtime/apply.ts)
- [test.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/runtime/test.ts)

Target:

- shared primitive

Consumers:

- `plx_*`
- `runtime_*`
- `pg_get`
- selected `pg_*`

Extraction priority:

- high

### 1. Problem Formatting

Purpose:

- standardize operator-facing failures
- keep `problem / where / fix_hint` stable across tools

Current sources:

- [module-status.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-status.ts)
- [module-apply.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-apply.ts)
- [module-drop.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-drop.ts)
- [module-test.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-test.ts)
- [schema.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/schema.ts)
- [func-load.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-load.ts)
- [func-set.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-set.ts)
- [func-del.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-del.ts)
- [pack.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/pack.ts)
- many other `pg_*` tools

Target:

- shared primitive

Consumers:

- `plx_*`
- `runtime_*`
- selected `pg_*`

Extraction priority:

- high

### 1b. Read Rendering

Purpose:

- standardize human-readable read/status output
- centralize `wrap(...)`, header/body structure, action hints
- make read tools consistent without forcing identical domain logic

Current sources:

- [module-status.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-status.ts)
- [module-apply.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-apply.ts)
- [module-test.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-test.ts)
- [status.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/runtime/status.ts)
- [apply.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/runtime/apply.ts)
- [test.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/runtime/test.ts)
- [get.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/get.ts)
- [health.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/health.ts)

Target:

- shared primitive

Consumers:

- `plx_status`
- `plx_apply`
- `plx_test`
- `runtime_status`
- `runtime_apply`
- `runtime_test`
- selected read-only `pg_*`

Extraction priority:

- medium

### 2. Transaction Policy

Purpose:

- consistent `BEGIN / COMMIT / ROLLBACK`
- optional savepoint use for sub-operations
- consistent failure rollback behavior

Current sources:

- [workflow.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/pgm/workflow.ts)
- [workflow.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/runtime/workflow.ts)
- [schema.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/schema.ts)
- [func-load.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-load.ts)
- [func-set.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-set.ts)
- [func-rename.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-rename.ts)
- [func-bulk-del.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-bulk-del.ts)
- [doc.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/doc.ts)
- [explain.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/explain.ts)

Target:

- shared primitive

Consumers:

- `plx_apply`
- `runtime_apply`
- selected low-level tools

Extraction priority:

- high

### 3. PostgREST Schema Reload

Purpose:

- notify PostgREST after successful schema-affecting operations

Current sources:

- [workflow.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/pgm/workflow.ts)
- [workflow.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/runtime/workflow.ts)
- [schema.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/schema.ts)
- [func-load.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-load.ts)
- [func-set.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-set.ts)
- [func-del.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-del.ts)
- [func-rename.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-rename.ts)
- [func-bulk-del.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-bulk-del.ts)
- [alter.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/alter.ts)

Target:

- shared primitive

Consumers:

- `plx_apply`
- `runtime_apply`
- selected low-level mutating tools

Extraction priority:

- high

### 4. Applied Artifact Tracking

Purpose:

- store applied artifact hashes
- diff current state vs database state
- expose `changed / unchanged / obsolete`

Current sources:

- [workflow.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/pgm/workflow.ts)
- [workflow.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/runtime/workflow.ts)

Target:

- shared primitive

Consumers:

- `plx_status`
- `plx_apply`
- `runtime_status`
- `runtime_apply`

Extraction priority:

- high

### 5. Target Validation

Purpose:

- validate tool targets before execution
- unify “not found / invalid target / wrong kind” behavior

Current sources:

- [func-load.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-load.ts)
- [func-save.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-save.ts)
- [func-del.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-del.ts)
- [func-rename.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-rename.ts)
- [func-edit.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-edit.ts)
- [coverage.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/coverage.ts)
- [module-test.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-test.ts)
- [module-status.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-status.ts)
- [module-apply.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-apply.ts)

Target:

- shared primitive

Consumers:

- `plx_*`
- `runtime_*`
- `pg_*` where still useful

Extraction priority:

- medium

### 5b. Structured Inspection

Purpose:

- expose structured inspection data before formatting
- keep lookup separate from presentation
- allow the same inspected state to feed status tools, diagnostics, and APIs

Current sources:

- [module-status.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-status.ts)
- [workflow.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/pgm/workflow.ts)
- [status.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/runtime/status.ts)
- [workflow.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/runtime/workflow.ts)
- [get.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/get.ts)
- [search.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/search.ts)
- [health.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/health.ts)

Target:

- shared primitive

Consumers:

- `plx_status`
- `runtime_status`
- future runtime introspection tools
- `pg_get`
- `pg_search`

Extraction priority:

- medium

### 6. Test Session Context

Purpose:

- deterministic session context for tests
- `tenant_id`
- inferred permissions
- optional integration-specific search path

Current source:

- [test.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/test.ts)

Target:

- keep shared

Consumers:

- `pg_test`
- `plx_test`
- `runtime_test`

Extraction priority:

- already done

### 7. Context Token Validation

Purpose:

- optimistic safety for destructive mutations
- ensures a function/object was read before mutation/delete

Current sources:

- [func-set.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-set.ts)
- [func-del.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-del.ts)

Target:

- keep low-level

Consumers:

- `pg_func_set`
- `pg_func_del`

Extraction priority:

- low

Reason:

- valuable for low-level expert tools
- not part of the normal `plx_*` or `runtime_*` workflows

### 8. Parser / Dependency Bootstrap

Purpose:

- ensure parser infra exists before AST-based analysis

Current sources:

- [deps.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/deps.ts)
- [pack.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/pack.ts)
- [doc.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/doc.ts)

Target:

- low-level shared utility

Consumers:

- AST-powered expert tools only

Extraction priority:

- low

### 9. Function Boundary Validation

Purpose:

- reject invalid function replacement cases
- signature change handling
- overload prevention
- optional plpgsql semantic checking

Current source:

- [func-set.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/func-set.ts)
- partially mirrored in [workflow.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/pgm/workflow.ts) for PLX-generated function apply

Target:

- split

Consumers:

- low-level function tooling
- `plx_apply` only for the overload/safe replacement subset

Extraction priority:

- medium

Reason:

- some parts are reusable
- `plpgsql_check` specifically should not be reintroduced into primary deploy flows

### 10. Migration/File Tracking

Purpose:

- track file-based DDL migrations
- detect changed files
- decide skip/reapply/error

Current source:

- [schema.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/schema.ts)

Target:

- low-level shared utility

Consumers:

- expert migration tooling
- possibly future runtime bootstrap flows

Extraction priority:

- medium

### 11. Diagnostic Rendering

Purpose:

- standardize reports for tests, coverage, health, visual checks, validation failures
- keep execution separate from the final operator-facing rendering

Current sources:

- [test.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/test.ts)
- [coverage.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/coverage.ts)
- [health.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/health.ts)
- [visual.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/plpgsql/visual.ts)
- [module-test.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/pgm/module-test.ts)
- [test.ts](/Users/alexandreboyer/dev/projects/plpgsql-workbench/src/core/tools/runtime/test.ts)

Target:

- shared primitive

Consumers:

- `pg_test`
- `plx_test`
- `runtime_test`
- future diagnostic/status tools

Extraction priority:

- medium

## Recommended First Extraction Batch

Extract first:

- Target resolution
- Problem formatting
- Transaction policy
- PostgREST schema reload
- Applied artifact tracking

Reason:

- already needed by both `plx_*` and `runtime_*`
- highest duplication
- lowest architectural risk

## Recommended Second Batch

- Read rendering
- Structured inspection
- Target validation
- Function boundary validation subset
- Migration/file tracking
- Diagnostic rendering

## Leave as Low-Level for Now

- context token validation
- parser bootstrap
- plpgsql-specific coverage and explain behavior
- deep function-edit string patch semantics

## Desired End State

### First-class workflows

- `plx_*`
- `runtime_*`

### Expert layer

- `pg_query`
- `pg_get`
- `pg_search`
- `pg_test`
- `pg_explain`
- selected mutation tools

### Deprecated path

- function-by-function deploy as the normal way of building the system
- schema/file deploy as the primary architecture driver
