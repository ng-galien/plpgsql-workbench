CREATE OR REPLACE FUNCTION purchase.post_facture_comptabiliser(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
  v_facture record;
  v_tva numeric(12,2);
  v_entry_id int;
  v_ledger_exists boolean;
BEGIN
  -- Check facture exists and is payee
  SELECT * INTO v_facture FROM purchase.facture_fournisseur WHERE id = v_id;
  IF NOT FOUND THEN
    RETURN '<template data-toast="error">Facture introuvable</template>';
  END IF;
  IF v_facture.statut <> 'payee' THEN
    RETURN '<template data-toast="error">La facture doit être payée avant comptabilisation</template>';
  END IF;
  IF v_facture.montant_ttc = 0 THEN
    RETURN '<template data-toast="error">Facture sans montant</template>';
  END IF;

  -- Check ledger schema exists
  SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = 'ledger') INTO v_ledger_exists;
  IF NOT v_ledger_exists THEN
    RETURN '<template data-toast="error">Module ledger non déployé</template>';
  END IF;

  -- Compute TVA (TTC - HT)
  v_tva := v_facture.montant_ttc - v_facture.montant_ht;

  -- Create journal entry via dynamic SQL (no hard dependency on ledger)
  EXECUTE format(
    $e$INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES (%L, %L, %L) RETURNING id$e$,
    coalesce(v_facture.date_facture, CURRENT_DATE),
    'FAF-' || v_facture.numero_fournisseur,
    'Facture fournisseur ' || v_facture.numero_fournisseur
  ) INTO v_entry_id;

  -- 601 Achats matériaux — débit HT
  EXECUTE format(
    $e$INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES (%s, (SELECT id FROM ledger.account WHERE code = '601'), %s, 0, %L)$e$,
    v_entry_id, v_facture.montant_ht,
    'Achat facture ' || v_facture.numero_fournisseur
  );

  -- 4456 TVA déductible — débit TVA
  IF v_tva > 0 THEN
    EXECUTE format(
      $e$INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
      VALUES (%s, (SELECT id FROM ledger.account WHERE code = '4456'), %s, 0, %L)$e$,
      v_entry_id, v_tva,
      'TVA déductible facture ' || v_facture.numero_fournisseur
    );
  END IF;

  -- 401 Fournisseurs — crédit TTC
  EXECUTE format(
    $e$INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES (%s, (SELECT id FROM ledger.account WHERE code = '401'), 0, %s, %L)$e$,
    v_entry_id, v_facture.montant_ttc,
    'Fournisseur facture ' || v_facture.numero_fournisseur
  );

  RETURN '<template data-toast="success">Écriture comptable créée</template>'
    || format('<template data-redirect="%s"></template>',
       pgv.call_ref('get_facture_fournisseur', jsonb_build_object('p_id', v_id)));
END;
$function$;
