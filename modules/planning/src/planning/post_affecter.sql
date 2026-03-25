CREATE OR REPLACE FUNCTION planning.post_affecter(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_evenement_id int := (p_data->>'p_evenement_id')::int;
  v_intervenant_id int := (p_data->>'p_intervenant_id')::int;
BEGIN
  INSERT INTO planning.affectation (evenement_id, intervenant_id)
  VALUES (v_evenement_id, v_intervenant_id)
  ON CONFLICT (evenement_id, intervenant_id) DO NOTHING;

  RETURN pgv.toast(pgv.t('planning.toast_affecte'))
      || pgv.redirect(pgv.call_ref('get_evenement', jsonb_build_object('p_id', v_evenement_id)));
END;
$function$;
