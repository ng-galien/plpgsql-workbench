CREATE OR REPLACE FUNCTION stock.get_articles()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  r record;
BEGIN
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.reference, a.designation, a.categorie, a.unite,
           a.prix_achat, a.pmp, a.seuil_mini, a.active, a.fournisseur_id,
           stock._stock_actuel(a.id) AS qty,
           c.name AS fournisseur
    FROM stock.article a
    LEFT JOIN crm.client c ON c.id = a.fournisseur_id
    ORDER BY a.designation
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_article', jsonb_build_object('p_id', r.id)), pgv.esc(r.reference)),
      pgv.esc(r.designation),
      pgv.badge(r.categorie, CASE r.categorie
        WHEN 'bois' THEN 'success'
        WHEN 'quincaillerie' THEN 'info'
        WHEN 'panneau' THEN 'warning'
        ELSE NULL
      END),
      r.qty::text || ' ' || r.unite,
      CASE WHEN r.pmp > 0 THEN to_char(r.pmp, 'FM999G990D00') ELSE '—' END,
      CASE WHEN r.seuil_mini > 0 AND r.qty < r.seuil_mini
        THEN pgv.badge(pgv.t('stock.col_alerte'), 'danger')
        ELSE '—'
      END,
      CASE WHEN r.fournisseur IS NOT NULL
        THEN format('<a href="/crm/client?p_id=%s">%s</a>', r.fournisseur_id, pgv.esc(r.fournisseur))
        ELSE '—'
      END,
      CASE WHEN r.active THEN pgv.t('stock.yes') ELSE pgv.t('stock.no') END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty(pgv.t('stock.empty_no_article'), pgv.t('stock.empty_first_article'));
  ELSE
    v_body := pgv.md_table(
      ARRAY[pgv.t('stock.col_ref'), pgv.t('stock.col_designation'), pgv.t('stock.col_categorie'), pgv.t('stock.col_stock'), pgv.t('stock.col_pmp'), pgv.t('stock.col_alerte'), pgv.t('stock.col_fournisseur'), pgv.t('stock.col_actif')],
      v_rows,
      20
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">%s</a></p>',
    pgv.call_ref('get_article_form'), pgv.t('stock.btn_nouvel_article'));

  RETURN v_body;
END;
$function$;
