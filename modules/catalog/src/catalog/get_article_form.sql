CREATE OR REPLACE FUNCTION catalog.get_article_form(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := nullif(p_params->>'p_id', '')::int;
  v_art catalog.article;
  v_body text;
  v_cat_opts jsonb;
  v_unite_opts jsonb;
  v_tva_opts jsonb;
BEGIN
  IF v_id IS NOT NULL THEN
    SELECT * INTO v_art FROM catalog.article WHERE id = v_id;
    IF NOT FOUND THEN RETURN pgv.empty(pgv.t('catalog.err_not_found')); END IF;
  END IF;

  -- Build option arrays
  SELECT COALESCE(jsonb_agg(jsonb_build_object('value', c.id::text, 'label', c.nom) ORDER BY c.nom), '[]'::jsonb)
  INTO v_cat_opts FROM catalog.categorie c;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('value', u.code, 'label', u.label) ORDER BY u.label), '[]'::jsonb)
  INTO v_unite_opts FROM catalog.unite u;

  v_tva_opts := jsonb_build_array(
    jsonb_build_object('value', '20.00', 'label', '20%'),
    jsonb_build_object('value', '10.00', 'label', '10%'),
    jsonb_build_object('value', '5.50', 'label', '5,5%'),
    jsonb_build_object('value', '0.00', 'label', '0%')
  );

  -- Form body
  v_body := CASE WHEN v_id IS NOT NULL
    THEN format('<input type="hidden" name="id" value="%s">', v_id)
    ELSE '' END;

  v_body := v_body || '<div class="grid">'
    || pgv.input('reference', 'text', pgv.t('catalog.field_reference'), v_art.reference)
    || pgv.input('designation', 'text', pgv.t('catalog.field_designation'), v_art.designation, true)
    || '</div>'
    || '<div class="grid">'
    || pgv.sel('categorie_id', pgv.t('catalog.field_categorie'), v_cat_opts, v_art.categorie_id::text)
    || pgv.sel('unite', pgv.t('catalog.field_unite'), v_unite_opts, coalesce(v_art.unite, 'u'))
    || pgv.sel('tva', pgv.t('catalog.field_tva'), v_tva_opts, coalesce(v_art.tva, 20.00)::text)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('prix_vente', 'number', pgv.t('catalog.field_prix_vente'),
         CASE WHEN v_art.prix_vente IS NOT NULL THEN v_art.prix_vente::text ELSE NULL END)
    || pgv.input('prix_achat', 'number', pgv.t('catalog.field_prix_achat'),
         CASE WHEN v_art.prix_achat IS NOT NULL THEN v_art.prix_achat::text ELSE NULL END)
    || '</div>'
    || pgv.textarea('description', pgv.t('catalog.field_description'), v_art.description);

  RETURN pgv.form(
    CASE WHEN v_id IS NOT NULL THEN 'post_article_modifier' ELSE 'post_article_creer' END,
    v_body,
    CASE WHEN v_id IS NOT NULL THEN pgv.t('catalog.btn_modifier') ELSE pgv.t('catalog.btn_creer') END
  );
END;
$function$;
