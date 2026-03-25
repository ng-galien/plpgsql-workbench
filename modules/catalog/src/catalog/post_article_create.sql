CREATE OR REPLACE FUNCTION catalog.post_article_create(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int;
BEGIN
  INSERT INTO catalog.article (reference, name, description, category_id, unit, sale_price, purchase_price, vat_rate)
  VALUES (
    nullif(trim(p_params->>'reference'), ''),
    trim(p_params->>'name'),
    nullif(trim(p_params->>'description'), ''),
    nullif(p_params->>'category_id', '')::int,
    coalesce(nullif(p_params->>'unit', ''), 'u'),
    nullif(p_params->>'sale_price', '')::numeric,
    nullif(p_params->>'purchase_price', '')::numeric,
    coalesce(nullif(p_params->>'vat_rate', '')::numeric, 20.00)
  ) RETURNING id INTO v_id;

  RETURN pgv.toast(pgv.t('catalog.toast_article_created'))
    || pgv.redirect(pgv.call_ref('get_article', jsonb_build_object('p_id', v_id)));
END;
$function$;
