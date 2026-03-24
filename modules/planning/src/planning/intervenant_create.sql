CREATE OR REPLACE FUNCTION planning.intervenant_create(p_row planning.intervenant)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.actif := COALESCE(p_row.actif, true);
  p_row.couleur := COALESCE(p_row.couleur, '#3b82f6');
  p_row.created_at := now();

  INSERT INTO planning.intervenant (tenant_id, nom, role, telephone, couleur, actif, created_at)
  VALUES (p_row.tenant_id, p_row.nom, COALESCE(p_row.role, ''), p_row.telephone, p_row.couleur, p_row.actif, p_row.created_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
