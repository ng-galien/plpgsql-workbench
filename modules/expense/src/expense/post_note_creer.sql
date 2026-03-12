CREATE OR REPLACE FUNCTION expense.post_note_creer(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_params->>'id')::int;
  v_auteur text := p_params->>'auteur';
  v_date_debut date := (p_params->>'date_debut')::date;
  v_date_fin date := (p_params->>'date_fin')::date;
  v_commentaire text := p_params->>'commentaire';
  v_note_id int;
BEGIN
  IF v_auteur IS NULL OR v_date_debut IS NULL OR v_date_fin IS NULL THEN
    RETURN '<template data-toast="error">Auteur, date début et date fin sont requis.</template>';
  END IF;

  IF v_date_fin < v_date_debut THEN
    RETURN '<template data-toast="error">La date de fin doit être postérieure à la date de début.</template>';
  END IF;

  IF v_id IS NOT NULL THEN
    UPDATE expense.note
       SET auteur = v_auteur,
           date_debut = v_date_debut,
           date_fin = v_date_fin,
           commentaire = v_commentaire,
           updated_at = now()
     WHERE id = v_id AND statut = 'brouillon';

    IF NOT FOUND THEN
      RETURN '<template data-toast="error">Note introuvable ou non modifiable.</template>';
    END IF;
    v_note_id := v_id;
  ELSE
    INSERT INTO expense.note (reference, auteur, date_debut, date_fin, commentaire)
    VALUES (expense._next_numero(), v_auteur, v_date_debut, v_date_fin, v_commentaire)
    RETURNING id INTO v_note_id;
  END IF;

  RETURN '<template data-toast="success">Note ' || CASE WHEN v_id IS NOT NULL THEN 'modifiée' ELSE 'créée' END || '.</template>'
    || '<template data-redirect="/note?p_id=' || v_note_id || '"></template>';
END;
$function$;
