CREATE OR REPLACE FUNCTION expense_ut.test_workflow()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_note_id int;
  v_res text;
  v_statut text;
BEGIN
  -- Clean
  DELETE FROM expense.ligne;
  DELETE FROM expense.note;

  -- Create note
  v_res := expense.post_note_creer('{"auteur":"Alice","date_debut":"2026-03-01","date_fin":"2026-03-31"}'::jsonb);
  RETURN NEXT ok(v_res LIKE '%data-toast="success"%', 'note created');
  SELECT id INTO v_note_id FROM expense.note ORDER BY id DESC LIMIT 1;

  -- Submit without lines -> fail
  v_res := expense.post_note_soumettre(jsonb_build_object('id', v_note_id));
  RETURN NEXT ok(v_res LIKE '%sans ligne%', 'cannot submit without lines');

  -- Add line
  v_res := expense.post_ligne_ajouter(jsonb_build_object(
    'note_id', v_note_id, 'date_depense', '2026-03-05',
    'description', 'Repas client', 'montant_ht', 25.00, 'tva', 5.00,
    'categorie_id', (SELECT id FROM expense.categorie WHERE nom = 'Repas')
  ));
  RETURN NEXT ok(v_res LIKE '%Ligne ajoutée%', 'line added');

  -- Submit
  v_res := expense.post_note_soumettre(jsonb_build_object('id', v_note_id));
  RETURN NEXT ok(v_res LIKE '%soumise%', 'note submitted');
  SELECT statut INTO v_statut FROM expense.note WHERE id = v_note_id;
  RETURN NEXT is(v_statut, 'soumise', 'statut is soumise');

  -- Cannot add line after submit
  v_res := expense.post_ligne_ajouter(jsonb_build_object(
    'note_id', v_note_id, 'date_depense', '2026-03-06',
    'description', 'Should fail', 'montant_ht', 10.00
  ));
  RETURN NEXT ok(v_res LIKE '%brouillon%', 'cannot add line to submitted note');

  -- Validate
  v_res := expense.post_note_valider(jsonb_build_object('id', v_note_id));
  RETURN NEXT ok(v_res LIKE '%validée%', 'note validated');
  SELECT statut INTO v_statut FROM expense.note WHERE id = v_note_id;
  RETURN NEXT is(v_statut, 'validee', 'statut is validee');

  -- Reimburse
  v_res := expense.post_note_rembourser(jsonb_build_object('id', v_note_id));
  RETURN NEXT ok(v_res LIKE '%remboursée%', 'note reimbursed');
  SELECT statut INTO v_statut FROM expense.note WHERE id = v_note_id;
  RETURN NEXT is(v_statut, 'remboursee', 'statut is remboursee');

  -- Cleanup
  DELETE FROM expense.ligne WHERE note_id = v_note_id;
  DELETE FROM expense.note WHERE id = v_note_id;
END;
$function$;
