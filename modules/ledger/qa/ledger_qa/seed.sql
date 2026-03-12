CREATE OR REPLACE FUNCTION ledger_qa.seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_entry_id integer;
BEGIN
    -- Set tenant context for RLS
    PERFORM set_config('app.tenant_id', 'dev', true);

    -- Nettoyer les données QA existantes
    UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
    DELETE FROM ledger.entry_line;
    DELETE FROM ledger.journal_entry;

    -- ========== 1. Facture client : pose de carrelage 2 500€ HT + TVA 20% ==========
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES ('2026-01-15', 'FAC-2026-001', 'Facture pose carrelage — Client Dupont')
    RETURNING id INTO v_entry_id;

    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '411'), 3000.00, 0, 'Client Dupont TTC'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '4457'), 0, 500.00, 'TVA collectée 20%'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '706'), 0, 2500.00, 'Pose carrelage');
    UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

    -- ========== 2. Encaissement client Dupont ==========
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES ('2026-01-28', 'ENC-2026-001', 'Encaissement facture Dupont')
    RETURNING id INTO v_entry_id;

    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '512'), 3000.00, 0, 'Virement reçu'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '411'), 0, 3000.00, 'Solde client Dupont');
    UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

    -- ========== 3. Achat matériaux chez Leroy Merlin 450€ HT + TVA ==========
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES ('2026-01-10', 'ACH-2026-001', 'Achat matériaux — Leroy Merlin')
    RETURNING id INTO v_entry_id;

    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '601'), 450.00, 0, 'Carrelage + colle'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '4456'), 90.00, 0, 'TVA déductible 20%'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '512'), 0, 540.00, 'Paiement CB');
    UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

    -- ========== 4. Loyer atelier janvier ==========
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES ('2026-01-05', 'LOY-2026-01', 'Loyer atelier janvier 2026')
    RETURNING id INTO v_entry_id;

    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '613'), 800.00, 0, 'Loyer mensuel'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '512'), 0, 800.00, 'Virement propriétaire');
    UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

    -- ========== 5. Assurance pro trimestrielle ==========
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES ('2026-01-02', 'ASS-2026-T1', 'Assurance RC Pro T1 2026')
    RETURNING id INTO v_entry_id;

    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '606'), 350.00, 0, 'Assurance RC Pro'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '512'), 0, 350.00, 'Prélèvement assurance');
    UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

    -- ========== 6. Facture client : rénovation salle de bain 4 200€ HT ==========
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES ('2026-02-10', 'FAC-2026-002', 'Facture rénovation SdB — Client Martin')
    RETURNING id INTO v_entry_id;

    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '411'), 5040.00, 0, 'Client Martin TTC'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '4457'), 0, 840.00, 'TVA collectée 20%'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '706'), 0, 4200.00, 'Rénovation SdB');
    UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

    -- ========== 7. Sous-traitance plomberie ==========
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES ('2026-02-08', 'ACH-2026-002', 'Sous-traitance plomberie — Plombier Martin')
    RETURNING id INTO v_entry_id;

    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '604'), 1200.00, 0, 'Plomberie SdB'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '4456'), 240.00, 0, 'TVA déductible 20%'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '401'), 0, 1440.00, 'Fournisseur à payer');
    UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

    -- ========== 8. Paiement fournisseur plombier ==========
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES ('2026-02-20', 'PAY-2026-001', 'Paiement sous-traitant plomberie')
    RETURNING id INTO v_entry_id;

    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '401'), 1440.00, 0, 'Solde fournisseur'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '512'), 0, 1440.00, 'Virement fournisseur');
    UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

    -- ========== 9. Téléphone mobile ==========
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES ('2026-02-01', 'TEL-2026-02', 'Forfait mobile pro février')
    RETURNING id INTO v_entry_id;

    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '616'), 45.00, 0, 'Forfait Orange Pro'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '4456'), 9.00, 0, 'TVA déductible 20%'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '512'), 0, 54.00, 'Prélèvement Orange');
    UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

    -- ========== 10. Carburant véhicule ==========
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES ('2026-02-15', 'DEP-2026-001', 'Plein gasoil — déplacement chantier')
    RETURNING id INTO v_entry_id;

    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '625'), 85.00, 0, 'Gasoil'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '4456'), 17.00, 0, 'TVA déductible 20%'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '530'), 0, 102.00, 'Paiement espèces');
    UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

    -- ========== 11. Apport exploitant ==========
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES ('2026-01-01', 'EXP-2026-001', 'Apport personnel exploitant')
    RETURNING id INTO v_entry_id;

    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '512'), 5000.00, 0, 'Virement apport'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '108'), 0, 5000.00, 'Apport exploitant');
    UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

    -- ========== 12. Frais bancaires ==========
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES ('2026-01-31', 'FRB-2026-01', 'Frais bancaires janvier')
    RETURNING id INTO v_entry_id;

    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '627'), 15.00, 0, 'Commission tenue de compte'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '512'), 0, 15.00, 'Prélèvement banque');
    UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

    -- ========== 13. Écriture brouillon (non validée) ==========
    INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES ('2026-03-01', 'FAC-2026-003', 'Facture en cours — Client Lefebvre')
    RETURNING id INTO v_entry_id;

    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '411'), 1800.00, 0, 'Client Lefebvre TTC'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '4457'), 0, 300.00, 'TVA collectée 20%'),
        (v_entry_id, (SELECT id FROM ledger.account WHERE code = '706'), 0, 1500.00, 'Pose parquet');
    -- PAS de UPDATE posted = true → reste brouillon

END;
$function$;
