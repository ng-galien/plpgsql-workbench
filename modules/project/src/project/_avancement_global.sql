CREATE OR REPLACE FUNCTION project._avancement_global(p_chantier_id integer)
 RETURNS numeric
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(ROUND(AVG(pct_avancement), 1), 0)
  FROM project.jalon
  WHERE chantier_id = p_chantier_id;
$function$;
