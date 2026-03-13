CREATE OR REPLACE FUNCTION hr_ut.test_employee_crud()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- Create
  v_result := hr.post_employee_save(jsonb_build_object(
    'nom', 'Dupont', 'prenom', 'Jean', 'email', 'jean@test.com',
    'poste', 'Développeur', 'departement', 'IT', 'type_contrat', 'cdi'
  ));
  RETURN NEXT ok(v_result LIKE '%Salarié créé%', 'create employee returns success toast');

  SELECT id INTO v_id FROM hr.employee WHERE nom = 'Dupont' AND prenom = 'Jean';
  RETURN NEXT ok(v_id IS NOT NULL, 'employee inserted in DB');

  -- Read
  v_result := hr.get_employee(v_id);
  RETURN NEXT ok(v_result LIKE '%Dupont%', 'get_employee contains name');
  RETURN NEXT ok(v_result LIKE '%Développeur%', 'get_employee contains poste');
  RETURN NEXT ok(v_result LIKE '%CDI%', 'get_employee contains contract type');

  -- Update
  v_result := hr.post_employee_save(jsonb_build_object(
    'id', v_id, 'nom', 'Dupont', 'prenom', 'Jean',
    'poste', 'Lead Dev', 'departement', 'IT', 'type_contrat', 'cdi'
  ));
  RETURN NEXT ok(v_result LIKE '%mis à jour%', 'update employee returns success toast');
  RETURN NEXT ok((SELECT poste FROM hr.employee WHERE id = v_id) = 'Lead Dev', 'poste updated in DB');

  -- Delete
  v_result := hr.post_employee_delete(jsonb_build_object('id', v_id));
  RETURN NEXT ok(v_result LIKE '%supprimé%', 'delete returns success toast');
  RETURN NEXT ok(NOT EXISTS(SELECT 1 FROM hr.employee WHERE id = v_id), 'employee deleted from DB');

  -- Validation
  v_result := hr.post_employee_save(jsonb_build_object('nom', '', 'prenom', ''));
  RETURN NEXT ok(v_result LIKE '%obligatoires%', 'empty name/prenom rejected');
END;
$function$;
