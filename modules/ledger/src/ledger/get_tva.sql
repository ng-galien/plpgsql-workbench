CREATE OR REPLACE FUNCTION ledger.get_tva(p_params jsonb DEFAULT '{}'::jsonb)
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

  v_body := pgv.breadcrumb(VARIADIC ARRAY['TVA']);

  -- Sélecteur période
  v_body := v_body || '<div class="grid">'
    || format('<a href="%s" role="button" class="outline">T1</a>', pgv.call_ref('get_tva', jsonb_build_object('p_year', v_year, 'p_quarter', 1)))
    || format('<a href="%s" role="button" class="outline">T2</a>', pgv.call_ref('get_tva', jsonb_build_object('p_year', v_year, 'p_quarter', 2)))
    || format('<a href="%s" role="button" class="outline">T3</a>', pgv.call_ref('get_tva', jsonb_build_object('p_year', v_year, 'p_quarter', 3)))
    || format('<a href="%s" role="button" class="outline">T4</a>', pgv.call_ref('get_tva', jsonb_build_object('p_year', v_year, 'p_quarter', 4)))
    || '</div>';

  v_body := v_body || '<p>Période : T' || v_quarter || ' ' || v_year
    || ' (' || to_char(v_start, 'DD/MM/YYYY') || ' — ' || to_char(v_end, 'DD/MM/YYYY') || ')</p>';

  -- TVA collectée (4457) = SUM credit - SUM debit sur la période
  SELECT coalesce(sum(el.credit) - sum(el.debit), 0) INTO v_collectee
    FROM ledger.entry_line el
    JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
    JOIN ledger.account a ON a.id = el.account_id
   WHERE a.code = '4457' AND je.posted = true
     AND je.entry_date >= v_start AND je.entry_date <= v_end;

  -- TVA déductible (4456) = SUM debit - SUM credit sur la période
  SELECT coalesce(sum(el.debit) - sum(el.credit), 0) INTO v_deductible
    FROM ledger.entry_line el
    JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
    JOIN ledger.account a ON a.id = el.account_id
   WHERE a.code = '4456' AND je.posted = true
     AND je.entry_date >= v_start AND je.entry_date <= v_end;

  v_solde := v_collectee - v_deductible;

  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.stat('TVA collectée', to_char(v_collectee, 'FM999 990.00') || ' €'),
    pgv.stat('TVA déductible', to_char(v_deductible, 'FM999 990.00') || ' €'),
    pgv.stat(
      CASE WHEN v_solde >= 0 THEN 'TVA à reverser' ELSE 'Crédit de TVA' END,
      to_char(abs(v_solde), 'FM999 990.00') || ' €'
    )
  ]);

  -- Détail par écriture
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
    v_body := v_body || '<h4>Détail mouvements TVA</h4>'
      || pgv.md_table(ARRAY['Date', 'Référence', 'Compte', 'Débit', 'Crédit'], v_rows);
  ELSE
    v_body := v_body || pgv.empty('Aucun mouvement TVA sur la période');
  END IF;

  RETURN v_body;
END;
$function$;
