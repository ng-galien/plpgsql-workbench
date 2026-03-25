CREATE OR REPLACE FUNCTION hr.employee_create(p_row hr.employee)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.created_at := now();
  p_row.updated_at := now();

  INSERT INTO hr.employee (tenant_id, matricule, nom, prenom, email, phone, date_naissance, sexe, nationalite, poste, qualification, departement, type_contrat, date_embauche, date_fin, salaire_brut, heures_hebdo, statut, notes, created_at, updated_at)
  VALUES (p_row.tenant_id, COALESCE(p_row.matricule, ''), p_row.nom, p_row.prenom, p_row.email, p_row.phone, p_row.date_naissance, COALESCE(p_row.sexe, ''), COALESCE(p_row.nationalite, ''), COALESCE(p_row.poste, ''), COALESCE(p_row.qualification, ''), COALESCE(p_row.departement, ''), COALESCE(p_row.type_contrat, 'cdi'), COALESCE(p_row.date_embauche, CURRENT_DATE), p_row.date_fin, p_row.salaire_brut, COALESCE(p_row.heures_hebdo, 35), COALESCE(p_row.statut, 'actif'), COALESCE(p_row.notes, ''), p_row.created_at, p_row.updated_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
