CREATE OR REPLACE FUNCTION stock.post_warehouse_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int;
BEGIN
  v_id := (p_data->>'id')::int;

  IF v_id IS NOT NULL AND v_id > 0 THEN
    UPDATE stock.warehouse SET
      name = p_data->>'name',
      type = p_data->>'type',
      address = nullif(p_data->>'address', '')
    WHERE id = v_id;

    RETURN pgv.toast(pgv.t('stock.toast_depot_modifie'))
      || pgv.redirect(pgv.call_ref('get_warehouse', jsonb_build_object('p_id', v_id)));
  ELSE
    INSERT INTO stock.warehouse (name, type, address)
    VALUES (p_data->>'name', p_data->>'type', nullif(p_data->>'address', ''))
    RETURNING id INTO v_id;

    RETURN pgv.toast(pgv.t('stock.toast_depot_cree'))
      || pgv.redirect(pgv.call_ref('get_warehouse', jsonb_build_object('p_id', v_id)));
  END IF;
END;
$function$;
