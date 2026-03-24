CREATE OR REPLACE FUNCTION ledger.account_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_account jsonb;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('ledger.nav_accounts')),
        pgv.ui_table('accounts', jsonb_build_array(
          pgv.ui_col('code', pgv.t('ledger.col_code'), pgv.ui_link('{code}', '/ledger/accounts/{id}')),
          pgv.ui_col('label', pgv.t('ledger.col_label')),
          pgv.ui_col('type_label', pgv.t('ledger.col_type'), pgv.ui_badge('{type_label}')),
          pgv.ui_col('balance', pgv.t('ledger.col_balance')),
          pgv.ui_col('active', pgv.t('ledger.col_active'), pgv.ui_badge('{active}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'accounts', pgv.ui_datasource('ledger://account', 30, true, 'code')
      )
    );
  END IF;

  -- Detail mode
  v_account := ledger.account_read(p_slug);
  IF v_account IS NULL THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link(E'\u2190 ' || pgv.t('ledger.nav_accounts'), '/ledger/accounts'),
        pgv.ui_heading((v_account->>'code') || ' — ' || (v_account->>'label'))
      ),
      pgv.ui_row(
        pgv.ui_badge(ledger._type_label(v_account->>'type')),
        pgv.ui_badge(
          CASE WHEN (v_account->>'active')::boolean THEN pgv.t('ledger.badge_active') ELSE pgv.t('ledger.badge_inactive') END,
          CASE WHEN (v_account->>'active')::boolean THEN 'success' ELSE 'error' END
        )
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('ledger.col_balance') || ' : ' || (v_account->>'balance')),
        pgv.ui_text(pgv.t('ledger.col_lines') || ' : ' || (v_account->>'line_count'))
      )
    )
  );
END;
$function$;
