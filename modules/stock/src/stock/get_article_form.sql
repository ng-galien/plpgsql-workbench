CREATE OR REPLACE FUNCTION stock.get_article_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_art stock.article;
  v_body text;
  v_cat_options text;
  v_unite_options text;
  v_fournisseur_options text;
  v_catalog_search text;
  v_catalog_display text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_art FROM stock.article WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.empty('Article introuvable', ''); END IF;
  END IF;

  -- Options catégorie
  v_cat_options := '';
  FOR v_cat_options IN SELECT '' LOOP END LOOP; -- reset
  v_cat_options := '<option value="">-- Catégorie --</option>';
  v_cat_options := v_cat_options || format('<option value="bois"%s>Bois</option>', CASE WHEN v_art.categorie = 'bois' THEN ' selected' ELSE '' END);
  v_cat_options := v_cat_options || format('<option value="quincaillerie"%s>Quincaillerie</option>', CASE WHEN v_art.categorie = 'quincaillerie' THEN ' selected' ELSE '' END);
  v_cat_options := v_cat_options || format('<option value="panneau"%s>Panneau</option>', CASE WHEN v_art.categorie = 'panneau' THEN ' selected' ELSE '' END);
  v_cat_options := v_cat_options || format('<option value="isolant"%s>Isolant</option>', CASE WHEN v_art.categorie = 'isolant' THEN ' selected' ELSE '' END);
  v_cat_options := v_cat_options || format('<option value="finition"%s>Finition</option>', CASE WHEN v_art.categorie = 'finition' THEN ' selected' ELSE '' END);
  v_cat_options := v_cat_options || format('<option value="autre"%s>Autre</option>', CASE WHEN v_art.categorie = 'autre' THEN ' selected' ELSE '' END);

  -- Options unité
  v_unite_options := '';
  v_unite_options := format('<option value="u"%s>Unité</option>', CASE WHEN coalesce(v_art.unite, 'u') = 'u' THEN ' selected' ELSE '' END);
  v_unite_options := v_unite_options || format('<option value="m"%s>Mètre</option>', CASE WHEN v_art.unite = 'm' THEN ' selected' ELSE '' END);
  v_unite_options := v_unite_options || format('<option value="m2"%s>m²</option>', CASE WHEN v_art.unite = 'm2' THEN ' selected' ELSE '' END);
  v_unite_options := v_unite_options || format('<option value="m3"%s>m³</option>', CASE WHEN v_art.unite = 'm3' THEN ' selected' ELSE '' END);
  v_unite_options := v_unite_options || format('<option value="kg"%s>kg</option>', CASE WHEN v_art.unite = 'kg' THEN ' selected' ELSE '' END);
  v_unite_options := v_unite_options || format('<option value="l"%s>Litre</option>', CASE WHEN v_art.unite = 'l' THEN ' selected' ELSE '' END);

  -- Options fournisseur (CRM companies)
  v_fournisseur_options := '<option value="">-- Aucun --</option>';
  SELECT v_fournisseur_options || string_agg(
    format('<option value="%s"%s>%s</option>', c.id, CASE WHEN c.id = v_art.fournisseur_id THEN ' selected' ELSE '' END, pgv.esc(c.name)),
    '' ORDER BY c.name
  ) INTO v_fournisseur_options
  FROM crm.client c WHERE c.type = 'company' AND c.active;

  -- Catalog article search (cross-module guard)
  v_catalog_search := '';
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'catalog') THEN
    -- Resolve current display value
    v_catalog_display := NULL;
    IF v_art.catalog_article_id IS NOT NULL THEN
      SELECT ca.designation INTO v_catalog_display
      FROM catalog.article ca WHERE ca.id = v_art.catalog_article_id;
    END IF;
    v_catalog_search := pgv.select_search(
      'catalog_article_id', 'Article catalog',
      'catalog.article_options',
      'Rechercher un article catalog...',
      v_art.catalog_article_id::text,
      v_catalog_display
    );
  END IF;

  v_body := format('<form data-rpc="post_article_save">
    <input type="hidden" name="id" value="%s">
    <label>Référence <input type="text" name="reference" value="%s" required></label>
    <label>Désignation <input type="text" name="designation" value="%s" required></label>
    <label>Catégorie <select name="categorie" required>%s</select></label>
    <label>Unité <select name="unite" required>%s</select></label>
    <label>Prix d''achat <input type="number" name="prix_achat" value="%s" step="0.01" min="0"></label>
    <label>Seuil mini <input type="number" name="seuil_mini" value="%s" step="0.01" min="0"></label>
    <label>Fournisseur <select name="fournisseur_id">%s</select></label>
    %s
    <label>Notes <textarea name="notes">%s</textarea></label>
    <button type="submit">%s</button>
  </form>',
    coalesce(p_id::text, ''),
    coalesce(pgv.esc(v_art.reference), ''),
    coalesce(pgv.esc(v_art.designation), ''),
    v_cat_options,
    v_unite_options,
    coalesce(v_art.prix_achat::text, ''),
    coalesce(v_art.seuil_mini::text, '0'),
    v_fournisseur_options,
    v_catalog_search,
    coalesce(pgv.esc(v_art.notes), ''),
    CASE WHEN p_id IS NOT NULL THEN 'Modifier' ELSE 'Créer' END
  );

  RETURN v_body;
END;
$function$;
