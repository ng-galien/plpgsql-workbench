CREATE OR REPLACE FUNCTION document_qa.clean()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  DELETE FROM document.canvas WHERE tenant_id = 'dev';
  DELETE FROM document.document WHERE tenant_id = 'dev';
  DELETE FROM document.template WHERE tenant_id = 'dev';
  DELETE FROM document.brand_guide WHERE tenant_id = 'dev';
  DELETE FROM document.company WHERE tenant_id = 'dev';
END;
$function$;
