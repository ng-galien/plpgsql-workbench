CREATE OR REPLACE FUNCTION expense.post_note_soumettre(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_params->>'id')::int;
  v_nb_lignes int;
BEGIN
  IF v_id IS NULL THEN
    RETURN '<template data-toast="error">ID requis.</template>';
  END IF;

  SELECT count(*)::int INTO v_nb_lignes FROM expense.ligne WHERE note_id = v_id;
  IF v_nb_lignes = 0 THEN
    RETURN '<template data-toast="error">Impossible de soumettre une note sans ligne.</template>';
  END IF;

  UPDATE expense.note SET statut = 'soumise', updated_at = now()
   WHERE id = v_id AND statut = 'brouillon';

  IF NOT FOUND THEN
    RETURN '<template data-toast="error">Note introuvable ou pas en brouillon.</template>';
  END IF;

  RETURN '<template data-toast="success">Note soumise pour validation.</template>'
    || '<template data-redirect="/note?p_id=' || v_id || '"></template>';
END;
$function$;
