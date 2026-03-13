CREATE OR REPLACE FUNCTION hr.post_employee_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_nom text := trim(COALESCE(p_data->>'nom', ''));
  v_prenom text := trim(COALESCE(p_data->>'prenom', ''));
BEGIN
  IF v_nom = '' OR v_prenom = '' THEN
    RETURN pgv.toast('Nom et prénom obligatoires.', 'error');
  END IF;

  v_id := (p_data->>'id')::int;

  IF v_id IS NOT NULL THEN
    UPDATE hr.employee SET
      nom = v_nom,
      prenom = v_prenom,
      email = NULLIF(trim(COALESCE(p_data->>'email', '')), ''),
      phone = NULLIF(trim(COALESCE(p_data->>'phone', '')), ''),
      matricule = COALESCE(trim(p_data->>'matricule'), ''),
      date_naissance = (NULLIF(trim(COALESCE(p_data->>'date_naissance', '')), ''))::date,
      poste = COALESCE(trim(p_data->>'poste'), ''),
      departement = COALESCE(trim(p_data->>'departement'), ''),
      sexe = COALESCE(NULLIF(trim(p_data->>'sexe'), ''), ''),
      nationalite = COALESCE(trim(p_data->>'nationalite'), ''),
      qualification = COALESCE(trim(p_data->>'qualification'), ''),
      type_contrat = COALESCE(NULLIF(trim(p_data->>'type_contrat'), ''), 'cdi'),
      date_embauche = COALESCE((NULLIF(trim(p_data->>'date_embauche'), ''))::date, CURRENT_DATE),
      date_fin = (NULLIF(trim(COALESCE(p_data->>'date_fin', '')), ''))::date,
      heures_hebdo = COALESCE((NULLIF(trim(p_data->>'heures_hebdo'), ''))::numeric, 35),
      notes = COALESCE(trim(p_data->>'notes'), '')
    WHERE id = v_id;

    IF NOT FOUND THEN
      RETURN pgv.toast('Salarié introuvable.', 'error');
    END IF;

    RETURN pgv.toast('Salarié mis à jour.')
      || pgv.redirect(pgv.call_ref('get_employee', jsonb_build_object('p_id', v_id)));
  ELSE
    INSERT INTO hr.employee (nom, prenom, email, phone, matricule, date_naissance, sexe, nationalite, poste, departement, qualification, type_contrat, date_embauche, date_fin, heures_hebdo, notes)
    VALUES (
      v_nom, v_prenom,
      NULLIF(trim(COALESCE(p_data->>'email', '')), ''),
      NULLIF(trim(COALESCE(p_data->>'phone', '')), ''),
      COALESCE(trim(p_data->>'matricule'), ''),
      (NULLIF(trim(COALESCE(p_data->>'date_naissance', '')), ''))::date,
      COALESCE(NULLIF(trim(p_data->>'sexe'), ''), ''),
      COALESCE(trim(p_data->>'nationalite'), ''),
      COALESCE(trim(p_data->>'poste'), ''),
      COALESCE(trim(p_data->>'departement'), ''),
      COALESCE(trim(p_data->>'qualification'), ''),
      COALESCE(NULLIF(trim(p_data->>'type_contrat'), ''), 'cdi'),
      COALESCE((NULLIF(trim(p_data->>'date_embauche'), ''))::date, CURRENT_DATE),
      (NULLIF(trim(COALESCE(p_data->>'date_fin', '')), ''))::date,
      COALESCE((NULLIF(trim(p_data->>'heures_hebdo'), ''))::numeric, 35),
      COALESCE(trim(p_data->>'notes'), '')
    )
    RETURNING id INTO v_id;

    RETURN pgv.toast('Salarié créé.')
      || pgv.redirect(pgv.call_ref('get_employee', jsonb_build_object('p_id', v_id)));
  END IF;
END;
$function$;
