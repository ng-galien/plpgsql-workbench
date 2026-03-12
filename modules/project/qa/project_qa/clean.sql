CREATE OR REPLACE FUNCTION project_qa.clean()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  DELETE FROM project.affectation;
  DELETE FROM project.note_chantier;
  DELETE FROM project.pointage;
  DELETE FROM project.jalon;
  DELETE FROM project.chantier;
  RETURN 'project_qa.clean: done';
END;
$function$;
