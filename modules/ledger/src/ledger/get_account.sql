CREATE OR REPLACE FUNCTION ledger.get_account(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_account record;
  v_balance numeric;
  v_body text;
  v_rows text[];
  v_cumul numeric := 0;
  v_sign integer;
  r record;
BEGIN
  SELECT * INTO v_account FROM ledger.account WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.empty(pgv.t('ledger.empty_account_not_found')); END IF;

  v_balance := ledger._account_balance(p_id);
  v_sign := ledger._type_sign(v_account.type);

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    pgv.t('ledger.nav_accounts'), pgv.call_ref('get_accounts'),
    v_account.code || ' — ' || v_account.label
  ]);

  v_body := v_body || pgv.dl(VARIADIC ARRAY[
    pgv.t('ledger.col_code'), v_account.code,
    pgv.t('ledger.col_label'), pgv.esc(v_account.label),
    pgv.t('ledger.col_type'), pgv.badge(ledger._type_label(v_account.type),
      CASE v_account.type WHEN 'asset' THEN 'info' WHEN 'liability' THEN 'warning'
        WHEN 'equity' THEN 'default' WHEN 'revenue' THEN 'success' WHEN 'expense' THEN 'danger' END),
    pgv.t('ledger.col_balance'), to_char(v_balance, 'FM999 990.00') || ' €'
  ]);

  -- Lignes du grand livre
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT je.entry_date, je.reference, je.id AS entry_id,
           el.debit, el.credit, el.label
      FROM ledger.entry_line el
      JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
     WHERE el.account_id = p_id AND je.posted = true
     ORDER BY je.entry_date, je.id
  LOOP
    v_cumul := v_cumul + (r.debit - r.credit) * v_sign;
    v_rows := v_rows || ARRAY[
      to_char(r.entry_date, 'DD/MM/YYYY'),
      format('<a href="%s">%s</a>', pgv.call_ref('get_entry', jsonb_build_object('p_id', r.entry_id)), pgv.esc(r.reference)),
      pgv.esc(r.label),
      CASE WHEN r.debit > 0 THEN to_char(r.debit, 'FM999 990.00') ELSE '' END,
      CASE WHEN r.credit > 0 THEN to_char(r.credit, 'FM999 990.00') ELSE '' END,
      to_char(v_cumul, 'FM999 990.00')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('ledger.empty_no_movement'), pgv.t('ledger.empty_no_posted_lines'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('ledger.col_date'), pgv.t('ledger.col_reference'), pgv.t('ledger.col_label'), pgv.t('ledger.col_debit'), pgv.t('ledger.col_credit'), pgv.t('ledger.col_balance')],
      v_rows
    );
  END IF;

  RETURN v_body;
END;
$function$;
