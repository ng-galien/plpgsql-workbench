CREATE OR REPLACE FUNCTION quote.facture_create(p_row quote.facture)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.numero := quote._next_numero('FAC');
  p_row.statut := coalesce(p_row.statut, 'brouillon');
  p_row.notes := coalesce(p_row.notes, '');
  p_row.created_at := now();
  p_row.updated_at := now();

  INSERT INTO quote.facture (numero, client_id, devis_id, objet, statut, notes, tenant_id, created_at, updated_at)
  VALUES (p_row.numero, p_row.client_id, p_row.devis_id, p_row.objet, p_row.statut, p_row.notes, p_row.tenant_id, p_row.created_at, p_row.updated_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
