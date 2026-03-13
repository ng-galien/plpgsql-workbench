CREATE OR REPLACE FUNCTION hr_qa.clean()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  DELETE FROM hr.employee WHERE nom IN (
    'Dupont', 'Martin', 'Lefebvre', 'Moreau', 'Rousseau', 'Garcia'
  ) AND prenom IN ('Marie', 'Thomas', 'Claire', 'Lucas', 'Emma', 'Antoine');

  RETURN pgv.toast('Données QA hr supprimées.');
END;
$function$;
