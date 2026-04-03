CREATE SCHEMA IF NOT EXISTS "plxdemo";

CREATE SCHEMA IF NOT EXISTS "plxdemo_ut";

CREATE OR REPLACE FUNCTION plxdemo.authorize(p_permission text) RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = plxdemo, pg_catalog, pg_temp AS $$
BEGIN
  IF current_setting('app.permissions', true) IS NULL THEN
    RAISE EXCEPTION 'forbidden: no permissions configured';
  END IF;
  IF NOT p_permission = ANY(string_to_array(current_setting('app.permissions', true), ',')) THEN
    RAISE EXCEPTION 'forbidden: % denied', p_permission;
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS plxdemo.project (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id'),
  name text NOT NULL UNIQUE,
  code text NOT NULL UNIQUE,
  description text,
  budget numeric,
  owner text,
  deadline date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'completed', 'archived'))
);

GRANT USAGE ON SCHEMA plxdemo TO anon;

REVOKE INSERT, UPDATE, DELETE ON TABLE plxdemo.project FROM anon;

CREATE INDEX IF NOT EXISTS idx_project_tenant ON plxdemo.project(tenant_id);

ALTER TABLE plxdemo.project ENABLE ROW LEVEL SECURITY;
ALTER TABLE plxdemo.project FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON plxdemo.project;
CREATE POLICY tenant_isolation ON plxdemo.project FOR ALL TO anon, authenticated
  USING (tenant_id = (SELECT current_setting('app.tenant_id')))
  WITH CHECK (tenant_id = (SELECT current_setting('app.tenant_id')));

CREATE TABLE IF NOT EXISTS plxdemo.task (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id'),
  rank int DEFAULT 0,
  note_id int,
  project_id int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb
);

ALTER TABLE plxdemo.task DROP CONSTRAINT IF EXISTS task_note_id_fkey;
ALTER TABLE plxdemo.task ADD CONSTRAINT task_note_id_fkey FOREIGN KEY (note_id) REFERENCES plxdemo.note(id);

ALTER TABLE plxdemo.task DROP CONSTRAINT IF EXISTS task_project_id_fkey;
ALTER TABLE plxdemo.task ADD CONSTRAINT task_project_id_fkey FOREIGN KEY (project_id) REFERENCES plxdemo.project(id);

GRANT USAGE ON SCHEMA plxdemo TO anon;

REVOKE INSERT, UPDATE, DELETE ON TABLE plxdemo.task FROM anon;

CREATE INDEX IF NOT EXISTS idx_task_tenant ON plxdemo.task(tenant_id);

ALTER TABLE plxdemo.task ENABLE ROW LEVEL SECURITY;
ALTER TABLE plxdemo.task FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON plxdemo.task;
CREATE POLICY tenant_isolation ON plxdemo.task FOR ALL TO anon, authenticated
  USING (tenant_id = (SELECT current_setting('app.tenant_id')))
  WITH CHECK (tenant_id = (SELECT current_setting('app.tenant_id')));

