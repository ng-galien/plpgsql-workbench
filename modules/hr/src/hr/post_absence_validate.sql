CREATE OR REPLACE FUNCTION hr.post_absence_validate(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'id')::int;
  v_action text := COALESCE(p_data->>'action', '');
  v_employee_id int;
  v_new_status text;
  v_leave record;
  v_balance numeric;
BEGIN
  IF v_action = 'validate' THEN
    v_new_status := 'approved';
  ELSIF v_action = 'refuse' THEN
    v_new_status := 'rejected';
  ELSIF v_action = 'cancel' THEN
    v_new_status := 'cancelled';
  -- Legacy French action names for backward compat with pgView forms
  ELSIF v_action = 'valider' THEN
    v_new_status := 'approved';
  ELSIF v_action = 'refuser' THEN
    v_new_status := 'rejected';
  ELSIF v_action = 'annuler' THEN
    v_new_status := 'cancelled';
  ELSE
    RETURN pgv.toast('Action invalide.', 'error');
  END IF;

  SELECT a.employee_id, a.leave_type, a.day_count, a.status
    INTO v_leave
    FROM hr.leave_request a WHERE a.id = v_id;

  IF v_leave IS NULL THEN
    RETURN pgv.toast('Absence introuvable.', 'error');
  END IF;

  IF v_leave.status <> 'pending' THEN
    RETURN pgv.toast('Absence déjà traitée.', 'error');
  END IF;

  IF v_new_status = 'approved' AND v_leave.leave_type IN ('paid_leave', 'rtt') THEN
    SELECT (lb.allocated - lb.used) INTO v_balance
      FROM hr.leave_balance lb
     WHERE lb.employee_id = v_leave.employee_id
       AND lb.leave_type = v_leave.leave_type;

    IF v_balance IS NOT NULL AND v_balance < v_leave.day_count THEN
      RETURN pgv.toast('Solde insuffisant : ' || v_balance || 'j restants sur ' || v_leave.day_count || 'j demandés.', 'error');
    END IF;
  END IF;

  UPDATE hr.leave_request SET status = v_new_status
    WHERE id = v_id AND status = 'pending'
    RETURNING employee_id INTO v_employee_id;

  IF NOT FOUND THEN
    RETURN pgv.toast('Absence introuvable ou déjà traitée.', 'error');
  END IF;

  IF v_new_status = 'approved' THEN
    UPDATE hr.leave_balance
       SET used = used + v_leave.day_count
     WHERE employee_id = v_employee_id
       AND leave_type = v_leave.leave_type;
  END IF;

  RETURN pgv.toast('Absence ' || v_new_status || '.')
    || pgv.redirect(pgv.call_ref('get_employee', jsonb_build_object('p_id', v_employee_id)));
END;
$function$;
