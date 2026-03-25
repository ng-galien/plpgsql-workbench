CREATE OR REPLACE FUNCTION project.post_project_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_id int; v_code text;
BEGIN
  IF p_data->>'id' IS NOT NULL THEN
    v_id := (p_data->>'id')::int;
    IF NOT EXISTS (SELECT 1 FROM project.project WHERE id = v_id AND status IN ('draft','active')) THEN
      RAISE EXCEPTION '%', pgv.t('project.err_not_editable');
    END IF;
    UPDATE project.project SET client_id = (p_data->>'client_id')::int, estimate_id = NULLIF(p_data->>'estimate_id', '')::int,
      subject = p_data->>'subject', address = coalesce(p_data->>'address', ''),
      start_date = NULLIF(p_data->>'start_date', '')::date, due_date = NULLIF(p_data->>'due_date', '')::date,
      notes = coalesce(p_data->>'notes', ''), updated_at = now() WHERE id = v_id;
  ELSE
    v_code := project._next_code();
    INSERT INTO project.project (code, client_id, estimate_id, subject, address, start_date, due_date, notes)
    VALUES (v_code, (p_data->>'client_id')::int, NULLIF(p_data->>'estimate_id', '')::int, p_data->>'subject',
      coalesce(p_data->>'address', ''), NULLIF(p_data->>'start_date', '')::date, NULLIF(p_data->>'due_date', '')::date,
      coalesce(p_data->>'notes', '')) RETURNING id INTO v_id;
  END IF;
  RETURN pgv.toast(pgv.t('project.toast_saved')) || pgv.redirect(pgv.call_ref('get_project', jsonb_build_object('p_id', v_id)));
END;
$function$;
