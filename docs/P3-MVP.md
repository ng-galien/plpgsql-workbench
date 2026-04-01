# P3 MVP

## Goal

P3 is the smallest credible step that turns PLX from a transpiler into a verifiable module platform.

The MVP stays intentionally narrow:

- `module`
- `depends`
- `export` / `internal`
- multi-module build

That is enough to verify:

- a module only calls declared dependencies
- cross-module calls target public symbols only
- a client composition is complete and coherent at build time

It is not yet:

- `interface`
- `provide` / `inject`
- provider resolution
- marketplace-grade substitution

Those come later, once the public boundary and dependency graph are stable.

## Why This Repo Needs Local Codex MCP Wiring

This repository already declares its MCP setup in [`./.mcp.json`](../.mcp.json):

- `plpgsql-workbench`
- `maket`
- `workbench-msg`

That file is consumed by Claude Code style tooling, but the Codex CLI used here loads MCP servers from `~/.codex/config.toml` or explicit `-c mcp_servers...` overrides.

So the repo-local way to launch Codex with the same MCP topology is the wrapper script:

- [`./scripts/codex-local.sh`](../scripts/codex-local.sh)

It mirrors the existing local MCP setup without changing the global Codex config.

## Local Usage

Default lead session:

```bash
./scripts/codex-local.sh
```

Module-scoped session:

```bash
WORKBENCH_MCP_SESSION=quote ./scripts/codex-local.sh
```

Check the effective local MCP wiring:

```bash
./scripts/codex-local.sh mcp list
./scripts/codex-local.sh mcp get maket
```

The wrapper injects:

- `plpgsql-workbench -> http://localhost:3100/mcp`
- `maket -> http://localhost:3337/mcp`
- `maket.http_headers.X-Session = $WORKBENCH_MCP_SESSION`
- `workbench-msg -> npx tsx src/channel/workbench-msg.ts`
- `workbench-msg.env.MODULE = $WORKBENCH_MCP_SESSION`

## MVP Build Contract

The first P3 build should fail on these classes of errors:

- `module.duplicate-module`
- `module.missing-dependency`
- `module.private-symbol-access`
- `module.unknown-export`
- `module.dependency-cycle`

That gives a concrete build-time contract before adding richer abstractions like interfaces or DI.

## Next Implementation Order

1. Parse `module` and `depends`
2. Mark callable symbols as `export` or `internal`
3. Build a multi-module symbol index
4. Resolve cross-module calls against declared dependencies
5. Emit dedicated diagnostics for visibility and dependency failures

If those 5 steps are stable, P3 already has product value.

## End-of-P3 Notes

The MVP ended up including a few pragmatic additions beyond the initial module-only scope because they were necessary to make the platform usable by agents in real workflows.

### Multi-file Module Entry

`plx.entry` is now a module root, not a monolithic implementation file.

The entry file owns:

- `module`
- `depends`
- `include`
- root `export`

Included fragments own the implementation details.

That preserves:

- `1 module = 1 logical entrypoint`
- `N .plx files = editable implementation slices`

### Agent Workflow

The nominal PLX-first loop is now:

1. `pgm_module_status`
2. `pgm_module_apply` dry-run
3. edit `.plx` fragments
4. `pgm_module_apply apply:true`
5. `pgm_module_status`

The apply workflow is:

- full compile
- build files written to disk
- incremental apply from generated artifacts
- module tests run before commit

### Entity Contract

Generated entity CRUD is now public `jsonb`, not public table-composite input.

Current generated signatures are:

- `entity_create(p_data jsonb) -> jsonb`
- `entity_update(p_id text, p_patch jsonb) -> jsonb`
- `entity_read(p_id text) -> jsonb`
- `entity_list(...) -> setof jsonb`
- `entity_delete(p_id text) -> jsonb`

Internally, PLX now supports two storage shapes:

- `fields:` for classic row-shaped entities
- `columns:` + `payload:` for hybrid entities

Example:

```plx
entity project.task:
  columns:
    project_id int ref(project.project)
    due_date date?

  payload:
    title text required
    description text?
    priority text? default('normal')

  states draft -> active -> done:
    column: phase
    activate(draft -> active)
    complete(active -> done)
```

Semantics:

