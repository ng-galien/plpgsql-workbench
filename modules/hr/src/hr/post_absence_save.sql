CREATE OR REPLACE FUNCTION hr.post_absence_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_employee_id int := (p_data->>'employee_id')::int;
  v_date_debut date;
  v_date_fin date;
  v_nb_jours numeric;
BEGIN
  IF v_employee_id IS NULL THEN
    RETURN pgv.toast('Salarié manquant.', 'error');
  END IF;

  v_date_debut := (p_data->>'date_debut')::date;
  v_date_fin := (p_data->>'date_fin')::date;
  v_nb_jours := (p_data->>'nb_jours')::numeric;

  IF v_date_debut IS NULL OR v_date_fin IS NULL OR v_nb_jours IS NULL THEN
    RETURN pgv.toast('Dates et nombre de jours obligatoires.', 'error');
  END IF;

  IF v_date_fin < v_date_debut THEN
    RETURN pgv.toast('La date de fin doit être après la date de début.', 'error');
  END IF;

  INSERT INTO hr.absence (employee_id, type_absence, date_debut, date_fin, nb_jours, motif)
  VALUES (
    v_employee_id,
    COALESCE(NULLIF(trim(p_data->>'type_absence'), ''), 'conge_paye'),
    v_date_debut,
    v_date_fin,
    v_nb_jours,
    COALESCE(trim(p_data->>'motif'), '')
  );

  RETURN pgv.toast('Absence déclarée.')
    || pgv.redirect(pgv.call_ref('get_employee', jsonb_build_object('p_id', v_employee_id)));
END;
$function$;
