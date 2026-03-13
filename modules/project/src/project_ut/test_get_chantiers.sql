CREATE OR REPLACE FUNCTION project_ut.test_get_chantiers()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_cid  int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  PERFORM set_config('pgv.route_prefix', '/project', true);

  -- Seed one chantier for testing
  INSERT INTO crm.client(type, name, email, tenant_id) VALUES ('individual', 'TestFilterCli', 'tf@test.com', 'dev') RETURNING id INTO v_cid;
  INSERT INTO project.chantier(numero, client_id, objet, statut, tenant_id)
    VALUES ('CHT-TEST-F01', v_cid, 'Objet filtre test', 'execution', 'dev');

  -- No filter => has rows
  v_html := project.get_chantiers();
  RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 50, 'get_chantiers no filter renders');
  RETURN NEXT ok(v_html LIKE '%CHT-TEST-F01%', 'no filter shows test chantier');
  RETURN NEXT ok(v_html LIKE '%Filtrer%', 'has filter button');

  -- Statut filter
  v_html := project.get_chantiers('{"statut":"execution"}'::jsonb);
  RETURN NEXT ok(v_html LIKE '%CHT-TEST-F01%', 'statut execution shows test chantier');
  RETURN NEXT ok(v_html LIKE '%selected%', 'execution option selected');

  v_html := project.get_chantiers('{"statut":"clos"}'::jsonb);
  RETURN NEXT ok(v_html NOT LIKE '%CHT-TEST-F01%', 'statut clos hides test chantier');

  -- Text search
  v_html := project.get_chantiers('{"q":"TestFilterCli"}'::jsonb);
  RETURN NEXT ok(v_html LIKE '%CHT-TEST-F01%', 'search by client name works');

  v_html := project.get_chantiers('{"q":"Objet filtre"}'::jsonb);
  RETURN NEXT ok(v_html LIKE '%CHT-TEST-F01%', 'search by objet works');

  v_html := project.get_chantiers('{"q":"ZZZZNOTFOUND"}'::jsonb);
  RETURN NEXT ok(v_html LIKE '%Aucun projet%', 'no results shows empty msg');

  -- Combined filter
  v_html := project.get_chantiers('{"statut":"execution","q":"TestFilterCli"}'::jsonb);
  RETURN NEXT ok(v_html LIKE '%CHT-TEST-F01%', 'combined filter works');

  -- Cleanup
  DELETE FROM project.chantier WHERE numero = 'CHT-TEST-F01';
  DELETE FROM crm.client WHERE id = v_cid;
END;
$function$;
