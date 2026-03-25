CREATE OR REPLACE FUNCTION hr.absence_create(p_row hr.absence)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.created_at := now();

  INSERT INTO hr.absence (tenant_id, employee_id, type_absence, date_debut, date_fin, nb_jours, motif, statut, created_at)
  VALUES (p_row.tenant_id, p_row.employee_id, COALESCE(p_row.type_absence, 'conge_paye'), p_row.date_debut, p_row.date_fin, COALESCE(p_row.nb_jours, 1), COALESCE(p_row.motif, ''), COALESCE(p_row.statut, 'demande'), p_row.created_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
