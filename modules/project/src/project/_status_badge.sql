CREATE OR REPLACE FUNCTION project._status_badge(p_status text)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT pgv.badge(
    CASE p_status
      WHEN 'draft' THEN pgv.t('project.status_draft')
      WHEN 'active' THEN pgv.t('project.status_active')
      WHEN 'review' THEN pgv.t('project.status_review')
      WHEN 'closed' THEN pgv.t('project.status_closed')
      ELSE p_status
    END,
    CASE p_status
      WHEN 'draft' THEN 'secondary'
      WHEN 'active' THEN 'primary'
      WHEN 'review' THEN 'warning'
      WHEN 'closed' THEN 'success'
      ELSE 'secondary'
    END
  );
$function$;
