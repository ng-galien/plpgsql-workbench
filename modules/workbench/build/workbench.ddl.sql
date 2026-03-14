CREATE SCHEMA IF NOT EXISTS workbench;

-- ── Tables ──

CREATE TABLE IF NOT EXISTS workbench.toolbox (
  name TEXT PRIMARY KEY,
  description TEXT
);

CREATE TABLE IF NOT EXISTS workbench.toolbox_tool (
  toolbox_name TEXT NOT NULL REFERENCES workbench.toolbox(name) ON DELETE CASCADE,
  tool_name TEXT NOT NULL,
  description TEXT,
  input_schema JSONB,
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

CREATE TABLE IF NOT EXISTS workbench.tenant_module (
  tenant_id   TEXT NOT NULL REFERENCES workbench.tenant(id) ON DELETE CASCADE,
  module      TEXT NOT NULL,
  active      BOOLEAN NOT NULL DEFAULT true,
  sort_order  INTEGER NOT NULL DEFAULT 50,
  activated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, module)
);

CREATE INDEX IF NOT EXISTS idx_tenant_module_active
  ON workbench.tenant_module (tenant_id) WHERE active;

CREATE TABLE IF NOT EXISTS workbench.config (
  app TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  PRIMARY KEY (app, key)
);

CREATE TABLE IF NOT EXISTS workbench.agent_message (
  id              SERIAL PRIMARY KEY,
  from_module     TEXT NOT NULL,
  to_module       TEXT NOT NULL,
  msg_type        TEXT NOT NULL CHECK (msg_type IN (
                    'feature_request','bug_report','issue_report','breaking_change','question','info','task')),
  subject         TEXT NOT NULL,
  body            TEXT,
  status          TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new','acknowledged','resolved')),
  resolution      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  acknowledged_at TIMESTAMPTZ,
  resolved_at     TIMESTAMPTZ,
  reply_to        INTEGER REFERENCES workbench.agent_message(id),
  payload         JSONB,
  result          JSONB,
  priority        TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal','high'))
);

CREATE INDEX IF NOT EXISTS idx_agent_message_inbox
  ON workbench.agent_message (to_module, status) WHERE status != 'resolved';
CREATE INDEX IF NOT EXISTS idx_agent_message_reply
  ON workbench.agent_message (reply_to) WHERE reply_to IS NOT NULL;

CREATE TABLE IF NOT EXISTS workbench.gotcha (
  id          SERIAL PRIMARY KEY,
  scope       TEXT NOT NULL DEFAULT '*',
  trigger     TEXT,
  rule        TEXT NOT NULL,
  detail      TEXT,
  severity    TEXT NOT NULL DEFAULT 'error' CHECK (severity IN ('error','warning','info')),
  active      BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gotcha_scope
  ON workbench.gotcha (scope) WHERE active;

CREATE TABLE IF NOT EXISTS workbench.issue_report (
  id          SERIAL PRIMARY KEY,
  issue_type  TEXT NOT NULL DEFAULT 'bug' CHECK (issue_type IN ('bug','enhancement','question')),
  module      TEXT,
  description TEXT NOT NULL,
  context     JSONB NOT NULL DEFAULT '{}',
  status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','acknowledged','resolved','closed')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  message_id  INTEGER REFERENCES workbench.agent_message(id)
);

CREATE INDEX IF NOT EXISTS idx_issue_report_status
  ON workbench.issue_report (status) WHERE status != 'closed';
CREATE INDEX IF NOT EXISTS idx_issue_report_module
  ON workbench.issue_report (module) WHERE module IS NOT NULL;

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

-- ── RLS ──

ALTER TABLE workbench.tenant ENABLE ROW LEVEL SECURITY;
ALTER TABLE workbench.tenant_module ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_isolation ON workbench.tenant;
CREATE POLICY tenant_isolation ON workbench.tenant
  USING (id = coalesce(current_setting('app.tenant_id', true), id));

DROP POLICY IF EXISTS tenant_module_isolation ON workbench.tenant_module;
CREATE POLICY tenant_module_isolation ON workbench.tenant_module
  USING (tenant_id = coalesce(current_setting('app.tenant_id', true), tenant_id));

-- ── Triggers ──

DROP TRIGGER IF EXISTS trg_issue_report_notify ON workbench.issue_report;
CREATE TRIGGER trg_issue_report_notify
  BEFORE INSERT ON workbench.issue_report
  FOR EACH ROW
  EXECUTE FUNCTION workbench.on_issue_report_insert();

-- ── Grants ──

GRANT USAGE ON SCHEMA workbench TO anon;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA workbench TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA workbench TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA workbench TO anon;
