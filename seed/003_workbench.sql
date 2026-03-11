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
  slug TEXT UNIQUE,
  plan TEXT NOT NULL DEFAULT 'solo' CHECK (plan IN ('solo','pro','equipe')),
  toolbox_name TEXT REFERENCES workbench.toolbox(name),
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Module activation per tenant
CREATE TABLE IF NOT EXISTS workbench.tenant_module (
  tenant_id   TEXT NOT NULL REFERENCES workbench.tenant(id) ON DELETE CASCADE,
  module      TEXT NOT NULL,
  active      BOOLEAN NOT NULL DEFAULT true,
  activated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, module)
);

CREATE INDEX IF NOT EXISTS idx_tenant_module_active
  ON workbench.tenant_module (tenant_id) WHERE active;

-- RLS
ALTER TABLE workbench.tenant ENABLE ROW LEVEL SECURITY;
ALTER TABLE workbench.tenant_module ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_isolation ON workbench.tenant;
CREATE POLICY tenant_isolation ON workbench.tenant
  USING (id = coalesce(current_setting('app.tenant_id', true), id));

DROP POLICY IF EXISTS tenant_module_isolation ON workbench.tenant_module;
CREATE POLICY tenant_module_isolation ON workbench.tenant_module
  USING (tenant_id = coalesce(current_setting('app.tenant_id', true), tenant_id));

-- Dev seed
INSERT INTO workbench.tenant (id, name, slug, plan)
VALUES ('dev', 'Dev Workbench', 'dev', 'equipe')
ON CONFLICT (id) DO NOTHING;

INSERT INTO workbench.tenant_module (tenant_id, module) VALUES
  ('dev', 'pgv'), ('dev', 'cad'), ('dev', 'crm'),
  ('dev', 'quote'), ('dev', 'ledger'), ('dev', 'ops')
ON CONFLICT DO NOTHING;

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

-- Hook event log
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

-- Agent sessions
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

-- Grants for PostgREST
GRANT USAGE ON SCHEMA workbench TO web_anon;
GRANT SELECT, INSERT, UPDATE ON workbench.config TO web_anon;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA workbench TO web_anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA workbench TO web_anon;
