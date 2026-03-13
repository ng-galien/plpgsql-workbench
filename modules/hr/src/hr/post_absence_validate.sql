CREATE OR REPLACE FUNCTION hr.post_absence_validate(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'id')::int;
  v_action text := COALESCE(p_data->>'action', '');
  v_employee_id int;
  v_new_statut text;
  v_absence record;
  v_balance numeric;
BEGIN
  IF v_action = 'valider' THEN
    v_new_statut := 'validee';
  ELSIF v_action = 'refuser' THEN
    v_new_statut := 'refusee';
  ELSIF v_action = 'annuler' THEN
    v_new_statut := 'annulee';
  ELSE
    RETURN pgv.toast('Action invalide.', 'error');
  END IF;

  -- Fetch absence details before update
  SELECT a.employee_id, a.type_absence, a.nb_jours, a.statut
    INTO v_absence
    FROM hr.absence a WHERE a.id = v_id;

  IF v_absence IS NULL THEN
    RETURN pgv.toast('Absence introuvable.', 'error');
  END IF;

  IF v_absence.statut <> 'demande' THEN
    RETURN pgv.toast('Absence déjà traitée.', 'error');
  END IF;

  -- Check leave balance before validating (only for types with balance)
  IF v_action = 'valider' AND v_absence.type_absence IN ('conge_paye', 'rtt') THEN
    SELECT (lb.allocated - lb.used) INTO v_balance
      FROM hr.leave_balance lb
     WHERE lb.employee_id = v_absence.employee_id
       AND lb.leave_type = v_absence.type_absence;

    IF v_balance IS NOT NULL AND v_balance < v_absence.nb_jours THEN
      RETURN pgv.toast('Solde insuffisant : ' || v_balance || 'j restants sur ' || v_absence.nb_jours || 'j demandés.', 'error');
    END IF;
  END IF;

  -- Update absence status
  UPDATE hr.absence SET statut = v_new_statut
    WHERE id = v_id AND statut = 'demande'
    RETURNING employee_id INTO v_employee_id;

  IF NOT FOUND THEN
    RETURN pgv.toast('Absence introuvable ou déjà traitée.', 'error');
  END IF;

  -- Decrement leave balance on validation
  IF v_action = 'valider' THEN
    UPDATE hr.leave_balance
       SET used = used + v_absence.nb_jours
     WHERE employee_id = v_employee_id
       AND leave_type = v_absence.type_absence;
  END IF;

  RETURN pgv.toast('Absence ' || v_new_statut || '.')
    || pgv.redirect(pgv.call_ref('get_employee', jsonb_build_object('p_id', v_employee_id)));
END;
$function$;
