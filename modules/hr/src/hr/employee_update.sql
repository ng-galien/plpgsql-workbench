CREATE OR REPLACE FUNCTION hr.employee_update(p_row hr.employee)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE hr.employee SET
    matricule = COALESCE(NULLIF(p_row.matricule, ''), matricule),
    nom = COALESCE(NULLIF(p_row.nom, ''), nom),
    prenom = COALESCE(NULLIF(p_row.prenom, ''), prenom),
    email = COALESCE(p_row.email, email),
    phone = COALESCE(p_row.phone, phone),
    date_naissance = COALESCE(p_row.date_naissance, date_naissance),
    sexe = COALESCE(NULLIF(p_row.sexe, ''), sexe),
    nationalite = COALESCE(NULLIF(p_row.nationalite, ''), nationalite),
    poste = COALESCE(NULLIF(p_row.poste, ''), poste),
    qualification = COALESCE(NULLIF(p_row.qualification, ''), qualification),
    departement = COALESCE(NULLIF(p_row.departement, ''), departement),
    type_contrat = COALESCE(NULLIF(p_row.type_contrat, ''), type_contrat),
    date_embauche = COALESCE(p_row.date_embauche, date_embauche),
    date_fin = p_row.date_fin,
    salaire_brut = COALESCE(p_row.salaire_brut, salaire_brut),
    heures_hebdo = COALESCE(p_row.heures_hebdo, heures_hebdo),
    statut = COALESCE(NULLIF(p_row.statut, ''), statut),
    notes = COALESCE(p_row.notes, notes),
    updated_at = now()
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
