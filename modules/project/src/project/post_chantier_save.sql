CREATE OR REPLACE FUNCTION project.post_chantier_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int;
  v_numero text;
BEGIN
  IF p_data->>'id' IS NOT NULL THEN
    v_id := (p_data->>'id')::int;
    IF NOT EXISTS (SELECT 1 FROM project.chantier WHERE id = v_id AND statut IN ('preparation','execution')) THEN
      RAISE EXCEPTION '%', pgv.t('project.err_seuls_modifiables');
    END IF;
    UPDATE project.chantier SET
      client_id = (p_data->>'client_id')::int,
      devis_id = NULLIF(p_data->>'devis_id', '')::int,
      objet = p_data->>'objet',
      adresse = coalesce(p_data->>'adresse', ''),
      date_debut = NULLIF(p_data->>'date_debut', '')::date,
      date_fin_prevue = NULLIF(p_data->>'date_fin_prevue', '')::date,
      notes = coalesce(p_data->>'notes', ''),
      updated_at = now()
    WHERE id = v_id;
  ELSE
    v_numero := project._next_numero();
    INSERT INTO project.chantier (numero, client_id, devis_id, objet, adresse, date_debut, date_fin_prevue, notes)
    VALUES (
      v_numero,
      (p_data->>'client_id')::int,
      NULLIF(p_data->>'devis_id', '')::int,
      p_data->>'objet',
      coalesce(p_data->>'adresse', ''),
      NULLIF(p_data->>'date_debut', '')::date,
      NULLIF(p_data->>'date_fin_prevue', '')::date,
      coalesce(p_data->>'notes', '')
    ) RETURNING id INTO v_id;
  END IF;

  RETURN pgv.toast(pgv.t('project.toast_enregistre'))
    || pgv.redirect(pgv.call_ref('get_chantier', jsonb_build_object('p_id', v_id)));
END;
$function$;
