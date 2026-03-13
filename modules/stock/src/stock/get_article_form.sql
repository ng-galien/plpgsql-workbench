CREATE OR REPLACE FUNCTION stock.get_article_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_art stock.article;
  v_cat_opts jsonb;
  v_unit_opts jsonb;
  v_fournisseur_opts jsonb;
  v_catalog_search text;
  v_catalog_display text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_art FROM stock.article WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.empty(pgv.t('stock.empty_article_not_found'), ''); END IF;
  END IF;

  v_cat_opts := jsonb_build_array(
    jsonb_build_object('value', 'bois', 'label', pgv.t('stock.cat_bois')),
    jsonb_build_object('value', 'quincaillerie', 'label', pgv.t('stock.cat_quincaillerie')),
    jsonb_build_object('value', 'panneau', 'label', pgv.t('stock.cat_panneau')),
    jsonb_build_object('value', 'isolant', 'label', pgv.t('stock.cat_isolant')),
    jsonb_build_object('value', 'finition', 'label', pgv.t('stock.cat_finition')),
    jsonb_build_object('value', 'autre', 'label', pgv.t('stock.cat_autre'))
  );

  v_unit_opts := jsonb_build_array(
    jsonb_build_object('value', 'u', 'label', pgv.t('stock.unit_u')),
    jsonb_build_object('value', 'm', 'label', pgv.t('stock.unit_m')),
    jsonb_build_object('value', 'm2', 'label', pgv.t('stock.unit_m2')),
    jsonb_build_object('value', 'm3', 'label', pgv.t('stock.unit_m3')),
    jsonb_build_object('value', 'kg', 'label', pgv.t('stock.unit_kg')),
    jsonb_build_object('value', 'l', 'label', pgv.t('stock.unit_l'))
  );

  SELECT coalesce(jsonb_agg(jsonb_build_object('value', c.id::text, 'label', c.name) ORDER BY c.name), '[]'::jsonb)
  INTO v_fournisseur_opts
  FROM crm.client c WHERE c.type = 'company' AND c.active;

  v_catalog_search := '';
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'catalog') THEN
    v_catalog_display := NULL;
    IF v_art.catalog_article_id IS NOT NULL THEN
      SELECT ca.designation INTO v_catalog_display
      FROM catalog.article ca WHERE ca.id = v_art.catalog_article_id;
    END IF;
    v_catalog_search := pgv.select_search(
      'catalog_article_id', pgv.t('stock.field_article_catalog'),
      'catalog.article_options',
      pgv.t('stock.ph_search_catalog'),
      v_art.catalog_article_id::text,
      v_catalog_display
    );
  END IF;

  RETURN '<input type="hidden" name="id" value="' || coalesce(p_id::text, '') || '">'
    || pgv.input('reference', 'text', pgv.t('stock.field_reference'), coalesce(v_art.reference, ''), true)
    || pgv.input('designation', 'text', pgv.t('stock.field_designation'), coalesce(v_art.designation, ''), true)
    || pgv.sel('categorie', pgv.t('stock.field_categorie'), v_cat_opts, v_art.categorie)
    || pgv.sel('unite', pgv.t('stock.field_unite'), v_unit_opts, coalesce(v_art.unite, 'u'))
    || pgv.input('prix_achat', 'number', pgv.t('stock.field_prix_achat'), coalesce(v_art.prix_achat::text, ''))
    || pgv.input('seuil_mini', 'number', pgv.t('stock.field_seuil_mini'), coalesce(v_art.seuil_mini::text, '0'))
    || pgv.sel('fournisseur_id', pgv.t('stock.field_fournisseur'), v_fournisseur_opts, v_art.fournisseur_id::text)
    || v_catalog_search
    || pgv.textarea('notes', pgv.t('stock.field_notes'), v_art.notes);
END;
$function$;
