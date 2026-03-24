CREATE OR REPLACE FUNCTION quote.devis_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_d record;
  v_ht numeric;
  v_tva numeric;
  v_ttc numeric;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('quote.nav_devis')),
        pgv.ui_table('devis', jsonb_build_array(
          pgv.ui_col('numero', pgv.t('quote.col_numero'), pgv.ui_link('{numero}', 'quote://devis/{id}')),
          pgv.ui_col('client_name', pgv.t('quote.col_client')),
          pgv.ui_col('objet', pgv.t('quote.col_objet')),
          pgv.ui_col('statut', pgv.t('quote.col_statut'), pgv.ui_badge('{statut}')),
          pgv.ui_col('created_at', pgv.t('quote.col_date'))
        ))
      ),
      'datasources', jsonb_build_object(
        'devis', pgv.ui_datasource('quote://devis', 20, true, '-created_at')
      )
    );
  END IF;

  -- Detail mode
  SELECT d.*, c.name AS client_name
    INTO v_d
    FROM quote.devis d
    JOIN crm.client c ON c.id = d.client_id
   WHERE d.id = p_slug::int AND d.tenant_id = current_setting('app.tenant_id', true);

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  v_ht := quote._total_ht(v_d.id, NULL);
  v_tva := quote._total_tva(v_d.id, NULL);
  v_ttc := v_ht + v_tva;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link(pgv.t('quote.nav_devis'), 'quote://devis'),
        pgv.ui_heading(v_d.numero)
      ),
      pgv.ui_row(
        pgv.ui_badge(v_d.statut),
        pgv.ui_text(v_d.client_name)
      ),
      pgv.ui_text(v_d.objet),
      pgv.ui_heading(pgv.t('quote.field_total_ttc'), 3),
      pgv.ui_row(
        pgv.ui_text(pgv.t('quote.field_total_ht') || ' : ' || to_char(v_ht, 'FM999 990.00') || ' ' || pgv.t('quote.currency')),
        pgv.ui_text(pgv.t('quote.field_total_tva') || ' : ' || to_char(v_tva, 'FM999 990.00') || ' ' || pgv.t('quote.currency')),
        pgv.ui_text(pgv.t('quote.field_total_ttc') || ' : ' || to_char(v_ttc, 'FM999 990.00') || ' ' || pgv.t('quote.currency'))
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('quote.field_validite') || ' : ' || v_d.validite_jours || ' ' || pgv.t('quote.field_jours')),
        pgv.ui_text(pgv.t('quote.field_date') || ' : ' || to_char(v_d.created_at, 'DD/MM/YYYY'))
      )
    )
  );
END;
$function$;
