CREATE OR REPLACE FUNCTION purchase.commande_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_actions jsonb;
  v_has_receptions boolean;
BEGIN
  SELECT to_jsonb(c) || jsonb_build_object(
    'fournisseur_name', cl.name,
    'total_ht', purchase._total_ht(c.id),
    'total_tva', purchase._total_tva(c.id),
    'total_ttc', purchase._total_ttc(c.id),
    'nb_lignes', (SELECT count(*) FROM purchase.ligne l WHERE l.commande_id = c.id),
    'nb_receptions', (SELECT count(*) FROM purchase.reception r WHERE r.commande_id = c.id)
  ) INTO v_result
  FROM purchase.commande c
  JOIN crm.client cl ON cl.id = c.fournisseur_id
  WHERE c.id = p_id::int AND c.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;

  -- HATEOAS actions based on state
  v_actions := '[]'::jsonb;

  CASE v_result->>'statut'
    WHEN 'brouillon' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'envoyer', 'uri', 'purchase://commande/' || p_id || '/envoyer'),
        jsonb_build_object('method', 'annuler', 'uri', 'purchase://commande/' || p_id || '/annuler'),
        jsonb_build_object('method', 'delete', 'uri', 'purchase://commande/' || p_id)
      );
    WHEN 'envoyee', 'partiellement_recue' THEN
      v_has_receptions := (v_result->'nb_receptions')::int > 0;
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'recevoir', 'uri', 'purchase://commande/' || p_id || '/recevoir')
      );
      IF NOT v_has_receptions THEN
        v_actions := v_actions || jsonb_build_array(
          jsonb_build_object('method', 'annuler', 'uri', 'purchase://commande/' || p_id || '/annuler')
        );
      END IF;
    ELSE
      -- recue, annulee: no actions (terminal)
  END CASE;

  v_result := v_result || jsonb_build_object('actions', v_actions);

  RETURN v_result;
END;
$function$;
