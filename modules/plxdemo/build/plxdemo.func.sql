CREATE OR REPLACE FUNCTION plxdemo.health()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE AS $$
BEGIN
  RETURN jsonb_build_object('name', 'plxdemo', 'status', 'ok', 'demo', 'crud');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE AS $$
BEGIN
  RETURN jsonb_build_object('uri', 'plxdemo://task', 'label', 'plxdemo.entity_task', 'icon', '✓', 'template', jsonb_build_object('compact', jsonb_build_object('fields', jsonb_build_array('title', 'priority', 'done')), 'standard', jsonb_build_object('fields', jsonb_build_array('title', 'description', 'priority', 'done')), 'expanded', jsonb_build_object('fields', jsonb_build_array('title', 'description', 'priority', 'done', 'created_at', 'updated_at')), 'form', jsonb_build_object('sections', jsonb_build_array(jsonb_build_object('label', 'plxdemo.section_task', 'fields', jsonb_build_array(jsonb_build_object('key', 'title', 'type', 'text', 'label', 'plxdemo.field_title', 'required', true), jsonb_build_object('key', 'description', 'type', 'textarea', 'label', 'plxdemo.field_description'), jsonb_build_object('key', 'priority', 'type', 'select', 'label', 'plxdemo.field_priority')))))), 'actions', jsonb_build_object('edit', jsonb_build_object('label', 'plxdemo.action_edit', 'icon', '✏', 'variant', 'muted'), 'delete', jsonb_build_object('label', 'plxdemo.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'plxdemo.confirm_delete')));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE AS $$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY SELECT to_jsonb(t) FROM plxdemo.task t ORDER BY t.created_at desc;
  ELSE
    RETURN QUERY EXECUTE 'SELECT to_jsonb(t) FROM plxdemo.task t WHERE ' || pgv.rsql_to_where(p_filter, 'plxdemo', 'task') || ' ORDER BY t.created_at desc';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT to_jsonb(t) INTO v_result FROM plxdemo.task t WHERE t.id = p_id::int;
  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN v_result || jsonb_build_object('actions', jsonb_build_array(jsonb_build_object('method', 'edit', 'uri', 'plxdemo://task/' || p_id || '/edit'), jsonb_build_object('method', 'delete', 'uri', 'plxdemo://task/' || p_id || '/delete')));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_create(p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER AS $$
DECLARE
  v_p_row record;
  v_result record;
BEGIN
  IF NOT (jsonb_typeof(p_data) = 'object') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_invalid_task_payload';
  END IF;
  IF NOT (NOT EXISTS (SELECT 1 FROM jsonb_object_keys(p_data) AS k(key) WHERE k.key <> ALL (ARRAY['title', 'description', 'priority', 'done']::text[]))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_unknown_task_field';
  END IF;
  IF NOT (NOT jsonb_exists(p_data, 'id')) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_id_readonly';
  END IF;
  IF NOT (jsonb_exists(p_data, 'title') AND p_data->>'title' IS NOT NULL) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_title_required';
  END IF;
  v_p_row := jsonb_populate_record(NULL::plxdemo.task, p_data);
  IF NOT (coalesce(v_p_row.priority, 'normal') = 'low' OR coalesce(v_p_row.priority, 'normal') = 'normal' OR coalesce(v_p_row.priority, 'normal') = 'high') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_priority_invalid';
  END IF;
  INSERT INTO plxdemo.task (title, description, priority, done)
      VALUES (v_p_row.title, v_p_row.description, COALESCE(v_p_row.priority, 'normal'), COALESCE(v_p_row.done, false))
      RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_update(p_id text, p_patch jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER AS $$
DECLARE
  v_current plxdemo.task;
  v_p_row record;
  v_result record;
BEGIN
  IF NOT (jsonb_typeof(p_patch) = 'object') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_invalid_task_payload';
  END IF;
  IF NOT (NOT EXISTS (SELECT 1 FROM jsonb_object_keys(p_patch) AS k(key) WHERE k.key <> ALL (ARRAY['title', 'description', 'priority', 'done']::text[]))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_unknown_task_field';
  END IF;
  IF NOT (NOT jsonb_exists(p_patch, 'id')) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_id_readonly';
  END IF;
  SELECT * INTO v_current FROM plxdemo.task WHERE id = p_id::int;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'plxdemo.err_not_found';
  END IF;
  v_p_row := jsonb_populate_record(v_current, p_patch);
  IF NOT (coalesce(v_p_row.priority, 'normal') = 'low' OR coalesce(v_p_row.priority, 'normal') = 'normal' OR coalesce(v_p_row.priority, 'normal') = 'high') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_priority_invalid';
  END IF;
  UPDATE plxdemo.task SET
      title = v_p_row.title,
      description = v_p_row.description,
      priority = v_p_row.priority,
      done = v_p_row.done,
      updated_at = now()
      WHERE id = p_id::int
      RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER AS $$
DECLARE
  v_result plxdemo.task;
BEGIN
  DELETE FROM plxdemo.task WHERE id = p_id::int RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$$;
