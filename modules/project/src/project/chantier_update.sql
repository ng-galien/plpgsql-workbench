CREATE OR REPLACE FUNCTION project.chantier_update(p_row project.project)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  UPDATE project.chantier SET
    client_id = COALESCE(p_row.client_id, client_id),
    devis_id = COALESCE(p_row.devis_id, devis_id),
    objet = COALESCE(NULLIF(p_row.objet, ''), objet),
    adresse = COALESCE(p_row.adresse, adresse),
    date_debut = COALESCE(p_row.date_debut, date_debut),
    date_fin_prevue = COALESCE(p_row.date_fin_prevue, date_fin_prevue),
    notes = COALESCE(p_row.notes, notes),
    updated_at = now()
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING to_jsonb(project.chantier.*) INTO v_result;

  RETURN v_result;
END;
$function$;
