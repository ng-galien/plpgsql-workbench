CREATE OR REPLACE FUNCTION project._global_progress(p_project_id integer)
 RETURNS numeric
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(ROUND(AVG(progress_pct), 1), 0)
    FROM project.milestone WHERE project_id = p_project_id;
$function$;
