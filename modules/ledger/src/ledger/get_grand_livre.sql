CREATE OR REPLACE FUNCTION ledger.get_grand_livre(p_account_id integer, p_year integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_account record;
  v_year integer;
  v_start date;
  v_end date;
  v_body text;
  v_rows text[];
  v_cumul numeric := 0;
  v_total_debit numeric := 0;
  v_total_credit numeric := 0;
  r record;
BEGIN
  SELECT * INTO v_account FROM ledger.account WHERE id = p_account_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Compte % introuvable', p_account_id; END IF;

  v_year := coalesce(p_year, extract(year FROM CURRENT_DATE)::integer);
  v_start := make_date(v_year, 1, 1);
  v_end := make_date(v_year, 12, 31);

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    format('<a href="%s">Balance</a>', pgv.call_ref('get_balance', jsonb_build_object('p_year', v_year))),
    v_account.code || ' — ' || v_account.label
  ]);

  -- Year selector
  v_body := v_body || '<div class="grid">'
    || format('<a href="%s" role="button" class="outline">%s</a>', pgv.call_ref('get_grand_livre', jsonb_build_object('p_account_id', p_account_id, 'p_year', v_year - 1)), (v_year - 1)::text)
    || format('<a href="%s" role="button">%s</a>', pgv.call_ref('get_grand_livre', jsonb_build_object('p_account_id', p_account_id, 'p_year', v_year)), v_year::text)
    || format('<a href="%s" role="button" class="outline">%s</a>', pgv.call_ref('get_grand_livre', jsonb_build_object('p_account_id', p_account_id, 'p_year', v_year + 1)), (v_year + 1)::text)
    || '</div>';

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT je.id AS entry_id, je.entry_date, je.reference, el.label,
           el.debit, el.credit
      FROM ledger.entry_line el
      JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
     WHERE el.account_id = p_account_id
       AND je.posted = true
       AND je.entry_date >= v_start AND je.entry_date <= v_end
     ORDER BY je.entry_date, je.id
  LOOP
    v_cumul := v_cumul + r.debit - r.credit;
    v_total_debit := v_total_debit + r.debit;
    v_total_credit := v_total_credit + r.credit;
    v_rows := v_rows || ARRAY[
      to_char(r.entry_date, 'DD/MM/YYYY'),
      format('<a href="%s">%s</a>', pgv.call_ref('get_entry', jsonb_build_object('p_id', r.entry_id)), pgv.esc(r.reference)),
      pgv.esc(r.label),
      CASE WHEN r.debit > 0 THEN to_char(r.debit, 'FM999 990.00') ELSE '' END,
      CASE WHEN r.credit > 0 THEN to_char(r.credit, 'FM999 990.00') ELSE '' END,
      to_char(v_cumul, 'FM999 990.00')
    ];
  END LOOP;

  -- Stats
  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.stat('Total débit', to_char(v_total_debit, 'FM999 990.00') || ' €'),
    pgv.stat('Total crédit', to_char(v_total_credit, 'FM999 990.00') || ' €'),
    pgv.stat('Solde', to_char(v_cumul, 'FM999 990.00') || ' €')
  ]);

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucun mouvement sur ' || v_year, 'Ce compte n''a pas d''écriture validée sur la période.');
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY['Date', 'Référence', 'Libellé', 'Débit', 'Crédit', 'Solde cumulé'],
      v_rows, 20
    );
  END IF;

  RETURN v_body;
END;
$function$;
