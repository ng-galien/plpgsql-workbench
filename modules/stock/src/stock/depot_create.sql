CREATE OR REPLACE FUNCTION stock.depot_create(p_row stock.depot)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.created_at := now();

  INSERT INTO stock.depot (tenant_id, nom, type, adresse, actif, created_at)
  VALUES (p_row.tenant_id, p_row.nom, p_row.type, p_row.adresse, coalesce(p_row.actif, true), p_row.created_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
