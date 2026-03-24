CREATE OR REPLACE FUNCTION quote.facture_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN (
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
    FROM quote.facture f
    JOIN crm.client c ON c.id = f.client_id
    LEFT JOIN quote.devis dv ON dv.id = f.devis_id
    WHERE f.id = p_id::int AND f.tenant_id = current_setting('app.tenant_id', true)
  );
END;
$function$;
