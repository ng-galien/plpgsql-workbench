CREATE OR REPLACE FUNCTION hr.post_timesheet_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_employee_id int := (p_data->>'employee_id')::int;
  v_date date;
  v_heures numeric;
BEGIN
  IF v_employee_id IS NULL THEN
    RETURN pgv.toast('Salarié manquant.', 'error');
  END IF;

  v_date := (p_data->>'date_travail')::date;
  v_heures := (p_data->>'heures')::numeric;

  IF v_date IS NULL OR v_heures IS NULL THEN
    RETURN pgv.toast('Date et heures obligatoires.', 'error');
  END IF;

  IF v_heures < 0 OR v_heures > 24 THEN
    RETURN pgv.toast('Heures entre 0 et 24.', 'error');
  END IF;

  INSERT INTO hr.timesheet (employee_id, date_travail, heures, description)
  VALUES (v_employee_id, v_date, v_heures, COALESCE(trim(p_data->>'description'), ''))
  ON CONFLICT (employee_id, date_travail)
  DO UPDATE SET heures = EXCLUDED.heures, description = EXCLUDED.description;

  RETURN pgv.toast('Heures enregistrées.')
    || pgv.redirect(pgv.call_ref('get_employee', jsonb_build_object('p_id', v_employee_id)));
END;
$function$;
