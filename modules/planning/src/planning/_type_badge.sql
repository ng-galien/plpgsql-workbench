CREATE OR REPLACE FUNCTION planning._type_badge(p_type text)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT pgv.badge(
    CASE p_type
      WHEN 'job_site' THEN pgv.t('planning.type_job_site')
      WHEN 'delivery' THEN pgv.t('planning.type_delivery')
      WHEN 'meeting'  THEN pgv.t('planning.type_meeting')
      WHEN 'leave'    THEN pgv.t('planning.type_leave')
      ELSE pgv.t('planning.type_other')
    END,
    CASE p_type
      WHEN 'job_site' THEN 'info'
      WHEN 'delivery' THEN 'warning'
      WHEN 'meeting'  THEN 'default'
      WHEN 'leave'    THEN 'error'
      ELSE 'default'
    END
  );
$function$;
