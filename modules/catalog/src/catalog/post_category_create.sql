CREATE OR REPLACE FUNCTION catalog.post_category_create(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO catalog.category (name, parent_id)
  VALUES (
    trim(p_params->>'name'),
    nullif(p_params->>'parent_id', '')::int
  );

  RETURN pgv.toast(pgv.t('catalog.toast_category_created'))
    || pgv.redirect(pgv.call_ref('get_categories'));
END;
$function$;
