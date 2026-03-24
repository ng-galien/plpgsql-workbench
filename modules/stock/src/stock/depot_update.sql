CREATE OR REPLACE FUNCTION stock.depot_update(p_row stock.depot)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE stock.depot SET
    nom = COALESCE(NULLIF(p_row.nom, ''), nom),
    type = COALESCE(NULLIF(p_row.type, ''), type),
    adresse = COALESCE(p_row.adresse, adresse),
    actif = COALESCE(p_row.actif, actif)
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
