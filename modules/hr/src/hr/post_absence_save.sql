CREATE OR REPLACE FUNCTION hr.post_absence_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_employee_id int := (p_data->>'employee_id')::int;
  v_date_debut date;
  v_date_fin date;
  v_nb_jours numeric;
  v_type text;
  v_balance numeric;
  v_warning text := '';
BEGIN
  IF v_employee_id IS NULL THEN
    RETURN pgv.toast('Salarié manquant.', 'error');
  END IF;

  v_date_debut := (p_data->>'date_debut')::date;
  v_date_fin := (p_data->>'date_fin')::date;
  v_nb_jours := (p_data->>'nb_jours')::numeric;
  v_type := COALESCE(NULLIF(trim(p_data->>'type_absence'), ''), 'conge_paye');

  IF v_date_debut IS NULL OR v_date_fin IS NULL OR v_nb_jours IS NULL THEN
    RETURN pgv.toast('Dates et nombre de jours obligatoires.', 'error');
  END IF;

  IF v_date_fin < v_date_debut THEN
    RETURN pgv.toast('La date de fin doit être après la date de début.', 'error');
  END IF;

  IF v_type IN ('conge_paye', 'rtt') THEN
    SELECT (lb.allocated - lb.used) INTO v_balance
      FROM hr.leave_balance lb
     WHERE lb.employee_id = v_employee_id
       AND lb.leave_type = v_type;

    IF v_balance IS NOT NULL AND v_balance < v_nb_jours THEN
      v_warning := ' Attention : solde insuffisant (' || v_balance || 'j restants).';
    END IF;
  END IF;

  INSERT INTO hr.absence (employee_id, type_absence, date_debut, date_fin, nb_jours, motif)
  VALUES (
    v_employee_id,
    v_type,
    v_date_debut,
    v_date_fin,
    v_nb_jours,
    COALESCE(trim(p_data->>'motif'), '')
  );

  RETURN pgv.toast('Absence déclarée.' || v_warning)
    || pgv.redirect(pgv.call_ref('get_employee', jsonb_build_object('p_id', v_employee_id)));
END;
$function$;
