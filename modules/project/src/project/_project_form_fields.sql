CREATE OR REPLACE FUNCTION project._project_form_fields(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body text := ''; v_subject text := ''; v_address text := ''; v_notes text := '';
  v_start_date text := ''; v_due_date text := ''; v_client_id int; v_estimate_id int;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT subject, address, notes, start_date::text, due_date::text, client_id, estimate_id
      INTO v_subject, v_address, v_notes, v_start_date, v_due_date, v_client_id, v_estimate_id
      FROM project.project WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.empty(pgv.t('project.empty_not_found')); END IF;
    v_body := '<input type="hidden" name="id" value="' || p_id || '">';
    v_subject := pgv.esc(v_subject);
    v_address := pgv.esc(COALESCE(v_address, ''));
    v_notes := pgv.esc(COALESCE(v_notes, ''));
    v_start_date := COALESCE(v_start_date, '');
    v_due_date := COALESCE(v_due_date, '');
  END IF;
  v_body := v_body || '<label>' || pgv.t('project.field_client') || ' <select name="client_id" required>'
    || '<option value="">' || pgv.t('project.field_choose') || '</option>' || project._client_options() || '</select></label>';
  IF v_client_id IS NOT NULL THEN
    v_body := replace(v_body, 'value="' || v_client_id || '">', 'value="' || v_client_id || '" selected>');
  END IF;
  v_body := v_body || '<label>' || pgv.t('project.field_estimate') || ' <select name="estimate_id">'
    || '<option value="">' || pgv.t('project.field_none') || '</option>' || project._estimate_options() || '</select></label>';
  IF v_estimate_id IS NOT NULL THEN
    v_body := replace(v_body, 'value="' || v_estimate_id || '">', 'value="' || v_estimate_id || '" selected>');
  END IF;
  v_body := v_body
    || pgv.input('subject', 'text', pgv.t('project.field_subject'), v_subject, true)
    || pgv.input('address', 'text', pgv.t('project.field_address'), v_address)
    || '<div class="grid">'
    || pgv.input('start_date', 'date', pgv.t('project.field_start_date'), NULLIF(v_start_date, ''))
    || pgv.input('due_date', 'date', pgv.t('project.field_due_date'), NULLIF(v_due_date, ''))
    || '</div>'
    || pgv.textarea('notes', pgv.t('project.field_notes'), v_notes);
  RETURN v_body;
END;
$function$;
