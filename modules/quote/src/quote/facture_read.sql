CREATE OR REPLACE FUNCTION quote.facture_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_result jsonb;
  v_actions jsonb;
  v_statut text;
  v_days int;
BEGIN
  SELECT to_jsonb(f) || jsonb_build_object(
    'client_name', c.name,
    'devis_numero', dv.numero,
    'total_ht', quote._total_ht(NULL, f.id),
    'total_tva', quote._total_tva(NULL, f.id),
    'total_ttc', quote._total_ttc(NULL, f.id),
    'lignes', coalesce((
      SELECT jsonb_agg(to_jsonb(l) ORDER BY l.sort_order, l.id)
      FROM quote.ligne l WHERE l.facture_id = f.id
    ), '[]'::jsonb))
  INTO v_result
  FROM quote.facture f
  JOIN crm.client c ON c.id = f.client_id
  LEFT JOIN quote.devis dv ON dv.id = f.devis_id
  WHERE f.id = p_id::int AND f.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN RETURN NULL; END IF;

  -- HATEOAS actions based on state
  v_statut := v_result->>'statut';
  v_days := extract(day FROM now() - (v_result->>'created_at')::timestamptz)::int;
  v_actions := '[]'::jsonb;

  CASE v_statut
    WHEN 'brouillon' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'envoyer', 'uri', 'quote://facture/' || p_id || '/envoyer'),
        jsonb_build_object('method', 'supprimer', 'uri', 'quote://facture/' || p_id)
      );
    WHEN 'envoyee' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'payer', 'uri', 'quote://facture/' || p_id || '/payer')
      );
      IF v_days > 30 THEN
        v_actions := v_actions || jsonb_build_array(
          jsonb_build_object('method', 'relancer', 'uri', 'quote://facture/' || p_id || '/relancer')
        );
      END IF;
    WHEN 'relance' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'payer', 'uri', 'quote://facture/' || p_id || '/payer')
      );
    WHEN 'payee' THEN
      -- Terminal state: no actions (immutable)
      v_actions := '[]'::jsonb;
  END CASE;

  RETURN v_result || jsonb_build_object('actions', v_actions);
END;
$function$;
