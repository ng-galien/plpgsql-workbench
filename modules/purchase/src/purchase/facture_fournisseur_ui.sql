CREATE OR REPLACE FUNCTION purchase.facture_fournisseur_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_fac purchase.facture_fournisseur;
  v_cmd_numero text;
  v_fournisseur_name text;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('purchase.nav_factures')),
        pgv.ui_table('factures', jsonb_build_array(
          pgv.ui_col('numero_fournisseur', pgv.t('purchase.col_no_fournisseur'), pgv.ui_link('{numero_fournisseur}', '/purchase/facture_fournisseur/{id}')),
          pgv.ui_col('fournisseur_name', pgv.t('purchase.col_fournisseur')),
          pgv.ui_col('commande_numero', pgv.t('purchase.col_commande')),
          pgv.ui_col('statut', pgv.t('purchase.col_statut'), pgv.ui_badge('{statut}')),
          pgv.ui_col('montant_ttc', pgv.t('purchase.col_montant_ttc')),
          pgv.ui_col('date_facture', pgv.t('purchase.col_date_facture')),
          pgv.ui_col('date_echeance', pgv.t('purchase.col_echeance'))
        ))
      ),
      'datasources', jsonb_build_object(
        'factures', pgv.ui_datasource('purchase://facture_fournisseur', 20, true, 'created_at')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_fac FROM purchase.facture_fournisseur WHERE id = p_slug::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  SELECT numero INTO v_cmd_numero FROM purchase.commande WHERE id = v_fac.commande_id;
  SELECT cl.name INTO v_fournisseur_name
    FROM purchase.commande c
    JOIN crm.client cl ON cl.id = c.fournisseur_id
   WHERE c.id = v_fac.commande_id;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← ' || pgv.t('purchase.nav_factures'), '/purchase/facture_fournisseur'),
        pgv.ui_heading(pgv.t('purchase.card_facture') || ' ' || v_fac.numero_fournisseur)
      ),
      pgv.ui_row(
        pgv.ui_badge(v_fac.statut),
        pgv.ui_text(pgv.t('purchase.card_fournisseur') || ': ' || coalesce(v_fournisseur_name, '—')),
        pgv.ui_text(pgv.t('purchase.card_commande') || ': ' || coalesce(v_cmd_numero, '—'))
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('purchase.card_montant_ht') || ': ' || to_char(v_fac.montant_ht, 'FM999 990.00') || ' EUR'),
        pgv.ui_text(pgv.t('purchase.card_montant_ttc') || ': ' || to_char(v_fac.montant_ttc, 'FM999 990.00') || ' EUR')
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('purchase.label_date_facture') || ': ' || to_char(v_fac.date_facture, 'DD/MM/YYYY')),
        pgv.ui_text(pgv.t('purchase.label_echeance') || ': ' || coalesce(to_char(v_fac.date_echeance, 'DD/MM/YYYY'), '—'))
      ),
      CASE WHEN v_fac.commande_id IS NOT NULL THEN
        pgv.ui_row(
          pgv.ui_text(pgv.t('purchase.label_rapprochement') || ': '
            || pgv.t('purchase.label_commande_ttc') || ' ' || to_char(purchase._total_ttc(v_fac.commande_id), 'FM999 990.00') || ' EUR'
            || ' | ' || pgv.t('purchase.label_ecart') || ' ' || to_char(v_fac.montant_ttc - purchase._total_ttc(v_fac.commande_id), 'FM999 990.00') || ' EUR'),
          CASE WHEN abs(v_fac.montant_ttc - purchase._total_ttc(v_fac.commande_id)) > 0.01
            THEN pgv.ui_badge(pgv.t('purchase.badge_ecart'), 'warning')
            ELSE pgv.ui_badge(pgv.t('purchase.badge_ok'), 'success')
          END
        )
      ELSE
        pgv.ui_text('')
      END,
      CASE WHEN v_fac.notes <> '' THEN pgv.ui_text(pgv.t('purchase.label_notes') || ': ' || v_fac.notes)
      ELSE pgv.ui_text('') END,
      CASE WHEN v_fac.comptabilisee THEN pgv.ui_badge(pgv.t('purchase.badge_comptabilisee'), 'success')
      ELSE pgv.ui_text('') END
    )
  );
END;
$function$;
