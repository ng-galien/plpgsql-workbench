CREATE OR REPLACE FUNCTION project.chantier_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_row jsonb;
BEGIN
  SELECT to_jsonb(c) || jsonb_build_object(
    'client_name', cl.name,
    'devis_numero', d.numero,
    'avancement', project._avancement_global(c.id)
  ) INTO v_row
  FROM project.chantier c
  JOIN crm.client cl ON cl.id = c.client_id
  LEFT JOIN quote.devis d ON d.id = c.devis_id
  WHERE c.id = p_id::int AND c.tenant_id = current_setting('app.tenant_id', true);
  RETURN v_row;
END;
$function$;
