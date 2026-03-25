CREATE OR REPLACE FUNCTION project.get_project(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE v_row jsonb;
BEGIN
  v_row := project.project_read(p_id::text);
  IF v_row IS NULL THEN RETURN pgv.empty(pgv.t('project.empty_not_found')); END IF;
  RETURN '<h2>' || pgv.esc(v_row->>'code') || ' — ' || pgv.esc(v_row->>'subject') || '</h2>'
    || '<p>' || project._status_badge(v_row->>'status') || ' ' || pgv.t('project.col_progress') || ': ' || (v_row->>'progress') || '%</p>'
    || '<p>' || pgv.t('project.col_client') || ': ' || pgv.esc(v_row->>'client_name') || '</p>';
END;
$function$;
