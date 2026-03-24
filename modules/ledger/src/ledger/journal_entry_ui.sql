CREATE OR REPLACE FUNCTION ledger.journal_entry_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_entry jsonb;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('ledger.nav_entries')),
        pgv.ui_table('entries', jsonb_build_array(
          pgv.ui_col('entry_date', pgv.t('ledger.col_date')),
          pgv.ui_col('reference', pgv.t('ledger.col_reference'), pgv.ui_link('{reference}', '/ledger/entries/{id}')),
          pgv.ui_col('description', pgv.t('ledger.col_description')),
          pgv.ui_col('total_debit', pgv.t('ledger.col_amount')),
          pgv.ui_col('status', pgv.t('ledger.col_status'), pgv.ui_badge('{status}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'entries', pgv.ui_datasource('ledger://journal_entry', 20, true, 'entry_date')
      )
    );
  END IF;

  -- Detail mode
  v_entry := ledger.journal_entry_read(p_slug);
  IF v_entry IS NULL THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link(E'\u2190 ' || pgv.t('ledger.nav_entries'), '/ledger/entries'),
        pgv.ui_heading(v_entry->>'reference')
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('ledger.col_date') || ' : ' || (v_entry->>'entry_date')),
        pgv.ui_badge(
          CASE WHEN (v_entry->>'posted')::boolean THEN pgv.t('ledger.badge_posted') ELSE pgv.t('ledger.badge_draft') END,
          CASE WHEN (v_entry->>'posted')::boolean THEN 'success' ELSE 'warning' END
        )
      ),
      pgv.ui_text(v_entry->>'description')
    )
  );
END;
$function$;
