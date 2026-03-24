CREATE OR REPLACE FUNCTION project.chantier_create(p_row project.chantier)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.numero := project._next_numero();
  p_row.statut := COALESCE(NULLIF(p_row.statut, ''), 'preparation');
  p_row.created_at := now();
  p_row.updated_at := now();

  INSERT INTO project.chantier (numero, client_id, devis_id, objet, adresse, statut,
    date_debut, date_fin_prevue, notes, created_at, updated_at, tenant_id)
  VALUES (p_row.numero, p_row.client_id, p_row.devis_id, p_row.objet, p_row.adresse, p_row.statut,
    p_row.date_debut, p_row.date_fin_prevue, p_row.notes, p_row.created_at, p_row.updated_at, p_row.tenant_id)
  RETURNING to_jsonb(project.chantier.*) INTO v_result;

  RETURN v_result;
END;
$function$;
