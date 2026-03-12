CREATE OR REPLACE FUNCTION catalog.get_article(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_art catalog.article;
  v_categorie text;
  v_unite_label text;
  v_body text;
BEGIN
  SELECT * INTO v_art FROM catalog.article WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.empty('Article introuvable'); END IF;

  SELECT c.nom INTO v_categorie FROM catalog.categorie c WHERE c.id = v_art.categorie_id;
  SELECT u.label INTO v_unite_label FROM catalog.unite u WHERE u.code = v_art.unite;

  -- Stats
  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Prix vente HT',
      CASE WHEN v_art.prix_vente IS NOT NULL
        THEN to_char(v_art.prix_vente, 'FM999G990D00') || ' EUR'
        ELSE '—' END),
    pgv.stat('Prix achat HT',
      CASE WHEN v_art.prix_achat IS NOT NULL
        THEN to_char(v_art.prix_achat, 'FM999G990D00') || ' EUR'
        ELSE '—' END),
    pgv.stat('TVA', v_art.tva || '%'),
    pgv.stat('Unité', coalesce(v_unite_label, v_art.unite))
  ]);

  -- Détails
  v_body := v_body || pgv.dl(VARIADIC ARRAY[
    'Référence', coalesce(pgv.esc(v_art.reference), '—'),
    'Désignation', pgv.esc(v_art.designation),
    'Catégorie', coalesce(pgv.badge(v_categorie), '—'),
    'Description', coalesce(pgv.esc(v_art.description), '—'),
    'Statut', CASE WHEN v_art.actif THEN pgv.badge('Actif', 'success') ELSE pgv.badge('Inactif', 'warning') END,
    'Créé le', to_char(v_art.created_at, 'DD/MM/YYYY HH24:MI'),
    'Modifié le', to_char(v_art.updated_at, 'DD/MM/YYYY HH24:MI')
  ]);

  -- Actions
  v_body := v_body || '<p>'
    || format('<a href="%s" role="button">Modifier</a> ',
       pgv.call_ref('get_article_form', jsonb_build_object('p_id', p_id)))
    || CASE WHEN v_art.actif
       THEN pgv.action('post_article_modifier',
              'Désactiver',
              jsonb_build_object('id', p_id, 'actif', 'false'),
              'Désactiver cet article ?', 'danger')
       ELSE pgv.action('post_article_modifier',
              'Réactiver',
              jsonb_build_object('id', p_id, 'actif', 'true'))
       END
    || '</p>';

  RETURN v_body;
END;
$function$;
