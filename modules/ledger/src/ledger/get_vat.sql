CREATE OR REPLACE FUNCTION ledger.get_vat(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_year integer;
  v_quarter integer;
  v_start date;
  v_end date;
  v_collectee numeric;
  v_deductible numeric;
  v_solde numeric;
  v_body text;
  v_rows text[];
  r record;
BEGIN
  v_year := coalesce((p_params->>'p_year')::integer, extract(year FROM CURRENT_DATE)::integer);
  v_quarter := coalesce((p_params->>'p_quarter')::integer, extract(quarter FROM CURRENT_DATE)::integer);

  v_start := make_date(v_year, (v_quarter - 1) * 3 + 1, 1);
  v_end := (v_start + interval '3 months' - interval '1 day')::date;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[pgv.t('ledger.nav_vat')]);

  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.link_button(pgv.call_ref('get_vat', jsonb_build_object('p_year', v_year, 'p_quarter', 1)), 'T1', 'outline'),
    pgv.link_button(pgv.call_ref('get_vat', jsonb_build_object('p_year', v_year, 'p_quarter', 2)), 'T2', 'outline'),
    pgv.link_button(pgv.call_ref('get_vat', jsonb_build_object('p_year', v_year, 'p_quarter', 3)), 'T3', 'outline'),
    pgv.link_button(pgv.call_ref('get_vat', jsonb_build_object('p_year', v_year, 'p_quarter', 4)), 'T4', 'outline')
  ]);

  v_body := v_body || '<p>' || pgv.t('ledger.title_period') || ' : T' || v_quarter || ' ' || v_year
    || ' (' || to_char(v_start, 'DD/MM/YYYY') || ' — ' || to_char(v_end, 'DD/MM/YYYY') || ')</p>';

  SELECT coalesce(sum(el.credit) - sum(el.debit), 0) INTO v_collectee
    FROM ledger.entry_line el
    JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
    JOIN ledger.account a ON a.id = el.account_id
   WHERE a.code = '4457' AND je.posted = true
     AND je.entry_date >= v_start AND je.entry_date <= v_end;

  SELECT coalesce(sum(el.debit) - sum(el.credit), 0) INTO v_deductible
    FROM ledger.entry_line el
    JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
    JOIN ledger.account a ON a.id = el.account_id
   WHERE a.code = '4456' AND je.posted = true
     AND je.entry_date >= v_start AND je.entry_date <= v_end;

  v_solde := v_collectee - v_deductible;

  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('ledger.stat_tva_collected'), to_char(v_collectee, 'FM999 990.00') || ' €'),
    pgv.stat(pgv.t('ledger.stat_tva_deductible'), to_char(v_deductible, 'FM999 990.00') || ' €'),
    pgv.stat(
      CASE WHEN v_solde >= 0 THEN pgv.t('ledger.stat_tva_due') ELSE pgv.t('ledger.stat_tva_credit') END,
      to_char(abs(v_solde), 'FM999 990.00') || ' €'
    )
  ]);

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT je.entry_date, je.reference, je.id AS entry_id,
           el.debit, el.credit, a.code, a.label AS account_label
      FROM ledger.entry_line el
      JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
      JOIN ledger.account a ON a.id = el.account_id
     WHERE a.code IN ('4456', '4457') AND je.posted = true
       AND je.entry_date >= v_start AND je.entry_date <= v_end
     ORDER BY je.entry_date, je.id
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.entry_date, 'DD/MM/YYYY'),
      format('<a href="%s">%s</a>', pgv.call_ref('get_entry', jsonb_build_object('p_id', r.entry_id)), pgv.esc(r.reference)),
      r.code || ' ' || pgv.esc(r.account_label),
      CASE WHEN r.debit > 0 THEN to_char(r.debit, 'FM999 990.00') ELSE '' END,
      CASE WHEN r.credit > 0 THEN to_char(r.credit, 'FM999 990.00') ELSE '' END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h4>' || pgv.t('ledger.title_tva_detail') || '</h4>'
      || pgv.md_table(ARRAY[pgv.t('ledger.col_date'), pgv.t('ledger.col_reference'), pgv.t('ledger.col_account'), pgv.t('ledger.col_debit'), pgv.t('ledger.col_credit')], v_rows);
  ELSE
    v_body := v_body || pgv.empty(pgv.t('ledger.empty_no_tva'));
  END IF;

  RETURN v_body;
END;
$function$;
