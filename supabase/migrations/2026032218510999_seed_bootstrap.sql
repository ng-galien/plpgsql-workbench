-- Bootstrap seed: pre_request, tenant, modules, i18n, QA data

-- 1. PostgREST pre_request
CREATE OR REPLACE FUNCTION workbench.postgrest_pre_request()
 RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_tenant text;
BEGIN
  v_tenant := coalesce(current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id', 'dev');
  PERFORM set_config('app.tenant_id', v_tenant, true);
END; $$;
GRANT EXECUTE ON FUNCTION workbench.postgrest_pre_request() TO anon;
ALTER ROLE authenticator SET pgrst.db_pre_request = 'workbench.postgrest_pre_request';

-- 2. Dev tenant + modules
INSERT INTO workbench.tenant (id, name, slug, plan, active) VALUES ('dev', 'Dev Workbench', 'dev', 'equipe', true) ON CONFLICT DO NOTHING;
INSERT INTO workbench.tenant_module (tenant_id, module, active, sort_order) VALUES
  ('dev','pgv',true,0),('dev','workbench',true,5),('dev','docs',true,6),
  ('dev','asset',true,7),('dev','ops',true,8),('dev','crm',true,10),
  ('dev','quote',true,15),('dev','project',true,20),('dev','planning',true,25),
  ('dev','cad',true,30),('dev','purchase',true,40),('dev','stock',true,50),
  ('dev','ledger',true,60),('dev','hr',true,80)
ON CONFLICT DO NOTHING;

-- 3. i18n seed
SET app.tenant_id = 'dev';
SELECT pgv.i18n_seed();
SELECT workbench.i18n_seed();
SELECT docs.i18n_seed();
SELECT asset.i18n_seed();
SELECT crm.i18n_seed();
SELECT quote.i18n_seed();
SELECT cad.i18n_seed();
SELECT project.i18n_seed();
SELECT planning.i18n_seed();
SELECT stock.i18n_seed();
SELECT purchase.i18n_seed();
SELECT catalog.i18n_seed();
SELECT ledger.i18n_seed();
SELECT expense.i18n_seed();
SELECT hr.i18n_seed();

-- 4. QA seed docs
SELECT docs_qa.seed();
