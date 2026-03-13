CREATE OR REPLACE FUNCTION catalog.post_categorie_creer(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO catalog.categorie (nom, parent_id)
  VALUES (
    trim(p_params->>'nom'),
    nullif(p_params->>'parent_id', '')::int
  );

  RETURN pgv.toast(pgv.t('catalog.toast_categorie_created'))
    || pgv.redirect(pgv.call_ref('get_categories'));
END;
$function$;
