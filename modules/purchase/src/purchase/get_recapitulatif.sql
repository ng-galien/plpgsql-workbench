CREATE OR REPLACE FUNCTION purchase.get_recapitulatif(p_annee integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_annee int := coalesce(p_annee, extract(year FROM now())::int);
  v_body text;
  v_headers text[];
  v_rows text[];
  r record;
  v_total_annuel numeric(12,2) := 0;
BEGIN
  v_headers := ARRAY[
    pgv.t('purchase.col_fournisseur'),
    pgv.t('purchase.month_jan'), pgv.t('purchase.month_feb'), pgv.t('purchase.month_mar'),
    pgv.t('purchase.month_apr'), pgv.t('purchase.month_may'), pgv.t('purchase.month_jun'),
    pgv.t('purchase.month_jul'), pgv.t('purchase.month_aug'), pgv.t('purchase.month_sep'),
    pgv.t('purchase.month_oct'), pgv.t('purchase.month_nov'), pgv.t('purchase.month_dec'),
    pgv.t('purchase.col_total')
  ];

  v_body := '<h3>' || pgv.t('purchase.title_recap') || ' ' || v_annee || '</h3>';

  -- Year navigation
  v_body := v_body || '<p>'
    || format('<a href="%s">&laquo; %s</a>',
       pgv.call_ref('get_recapitulatif', jsonb_build_object('p_annee', v_annee - 1)), v_annee - 1)
    || ' | <strong>' || v_annee || '</strong> | '
    || format('<a href="%s">%s &raquo;</a>',
       pgv.call_ref('get_recapitulatif', jsonb_build_object('p_annee', v_annee + 1)), v_annee + 1)
    || '</p>';

  -- Build rows per supplier
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT cl.id AS fournisseur_id, cl.name AS fournisseur,
           (SELECT coalesce(sum(purchase._total_ht(c2.id)), 0) FROM purchase.commande c2
             WHERE c2.fournisseur_id = cl.id AND extract(year FROM c2.created_at) = v_annee
               AND extract(month FROM c2.created_at) = 1) AS m01,
           (SELECT coalesce(sum(purchase._total_ht(c2.id)), 0) FROM purchase.commande c2
             WHERE c2.fournisseur_id = cl.id AND extract(year FROM c2.created_at) = v_annee
               AND extract(month FROM c2.created_at) = 2) AS m02,
           (SELECT coalesce(sum(purchase._total_ht(c2.id)), 0) FROM purchase.commande c2
             WHERE c2.fournisseur_id = cl.id AND extract(year FROM c2.created_at) = v_annee
               AND extract(month FROM c2.created_at) = 3) AS m03,
           (SELECT coalesce(sum(purchase._total_ht(c2.id)), 0) FROM purchase.commande c2
             WHERE c2.fournisseur_id = cl.id AND extract(year FROM c2.created_at) = v_annee
               AND extract(month FROM c2.created_at) = 4) AS m04,
           (SELECT coalesce(sum(purchase._total_ht(c2.id)), 0) FROM purchase.commande c2
             WHERE c2.fournisseur_id = cl.id AND extract(year FROM c2.created_at) = v_annee
               AND extract(month FROM c2.created_at) = 5) AS m05,
           (SELECT coalesce(sum(purchase._total_ht(c2.id)), 0) FROM purchase.commande c2
             WHERE c2.fournisseur_id = cl.id AND extract(year FROM c2.created_at) = v_annee
               AND extract(month FROM c2.created_at) = 6) AS m06,
           (SELECT coalesce(sum(purchase._total_ht(c2.id)), 0) FROM purchase.commande c2
             WHERE c2.fournisseur_id = cl.id AND extract(year FROM c2.created_at) = v_annee
               AND extract(month FROM c2.created_at) = 7) AS m07,
           (SELECT coalesce(sum(purchase._total_ht(c2.id)), 0) FROM purchase.commande c2
             WHERE c2.fournisseur_id = cl.id AND extract(year FROM c2.created_at) = v_annee
               AND extract(month FROM c2.created_at) = 8) AS m08,
           (SELECT coalesce(sum(purchase._total_ht(c2.id)), 0) FROM purchase.commande c2
             WHERE c2.fournisseur_id = cl.id AND extract(year FROM c2.created_at) = v_annee
               AND extract(month FROM c2.created_at) = 9) AS m09,
           (SELECT coalesce(sum(purchase._total_ht(c2.id)), 0) FROM purchase.commande c2
             WHERE c2.fournisseur_id = cl.id AND extract(year FROM c2.created_at) = v_annee
               AND extract(month FROM c2.created_at) = 10) AS m10,
           (SELECT coalesce(sum(purchase._total_ht(c2.id)), 0) FROM purchase.commande c2
             WHERE c2.fournisseur_id = cl.id AND extract(year FROM c2.created_at) = v_annee
               AND extract(month FROM c2.created_at) = 11) AS m11,
           (SELECT coalesce(sum(purchase._total_ht(c2.id)), 0) FROM purchase.commande c2
             WHERE c2.fournisseur_id = cl.id AND extract(year FROM c2.created_at) = v_annee
               AND extract(month FROM c2.created_at) = 12) AS m12
      FROM crm.client cl
     WHERE EXISTS (
       SELECT 1 FROM purchase.commande c3
        WHERE c3.fournisseur_id = cl.id
          AND extract(year FROM c3.created_at) = v_annee
     )
     ORDER BY cl.name
  LOOP
    DECLARE
      v_row_total numeric(12,2);
      v_months numeric[] := ARRAY[r.m01, r.m02, r.m03, r.m04, r.m05, r.m06,
                                   r.m07, r.m08, r.m09, r.m10, r.m11, r.m12];
    BEGIN
      v_row_total := r.m01 + r.m02 + r.m03 + r.m04 + r.m05 + r.m06
                   + r.m07 + r.m08 + r.m09 + r.m10 + r.m11 + r.m12;
      v_total_annuel := v_total_annuel + v_row_total;

      v_rows := v_rows || format('<a href="/crm/client?p_id=%s">%s</a>',
        r.fournisseur_id, pgv.esc(r.fournisseur));
      FOR i IN 1..12 LOOP
        v_rows := v_rows || CASE WHEN v_months[i] = 0 THEN '—'
          ELSE to_char(v_months[i], 'FM999 990') END;
      END LOOP;
      v_rows := v_rows || ('<strong>' || to_char(v_row_total, 'FM999 990') || '</strong>');
    END;
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('purchase.empty_no_commande'));
  ELSE
    v_body := v_body || pgv.stat(pgv.t('purchase.stat_total_annuel'), to_char(v_total_annuel, 'FM999 990.00') || ' EUR');
    v_body := v_body || pgv.md_table(v_headers, v_rows);
  END IF;

  RETURN v_body;
END;
$function$;