- `columns:` compile to real SQL columns
- `payload:` compiles to validated keys stored in `data jsonb`
- `ref(schema.entity)` is only valid in `columns:` and compiles to a real `REFERENCES ... (id)` constraint
- `states ...:` stays relational and compiles to a real state column, defaulting to `status` unless `column:` is provided
- the public API stays unified as `jsonb`

So the storage split is internal to the compiler. The module and its callers still see one logical entity contract.

### Validation

Entity validation is declarative through dedicated hooks:

- `validate create:`
- `validate update:`
- `validate delete:`

Inside these hooks, the current MVP form is a list of `assert` statements.

The compiler also injects a small structural validation layer automatically:

- payload must be a JSON object
- unknown fields are rejected
- forbidden/read-only fields are rejected
- required fields are enforced on create

Then the payload is coerced with `jsonb_populate_record(...)`.

For hybrid `columns:` + `payload:` entities:

- `validate create:` should reason on `p_data`
- `validate update:` should reason on `p_patch`
- `p_row` remains a good fit for classic `fields:` / row-shaped entities

That keeps the validation contract explicit instead of hiding storage-specific magic in hook variables.

### Migration Policy

The storage split also changes the migration posture.

Most day-to-day schema evolution should now happen in `payload:`:

- add a field
- stop writing a field
- rename with fallback logic in CRUD / validation

Those changes do not require DDL by default.

Structural changes remain explicit and manual:

- new or changed `columns:`
- new FK
- new state column / state-machine structure
- indexes or other relational constraints

So P7 does not need to start as a full auto-migration engine.

The intended policy is:

- `payload:` change -> no automatic DB migration required
- structural `columns:` / relational change -> manual migration required

Tooling should eventually detect structural drift and point to the need for a migration, but not try to synthesize every migration automatically.

### DDL Apply Graph

The apply graph is no longer a single monolithic `ddl` node.

For PLX entities, the builder now emits a split DDL plan:

- `ddl:schema:<schema>`
- `ddl:table:<schema.entity>`
- `ddl:fk:<schema.entity>.<column>`
- `ddl:grant:<schema.entity>`

This keeps P4 simple while still giving a real dependency graph for:

- table before FK
- referenced table before FK
- schema before table

More complex DDL shapes like triggers or multi-pass constraints remain later work, but the apply order is no longer a flat rank-only guess.

### Explicitly Out of Scope

The following are intentionally not part of P3:

- `interface`
- `provide` / `inject`
- provider resolution
- richer validation DSL than `validate *` + `assert`
- automatic structural migrations
- marketplace/package substitution semantics

## Compiler Technical Debt

Identified by full architectural review of `src/core/plx/` (57 tests, ~8000 LOC).

### P1 — CompiledBundle internal type

`_artifact` and `_blocks` leak on `CompileResult` as optional fields, mutated/deleted by `compileAndValidate`. Introduce `CompiledBundle` (internal) wrapping `CompileResult` + internals. Public `compile()` returns `CompileResult` only. `compose()` receives `CompiledBundle[]` directly. Files: compiler.ts, composition.ts, plx-builder.ts.

### P2 — Entity LOC sentinel {0,0}

Every AST node synthesized by entity-expander uses `pointLoc()`. All diagnostics and source maps for entity CRUD show (0,0). Propagate `entity.loc` through builder functions. Files: entity-expander.ts.

### P3 — Shared AST walker

Three independent walkers (composition.ts, semantic.ts, parse-context.ts). Extract `walkStatements` + `walkExpression` to `walker.ts` (~80 lines). Eliminates N-walker divergence on new node kinds. Files: new walker.ts + 3 consumers.

### P4 — as EntityHookEvent cast

`${event}_${action}` cast bypasses TypeScript. Replace with explicit lookup table. ~10 lines. Files: entity-parser.ts.

### P5 — Extract entity DDL to entity-ddl.ts

entity-expander.ts (~1000 lines) is both function builder and DDL generator. DDL strings bypass codegen. Extract to entity-ddl.ts. Files: entity-expander.ts.

### P6 — Deduplicate stripLocPrefix

Duplicated in compiler.ts and parse-context.ts. Move to ast.ts. Files: 3.

### P7 — Remove module augmentation

`peekBinaryOperator`/`advanceBinaryOperator` use prototype augmentation. Convert to class methods. Files: parse-context.ts.

### Not debt — keep as-is

Lexer, AST unions, pipeline entry points, module-loader, test-expander, composition cycle detection.
