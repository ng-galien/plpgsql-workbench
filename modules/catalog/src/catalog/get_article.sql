CREATE OR REPLACE FUNCTION catalog.get_article(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_art catalog.article;
  v_categorie text;
  v_unite_label text;
  v_body text;
BEGIN
  SELECT * INTO v_art FROM catalog.article WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.empty(pgv.t('catalog.err_not_found')); END IF;

  SELECT c.nom INTO v_categorie FROM catalog.categorie c WHERE c.id = v_art.categorie_id;
  SELECT u.label INTO v_unite_label FROM catalog.unite u WHERE u.code = v_art.unite;

  -- Stats
  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('catalog.field_prix_vente'),
      CASE WHEN v_art.prix_vente IS NOT NULL
        THEN to_char(v_art.prix_vente, 'FM999G990D00') || ' EUR'
        ELSE '—' END),
    pgv.stat(pgv.t('catalog.field_prix_achat'),
      CASE WHEN v_art.prix_achat IS NOT NULL
        THEN to_char(v_art.prix_achat, 'FM999G990D00') || ' EUR'
        ELSE '—' END),
    pgv.stat(pgv.t('catalog.field_tva'), v_art.tva || '%'),
    pgv.stat(pgv.t('catalog.field_unite'), coalesce(v_unite_label, v_art.unite))
  ]);

  -- Détails
  v_body := v_body || pgv.dl(VARIADIC ARRAY[
    pgv.t('catalog.field_reference'), coalesce(pgv.esc(v_art.reference), '—'),
    pgv.t('catalog.field_designation'), pgv.esc(v_art.designation),
    pgv.t('catalog.field_categorie'), coalesce(pgv.badge(v_categorie), '—'),
    pgv.t('catalog.field_description'), coalesce(pgv.esc(v_art.description), '—'),
    pgv.t('catalog.field_statut'), CASE WHEN v_art.actif THEN pgv.badge(pgv.t('catalog.badge_actif'), 'success') ELSE pgv.badge(pgv.t('catalog.badge_inactif'), 'warning') END,
    pgv.t('catalog.detail_created_at'), to_char(v_art.created_at, 'DD/MM/YYYY HH24:MI'),
    pgv.t('catalog.detail_updated_at'), to_char(v_art.updated_at, 'DD/MM/YYYY HH24:MI')
  ]);

  -- Actions
  v_body := v_body || '<p>'
    || format('<a href="%s" role="button">%s</a> ',
       pgv.call_ref('get_article_form', jsonb_build_object('p_id', p_id)),
       pgv.t('catalog.btn_modifier'))
    || CASE WHEN v_art.actif
       THEN pgv.action('post_article_modifier',
              pgv.t('catalog.btn_desactiver'),
              jsonb_build_object('id', p_id, 'actif', 'false'),
              pgv.t('catalog.confirm_desactiver'), 'danger')
       ELSE pgv.action('post_article_modifier',
              pgv.t('catalog.btn_reactiver'),
              jsonb_build_object('id', p_id, 'actif', 'true'))
       END
    || '</p>';

  RETURN v_body;
END;
$function$;
