CREATE OR REPLACE FUNCTION hr.absence_update(p_row hr.absence)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE hr.absence SET
    type_absence = COALESCE(NULLIF(p_row.type_absence, ''), type_absence),
    date_debut = COALESCE(p_row.date_debut, date_debut),
    date_fin = COALESCE(p_row.date_fin, date_fin),
    nb_jours = COALESCE(p_row.nb_jours, nb_jours),
    motif = COALESCE(p_row.motif, motif),
    statut = COALESCE(NULLIF(p_row.statut, ''), statut)
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
