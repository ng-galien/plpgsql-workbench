CREATE OR REPLACE FUNCTION quote.devis_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_result jsonb;
  v_actions jsonb;
  v_statut text;
BEGIN
  SELECT to_jsonb(d) || jsonb_build_object(
    'client_name', c.name,
    'total_ht', quote._total_ht(d.id, NULL),
    'total_tva', quote._total_tva(d.id, NULL),
    'total_ttc', quote._total_ttc(d.id, NULL),
    'lignes', coalesce((
      SELECT jsonb_agg(to_jsonb(l) ORDER BY l.sort_order, l.id)
      FROM quote.ligne l WHERE l.devis_id = d.id
    ), '[]'::jsonb))
  INTO v_result
  FROM quote.devis d
  JOIN crm.client c ON c.id = d.client_id
  WHERE d.id = p_id::int AND d.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN RETURN NULL; END IF;

  -- HATEOAS actions based on state
  v_statut := v_result->>'statut';
  v_actions := '[]'::jsonb;

  CASE v_statut
    WHEN 'brouillon' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'envoyer', 'uri', 'quote://devis/' || p_id || '/envoyer'),
        jsonb_build_object('method', 'dupliquer', 'uri', 'quote://devis/' || p_id || '/dupliquer'),
        jsonb_build_object('method', 'supprimer', 'uri', 'quote://devis/' || p_id)
      );
    WHEN 'envoye' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'accepter', 'uri', 'quote://devis/' || p_id || '/accepter'),
        jsonb_build_object('method', 'refuser', 'uri', 'quote://devis/' || p_id || '/refuser'),
        jsonb_build_object('method', 'dupliquer', 'uri', 'quote://devis/' || p_id || '/dupliquer')
      );
    WHEN 'accepte' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'facturer', 'uri', 'quote://devis/' || p_id || '/facturer'),
        jsonb_build_object('method', 'dupliquer', 'uri', 'quote://devis/' || p_id || '/dupliquer')
      );
    WHEN 'refuse' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'dupliquer', 'uri', 'quote://devis/' || p_id || '/dupliquer')
      );
  END CASE;

  RETURN v_result || jsonb_build_object('actions', v_actions);
END;
$function$;
