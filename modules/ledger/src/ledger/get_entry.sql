CREATE OR REPLACE FUNCTION ledger.get_entry(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_entry record;
  v_body text;
  v_rows text[];
  v_total_debit numeric := 0;
  v_total_credit numeric := 0;
  v_balanced boolean;
  v_accounts_json jsonb;
  r record;
BEGIN
  SELECT * INTO v_entry FROM ledger.journal_entry WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.empty(pgv.t('ledger.empty_entry_not_found')); END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    pgv.t('ledger.nav_entries'), pgv.call_ref('get_entries'),
    v_entry.reference
  ]);

  v_body := v_body || pgv.dl(VARIADIC ARRAY[
    pgv.t('ledger.col_date'), to_char(v_entry.entry_date, 'DD/MM/YYYY'),
    pgv.t('ledger.col_reference'), pgv.esc(v_entry.reference),
    pgv.t('ledger.col_description'), pgv.esc(v_entry.description),
    pgv.t('ledger.col_status'), CASE WHEN v_entry.posted THEN pgv.badge(pgv.t('ledger.badge_posted'), 'success') ELSE pgv.badge(pgv.t('ledger.badge_draft'), 'warning') END
  ]);

  -- Lignes
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT el.id, el.account_id, a.code, a.label AS account_label,
           el.debit, el.credit, el.label
      FROM ledger.entry_line el
      JOIN ledger.account a ON a.id = el.account_id
     WHERE el.journal_entry_id = p_id
     ORDER BY el.id
  LOOP
    v_total_debit := v_total_debit + r.debit;
    v_total_credit := v_total_credit + r.credit;
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a> %s', pgv.call_ref('get_account', jsonb_build_object('p_id', r.account_id)), pgv.esc(r.code), pgv.esc(r.account_label)),
      pgv.esc(r.label),
      CASE WHEN r.debit > 0 THEN to_char(r.debit, 'FM999 990.00') ELSE '' END,
      CASE WHEN r.credit > 0 THEN to_char(r.credit, 'FM999 990.00') ELSE '' END,
      CASE WHEN NOT v_entry.posted
        THEN pgv.action('post_line_delete', pgv.t('ledger.btn_delete_short'), jsonb_build_object('id', r.id, 'entry_id', p_id), pgv.t('ledger.confirm_delete_line'), 'danger')
        ELSE ''
      END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('ledger.empty_no_line'), pgv.t('ledger.empty_add_lines'));
  ELSE
    -- Add totals row
    v_rows := v_rows || ARRAY[
      '<strong>' || pgv.t('ledger.title_total') || '</strong>', '',
      '<strong>' || to_char(v_total_debit, 'FM999 990.00') || '</strong>',
      '<strong>' || to_char(v_total_credit, 'FM999 990.00') || '</strong>',
      ''
    ];
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('ledger.col_account'), pgv.t('ledger.col_label'), pgv.t('ledger.col_debit'), pgv.t('ledger.col_credit'), ''],
      v_rows
    );
  END IF;

  -- Alert si déséquilibrée
  v_balanced := ledger._entry_balanced(p_id);
  IF NOT v_balanced AND v_total_debit + v_total_credit > 0 THEN
    v_body := v_body || pgv.alert(
      pgv.t('ledger.err_unbalanced_prefix') || ' ' || to_char(v_total_debit, 'FM999 990.00')
        || E' \u20ac \u2260 ' || pgv.t('ledger.col_credit') || ' ' || to_char(v_total_credit, 'FM999 990.00') || E' \u20ac',
      'danger'
    );
  END IF;

  -- Formulaire ajout ligne (brouillon uniquement)
  IF NOT v_entry.posted THEN
    -- Build account options
    v_accounts_json := '[]'::jsonb;
    FOR r IN SELECT id, code, label FROM ledger.account WHERE active ORDER BY code LOOP
      v_accounts_json := v_accounts_json || jsonb_build_array(jsonb_build_object('value', r.id::text, 'label', r.code || E' \u2014 ' || r.label));
    END LOOP;

    v_body := v_body || pgv.accordion(VARIADIC ARRAY[
      pgv.t('ledger.title_add_line'),
      pgv.form('post_line_add',
        '<input type="hidden" name="entry_id" value="' || p_id || '">'
        || pgv.sel('account_id', pgv.t('ledger.field_account'), v_accounts_json)
        || pgv.grid(VARIADIC ARRAY[
          pgv.input('debit', 'number', pgv.t('ledger.field_debit'), '0'),
          pgv.input('credit', 'number', pgv.t('ledger.field_credit'), '0')
        ])
        || pgv.input('label', 'text', pgv.t('ledger.field_label'), ''),
        pgv.t('ledger.btn_add'))
    ]);

    -- Actions brouillon
    v_body := v_body || pgv.grid(VARIADIC ARRAY[
      format('<a href="%s" role="button" class="outline">%s</a>', pgv.call_ref('get_entry_form', jsonb_build_object('p_id', p_id)), pgv.t('ledger.btn_edit')),
      pgv.action('post_entry_post', pgv.t('ledger.btn_post'), jsonb_build_object('id', p_id), pgv.t('ledger.confirm_post_entry')),
      pgv.action('post_entry_delete', pgv.t('ledger.btn_delete'), jsonb_build_object('id', p_id), pgv.t('ledger.confirm_delete_draft'), 'danger')
    ]);
  END IF;

  RETURN v_body;
END;
$function$;
