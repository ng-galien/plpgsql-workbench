CREATE OR REPLACE FUNCTION docs_qa.clean()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM set_config('app.tenant_id', coalesce(current_setting('app.tenant_id', true), 'dev'), true);

  DELETE FROM docs.page_revision WHERE doc_id IN (SELECT id FROM docs.document WHERE tenant_id = current_setting('app.tenant_id', true));
  DELETE FROM docs.page WHERE doc_id IN (SELECT id FROM docs.document WHERE tenant_id = current_setting('app.tenant_id', true));
  DELETE FROM docs.library_asset WHERE library_id IN (SELECT id FROM docs.library WHERE tenant_id = current_setting('app.tenant_id', true));
  DELETE FROM docs.document WHERE tenant_id = current_setting('app.tenant_id', true);
  DELETE FROM docs.library WHERE tenant_id = current_setting('app.tenant_id', true);
  DELETE FROM docs.charter WHERE tenant_id = current_setting('app.tenant_id', true);
END;
$function$;
