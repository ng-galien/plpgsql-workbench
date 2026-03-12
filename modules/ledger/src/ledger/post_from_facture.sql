CREATE OR REPLACE FUNCTION ledger.post_from_facture(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_facture_id integer;
  v_facture record;
  v_entry_id integer;
  v_total_ht numeric(12,2);
  v_total_tva numeric(12,2);
  v_total_ttc numeric(12,2);
  v_account_411 integer;
  v_account_4457 integer;
  v_account_706 integer;
BEGIN
  v_facture_id := (p_data->>'facture_id')::integer;

  SELECT * INTO v_facture FROM quote.facture WHERE id = v_facture_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Facture % introuvable', v_facture_id; END IF;

  -- Guard: doublon interdit
  IF EXISTS (SELECT 1 FROM ledger.journal_entry WHERE facture_id = v_facture_id) THEN
    RETURN '<template data-toast="error">Cette facture a déjà une écriture comptable</template>';
  END IF;

  -- Totaux
  SELECT coalesce(sum(round(l.quantite * l.prix_unitaire, 2)), 0),
         coalesce(sum(round(l.quantite * l.prix_unitaire * l.tva_rate / 100, 2)), 0)
    INTO v_total_ht, v_total_tva
    FROM quote.ligne l
   WHERE l.facture_id = v_facture_id;

  v_total_ttc := v_total_ht + v_total_tva;

  IF v_total_ttc = 0 THEN RAISE EXCEPTION 'Facture sans montant'; END IF;

  -- Resolve account IDs
  SELECT id INTO v_account_411 FROM ledger.account WHERE code = '411';
  SELECT id INTO v_account_4457 FROM ledger.account WHERE code = '4457';
  SELECT id INTO v_account_706 FROM ledger.account WHERE code = '706';

  -- Create journal entry with facture_id
  INSERT INTO ledger.journal_entry (entry_date, reference, description, facture_id)
  VALUES (
    coalesce(v_facture.paid_at::date, CURRENT_DATE),
    'FAC-' || v_facture.numero,
    'Facture ' || v_facture.numero || ' — ' || v_facture.objet,
    v_facture_id
  ) RETURNING id INTO v_entry_id;

  -- 411 Clients — débit TTC
  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  VALUES (v_entry_id, v_account_411, v_total_ttc, 0, 'Client facture ' || v_facture.numero);

  -- 4457 TVA collectée — crédit TVA
  IF v_total_tva > 0 THEN
    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES (v_entry_id, v_account_4457, 0, v_total_tva, 'TVA collectée facture ' || v_facture.numero);
  END IF;

  -- 706 Prestations — crédit HT
  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  VALUES (v_entry_id, v_account_706, 0, v_total_ht, 'Prestation facture ' || v_facture.numero);

  RETURN '<template data-toast="success">Écriture créée depuis facture ' || pgv.esc(v_facture.numero) || '</template>'
    || '<template data-redirect="' || pgv.call_ref('get_entry', jsonb_build_object('p_id', v_entry_id)) || '"></template>';
END;
$function$;
