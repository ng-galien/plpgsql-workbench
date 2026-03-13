CREATE OR REPLACE FUNCTION planning.post_desaffecter(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
  v_evenement_id int := (p_data->>'p_evenement_id')::int;
BEGIN
  DELETE FROM planning.affectation WHERE id = v_id;
  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('planning.toast_affectation_not_found'), 'error');
  END IF;
  RETURN pgv.toast(pgv.t('planning.toast_desaffecte'))
      || pgv.redirect(pgv.call_ref('get_evenement', jsonb_build_object('p_id', v_evenement_id)));
END;
$function$;
