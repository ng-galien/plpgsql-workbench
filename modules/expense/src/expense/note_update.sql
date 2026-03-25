CREATE OR REPLACE FUNCTION expense.note_update(p_row expense.note)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_result expense.note;
BEGIN
  UPDATE expense.note SET
    auteur = COALESCE(p_row.auteur, auteur),
    date_debut = COALESCE(p_row.date_debut, date_debut),
    date_fin = COALESCE(p_row.date_fin, date_fin),
    commentaire = COALESCE(p_row.commentaire, commentaire),
    updated_at = now()
  WHERE id = p_row.id AND statut = 'brouillon'
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
