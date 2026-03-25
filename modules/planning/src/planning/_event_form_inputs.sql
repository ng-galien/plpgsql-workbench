CREATE OR REPLACE FUNCTION planning._event_form_inputs(p_id integer DEFAULT NULL::integer, p_title text DEFAULT NULL::text, p_type text DEFAULT NULL::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_start_time time without time zone DEFAULT NULL::time without time zone, p_end_time time without time zone DEFAULT NULL::time without time zone, p_location text DEFAULT NULL::text, p_project_id integer DEFAULT NULL::integer, p_notes text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN format('<input type="hidden" name="id" value="%s">', COALESCE(p_id::text, ''))
    || pgv.input('title', 'text', pgv.t('planning.field_title') || ' *', p_title, true)
    || pgv.sel('type', pgv.t('planning.field_type'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('planning.type_job_site'), 'value', 'job_site'),
         jsonb_build_object('label', pgv.t('planning.type_delivery'), 'value', 'delivery'),
         jsonb_build_object('label', pgv.t('planning.type_meeting'), 'value', 'meeting'),
         jsonb_build_object('label', pgv.t('planning.type_leave'), 'value', 'leave'),
         jsonb_build_object('label', pgv.t('planning.type_other'), 'value', 'other')
       ), COALESCE(p_type, 'job_site'))
    || '<div class="grid">'
    || pgv.input('start_date', 'date', pgv.t('planning.field_start_date') || ' *', COALESCE(p_start_date::text, current_date::text), true)
    || pgv.input('end_date', 'date', pgv.t('planning.field_end_date') || ' *', COALESCE(p_end_date::text, current_date::text), true)
    || '</div><div class="grid">'
    || pgv.input('start_time', 'time', pgv.t('planning.field_start_time'), COALESCE(p_start_time::text, '08:00'))
    || pgv.input('end_time', 'time', pgv.t('planning.field_end_time'), COALESCE(p_end_time::text, '17:00'))
    || '</div>'
    || pgv.input('location', 'text', pgv.t('planning.field_location'), p_location)
    || pgv.select_search('project_id', pgv.t('planning.field_project'), 'project_options', 'Search project...', p_project_id::text)
    || pgv.textarea('notes', pgv.t('planning.field_notes'), p_notes);
END;
$function$;
