-- Bootstrap — runs after all modules are deployed
-- Pre-request, tenant, module registrations

-- PostgREST pre_request (sets app.tenant_id per request)
CREATE OR REPLACE FUNCTION workbench.postgrest_pre_request()
 RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_tenant text;
BEGIN
  v_tenant := coalesce(
    current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id',
    'dev'
  );
  PERFORM set_config('app.tenant_id', v_tenant, true);
END; $$;
GRANT EXECUTE ON FUNCTION workbench.postgrest_pre_request() TO anon;
ALTER ROLE authenticator SET pgrst.db_pre_request = 'workbench.postgrest_pre_request';

-- Dev tenant
INSERT INTO workbench.tenant (id, name, slug, plan, active)
VALUES ('dev', 'Dev Workbench', 'dev', 'equipe', true)
ON CONFLICT DO NOTHING;

-- Module registrations
INSERT INTO workbench.tenant_module (tenant_id, module, active, sort_order) VALUES
  ('dev', 'pgv', true, 0),
  ('dev', 'workbench', true, 5),
  ('dev', 'docs', true, 6),
  ('dev', 'asset', true, 7),
  ('dev', 'ops', true, 8),
  ('dev', 'crm', true, 10),
  ('dev', 'quote', true, 15),
  ('dev', 'project', true, 20),
  ('dev', 'planning', true, 25),
  ('dev', 'cad', true, 30),
  ('dev', 'purchase', true, 40),
  ('dev', 'stock', true, 50),
  ('dev', 'ledger', true, 60),
  ('dev', 'hr', true, 80)
ON CONFLICT DO NOTHING;

-- Supabase Realtime — enable CDC for agent messaging (skip on dev stack without Supabase)
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS workbench.agent_message;
  ALTER TABLE workbench.agent_message REPLICA IDENTITY FULL;
EXCEPTION WHEN undefined_object THEN
  RAISE NOTICE 'supabase_realtime publication not found — skipping (dev stack without Supabase)';
END $$;

-- Grants for browser issue reporting (anon role via PostgREST)
GRANT INSERT ON workbench.issue_report TO anon;
GRANT USAGE ON SEQUENCE workbench.issue_report_id_seq TO anon;
GRANT INSERT ON workbench.agent_message TO anon;
GRANT USAGE ON SEQUENCE workbench.agent_message_id_seq TO anon;
