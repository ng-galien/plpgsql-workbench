-- workbench tables for ops dashboard (hook_log + agent_session)
-- These tables live in workbench schema, read by ops module.

CREATE TABLE IF NOT EXISTS workbench.hook_log (
  id          SERIAL PRIMARY KEY,
  module      TEXT NOT NULL,
  tool        TEXT NOT NULL,
  action      TEXT NOT NULL DEFAULT '',
  allowed     BOOLEAN NOT NULL,
  reason      TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hook_log_module
  ON workbench.hook_log (module, created_at DESC);

CREATE TABLE IF NOT EXISTS workbench.agent_session (
  id             SERIAL PRIMARY KEY,
  module         TEXT NOT NULL,
  status         TEXT NOT NULL DEFAULT 'running'
                   CHECK (status IN ('running','waiting','stuck','done','error')),
  pid            INTEGER,
  started_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at       TIMESTAMPTZ,
  last_activity  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_session_module
  ON workbench.agent_session (module, started_at DESC);

GRANT SELECT, INSERT, UPDATE ON workbench.hook_log TO anon;
GRANT SELECT, INSERT, UPDATE ON workbench.agent_session TO anon;
GRANT USAGE, SELECT ON workbench.hook_log_id_seq TO anon;
GRANT USAGE, SELECT ON workbench.agent_session_id_seq TO anon;
