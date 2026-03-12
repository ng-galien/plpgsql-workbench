CREATE OR REPLACE FUNCTION ledger.get_accounts()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rows text[];
  v_body text;
  r record;
BEGIN
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.code, a.label, a.type,
           ledger._account_balance(a.id) AS balance
      FROM ledger.account a
     WHERE a.active
     ORDER BY a.code
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_account', jsonb_build_object('p_id', r.id)), pgv.esc(r.code)),
      pgv.esc(r.label),
      pgv.badge(ledger._type_label(r.type),
        CASE r.type WHEN 'asset' THEN 'info' WHEN 'liability' THEN 'warning'
          WHEN 'equity' THEN 'default' WHEN 'revenue' THEN 'success' WHEN 'expense' THEN 'danger' END),
      to_char(r.balance, 'FM999 990.00') || ' €'
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty('Aucun compte', 'Le plan comptable est vide.');
  ELSE
    v_body := pgv.md_table(
      ARRAY['Code', 'Libellé', 'Type', 'Solde'],
      v_rows, 20
    );
  END IF;

  RETURN pgv.breadcrumb(VARIADIC ARRAY['Plan comptable']) || v_body;
END;
$function$;
