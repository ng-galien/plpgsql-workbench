CREATE OR REPLACE FUNCTION planning.evenement_create(p_row planning.evenement)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.type := COALESCE(p_row.type, 'chantier');
  p_row.heure_debut := COALESCE(p_row.heure_debut, '08:00');
  p_row.heure_fin := COALESCE(p_row.heure_fin, '17:00');
  p_row.lieu := COALESCE(p_row.lieu, '');
  p_row.notes := COALESCE(p_row.notes, '');
  p_row.created_at := now();

  INSERT INTO planning.evenement (tenant_id, titre, type, chantier_id, date_debut, date_fin, heure_debut, heure_fin, lieu, notes, created_at)
  VALUES (p_row.tenant_id, p_row.titre, p_row.type, p_row.chantier_id, p_row.date_debut, p_row.date_fin, p_row.heure_debut, p_row.heure_fin, p_row.lieu, p_row.notes, p_row.created_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
