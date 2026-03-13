---
topic: coverage
---
# Code Coverage for PL/pgSQL

## Usage

  coverage target:plpgsql://public/function/classify

## How it works

1. Parse function AST (parsePlPgSQL)
2. Detect coverage points (blocks + branches)
3. Instrument body with RAISE WARNING markers
4. Run unit tests (<schema>_ut.test_<name>)
5. Capture markers via node-pg notice handler
6. Restore original function
7. Persist results in workbench.cov_run + cov_point

RAISE WARNING is non-transactional: survives pgTAP's SAVEPOINT/ROLLBACK.

## Coverage points

Blocks (was this statement executed?):
  - assign, perform, execsql, return, raise, dynexecute

Branches (was this path taken?):
  - IF -> THEN / ELSIF / ELSE
  - CASE -> WHEN / ELSE
  - LOOP / WHILE / FOR (entered?)
  - EXCEPTION WHEN (handler triggered?)

## Output

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

## Querying results

Results are in workbench.cov_run and workbench.cov_point:

  query SELECT p.line, p.kind, p.label, p.hit
        FROM workbench.cov_point p
        WHERE p.run_id = '<run_id>'
        ORDER BY p.line

Compare runs:

  query SELECT r.id, r.started_at,
               count(*) FILTER (WHERE p.hit) AS covered,
               count(*) AS total
        FROM workbench.cov_run r
        JOIN workbench.cov_point p ON p.run_id = r.id
        WHERE r.fn_name = 'classify'
        GROUP BY r.id, r.started_at
        ORDER BY r.started_at DESC

## Cleanup old runs

  query DELETE FROM workbench.cov_run
        WHERE started_at < now() - interval '7 days'
