CREATE OR REPLACE FUNCTION planning.post_evenement_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int;
  v_titre text;
  v_date_debut date;
  v_date_fin date;
BEGIN
  v_titre := trim(COALESCE(p_data->>'titre', ''));
  IF v_titre = '' THEN
    RETURN pgv.toast(pgv.t('planning.err_titre_required'), 'error');
  END IF;

  v_date_debut := (p_data->>'date_debut')::date;
  v_date_fin := (p_data->>'date_fin')::date;
  IF v_date_fin < v_date_debut THEN
    RETURN pgv.toast(pgv.t('planning.err_date_order'), 'error');
  END IF;

  v_id := NULLIF(trim(COALESCE(p_data->>'id', '')), '')::int;

  IF v_id IS NOT NULL THEN
    UPDATE planning.evenement SET
      titre = v_titre,
      type = COALESCE(NULLIF(trim(p_data->>'type'), ''), 'chantier'),
      date_debut = v_date_debut,
      date_fin = v_date_fin,
      heure_debut = COALESCE(NULLIF(trim(p_data->>'heure_debut'), '')::time, '08:00'),
      heure_fin = COALESCE(NULLIF(trim(p_data->>'heure_fin'), '')::time, '17:00'),
      lieu = COALESCE(trim(p_data->>'lieu'), ''),
      chantier_id = NULLIF(trim(COALESCE(p_data->>'chantier_id', '')), '')::int,
      notes = COALESCE(trim(p_data->>'notes'), '')
    WHERE id = v_id;
  ELSE
    INSERT INTO planning.evenement (titre, type, date_debut, date_fin, heure_debut, heure_fin, lieu, chantier_id, notes)
    VALUES (
      v_titre,
      COALESCE(NULLIF(trim(p_data->>'type'), ''), 'chantier'),
      v_date_debut,
      v_date_fin,
      COALESCE(NULLIF(trim(p_data->>'heure_debut'), '')::time, '08:00'),
      COALESCE(NULLIF(trim(p_data->>'heure_fin'), '')::time, '17:00'),
      COALESCE(trim(p_data->>'lieu'), ''),
      NULLIF(trim(COALESCE(p_data->>'chantier_id', '')), '')::int,
      COALESCE(trim(p_data->>'notes'), '')
    )
    RETURNING id INTO v_id;
  END IF;

  RETURN pgv.toast(pgv.t('planning.toast_evenement_saved'))
      || pgv.redirect(pgv.call_ref('get_evenement', jsonb_build_object('p_id', v_id)));
END;
$function$;
