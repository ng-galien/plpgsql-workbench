CREATE OR REPLACE FUNCTION plxdemo.health()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE AS $$
BEGIN
  RETURN jsonb_build_object('name', 'plxdemo', 'status', 'ok', 'demo', 'crud+validation+states+events');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.project_create_kickoff_task(project_id int)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
BEGIN
  insert into plxdemo.task (project_id, payload)
  values (
    project_id,
    jsonb_build_object(
      'title', 'Kickoff',
      'description', 'Auto-created when the project is activated',
      'priority', 'normal',
      'done', false
    )
  );
  RETURN;
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.project_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE AS $$
BEGIN
  RETURN jsonb_build_object('uri', 'plxdemo://project', 'label', 'plxdemo.entity_project', 'icon', '📁', 'template', jsonb_build_object('compact', jsonb_build_object('fields', jsonb_build_array('name', 'code', 'status')), 'standard', jsonb_build_object('fields', jsonb_build_array('name', 'code', 'description', 'budget', 'owner', 'deadline', 'status'), 'stats', jsonb_build_array(jsonb_build_object('key', 'task_count', 'label', 'plxdemo.stat_task_count'))), 'expanded', jsonb_build_object('fields', jsonb_build_array('name', 'code', 'description', 'budget', 'owner', 'deadline', 'status', 'created_at', 'updated_at')), 'form', jsonb_build_object('sections', jsonb_build_array(jsonb_build_object('label', 'plxdemo.section_project', 'fields', jsonb_build_array(jsonb_build_object('key', 'name', 'type', 'text', 'label', 'plxdemo.field_name', 'required', true), jsonb_build_object('key', 'code', 'type', 'text', 'label', 'plxdemo.field_code', 'required', true), jsonb_build_object('key', 'description', 'type', 'textarea', 'label', 'plxdemo.field_description'), jsonb_build_object('key', 'budget', 'type', 'number', 'label', 'plxdemo.field_budget'), jsonb_build_object('key', 'owner', 'type', 'text', 'label', 'plxdemo.field_owner'), jsonb_build_object('key', 'deadline', 'type', 'date', 'label', 'plxdemo.field_deadline')))))), 'actions', jsonb_build_object('edit', jsonb_build_object('label', 'plxdemo.action_edit', 'icon', '✏', 'variant', 'muted'), 'delete', jsonb_build_object('label', 'plxdemo.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'plxdemo.confirm_delete'), 'activate', jsonb_build_object('label', 'plxdemo.action_activate', 'variant', 'primary'), 'complete', jsonb_build_object('label', 'plxdemo.action_complete', 'variant', 'primary'), 'archive', jsonb_build_object('label', 'plxdemo.action_archive', 'variant', 'primary')));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.project_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.project.read');
  IF p_filter IS NULL THEN
    RETURN QUERY SELECT to_jsonb(t) FROM plxdemo.project t WHERE t.tenant_id = (SELECT current_setting('app.tenant_id')) AND t.deleted_at IS NULL ORDER BY t.updated_at desc;
  ELSE
    RETURN QUERY EXECUTE 'SELECT to_jsonb(t) FROM plxdemo.project t WHERE ' || pgv.rsql_to_where(p_filter, 'plxdemo', 'project') || ' AND t.tenant_id = (SELECT current_setting(''app.tenant_id'')) AND t.deleted_at IS NULL ORDER BY t.updated_at desc';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.project_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_result jsonb;
  v_status text;
  v_actions jsonb := '[]'::jsonb;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.project.read');
  SELECT to_jsonb(t) INTO v_result FROM plxdemo.project t WHERE t.id = p_id::int AND t.tenant_id = (SELECT current_setting('app.tenant_id')) AND t.deleted_at IS NULL;
  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;
  v_status := (v_result->>'status');
  CASE v_status
    WHEN 'draft' THEN
      v_actions := jsonb_build_array(jsonb_build_object('method', 'edit', 'uri', 'plxdemo://project/' || p_id || '/edit'), jsonb_build_object('method', 'activate', 'uri', 'plxdemo://project/' || p_id || '/activate'), jsonb_build_object('method', 'delete', 'uri', 'plxdemo://project/' || p_id || '/delete'));
    WHEN 'active' THEN
      v_actions := jsonb_build_array(jsonb_build_object('method', 'edit', 'uri', 'plxdemo://project/' || p_id || '/edit'), jsonb_build_object('method', 'complete', 'uri', 'plxdemo://project/' || p_id || '/complete'), jsonb_build_object('method', 'delete', 'uri', 'plxdemo://project/' || p_id || '/delete'));
    WHEN 'completed' THEN
      v_actions := jsonb_build_array(jsonb_build_object('method', 'archive', 'uri', 'plxdemo://project/' || p_id || '/archive'));
    ELSE
  END CASE;
  RETURN v_result || jsonb_build_object('actions', v_actions);
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.project_create(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_p_row record;
  v_result record;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.project.create');
  IF NOT (jsonb_typeof(p_input) = 'object') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_invalid_project_payload';
  END IF;
  IF NOT ((NOT EXISTS (SELECT 1 FROM jsonb_object_keys(p_input) AS k(key) WHERE k.key <> ALL (ARRAY['name', 'code', 'description', 'budget', 'owner', 'deadline']::text[])))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_unknown_project_field';
  END IF;
  IF NOT (NOT jsonb_exists(p_input, 'id')) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_id_readonly';
  END IF;
  IF NOT (jsonb_exists(p_input, 'name') AND p_input->>'name' IS NOT NULL) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_name_required';
  END IF;
  IF NOT (jsonb_exists(p_input, 'code') AND p_input->>'code' IS NOT NULL) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_code_required';
  END IF;
  v_p_row := jsonb_populate_record(NULL::plxdemo.project, p_input);
  IF NOT (coalesce((p_input->>'budget')::numeric, 0) >= 0) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'budget_positive';
  END IF;
  INSERT INTO plxdemo.project (name, code, description, budget, owner, deadline)
      VALUES (v_p_row.name, v_p_row.code, v_p_row.description, v_p_row.budget, v_p_row.owner, v_p_row.deadline)
      RETURNING * INTO v_result;
  RETURN (to_jsonb(v_result));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.project_update(p_id text, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_current plxdemo.project;
  v_p_row record;
  v_result record;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.project.modify');
  IF NOT (jsonb_typeof(p_input) = 'object') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_invalid_project_payload';
  END IF;
  IF NOT ((NOT EXISTS (SELECT 1 FROM jsonb_object_keys(p_input) AS k(key) WHERE k.key <> ALL (ARRAY['name', 'code', 'description', 'budget', 'owner', 'deadline']::text[])))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_unknown_project_field';
  END IF;
  IF NOT (NOT jsonb_exists(p_input, 'id')) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_id_readonly';
  END IF;
  SELECT * INTO v_current FROM plxdemo.project WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id'));
  IF NOT FOUND THEN
    RAISE EXCEPTION 'plxdemo.err_not_found';
  END IF;
  v_p_row := jsonb_populate_record(v_current, p_input);
  IF NOT (coalesce((p_input->>'budget')::numeric, 0) >= 0) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'budget_positive';
  END IF;
  UPDATE plxdemo.project SET
      name = v_p_row.name,
      description = v_p_row.description,
      budget = v_p_row.budget,
      owner = v_p_row.owner,
      deadline = v_p_row.deadline,
      updated_at = now()
      WHERE id = p_id::int AND status IN ('draft', 'active') AND tenant_id = (SELECT current_setting('app.tenant_id'))
      RETURNING * INTO v_result;
  RETURN (to_jsonb(v_result));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.project_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_result plxdemo.project;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.project.delete');
  UPDATE plxdemo.project SET deleted_at = now() WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id')) AND deleted_at IS NULL RETURNING * INTO v_result;
  RETURN (to_jsonb(v_result));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.project_activate(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_row jsonb;
  v_result plxdemo.project;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.project.activate');
  SELECT to_jsonb(t) INTO v_row FROM plxdemo.project t WHERE t.id = p_id::int AND t.tenant_id = (SELECT current_setting('app.tenant_id'));
  IF v_row IS NULL THEN
    RAISE EXCEPTION 'plxdemo.err_not_found';
  END IF;
  IF NOT (coalesce ( ( v_row ->> 'budget' ) :: numeric , 0 ) > 0 and v_row ->> 'owner' is not null) THEN
    RAISE EXCEPTION 'plxdemo.err_guard_activate';
  END IF;
  UPDATE plxdemo.project SET status = 'active' WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id')) AND status = 'draft' RETURNING * INTO v_result;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'plxdemo.err_not_draft';
  END IF;
  RETURN (to_jsonb(v_result));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.project_complete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_result plxdemo.project;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.project.complete');
  UPDATE plxdemo.project SET status = 'completed' WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id')) AND status = 'active' RETURNING * INTO v_result;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'plxdemo.err_not_active';
  END IF;
  RETURN (to_jsonb(v_result));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.project_archive(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_result plxdemo.project;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.project.archive');
  UPDATE plxdemo.project SET status = 'archived' WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id')) AND status = 'completed' RETURNING * INTO v_result;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'plxdemo.err_not_completed';
  END IF;
  RETURN (to_jsonb(v_result));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE AS $$
BEGIN
  RETURN jsonb_build_object('uri', 'plxdemo://task', 'label', 'plxdemo.entity_task', 'icon', '✓', 'template', jsonb_build_object('compact', jsonb_build_object('fields', jsonb_build_array('title', 'priority', 'done', 'rank', 'note_id')), 'standard', jsonb_build_object('fields', jsonb_build_array('title', 'description', 'priority', 'done', 'rank', 'note_id', 'project_id')), 'expanded', jsonb_build_object('fields', jsonb_build_array('title', 'description', 'priority', 'done', 'rank', 'note_id', 'project_id', 'created_at', 'updated_at')), 'form', jsonb_build_object('sections', jsonb_build_array(jsonb_build_object('label', 'plxdemo.section_task', 'fields', jsonb_build_array(jsonb_build_object('key', 'title', 'type', 'text', 'label', 'plxdemo.field_title', 'required', true), jsonb_build_object('key', 'description', 'type', 'textarea', 'label', 'plxdemo.field_description'), jsonb_build_object('key', 'priority', 'type', 'select', 'label', 'plxdemo.field_priority')))))), 'actions', jsonb_build_object('edit', jsonb_build_object('label', 'plxdemo.action_edit', 'icon', '✏', 'variant', 'muted'), 'delete', jsonb_build_object('label', 'plxdemo.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'plxdemo.confirm_delete')));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.task.read');
  IF p_filter IS NULL THEN
    RETURN QUERY SELECT jsonb_build_object('id', t.id, 'rank', t.rank, 'note_id', t.note_id, 'project_id', t.project_id, 'created_at', t.created_at, 'updated_at', t.updated_at) || jsonb_strip_nulls(COALESCE(t.payload, '{}'::jsonb)) FROM plxdemo.task t WHERE t.tenant_id = (SELECT current_setting('app.tenant_id')) ORDER BY t.created_at desc;
  ELSE
    RETURN QUERY EXECUTE 'SELECT jsonb_build_object(''id'', t.id, ''rank'', t.rank, ''note_id'', t.note_id, ''project_id'', t.project_id, ''created_at'', t.created_at, ''updated_at'', t.updated_at) || jsonb_strip_nulls(COALESCE(t.payload, ''{}''::jsonb)) FROM plxdemo.task t WHERE ' || pgv.rsql_to_where(p_filter, 'plxdemo', 'task') || ' AND t.tenant_id = (SELECT current_setting(''app.tenant_id'')) ORDER BY t.created_at desc';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.task.read');
  SELECT jsonb_build_object('id', t.id, 'rank', t.rank, 'note_id', t.note_id, 'project_id', t.project_id, 'created_at', t.created_at, 'updated_at', t.updated_at) || jsonb_strip_nulls(COALESCE(t.payload, '{}'::jsonb)) INTO v_result FROM plxdemo.task t WHERE t.id = p_id::int AND t.tenant_id = (SELECT current_setting('app.tenant_id'));
  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN v_result || jsonb_build_object('actions', jsonb_build_array(jsonb_build_object('method', 'edit', 'uri', 'plxdemo://task/' || p_id || '/edit'), jsonb_build_object('method', 'delete', 'uri', 'plxdemo://task/' || p_id || '/delete')));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_create(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_p_row record;
  v_result record;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.task.create');
  IF NOT (jsonb_typeof(p_input) = 'object') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_invalid_task_payload';
  END IF;
  IF NOT ((NOT EXISTS (SELECT 1 FROM jsonb_object_keys(p_input) AS k(key) WHERE k.key <> ALL (ARRAY['rank', 'note_id', 'project_id', 'title', 'description', 'priority', 'done']::text[])))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_unknown_task_field';
  END IF;
  IF NOT (NOT jsonb_exists(p_input, 'id')) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_id_readonly';
  END IF;
  IF NOT (jsonb_exists(p_input, 'title') AND p_input->>'title' IS NOT NULL) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_title_required';
  END IF;
  v_p_row := jsonb_populate_record(NULL::plxdemo.task, p_input);
  IF NOT ((coalesce(p_input->>'priority', 'normal') in ('low', 'normal', 'high'))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'priority_valid';
  END IF;
  INSERT INTO plxdemo.task (rank, note_id, project_id, payload)
      VALUES (COALESCE(v_p_row.rank, 0), v_p_row.note_id, v_p_row.project_id, jsonb_strip_nulls(jsonb_build_object('title', p_input->'title', 'description', p_input->'description', 'priority', COALESCE(p_input->'priority', to_jsonb('normal'::text)), 'done', COALESCE(p_input->'done', to_jsonb(false::boolean)))))
      RETURNING * INTO v_result;
  RETURN (jsonb_build_object('id', v_result.id, 'rank', v_result.rank, 'note_id', v_result.note_id, 'project_id', v_result.project_id, 'created_at', v_result.created_at, 'updated_at', v_result.updated_at) || jsonb_strip_nulls(COALESCE(v_result.payload, '{}'::jsonb)));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_update(p_id text, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_current plxdemo.task;
  v_p_row record;
  v_result record;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.task.modify');
  IF NOT (jsonb_typeof(p_input) = 'object') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_invalid_task_payload';
  END IF;
  IF NOT ((NOT EXISTS (SELECT 1 FROM jsonb_object_keys(p_input) AS k(key) WHERE k.key <> ALL (ARRAY['rank', 'note_id', 'project_id', 'title', 'description', 'priority', 'done']::text[])))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_unknown_task_field';
  END IF;
  IF NOT (NOT jsonb_exists(p_input, 'id')) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_id_readonly';
  END IF;
  SELECT * INTO v_current FROM plxdemo.task WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id'));
  IF NOT FOUND THEN
    RAISE EXCEPTION 'plxdemo.err_not_found';
  END IF;
  v_p_row := jsonb_populate_record(v_current, p_input);
  IF NOT ((coalesce(p_input->>'priority', 'normal') in ('low', 'normal', 'high'))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'priority_valid';
  END IF;
  UPDATE plxdemo.task SET
      rank = v_p_row.rank,
      note_id = v_p_row.note_id,
      project_id = v_p_row.project_id,
      payload = (v_current.payload - array_remove(ARRAY[CASE WHEN p_input ? 'title' AND p_input->'title' = 'null'::jsonb THEN 'title' ELSE NULL END, CASE WHEN p_input ? 'description' AND p_input->'description' = 'null'::jsonb THEN 'description' ELSE NULL END, CASE WHEN p_input ? 'priority' AND p_input->'priority' = 'null'::jsonb THEN 'priority' ELSE NULL END, CASE WHEN p_input ? 'done' AND p_input->'done' = 'null'::jsonb THEN 'done' ELSE NULL END], NULL)) || CASE WHEN p_input ? 'title' AND p_input->'title' <> 'null'::jsonb THEN jsonb_build_object('title', p_input->'title') ELSE '{}'::jsonb END || CASE WHEN p_input ? 'description' AND p_input->'description' <> 'null'::jsonb THEN jsonb_build_object('description', p_input->'description') ELSE '{}'::jsonb END || CASE WHEN p_input ? 'priority' AND p_input->'priority' <> 'null'::jsonb THEN jsonb_build_object('priority', p_input->'priority') ELSE '{}'::jsonb END || CASE WHEN p_input ? 'done' AND p_input->'done' <> 'null'::jsonb THEN jsonb_build_object('done', p_input->'done') ELSE '{}'::jsonb END,
      updated_at = now()
      WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id'))
      RETURNING * INTO v_result;
  RETURN (jsonb_build_object('id', v_result.id, 'rank', v_result.rank, 'note_id', v_result.note_id, 'project_id', v_result.project_id, 'created_at', v_result.created_at, 'updated_at', v_result.updated_at) || jsonb_strip_nulls(COALESCE(v_result.payload, '{}'::jsonb)));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_result plxdemo.task;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.task.delete');
  DELETE FROM plxdemo.task WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id')) RETURNING * INTO v_result;
  RETURN (jsonb_build_object('id', v_result.id, 'rank', v_result.rank, 'note_id', v_result.note_id, 'project_id', v_result.project_id, 'created_at', v_result.created_at, 'updated_at', v_result.updated_at) || jsonb_strip_nulls(COALESCE(v_result.payload, '{}'::jsonb)));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.note_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE AS $$
BEGIN
  RETURN jsonb_build_object('uri', 'plxdemo://note', 'label', 'plxdemo.entity_note', 'icon', '✎', 'template', jsonb_build_object('compact', jsonb_build_object('fields', jsonb_build_array('title')), 'standard', jsonb_build_object('fields', jsonb_build_array('title', 'body', 'pinned')), 'expanded', jsonb_build_object('fields', jsonb_build_array('title', 'body', 'pinned', 'created_at', 'updated_at')), 'form', jsonb_build_object('sections', jsonb_build_array(jsonb_build_object('label', 'plxdemo.section_note', 'fields', jsonb_build_array(jsonb_build_object('key', 'title', 'type', 'text', 'label', 'plxdemo.field_title', 'required', true), jsonb_build_object('key', 'body', 'type', 'textarea', 'label', 'plxdemo.field_body'), jsonb_build_object('key', 'pinned', 'type', 'checkbox', 'label', 'plxdemo.field_pinned')))))), 'actions', jsonb_build_object('edit', jsonb_build_object('label', 'plxdemo.action_edit', 'icon', '✏', 'variant', 'muted'), 'delete', jsonb_build_object('label', 'plxdemo.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'plxdemo.confirm_delete')));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.note_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.note.read');
  IF p_filter IS NULL THEN
    RETURN QUERY SELECT to_jsonb(t) FROM plxdemo.note t WHERE t.tenant_id = (SELECT current_setting('app.tenant_id')) AND t.deleted_at IS NULL ORDER BY t.created_at desc;
  ELSE
    RETURN QUERY EXECUTE 'SELECT to_jsonb(t) FROM plxdemo.note t WHERE ' || pgv.rsql_to_where(p_filter, 'plxdemo', 'note') || ' AND t.tenant_id = (SELECT current_setting(''app.tenant_id'')) AND t.deleted_at IS NULL ORDER BY t.created_at desc';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.note_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.note.read');
  SELECT to_jsonb(t) INTO v_result FROM plxdemo.note t WHERE t.id = p_id::int AND t.tenant_id = (SELECT current_setting('app.tenant_id')) AND t.deleted_at IS NULL;
  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN v_result || jsonb_build_object('actions', jsonb_build_array(jsonb_build_object('method', 'edit', 'uri', 'plxdemo://note/' || p_id || '/edit'), jsonb_build_object('method', 'delete', 'uri', 'plxdemo://note/' || p_id || '/delete')));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.note_create(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_p_row record;
  v_result record;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.note.create');
  IF NOT (jsonb_typeof(p_input) = 'object') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_invalid_note_payload';
  END IF;
  IF NOT ((NOT EXISTS (SELECT 1 FROM jsonb_object_keys(p_input) AS k(key) WHERE k.key <> ALL (ARRAY['title', 'body', 'pinned']::text[])))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_unknown_note_field';
  END IF;
  IF NOT (NOT jsonb_exists(p_input, 'id')) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_id_readonly';
  END IF;
  IF NOT (jsonb_exists(p_input, 'title') AND p_input->>'title' IS NOT NULL) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_title_required';
  END IF;
  v_p_row := jsonb_populate_record(NULL::plxdemo.note, p_input);
  INSERT INTO plxdemo.note (title, body, pinned)
      VALUES (v_p_row.title, v_p_row.body, COALESCE(v_p_row.pinned, false))
      RETURNING * INTO v_result;
  RETURN (to_jsonb(v_result));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.note_update(p_id text, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_current plxdemo.note;
  v_p_row record;
  v_result record;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.note.modify');
  IF NOT (jsonb_typeof(p_input) = 'object') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_invalid_note_payload';
  END IF;
  IF NOT ((NOT EXISTS (SELECT 1 FROM jsonb_object_keys(p_input) AS k(key) WHERE k.key <> ALL (ARRAY['title', 'body', 'pinned']::text[])))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_unknown_note_field';
  END IF;
  IF NOT (NOT jsonb_exists(p_input, 'id')) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_id_readonly';
  END IF;
  SELECT * INTO v_current FROM plxdemo.note WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id'));
  IF NOT FOUND THEN
    RAISE EXCEPTION 'plxdemo.err_not_found';
  END IF;
  v_p_row := jsonb_populate_record(v_current, p_input);
  UPDATE plxdemo.note SET
      title = v_p_row.title,
      body = v_p_row.body,
      pinned = v_p_row.pinned,
      updated_at = now()
      WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id'))
      RETURNING * INTO v_result;
  RETURN (to_jsonb(v_result));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.note_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_result plxdemo.note;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.note.delete');
  UPDATE plxdemo.note SET deleted_at = now() WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id')) AND deleted_at IS NULL RETURNING * INTO v_result;
  RETURN (to_jsonb(v_result));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.project_on_update(p_new plxdemo.project, p_old plxdemo.project)
 RETURNS void
 LANGUAGE plpgsql AS $$
BEGIN
  IF p_new.status = 'active' AND p_old.status = 'draft' THEN
    PERFORM plxdemo._emit_event('plxdemo.project.activated', 'plxdemo.project', p_new.id::text, jsonb_build_object('project_id', p_new.id), jsonb_build_object('operation', 'update', 'entity', 'plxdemo.project'));
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.on_plxdemo_project_activated_1(project_id int)
 RETURNS void
 LANGUAGE plpgsql AS $$
BEGIN
  PERFORM plxdemo.project_create_kickoff_task(project_id);
END;
$$;
