CREATE OR REPLACE FUNCTION project._statut_badge(p_statut text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN pgv.badge(
    CASE p_statut
      WHEN 'preparation' THEN pgv.t('project.statut_preparation')
      WHEN 'execution'   THEN pgv.t('project.statut_execution')
      WHEN 'reception'   THEN pgv.t('project.statut_reception')
      WHEN 'clos'        THEN pgv.t('project.statut_clos')
      ELSE initcap(p_statut)
    END,
    CASE p_statut
      WHEN 'preparation' THEN 'warning'
      WHEN 'execution'   THEN 'info'
      WHEN 'reception'   THEN 'success'
      WHEN 'clos'        THEN 'default'
    END
  );
END;
$function$;
