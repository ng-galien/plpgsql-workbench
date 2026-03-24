CREATE OR REPLACE FUNCTION quote.facture_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_f record;
  v_ht numeric;
  v_tva numeric;
  v_ttc numeric;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('quote.nav_factures')),
        pgv.ui_table('factures', jsonb_build_array(
          pgv.ui_col('numero', pgv.t('quote.col_numero'), pgv.ui_link('{numero}', 'quote://facture/{id}')),
          pgv.ui_col('client_name', pgv.t('quote.col_client')),
          pgv.ui_col('objet', pgv.t('quote.col_objet')),
          pgv.ui_col('statut', pgv.t('quote.col_statut'), pgv.ui_badge('{statut}')),
          pgv.ui_col('devis_numero', pgv.t('quote.field_devis')),
          pgv.ui_col('created_at', pgv.t('quote.col_date'))
        ))
      ),
      'datasources', jsonb_build_object(
        'factures', pgv.ui_datasource('quote://facture', 20, true, '-created_at')
      )
    );
  END IF;

  -- Detail mode
  SELECT f.*, c.name AS client_name, dv.numero AS devis_numero
    INTO v_f
    FROM quote.facture f
    JOIN crm.client c ON c.id = f.client_id
    LEFT JOIN quote.devis dv ON dv.id = f.devis_id
   WHERE f.id = p_slug::int AND f.tenant_id = current_setting('app.tenant_id', true);

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  v_ht := quote._total_ht(NULL, v_f.id);
  v_tva := quote._total_tva(NULL, v_f.id);
  v_ttc := v_ht + v_tva;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link(pgv.t('quote.nav_factures'), 'quote://facture'),
        pgv.ui_heading(v_f.numero)
      ),
      pgv.ui_row(
        pgv.ui_badge(v_f.statut),
        pgv.ui_text(v_f.client_name)
      ),
      pgv.ui_text(v_f.objet),
      CASE WHEN v_f.devis_numero IS NOT NULL
        THEN pgv.ui_link(pgv.t('quote.field_devis') || ' : ' || v_f.devis_numero, 'quote://devis/' || v_f.devis_id)
        ELSE pgv.ui_text(pgv.t('quote.field_facture_directe'))
      END,
      pgv.ui_heading(pgv.t('quote.field_total_ttc'), 3),
      pgv.ui_row(
        pgv.ui_text(pgv.t('quote.field_total_ht') || ' : ' || to_char(v_ht, 'FM999 990.00') || ' ' || pgv.t('quote.currency')),
        pgv.ui_text(pgv.t('quote.field_total_tva') || ' : ' || to_char(v_tva, 'FM999 990.00') || ' ' || pgv.t('quote.currency')),
        pgv.ui_text(pgv.t('quote.field_total_ttc') || ' : ' || to_char(v_ttc, 'FM999 990.00') || ' ' || pgv.t('quote.currency'))
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('quote.field_date') || ' : ' || to_char(v_f.created_at, 'DD/MM/YYYY')),
        pgv.ui_text(pgv.t('quote.field_paid_at') || ' : ' || CASE WHEN v_f.paid_at IS NOT NULL THEN to_char(v_f.paid_at, 'DD/MM/YYYY') ELSE '—' END)
      )
    )
  );
END;
$function$;
