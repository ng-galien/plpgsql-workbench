CREATE OR REPLACE FUNCTION purchase.commande_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cmd purchase.commande;
  v_fournisseur text;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('purchase.nav_commandes')),
        pgv.ui_table('commandes', jsonb_build_array(
          pgv.ui_col('numero', pgv.t('purchase.col_numero'), pgv.ui_link('{numero}', '/purchase/commande/{id}')),
          pgv.ui_col('fournisseur_name', pgv.t('purchase.col_fournisseur')),
          pgv.ui_col('objet', pgv.t('purchase.col_objet')),
          pgv.ui_col('statut', pgv.t('purchase.col_statut'), pgv.ui_badge('{statut}')),
          pgv.ui_col('total_ttc', pgv.t('purchase.col_total_ttc')),
          pgv.ui_col('created_at', pgv.t('purchase.col_date'))
        ))
      ),
      'datasources', jsonb_build_object(
        'commandes', pgv.ui_datasource('purchase://commande', 20, true, 'created_at')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_cmd FROM purchase.commande WHERE id = p_slug::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  SELECT name INTO v_fournisseur FROM crm.client WHERE id = v_cmd.fournisseur_id;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← ' || pgv.t('purchase.nav_commandes'), '/purchase/commande'),
        pgv.ui_heading(pgv.t('purchase.title_bon_commande') || ' ' || v_cmd.numero)
      ),
      pgv.ui_row(
        pgv.ui_badge(v_cmd.statut),
        pgv.ui_text(pgv.t('purchase.card_fournisseur') || ': ' || v_fournisseur),
        pgv.ui_text(pgv.t('purchase.card_total_ttc') || ': ' || to_char(purchase._total_ttc(v_cmd.id), 'FM999 990.00') || ' EUR')
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('purchase.label_objet') || ': ' || coalesce(nullif(v_cmd.objet, ''), '—')),
        pgv.ui_text(pgv.t('purchase.card_livraison') || ': ' || coalesce(to_char(v_cmd.date_livraison, 'DD/MM/YYYY'), '—'))
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('purchase.label_conditions') || ': ' || coalesce(nullif(v_cmd.conditions_paiement, ''), '—')),
        pgv.ui_text(pgv.t('purchase.label_notes') || ': ' || coalesce(nullif(v_cmd.notes, ''), '—'))
      ),
      pgv.ui_heading(pgv.t('purchase.label_total_ht') || ' / ' || pgv.t('purchase.label_tva') || ' / ' || pgv.t('purchase.label_ttc'), 3),
      pgv.ui_row(
        pgv.ui_text(to_char(purchase._total_ht(v_cmd.id), 'FM999 990.00') || ' EUR'),
        pgv.ui_text(to_char(purchase._total_tva(v_cmd.id), 'FM999 990.00') || ' EUR'),
        pgv.ui_text(to_char(purchase._total_ttc(v_cmd.id), 'FM999 990.00') || ' EUR')
      )
    )
  );
END;
$function$;
