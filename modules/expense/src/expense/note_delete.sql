CREATE OR REPLACE FUNCTION expense.note_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result expense.note;
BEGIN
  DELETE FROM expense.note
  WHERE (id = p_id::int OR reference = p_id) AND statut = 'brouillon'
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
