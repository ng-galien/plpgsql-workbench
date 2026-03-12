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
  sort_order  INTEGER NOT NULL DEFAULT 50,
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

INSERT INTO workbench.tenant_module (tenant_id, module, sort_order) VALUES
  ('dev', 'pgv',      0),
  ('dev', 'crm',     10),
  ('dev', 'quote',   20),
  ('dev', 'cad',     30),
  ('dev', 'ledger',  40),
  ('dev', 'stock',   50),
  ('dev', 'purchase',60),
  ('dev', 'project', 70),
  ('dev', 'ops',     90)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS workbench.config (
  app TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  PRIMARY KEY (app, key)
);

-- Inter-agent messaging (with task delegation support)
CREATE TABLE IF NOT EXISTS workbench.agent_message (
  id              SERIAL PRIMARY KEY,
  from_module     TEXT NOT NULL,
  to_module       TEXT NOT NULL,
  msg_type        TEXT NOT NULL CHECK (msg_type IN (
                    'feature_request','bug_report','breaking_change','question','info','task')),
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

-- ── Functions ──

-- Hook logging (fire-and-forget)
CREATE OR REPLACE FUNCTION workbench.log_hook(
  p_module text, p_tool text, p_action text, p_allowed boolean, p_reason text DEFAULT NULL
) RETURNS void LANGUAGE sql AS $$
  INSERT INTO workbench.hook_log (module, tool, action, allowed, reason)
    VALUES (p_module, p_tool, p_action, p_allowed, p_reason);
$$;

-- Agent session lifecycle
CREATE OR REPLACE FUNCTION workbench.session_create(p_module text, p_pid integer)
RETURNS integer LANGUAGE sql AS $$
  INSERT INTO workbench.agent_session (module, status, pid, started_at)
    VALUES (p_module, 'running', p_pid, now())
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION workbench.session_end(p_id integer, p_status text)
RETURNS void LANGUAGE sql AS $$
  UPDATE workbench.agent_session
    SET status = p_status, ended_at = now()
    WHERE id = p_id;
$$;

-- Inbox: pending messages for SessionStart hook (priority-sorted)
CREATE OR REPLACE FUNCTION workbench.inbox_pending(p_module text)
RETURNS TABLE(id integer, from_module text, msg_type text, subject text, priority text)
LANGUAGE sql STABLE AS $$
  SELECT m.id, m.from_module, m.msg_type, m.subject, m.priority
    FROM workbench.agent_message m
   WHERE m.to_module = p_module
     AND m.status IN ('new', 'acknowledged')
   ORDER BY
     CASE WHEN m.priority = 'high' THEN 0 ELSE 1 END,
     m.created_at DESC
   LIMIT 10;
$$;

-- Inbox: new unread messages for Stop hook
CREATE OR REPLACE FUNCTION workbench.inbox_new(p_module text)
RETURNS TABLE(id integer, from_module text, msg_type text, subject text)
LANGUAGE sql STABLE AS $$
  SELECT m.id, m.from_module, m.msg_type, m.subject
    FROM workbench.agent_message m
   WHERE m.to_module = p_module
     AND m.status = 'new'
   ORDER BY m.created_at
   LIMIT 10;
$$;

-- Inbox: high-priority check for PreToolUse hook (active delivery)
CREATE OR REPLACE FUNCTION workbench.inbox_check(p_module text)
RETURNS TABLE(id integer, from_module text, msg_type text, subject text,
              body text, payload jsonb, reply_to integer, priority text)
LANGUAGE sql STABLE AS $$
  SELECT m.id, m.from_module, m.msg_type, m.subject,
         m.body, m.payload, m.reply_to, m.priority
    FROM workbench.agent_message m
   WHERE m.to_module = p_module
     AND m.status = 'new'
     AND m.priority = 'high'
   ORDER BY m.created_at DESC
   LIMIT 1;
$$;

-- Auto-acknowledge resolved sent messages (Stop hook)
CREATE OR REPLACE FUNCTION workbench.ack_resolved(p_module text)
RETURNS TABLE(id integer, to_module text, msg_type text, subject text, resolution text)
LANGUAGE sql AS $$
  UPDATE workbench.agent_message
    SET acknowledged_at = resolved_at
    WHERE from_module = p_module
      AND status = 'resolved'
      AND (acknowledged_at IS NULL OR resolved_at > acknowledged_at)
    RETURNING agent_message.id, agent_message.to_module, agent_message.msg_type,
              agent_message.subject, agent_message.resolution;
$$;

-- REST API: sessions
CREATE OR REPLACE FUNCTION workbench.api_sessions()
RETURNS TABLE(module text, status text, pid integer, started_at timestamptz,
              ended_at timestamptz, last_activity timestamptz)
LANGUAGE sql STABLE AS $$
  SELECT s.module, s.status, s.pid, s.started_at, s.ended_at, s.last_activity
    FROM workbench.agent_session s
   ORDER BY s.started_at DESC
   LIMIT 50;
$$;

-- REST API: hook events
CREATE OR REPLACE FUNCTION workbench.api_hooks(p_module text DEFAULT NULL)
RETURNS TABLE(id integer, module text, tool text, action text, allowed boolean,
              reason text, created_at timestamptz)
LANGUAGE sql STABLE AS $$
  SELECT h.id, h.module, h.tool, h.action, h.allowed, h.reason, h.created_at
    FROM workbench.hook_log h
   WHERE p_module IS NULL OR h.module = p_module
   ORDER BY h.created_at DESC
   LIMIT 100;
$$;

-- REST API: messages (with task delegation columns)
CREATE OR REPLACE FUNCTION workbench.api_messages(p_module text DEFAULT NULL)
RETURNS TABLE(id integer, from_module text, to_module text, msg_type text,
              subject text, body text, status text, resolution text,
              priority text, reply_to integer, payload jsonb, result jsonb,
              created_at timestamptz, resolved_at timestamptz)
LANGUAGE sql STABLE AS $$
  SELECT m.id, m.from_module, m.to_module, m.msg_type, m.subject, m.body,
         m.status, m.resolution, m.priority, m.reply_to,
         m.payload, m.result, m.created_at, m.resolved_at
    FROM workbench.agent_message m
   WHERE (p_module IS NULL OR m.from_module = p_module OR m.to_module = p_module)
   ORDER BY m.created_at DESC
   LIMIT 100;
$$;

-- PostgREST pre-request hook: set tenant context
CREATE OR REPLACE FUNCTION workbench.postgrest_pre_request()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_tenant text;
BEGIN
  -- Try JWT claim first (production), fallback to 'dev' (development)
  v_tenant := coalesce(
    current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id',
    'dev'
  );
  PERFORM set_config('app.tenant_id', v_tenant, true);
END;
$$;

-- Grants for PostgREST
GRANT USAGE ON SCHEMA workbench TO web_anon;
GRANT SELECT, INSERT, UPDATE ON workbench.config TO web_anon;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA workbench TO web_anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA workbench TO web_anon;
GRANT EXECUTE ON FUNCTION workbench.postgrest_pre_request() TO web_anon;
