CREATE SCHEMA IF NOT EXISTS workbench;

CREATE TABLE IF NOT EXISTS workbench.toolbox (
  name TEXT PRIMARY KEY,
  description TEXT
);

CREATE TABLE IF NOT EXISTS workbench.toolbox_tool (
  toolbox_name TEXT NOT NULL REFERENCES workbench.toolbox(name) ON DELETE CASCADE,
  tool_name TEXT NOT NULL,
  PRIMARY KEY (toolbox_name, tool_name)
);

CREATE TABLE IF NOT EXISTS workbench.tenant (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  toolbox_name TEXT NOT NULL REFERENCES workbench.toolbox(name),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS workbench.config (
  app TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  PRIMARY KEY (app, key)
);

-- Inter-agent messaging
CREATE TABLE IF NOT EXISTS workbench.agent_message (
  id              SERIAL PRIMARY KEY,
  from_module     TEXT NOT NULL,
  to_module       TEXT NOT NULL,  -- module name or '*' for broadcast
  msg_type        TEXT NOT NULL CHECK (msg_type IN (
                    'feature_request','bug_report','breaking_change','question','info')),
  subject         TEXT NOT NULL,
  body            TEXT,
  status          TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new','acknowledged','resolved')),
  resolution      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  acknowledged_at TIMESTAMPTZ,
  resolved_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_agent_message_inbox
  ON workbench.agent_message (to_module, status) WHERE status != 'resolved';

-- Grants for PostgREST
GRANT USAGE ON SCHEMA workbench TO web_anon;
GRANT SELECT, INSERT, UPDATE ON workbench.config TO web_anon;
