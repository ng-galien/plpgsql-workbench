CREATE OR REPLACE FUNCTION quote.devis_create(p_row quote.devis)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.numero := quote._next_numero('DEV');
  p_row.statut := coalesce(p_row.statut, 'brouillon');
  p_row.notes := coalesce(p_row.notes, '');
  p_row.validite_jours := coalesce(p_row.validite_jours, 30);
  p_row.created_at := now();
  p_row.updated_at := now();

  INSERT INTO quote.devis (numero, client_id, objet, statut, notes, validite_jours, tenant_id, created_at, updated_at)
  VALUES (p_row.numero, p_row.client_id, p_row.objet, p_row.statut, p_row.notes, p_row.validite_jours, p_row.tenant_id, p_row.created_at, p_row.updated_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
