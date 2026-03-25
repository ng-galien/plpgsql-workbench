CREATE OR REPLACE FUNCTION catalog.post_article_update(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_params->>'id')::int;
BEGIN
  IF v_id IS NULL THEN
    RETURN pgv.toast(pgv.t('catalog.err_id_missing'), 'error');
  END IF;

  IF p_params ? 'name' THEN
    UPDATE catalog.article SET
      reference = nullif(trim(p_params->>'reference'), ''),
      name = trim(p_params->>'name'),
      description = nullif(trim(p_params->>'description'), ''),
      category_id = nullif(p_params->>'category_id', '')::int,
      unit = coalesce(nullif(p_params->>'unit', ''), 'u'),
      sale_price = nullif(p_params->>'sale_price', '')::numeric,
      purchase_price = nullif(p_params->>'purchase_price', '')::numeric,
      vat_rate = coalesce(nullif(p_params->>'vat_rate', '')::numeric, 20.00),
      updated_at = now()
    WHERE id = v_id;
  ELSE
    UPDATE catalog.article SET
      active = coalesce((p_params->>'active')::boolean, active),
      updated_at = now()
    WHERE id = v_id;
  END IF;

  RETURN pgv.toast(pgv.t('catalog.toast_article_updated'))
    || pgv.redirect(pgv.call_ref('get_article', jsonb_build_object('p_id', v_id)));
END;
$function$;
