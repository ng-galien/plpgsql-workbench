CREATE OR REPLACE FUNCTION planning.post_intervenant_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_nom text;
BEGIN
  v_nom := trim(COALESCE(p_data->>'nom', ''));
  IF v_nom = '' THEN
    RETURN pgv.toast(pgv.t('planning.err_nom_required'), 'error');
  END IF;

  v_id := NULLIF(trim(COALESCE(p_data->>'id', '')), '')::int;

  IF v_id IS NOT NULL THEN
    UPDATE planning.intervenant SET
      nom = v_nom,
      role = COALESCE(trim(p_data->>'role'), ''),
      telephone = NULLIF(trim(COALESCE(p_data->>'telephone', '')), ''),
      couleur = COALESCE(NULLIF(trim(p_data->>'couleur'), ''), '#3b82f6'),
      actif = COALESCE((p_data->>'actif')::boolean, true)
    WHERE id = v_id;
  ELSE
    INSERT INTO planning.intervenant (nom, role, telephone, couleur, actif)
    VALUES (
      v_nom,
      COALESCE(trim(p_data->>'role'), ''),
      NULLIF(trim(COALESCE(p_data->>'telephone', '')), ''),
      COALESCE(NULLIF(trim(p_data->>'couleur'), ''), '#3b82f6'),
      COALESCE((p_data->>'actif')::boolean, true)
    )
    RETURNING id INTO v_id;
  END IF;

  RETURN pgv.toast(pgv.t('planning.toast_intervenant_saved'))
      || pgv.redirect(pgv.call_ref('get_intervenant', jsonb_build_object('p_id', v_id)));
END;
$function$;
