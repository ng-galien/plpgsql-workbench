CREATE OR REPLACE FUNCTION purchase.facture_fournisseur_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_actions jsonb;
BEGIN
  SELECT to_jsonb(f) || jsonb_build_object(
    'commande_numero', c.numero,
    'fournisseur_name', cl.name,
    'fournisseur_id', cl.id,
    'commande_ttc', CASE WHEN f.commande_id IS NOT NULL THEN purchase._total_ttc(f.commande_id) END,
    'ecart', CASE WHEN f.commande_id IS NOT NULL THEN f.montant_ttc - purchase._total_ttc(f.commande_id) END
  ) INTO v_result
  FROM purchase.facture_fournisseur f
  LEFT JOIN purchase.commande c ON c.id = f.commande_id
  LEFT JOIN crm.client cl ON cl.id = c.fournisseur_id
  WHERE f.id = p_id::int AND f.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;

  -- HATEOAS actions based on state
  v_actions := '[]'::jsonb;

  CASE v_result->>'statut'
    WHEN 'recue' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'valider', 'uri', 'purchase://facture_fournisseur/' || p_id || '/valider'),
        jsonb_build_object('method', 'delete', 'uri', 'purchase://facture_fournisseur/' || p_id)
      );
    WHEN 'validee' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'payer', 'uri', 'purchase://facture_fournisseur/' || p_id || '/payer')
      );
    WHEN 'payee' THEN
      IF NOT (v_result->>'comptabilisee')::boolean THEN
        v_actions := jsonb_build_array(
          jsonb_build_object('method', 'comptabiliser', 'uri', 'purchase://facture_fournisseur/' || p_id || '/comptabiliser')
        );
      END IF;
    ELSE
      -- terminal
  END CASE;

  v_result := v_result || jsonb_build_object('actions', v_actions);

  RETURN v_result;
END;
$function$;
