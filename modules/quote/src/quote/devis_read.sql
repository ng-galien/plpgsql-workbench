CREATE OR REPLACE FUNCTION quote.devis_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN (
    SELECT to_jsonb(d) || jsonb_build_object(
      'client_name', c.name,
      'total_ht', quote._total_ht(d.id, NULL),
      'total_tva', quote._total_tva(d.id, NULL),
      'total_ttc', quote._total_ttc(d.id, NULL),
      'lignes', coalesce((
        SELECT jsonb_agg(to_jsonb(l) ORDER BY l.sort_order, l.id)
        FROM quote.ligne l WHERE l.devis_id = d.id
      ), '[]'::jsonb))
    FROM quote.devis d
    JOIN crm.client c ON c.id = d.client_id
    WHERE d.id = p_id::int AND d.tenant_id = current_setting('app.tenant_id', true)
  );
END;
$function$;
