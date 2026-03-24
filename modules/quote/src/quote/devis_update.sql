CREATE OR REPLACE FUNCTION quote.devis_update(p_row quote.devis)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM quote.devis WHERE id = p_row.id AND statut = 'brouillon' AND tenant_id = current_setting('app.tenant_id', true)) THEN
    RAISE EXCEPTION '%', pgv.t('quote.err_brouillon_only');
  END IF;

  UPDATE quote.devis SET
    client_id = coalesce(p_row.client_id, client_id),
    objet = coalesce(nullif(p_row.objet, ''), objet),
    validite_jours = coalesce(p_row.validite_jours, validite_jours),
    notes = coalesce(p_row.notes, notes),
    updated_at = now()
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
