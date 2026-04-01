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

Internally, PLX still relies on PostgreSQL row typing through `jsonb_populate_record(...)`.

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

### Explicitly Out of Scope

The following are intentionally not part of P3:

- `interface`
- `provide` / `inject`
- provider resolution
- richer validation DSL than `validate *` + `assert`
- marketplace/package substitution semantics
