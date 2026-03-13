CREATE OR REPLACE FUNCTION planning_qa.clean()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  DELETE FROM planning.affectation WHERE tenant_id = 'dev';
  DELETE FROM planning.evenement WHERE tenant_id = 'dev';
  DELETE FROM planning.intervenant WHERE tenant_id = 'dev';

  RETURN '<template data-toast="success">Données planning supprimées.</template>';
END;
$function$;
