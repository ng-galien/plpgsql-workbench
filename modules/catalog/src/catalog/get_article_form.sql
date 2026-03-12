CREATE OR REPLACE FUNCTION catalog.get_article_form(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_id int := nullif(p_params->>'p_id', '')::int;
  v_art catalog.article;
  v_body text;
  v_cat_options text;
  v_unite_options text;
  v_tva_options text;
  r record;
BEGIN
  IF v_id IS NOT NULL THEN
    SELECT * INTO v_art FROM catalog.article WHERE id = v_id;
    IF NOT FOUND THEN RETURN pgv.empty('Article introuvable'); END IF;
  END IF;

  -- Options catégorie
  v_cat_options := '<option value="">-- Catégorie --</option>';
  FOR r IN SELECT c.id, c.nom FROM catalog.categorie c ORDER BY c.nom LOOP
    v_cat_options := v_cat_options || format('<option value="%s"%s>%s</option>',
      r.id, CASE WHEN r.id = v_art.categorie_id THEN ' selected' ELSE '' END, pgv.esc(r.nom));
  END LOOP;

  -- Options unité (depuis table unite)
  v_unite_options := '';
  FOR r IN SELECT u.code, u.label FROM catalog.unite u ORDER BY u.label LOOP
    v_unite_options := v_unite_options || format('<option value="%s"%s>%s</option>',
      r.code, CASE WHEN coalesce(v_art.unite, 'u') = r.code THEN ' selected' ELSE '' END, pgv.esc(r.label));
  END LOOP;

  -- Options TVA
  v_tva_options := format('<option value="20.00"%s>20%%</option>', CASE WHEN coalesce(v_art.tva, 20.00) = 20.00 THEN ' selected' ELSE '' END)
    || format('<option value="10.00"%s>10%%</option>', CASE WHEN v_art.tva = 10.00 THEN ' selected' ELSE '' END)
    || format('<option value="5.50"%s>5,5%%</option>', CASE WHEN v_art.tva = 5.50 THEN ' selected' ELSE '' END)
    || format('<option value="0.00"%s>0%%</option>', CASE WHEN v_art.tva = 0.00 THEN ' selected' ELSE '' END);

  v_body := format('<form data-rpc="%s">',
    CASE WHEN v_id IS NOT NULL THEN 'post_article_modifier' ELSE 'post_article_creer' END);

  IF v_id IS NOT NULL THEN
    v_body := v_body || format('<input type="hidden" name="id" value="%s">', v_id);
  END IF;

  v_body := v_body || '<div class="grid">'
    || pgv.input('reference', 'text', 'Référence', v_art.reference)
    || pgv.input('designation', 'text', 'Désignation', v_art.designation, true)
    || '</div>'
    || '<div class="grid">'
    || '<label>Catégorie<select name="categorie_id">' || v_cat_options || '</select></label>'
    || '<label>Unité<select name="unite">' || v_unite_options || '</select></label>'
    || '<label>TVA<select name="tva">' || v_tva_options || '</select></label>'
    || '</div>'
    || '<div class="grid">'
    || pgv.input('prix_vente', 'number', 'Prix vente HT',
         CASE WHEN v_art.prix_vente IS NOT NULL THEN v_art.prix_vente::text ELSE NULL END)
    || pgv.input('prix_achat', 'number', 'Prix achat HT',
         CASE WHEN v_art.prix_achat IS NOT NULL THEN v_art.prix_achat::text ELSE NULL END)
    || '</div>'
    || pgv.textarea('description', 'Description', v_art.description)
    || format('<button type="submit">%s</button>',
         CASE WHEN v_id IS NOT NULL THEN 'Modifier' ELSE 'Créer' END)
    || '</form>';

  RETURN v_body;
END;
$function$;
