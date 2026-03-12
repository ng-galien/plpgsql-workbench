CREATE OR REPLACE FUNCTION expense.post_note_rejeter(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_params->>'id')::int;
BEGIN
  IF v_id IS NULL THEN
    RETURN '<template data-toast="error">ID requis.</template>';
  END IF;

  UPDATE expense.note SET statut = 'rejetee', updated_at = now()
   WHERE id = v_id AND statut = 'soumise';

  IF NOT FOUND THEN
    RETURN '<template data-toast="error">Note introuvable ou pas en statut soumise.</template>';
  END IF;

  RETURN '<template data-toast="success">Note rejetée.</template>'
    || '<template data-redirect="/note?p_id=' || v_id || '"></template>';
END;
$function$;
