CREATE OR REPLACE FUNCTION quote.facture_update(p_row quote.facture)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM quote.facture WHERE id = p_row.id AND statut = 'brouillon' AND tenant_id = current_setting('app.tenant_id', true)) THEN
    RAISE EXCEPTION '%', pgv.t('quote.err_brouillon_only');
  END IF;

  UPDATE quote.facture SET
    client_id = coalesce(p_row.client_id, client_id),
    objet = coalesce(nullif(p_row.objet, ''), objet),
    notes = coalesce(p_row.notes, notes),
    updated_at = now()
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
