CREATE OR REPLACE FUNCTION hr.post_timesheet_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_employee_id int := (p_data->>'employee_id')::int;
  v_date date;
  v_hours numeric;
BEGIN
  IF v_employee_id IS NULL THEN
    RETURN pgv.toast('Salarié manquant.', 'error');
  END IF;

  v_date := (COALESCE(p_data->>'work_date', p_data->>'date_travail'))::date;
  v_hours := (COALESCE(p_data->>'hours', p_data->>'heures'))::numeric;

  IF v_date IS NULL OR v_hours IS NULL THEN
    RETURN pgv.toast('Date et heures obligatoires.', 'error');
  END IF;

  IF v_hours < 0 OR v_hours > 24 THEN
    RETURN pgv.toast('Heures entre 0 et 24.', 'error');
  END IF;

  INSERT INTO hr.timesheet (employee_id, work_date, hours, description)
  VALUES (v_employee_id, v_date, v_hours, COALESCE(trim(p_data->>'description'), ''))
  ON CONFLICT (employee_id, work_date)
  DO UPDATE SET hours = EXCLUDED.hours, description = EXCLUDED.description;

  RETURN pgv.toast('Heures enregistrées.')
    || pgv.redirect(pgv.call_ref('get_employee', jsonb_build_object('p_id', v_employee_id)));
END;
$function$;
