---
topic: testing
---
# Testing PL/pgSQL with pgTAP

## Convention

  <schema>_ut   unit tests (auto-run on set/edit)
  <schema>_it   integration tests (manual via test tool)

Example: public.hello() -> public_ut.test_hello()

## Search path

Tests run with: SET search_path TO <test_schema>, <source_schema>, public
Call source functions without schema qualification:

  -- in public_ut.test_hello()
  RETURN NEXT is(hello('world'), 'Hello world', 'desc');

## Writing a unit test

  CREATE OR REPLACE FUNCTION public_ut.test_hello()
  RETURNS SETOF TEXT LANGUAGE plpgsql AS $$
  BEGIN
    RETURN NEXT is(hello('world'), 'Hello world', 'hello with name');
    RETURN NEXT is(hello(''), 'Hello ', 'hello with empty');
  END;
  $$;

Rules:
  - Name: test_<function_name>
  - Schema: <source_schema>_ut or <source_schema>_it
  - Returns SETOF TEXT
  - No plan needed (runtests handles it)

## Assertions

  is(have, want, desc)           equality (NULL-safe)
  isnt(have, want, desc)         inequality
  ok(bool, desc)                 boolean check
  lives_ok(sql, desc)            SQL runs without error
  throws_ok(sql, errcode, msg)   SQL raises expected error
  results_eq(sql, sql, desc)     result sets match (ordered)
  bag_eq(sql, sql, desc)         result sets match (unordered)
  performs_ok(sql, ms, desc)     SQL runs under time limit

## Running tests

  test target:plpgsql://public/function/hello     one function's UT
  test schema:public_ut                            all UTs for public
  test schema:public_it                            all ITs for public
  test schema:public_ut pattern:^test_hello$       filtered

## Auto-run

set/edit a function -> deploy -> plpgsql_check -> auto-run <schema>_ut.test_<name>

If tests exist, results appear after the deployed state:

  ✓ plpgsql_check passed
  ---
  public.hello(name text) -> text
    ...
  ---
  ✓ 2 passed, 0 failed, 2 total
    ✓ hello with name
    ✓ hello with empty string
