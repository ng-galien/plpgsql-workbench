CREATE OR REPLACE FUNCTION hr.post_absence_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_employee_id int := (p_data->>'employee_id')::int;
  v_start date;
  v_end date;
  v_days numeric;
  v_type text;
  v_balance numeric;
  v_warning text := '';
BEGIN
  IF v_employee_id IS NULL THEN
    RETURN pgv.toast('Salarié manquant.', 'error');
  END IF;

  v_start := (p_data->>'start_date')::date;
  v_end := (p_data->>'end_date')::date;
  v_days := (p_data->>'day_count')::numeric;
  v_type := COALESCE(NULLIF(trim(p_data->>'leave_type'), ''), 'paid_leave');

  IF v_start IS NULL OR v_end IS NULL OR v_days IS NULL THEN
    RETURN pgv.toast('Dates et nombre de jours obligatoires.', 'error');
  END IF;

  IF v_end < v_start THEN
    RETURN pgv.toast('La date de fin doit être après la date de début.', 'error');
  END IF;

  IF v_type IN ('paid_leave', 'rtt') THEN
    SELECT (lb.allocated - lb.used) INTO v_balance
      FROM hr.leave_balance lb
     WHERE lb.employee_id = v_employee_id
       AND lb.leave_type = v_type;

    IF v_balance IS NOT NULL AND v_balance < v_days THEN
      v_warning := ' Attention : solde insuffisant (' || v_balance || 'j restants).';
    END IF;
  END IF;

  INSERT INTO hr.leave_request (employee_id, leave_type, start_date, end_date, day_count, reason)
  VALUES (
    v_employee_id,
    v_type,
    v_start,
    v_end,
    v_days,
    COALESCE(trim(p_data->>'reason'), '')
  );

  RETURN pgv.toast('Absence déclarée.' || v_warning)
    || pgv.redirect(pgv.call_ref('get_employee', jsonb_build_object('p_id', v_employee_id)));
END;
$function$;
