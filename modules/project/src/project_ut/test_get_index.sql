CREATE OR REPLACE FUNCTION project_ut.test_get_index()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_cli_id int;
  v_ch_id  int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  PERFORM set_config('pgv.route_prefix', '/project', true);

  -- Renders with existing QA data
  v_html := project.get_index();
  RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 50, 'get_index renders');
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'has stats grid');
  RETURN NEXT ok(v_html LIKE '%Nouveau projet%', 'has new projet button');

  -- Create a late chantier to trigger alerts
  INSERT INTO crm.client(type, name, email, tenant_id) VALUES ('individual', 'RetardCli', 'retard@test.com', 'dev') RETURNING id INTO v_cli_id;
  INSERT INTO project.chantier(numero, client_id, objet, statut, date_fin_prevue, tenant_id)
    VALUES ('CHT-RETARD-01', v_cli_id, 'Chantier en retard', 'execution', CURRENT_DATE - 10, 'dev')
    RETURNING id INTO v_ch_id;

  v_html := project.get_index();
  RETURN NEXT ok(v_html LIKE '%Alertes retard%', 'has alerts section');
  RETURN NEXT ok(v_html LIKE '%CHT-RETARD-01%', 'shows late chantier');
  RETURN NEXT ok(v_html LIKE '%pgv-badge-warn%', 'has warn badge');
  RETURN NEXT ok(v_html LIKE '%Projets actifs%', 'has active projets section');

  -- Cleanup
  DELETE FROM project.chantier WHERE id = v_ch_id;
  DELETE FROM crm.client WHERE id = v_cli_id;
END;
$function$;
