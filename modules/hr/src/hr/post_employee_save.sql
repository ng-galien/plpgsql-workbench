CREATE OR REPLACE FUNCTION hr.post_employee_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int;
  v_last text := trim(COALESCE(p_data->>'last_name', p_data->>'nom', ''));
  v_first text := trim(COALESCE(p_data->>'first_name', p_data->>'prenom', ''));
BEGIN
  IF v_last = '' OR v_first = '' THEN
    RETURN pgv.toast('Nom et prénom obligatoires.', 'error');
  END IF;

  v_id := (p_data->>'id')::int;

  IF v_id IS NOT NULL THEN
    UPDATE hr.employee SET
      last_name = v_last,
      first_name = v_first,
      email = NULLIF(trim(COALESCE(p_data->>'email', '')), ''),
      phone = NULLIF(trim(COALESCE(p_data->>'phone', '')), ''),
      employee_code = COALESCE(trim(p_data->>'employee_code'), employee_code),
      birth_date = (NULLIF(trim(COALESCE(p_data->>'birth_date', '')), ''))::date,
      position = COALESCE(trim(p_data->>'position'), position),
      department = COALESCE(trim(p_data->>'department'), department),
      gender = COALESCE(NULLIF(trim(p_data->>'gender'), ''), gender),
      nationality = COALESCE(trim(p_data->>'nationality'), nationality),
      qualification = COALESCE(trim(p_data->>'qualification'), qualification),
      contract_type = COALESCE(NULLIF(trim(p_data->>'contract_type'), ''), contract_type),
      hire_date = COALESCE((NULLIF(trim(p_data->>'hire_date'), ''))::date, hire_date),
      end_date = (NULLIF(trim(COALESCE(p_data->>'end_date', '')), ''))::date,
      weekly_hours = COALESCE((NULLIF(trim(p_data->>'weekly_hours'), ''))::numeric, weekly_hours),
      notes = COALESCE(trim(p_data->>'notes'), notes)
    WHERE id = v_id;

    IF NOT FOUND THEN
      RETURN pgv.toast('Salarié introuvable.', 'error');
    END IF;

    RETURN pgv.toast('Salarié mis à jour.')
      || pgv.redirect(pgv.call_ref('get_employee', jsonb_build_object('p_id', v_id)));
  ELSE
    INSERT INTO hr.employee (last_name, first_name, email, phone, employee_code, birth_date, gender, nationality, position, department, qualification, contract_type, hire_date, end_date, weekly_hours, notes)
    VALUES (
      v_last, v_first,
      NULLIF(trim(COALESCE(p_data->>'email', '')), ''),
      NULLIF(trim(COALESCE(p_data->>'phone', '')), ''),
      COALESCE(trim(p_data->>'employee_code'), ''),
      (NULLIF(trim(COALESCE(p_data->>'birth_date', '')), ''))::date,
      COALESCE(NULLIF(trim(p_data->>'gender'), ''), ''),
      COALESCE(trim(p_data->>'nationality'), ''),
      COALESCE(trim(p_data->>'position'), ''),
      COALESCE(trim(p_data->>'department'), ''),
      COALESCE(trim(p_data->>'qualification'), ''),
      COALESCE(NULLIF(trim(p_data->>'contract_type'), ''), 'cdi'),
      COALESCE((NULLIF(trim(p_data->>'hire_date'), ''))::date, CURRENT_DATE),
      (NULLIF(trim(COALESCE(p_data->>'end_date', '')), ''))::date,
      COALESCE((NULLIF(trim(p_data->>'weekly_hours'), ''))::numeric, 35),
      COALESCE(trim(p_data->>'notes'), '')
    )
    RETURNING id INTO v_id;

    RETURN pgv.toast('Salarié créé.')
      || pgv.redirect(pgv.call_ref('get_employee', jsonb_build_object('p_id', v_id)));
  END IF;
END;
$function$;
