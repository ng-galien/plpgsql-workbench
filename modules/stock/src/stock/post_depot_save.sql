CREATE OR REPLACE FUNCTION stock.post_depot_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
BEGIN
  v_id := (p_data->>'id')::int;

  IF v_id IS NOT NULL AND v_id > 0 THEN
    UPDATE stock.depot SET
      nom = p_data->>'nom',
      type = p_data->>'type',
      adresse = nullif(p_data->>'adresse', '')
    WHERE id = v_id;

    RETURN pgv.toast(pgv.t('stock.toast_depot_modifie'))
      || pgv.redirect(pgv.call_ref('get_depot', jsonb_build_object('p_id', v_id)));
  ELSE
    INSERT INTO stock.depot (nom, type, adresse)
    VALUES (p_data->>'nom', p_data->>'type', nullif(p_data->>'adresse', ''))
    RETURNING id INTO v_id;

    RETURN pgv.toast(pgv.t('stock.toast_depot_cree'))
      || pgv.redirect(pgv.call_ref('get_depot', jsonb_build_object('p_id', v_id)));
  END IF;
END;
$function$;
