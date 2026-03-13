CREATE OR REPLACE FUNCTION catalog.post_article_modifier(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_params->>'id')::int;
BEGIN
  IF v_id IS NULL THEN
    RETURN pgv.toast(pgv.t('catalog.err_id_missing'), 'error');
  END IF;

  -- Modification partielle (toggle actif) ou complète
  IF p_params ? 'designation' THEN
    UPDATE catalog.article SET
      reference = nullif(trim(p_params->>'reference'), ''),
      designation = trim(p_params->>'designation'),
      description = nullif(trim(p_params->>'description'), ''),
      categorie_id = nullif(p_params->>'categorie_id', '')::int,
      unite = coalesce(nullif(p_params->>'unite', ''), 'u'),
      prix_vente = nullif(p_params->>'prix_vente', '')::numeric,
      prix_achat = nullif(p_params->>'prix_achat', '')::numeric,
      tva = coalesce(nullif(p_params->>'tva', '')::numeric, 20.00),
      updated_at = now()
    WHERE id = v_id;
  ELSE
    UPDATE catalog.article SET
      actif = coalesce((p_params->>'actif')::boolean, actif),
      updated_at = now()
    WHERE id = v_id;
  END IF;

  RETURN pgv.toast(pgv.t('catalog.toast_article_modified'))
    || pgv.redirect(pgv.call_ref('get_article', jsonb_build_object('p_id', v_id)));
END;
$function$;
