CREATE OR REPLACE FUNCTION planning.evenement_update(p_row planning.evenement)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE planning.evenement SET
    titre = COALESCE(NULLIF(p_row.titre, ''), titre),
    type = COALESCE(NULLIF(p_row.type, ''), type),
    chantier_id = COALESCE(p_row.chantier_id, chantier_id),
    date_debut = COALESCE(p_row.date_debut, date_debut),
    date_fin = COALESCE(p_row.date_fin, date_fin),
    heure_debut = COALESCE(p_row.heure_debut, heure_debut),
    heure_fin = COALESCE(p_row.heure_fin, heure_fin),
    lieu = COALESCE(p_row.lieu, lieu),
    notes = COALESCE(p_row.notes, notes)
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
