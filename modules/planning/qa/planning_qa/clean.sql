CREATE OR REPLACE FUNCTION planning_qa.clean()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  DELETE FROM planning.assignment WHERE tenant_id = 'dev';
  DELETE FROM planning.event WHERE tenant_id = 'dev';
  DELETE FROM planning.worker WHERE tenant_id = 'dev';

  RETURN '<template data-toast="success">Planning data cleaned.</template>';
END;
$function$;
