CREATE OR REPLACE FUNCTION ledger.post_cloture(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_year integer;
  v_start date;
  v_end date;
  v_total_revenue numeric;
  v_total_expense numeric;
  v_resultat numeric;
  v_draft_count integer;
  v_entry_id integer;
  v_account_120 integer;
BEGIN
  v_year := (p_data->>'year')::integer;
  IF v_year IS NULL THEN RAISE EXCEPTION 'Année requise'; END IF;

  -- Guard: pas de double clôture
  IF EXISTS (SELECT 1 FROM ledger.exercice WHERE year = v_year AND closed = true) THEN
    RETURN '<template data-toast="error">L''exercice ' || v_year || ' est déjà clôturé</template>';
  END IF;

  v_start := make_date(v_year, 1, 1);
  v_end := make_date(v_year, 12, 31);

  -- Guard: pas d'écritures brouillon sur la période
  SELECT count(*) INTO v_draft_count
    FROM ledger.journal_entry
   WHERE posted = false
     AND entry_date >= v_start AND entry_date <= v_end;

  IF v_draft_count > 0 THEN
    RETURN '<template data-toast="error">' || v_draft_count || ' écriture(s) brouillon sur ' || v_year || ' — validez-les avant clôture</template>';
  END IF;

  -- Calcul résultat : produits - charges (écritures postées)
  SELECT coalesce(sum(CASE WHEN a.type = 'revenue' THEN el.credit - el.debit ELSE 0 END), 0),
         coalesce(sum(CASE WHEN a.type = 'expense' THEN el.debit - el.credit ELSE 0 END), 0)
    INTO v_total_revenue, v_total_expense
    FROM ledger.entry_line el
    JOIN ledger.account a ON a.id = el.account_id
    JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
   WHERE je.posted = true
     AND je.entry_date >= v_start AND je.entry_date <= v_end;

  v_resultat := v_total_revenue - v_total_expense;

  -- Écriture de résultat (compte 120)
  SELECT id INTO v_account_120 FROM ledger.account WHERE code = '120';
  IF v_account_120 IS NULL THEN RAISE EXCEPTION 'Compte 120 (Résultat) introuvable dans le plan comptable'; END IF;

  INSERT INTO ledger.journal_entry (entry_date, reference, description)
  VALUES (v_end, 'CLO-' || v_year, 'Clôture exercice ' || v_year || ' — résultat ' || to_char(v_resultat, 'FM999 990.00') || ' €')
  RETURNING id INTO v_entry_id;

  -- Zero out revenue accounts: DEBIT (revenue normally has credit balance)
  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  SELECT v_entry_id, a.id, coalesce(sum(el.credit - el.debit), 0), 0, 'Solde ' || a.label
    FROM ledger.account a
    JOIN ledger.entry_line el ON el.account_id = a.id
    JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
   WHERE a.type = 'revenue' AND je.posted = true
     AND je.entry_date >= v_start AND je.entry_date <= v_end
     AND je.id <> v_entry_id
   GROUP BY a.id, a.label
  HAVING coalesce(sum(el.credit - el.debit), 0) <> 0;

  -- Zero out expense accounts: CREDIT (expense normally has debit balance)
  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  SELECT v_entry_id, a.id, 0, coalesce(sum(el.debit - el.credit), 0), 'Solde ' || a.label
    FROM ledger.account a
    JOIN ledger.entry_line el ON el.account_id = a.id
    JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
   WHERE a.type = 'expense' AND je.posted = true
     AND je.entry_date >= v_start AND je.entry_date <= v_end
     AND je.id <> v_entry_id
   GROUP BY a.id, a.label
  HAVING coalesce(sum(el.debit - el.credit), 0) <> 0;

  -- Result to account 120: credit if benefit, debit if deficit
  IF v_resultat >= 0 THEN
    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES (v_entry_id, v_account_120, 0, v_resultat, 'Résultat bénéficiaire ' || v_year);
  ELSE
    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES (v_entry_id, v_account_120, abs(v_resultat), 0, 'Résultat déficitaire ' || v_year);
  END IF;

  -- Valider l'écriture de clôture
  UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

  -- Marquer l'exercice clos
  INSERT INTO ledger.exercice (year, closed, closed_at, result)
  VALUES (v_year, true, now(), v_resultat)
  ON CONFLICT ON CONSTRAINT exercice_tenant_year_key
  DO UPDATE SET closed = true, closed_at = now(), result = v_resultat;

  RETURN '<template data-toast="success">Exercice ' || v_year || ' clôturé — résultat : ' || to_char(v_resultat, 'FM999 990.00') || ' €</template>'
    || '<template data-redirect="' || pgv.call_ref('get_exercice', jsonb_build_object('p_year', v_year)) || '"></template>';
END;
$function$;
