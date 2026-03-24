CREATE OR REPLACE FUNCTION expense.note_create(p_row expense.note)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_ref text;
  v_result expense.note;
BEGIN
  v_ref := expense._next_numero();
  INSERT INTO expense.note (reference, auteur, date_debut, date_fin, commentaire)
  VALUES (v_ref, p_row.auteur, p_row.date_debut, p_row.date_fin, p_row.commentaire)
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
