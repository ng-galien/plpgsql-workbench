CREATE OR REPLACE FUNCTION hr_qa.clean()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  DELETE FROM hr.employee WHERE last_name IN (
    'Dupont', 'Martin', 'Lefebvre', 'Moreau', 'Rousseau', 'Garcia'
  ) AND first_name IN ('Marie', 'Thomas', 'Claire', 'Lucas', 'Emma', 'Antoine');

  RETURN pgv.toast('HR QA data removed.');
END;
$function$;
