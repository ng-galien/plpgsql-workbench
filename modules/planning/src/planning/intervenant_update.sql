CREATE OR REPLACE FUNCTION planning.intervenant_update(p_row planning.intervenant)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE planning.intervenant SET
    nom = COALESCE(NULLIF(p_row.nom, ''), nom),
    role = COALESCE(p_row.role, role),
    telephone = COALESCE(p_row.telephone, telephone),
    couleur = COALESCE(NULLIF(p_row.couleur, ''), couleur),
    actif = COALESCE(p_row.actif, actif)
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