CREATE TABLE IF NOT EXISTS plxdemo.note (
  id serial PRIMARY KEY,
  tenant_id text NOT NULL DEFAULT current_setting('app.tenant_id'),
  title text NOT NULL,
  body text,
  pinned boolean DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

GRANT USAGE ON SCHEMA plxdemo TO anon;

REVOKE INSERT, UPDATE, DELETE ON TABLE plxdemo.note FROM anon;

CREATE INDEX IF NOT EXISTS idx_note_tenant ON plxdemo.note(tenant_id);

ALTER TABLE plxdemo.note ENABLE ROW LEVEL SECURITY;
ALTER TABLE plxdemo.note FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON plxdemo.note;
CREATE POLICY tenant_isolation ON plxdemo.note FOR ALL TO anon, authenticated
  USING (tenant_id = (SELECT current_setting('app.tenant_id')))
  WITH CHECK (tenant_id = (SELECT current_setting('app.tenant_id')));

CREATE TABLE IF NOT EXISTS plxdemo._event_outbox (
  id bigserial PRIMARY KEY,
  event_name text NOT NULL,
  aggregate_type text NOT NULL,
  aggregate_id text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  txid bigint NOT NULL DEFAULT txid_current(),
  causation_id bigint,
  correlation_id text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS plxdemo._event_subscription (
  event_name text NOT NULL,
  consumer_module text NOT NULL,
  consumer_key text NOT NULL,
  call_sql text NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  PRIMARY KEY (event_name, consumer_key)
);

CREATE TABLE IF NOT EXISTS plxdemo._event_delivery (
  event_id bigint NOT NULL REFERENCES plxdemo._event_outbox(id) ON DELETE CASCADE,
  consumer_key text NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, consumer_key)
);

CREATE OR REPLACE FUNCTION plxdemo._emit_event(
  p_event_name text,
  p_aggregate_type text,
  p_aggregate_id text,
  p_payload jsonb,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
  v_event_id bigint;
  v_causation_id bigint;
  v_correlation_id text;
BEGIN
  v_causation_id := nullif(current_setting('plx.current_event_id', true), '')::bigint;
  v_correlation_id := nullif(current_setting('plx.correlation_id', true), '');
  IF v_correlation_id IS NULL THEN
    v_correlation_id := txid_current()::text;
  END IF;

  INSERT INTO plxdemo._event_outbox (
    event_name,
    aggregate_type,
    aggregate_id,
    payload,
    metadata,
    causation_id,
    correlation_id
  ) VALUES (
    p_event_name,
    p_aggregate_type,
    p_aggregate_id,
    COALESCE(p_payload, '{}'::jsonb),
    COALESCE(p_metadata, '{}'::jsonb),
    v_causation_id,
    v_correlation_id
  )
  RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo._dispatch_event() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  rec record;
BEGIN
  IF pg_trigger_depth() > 32 THEN
    RAISE EXCEPTION 'plxdemo.err_event_dispatch_depth';
  END IF;

  PERFORM set_config('plx.current_event_id', NEW.id::text, true);
  PERFORM set_config('plx.correlation_id', NEW.correlation_id, true);

  FOR rec IN
    SELECT consumer_key, call_sql
    FROM plxdemo._event_subscription
    WHERE enabled
      AND event_name = NEW.event_name
  LOOP
    INSERT INTO plxdemo._event_delivery (event_id, consumer_key)
    VALUES (NEW.id, rec.consumer_key)
    ON CONFLICT DO NOTHING;

    IF FOUND THEN
      EXECUTE rec.call_sql USING NEW.payload;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS _dispatch_event_trigger ON plxdemo._event_outbox;
CREATE TRIGGER _dispatch_event_trigger
AFTER INSERT ON plxdemo._event_outbox
FOR EACH ROW
EXECUTE FUNCTION plxdemo._dispatch_event();

CREATE OR REPLACE FUNCTION plxdemo.project_event_trigger() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NULL;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    PERFORM plxdemo.project_on_update(NEW, OLD);
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    NULL;
    RETURN OLD;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS project_event_trigger ON plxdemo.project;
CREATE TRIGGER project_event_trigger
AFTER INSERT OR UPDATE OR DELETE ON plxdemo.project
FOR EACH ROW
EXECUTE FUNCTION plxdemo.project_event_trigger();

INSERT INTO plxdemo._event_subscription (
  event_name,
  consumer_module,
  consumer_key,
  call_sql,
  enabled
) VALUES (
  'plxdemo.project.activated',
  'plxdemo',
  'plxdemo.on_plxdemo_project_activated_1',
  'SELECT plxdemo.on_plxdemo_project_activated_1(($1->>''project_id'')::int)',
  true
)
ON CONFLICT (event_name, consumer_key) DO UPDATE
SET
  consumer_module = EXCLUDED.consumer_module,
  call_sql = EXCLUDED.call_sql,
  enabled = EXCLUDED.enabled;

CREATE SCHEMA IF NOT EXISTS "plxdemo_qa";
