CREATE OR REPLACE FUNCTION hr.post_absence_validate(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'id')::int;
  v_action text := COALESCE(p_data->>'action', '');
  v_employee_id int;
  v_new_statut text;
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

  UPDATE hr.absence SET statut = v_new_statut
    WHERE id = v_id AND statut = 'demande'
    RETURNING employee_id INTO v_employee_id;

  IF NOT FOUND THEN
    RETURN pgv.toast('Absence introuvable ou déjà traitée.', 'error');
  END IF;

  RETURN pgv.toast('Absence ' || v_new_statut || '.')
    || pgv.redirect(pgv.call_ref('get_employee', jsonb_build_object('p_id', v_employee_id)));
END;
$function$;
