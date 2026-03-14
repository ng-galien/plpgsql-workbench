-- ops — DDL (agent dashboard)

CREATE SCHEMA IF NOT EXISTS ops;
CREATE SCHEMA IF NOT EXISTS ops_ut;
CREATE SCHEMA IF NOT EXISTS ops_qa;

-- Test run history (used by ops.get_tests / ops.post_test_run)
CREATE TABLE IF NOT EXISTS workbench.test_run (
  id serial PRIMARY KEY,
  schema_ut text NOT NULL,
  total int NOT NULL DEFAULT 0,
  passed int NOT NULL DEFAULT 0,
  failed int NOT NULL DEFAULT 0,
  duration_ms int,
  run_at timestamptz NOT NULL DEFAULT now()
);

-- Tool metadata (description + input schema from MCP registry)
ALTER TABLE workbench.toolbox_tool ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE workbench.toolbox_tool ADD COLUMN IF NOT EXISTS input_schema jsonb;

-- Grants
GRANT USAGE ON SCHEMA ops TO anon;
GRANT USAGE ON SCHEMA ops_ut TO anon;
GRANT USAGE ON SCHEMA ops_qa TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ops TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ops_ut TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ops_qa TO anon;
