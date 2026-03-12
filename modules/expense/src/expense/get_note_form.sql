CREATE OR REPLACE FUNCTION expense.get_note_form(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_params->>'id')::int;
  v_note record;
  v_body text;
BEGIN
  IF v_id IS NOT NULL THEN
    SELECT * INTO v_note FROM expense.note WHERE id = v_id;
    IF NOT FOUND THEN
      RETURN pgv.error('404', 'Note introuvable');
    END IF;
    IF v_note.statut <> 'brouillon' THEN
      RETURN pgv.error('400', 'Modification impossible', 'Seules les notes en brouillon peuvent être modifiées.');
    END IF;
  END IF;

  v_body := '<form data-rpc="post_note_creer">';

  IF v_id IS NOT NULL THEN
    v_body := v_body || '<input type="hidden" name="id" value="' || v_id || '">';
  END IF;

  v_body := v_body
    || pgv.input('auteur', 'text', 'Auteur', v_note.auteur, true)
    || '<div class="pgv-grid">'
    || pgv.input('date_debut', 'date', 'Date début', CASE WHEN v_note IS NOT NULL THEN to_char(v_note.date_debut, 'YYYY-MM-DD') ELSE to_char(date_trunc('month', now()), 'YYYY-MM-DD') END, true)
    || pgv.input('date_fin', 'date', 'Date fin', CASE WHEN v_note IS NOT NULL THEN to_char(v_note.date_fin, 'YYYY-MM-DD') ELSE to_char(now()::date, 'YYYY-MM-DD') END, true)
    || '</div>'
    || pgv.textarea('commentaire', 'Commentaire', v_note.commentaire)
    || '<button type="submit">' || CASE WHEN v_id IS NOT NULL THEN 'Modifier' ELSE 'Créer la note' END || '</button>'
    || '</form>';

  RETURN v_body;
END;
$function$;
