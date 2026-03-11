CREATE OR REPLACE FUNCTION ledger.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_solde_banque numeric;
  v_ca_mois numeric;
  v_charges_mois numeric;
  v_resultat numeric;
  v_month_start date;
  v_month_end date;
  v_rows text[];
  r record;
BEGIN
  v_month_start := date_trunc('month', CURRENT_DATE)::date;
  v_month_end := (date_trunc('month', CURRENT_DATE) + interval '1 month' - interval '1 day')::date;

  -- KPIs
  SELECT ledger._account_balance(a.id) INTO v_solde_banque
    FROM ledger.account a WHERE a.code = '512';

  v_ca_mois := ledger._period_total('revenue', v_month_start, v_month_end);
  v_charges_mois := ledger._period_total('expense', v_month_start, v_month_end);
  v_resultat := coalesce(v_ca_mois, 0) - coalesce(v_charges_mois, 0);

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Solde banque', to_char(coalesce(v_solde_banque, 0), 'FM999 999.00') || ' €'),
    pgv.stat('CA du mois', to_char(coalesce(v_ca_mois, 0), 'FM999 999.00') || ' €'),
    pgv.stat('Charges du mois', to_char(coalesce(v_charges_mois, 0), 'FM999 999.00') || ' €'),
    pgv.stat('Résultat', to_char(v_resultat, 'FM999 999.00') || ' €')
  ]);

  -- Écritures récentes
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT je.id, je.entry_date, je.reference, je.description, je.posted,
           coalesce(sum(el.debit), 0) AS total_debit
      FROM ledger.journal_entry je
      LEFT JOIN ledger.entry_line el ON el.journal_entry_id = je.id
     GROUP BY je.id
     ORDER BY je.entry_date DESC, je.id DESC
     LIMIT 10
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.entry_date, 'DD/MM/YYYY'),
      format('<a href="%s">%s</a>', pgv.call_ref('get_entry', jsonb_build_object('p_id', r.id)), pgv.esc(r.reference)),
      pgv.esc(r.description),
      to_char(r.total_debit, 'FM999 999.00') || ' €',
      CASE WHEN r.posted THEN pgv.badge('Validée', 'success') ELSE pgv.badge('Brouillon', 'warning') END
    ];
  END LOOP;

  v_body := v_body || pgv.tabs(VARIADIC ARRAY[
    'Écritures récentes',
    CASE WHEN array_length(v_rows, 1) IS NULL
      THEN pgv.empty('Aucune écriture', 'Créez votre première écriture.')
      ELSE pgv.md_table(ARRAY['Date', 'Référence', 'Description', 'Montant', 'Statut'], v_rows)
    END
  ]);

  v_body := v_body || format('<p><a href="%s" role="button">Nouvelle écriture</a></p>', pgv.call_ref('get_entry_form'));

  RETURN v_body;
END;
$function$;
