CREATE OR REPLACE FUNCTION expense_ut.test_next_numero()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_ref1 text;
  v_ref2 text;
  v_year text := to_char(now(), 'YYYY');
  v_res text;
BEGIN
  -- Clean
  DELETE FROM expense.ligne;
  DELETE FROM expense.note;

  -- Create first note -> should get NDF-YYYY-001
  v_res := expense.post_note_creer('{"auteur":"Test","date_debut":"2026-03-01","date_fin":"2026-03-31"}'::jsonb);
  SELECT reference INTO v_ref1 FROM expense.note ORDER BY id DESC LIMIT 1;
  RETURN NEXT is(v_ref1, 'NDF-' || v_year || '-001', 'first note gets NDF-YYYY-001');

  -- Create second note -> should get NDF-YYYY-002
  v_res := expense.post_note_creer('{"auteur":"Test","date_debut":"2026-03-01","date_fin":"2026-03-31"}'::jsonb);
  SELECT reference INTO v_ref2 FROM expense.note ORDER BY id DESC LIMIT 1;
  RETURN NEXT is(v_ref2, 'NDF-' || v_year || '-002', 'second note gets NDF-YYYY-002');

  -- Cleanup
  DELETE FROM expense.ligne;
  DELETE FROM expense.note;
END;
$function$;
