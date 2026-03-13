CREATE OR REPLACE FUNCTION hr_ut.test_absence_workflow()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_emp_id int;
  v_abs_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- Setup: create employee
  INSERT INTO hr.employee (nom, prenom) VALUES ('Test', 'Absence') RETURNING id INTO v_emp_id;

  -- Declare absence
  v_result := hr.post_absence_save(jsonb_build_object(
    'employee_id', v_emp_id, 'type_absence', 'conge_paye',
    'date_debut', '2026-04-01', 'date_fin', '2026-04-05', 'nb_jours', 5
  ));
  RETURN NEXT ok(v_result LIKE '%déclarée%', 'absence declared');

  SELECT id INTO v_abs_id FROM hr.absence WHERE employee_id = v_emp_id;
  RETURN NEXT ok(v_abs_id IS NOT NULL, 'absence inserted');
  RETURN NEXT is((SELECT statut FROM hr.absence WHERE id = v_abs_id), 'demande', 'initial status is demande');

  -- Validate
  v_result := hr.post_absence_validate(jsonb_build_object('id', v_abs_id, 'action', 'valider'));
  RETURN NEXT ok(v_result LIKE '%validee%', 'validate returns success');
  RETURN NEXT is((SELECT statut FROM hr.absence WHERE id = v_abs_id), 'validee', 'status updated to validee');

  -- Cannot validate again
  v_result := hr.post_absence_validate(jsonb_build_object('id', v_abs_id, 'action', 'refuser'));
  RETURN NEXT ok(v_result LIKE '%déjà traitée%', 'double validation rejected');

  -- Validation errors
  v_result := hr.post_absence_save(jsonb_build_object(
    'employee_id', v_emp_id, 'type_absence', 'rtt',
    'date_debut', '2026-04-10', 'date_fin', '2026-04-05', 'nb_jours', 3
  ));
  RETURN NEXT ok(v_result LIKE '%après la date%', 'date_fin < date_debut rejected');

  -- Cleanup
  DELETE FROM hr.absence WHERE employee_id = v_emp_id;
  DELETE FROM hr.employee WHERE id = v_emp_id;
END;
$function$;
