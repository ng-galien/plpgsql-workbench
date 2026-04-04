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
  RETURN jsonb_build_object('uri', 'plxdemo://task', 'label', 'plxdemo.entity_task', 'icon', '✓', 'template', jsonb_build_object('compact', jsonb_build_object('fields', jsonb_build_array('title', 'priority', 'done', 'rank', 'note_id')), 'standard', jsonb_build_object('fields', jsonb_build_array('title', 'description', 'priority', 'done', 'rank', 'note_id')), 'expanded', jsonb_build_object('fields', jsonb_build_array('title', 'description', 'priority', 'done', 'rank', 'note_id', 'created_at', 'updated_at')), 'form', jsonb_build_object('sections', jsonb_build_array(jsonb_build_object('label', 'plxdemo.section_task', 'fields', jsonb_build_array(jsonb_build_object('key', 'title', 'type', 'text', 'label', 'plxdemo.field_title', 'required', true), jsonb_build_object('key', 'description', 'type', 'textarea', 'label', 'plxdemo.field_description'), jsonb_build_object('key', 'priority', 'type', 'select', 'label', 'plxdemo.field_priority')))))), 'actions', jsonb_build_object('edit', jsonb_build_object('label', 'plxdemo.action_edit', 'icon', '✏', 'variant', 'muted'), 'delete', jsonb_build_object('label', 'plxdemo.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'plxdemo.confirm_delete')));
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
    RETURN QUERY SELECT jsonb_build_object('id', t.id, 'rank', t.rank, 'note_id', t.note_id, 'created_at', t.created_at, 'updated_at', t.updated_at) || jsonb_strip_nulls(COALESCE(t.payload, '{}'::jsonb)) FROM plxdemo.task t WHERE t.tenant_id = (SELECT current_setting('app.tenant_id')) ORDER BY t.created_at desc;
  ELSE
    RETURN QUERY EXECUTE 'SELECT jsonb_build_object(''id'', t.id, ''rank'', t.rank, ''note_id'', t.note_id, ''created_at'', t.created_at, ''updated_at'', t.updated_at) || jsonb_strip_nulls(COALESCE(t.payload, ''{}''::jsonb)) FROM plxdemo.task t WHERE ' || pgv.rsql_to_where(p_filter, 'plxdemo', 'task') || ' AND t.tenant_id = (SELECT current_setting(''app.tenant_id'')) ORDER BY t.created_at desc';
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
  SELECT jsonb_build_object('id', t.id, 'rank', t.rank, 'note_id', t.note_id, 'created_at', t.created_at, 'updated_at', t.updated_at) || jsonb_strip_nulls(COALESCE(t.payload, '{}'::jsonb)) INTO v_result FROM plxdemo.task t WHERE t.id = p_id::int AND t.tenant_id = (SELECT current_setting('app.tenant_id'));
  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN v_result || jsonb_build_object('actions', jsonb_build_array(jsonb_build_object('method', 'edit', 'uri', 'plxdemo://task/' || p_id || '/edit'), jsonb_build_object('method', 'delete', 'uri', 'plxdemo://task/' || p_id || '/delete')));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_create(p_data jsonb)
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
  IF NOT (jsonb_typeof(p_data) = 'object') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_invalid_task_payload';
  END IF;
  IF NOT ((NOT EXISTS (SELECT 1 FROM jsonb_object_keys(p_data) AS k(key) WHERE k.key <> ALL (ARRAY['rank', 'note_id', 'title', 'description', 'priority', 'done']::text[])))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_unknown_task_field';
  END IF;
  IF NOT (NOT jsonb_exists(p_data, 'id')) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_id_readonly';
  END IF;
  IF NOT (jsonb_exists(p_data, 'title') AND p_data->>'title' IS NOT NULL) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_title_required';
  END IF;
  v_p_row := jsonb_populate_record(NULL::plxdemo.task, p_data);
  IF NOT ((coalesce(p_data->>'priority', 'normal') in ('low', 'normal', 'high'))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'priority_valid';
  END IF;
  INSERT INTO plxdemo.task (rank, note_id, payload)
      VALUES (COALESCE(v_p_row.rank, 0), v_p_row.note_id, jsonb_strip_nulls(jsonb_build_object('title', p_data->'title', 'description', p_data->'description', 'priority', COALESCE(p_data->'priority', to_jsonb('normal'::text)), 'done', COALESCE(p_data->'done', to_jsonb(false::boolean)))))
      RETURNING * INTO v_result;
  RETURN (jsonb_build_object('id', v_result.id, 'rank', v_result.rank, 'note_id', v_result.note_id, 'created_at', v_result.created_at, 'updated_at', v_result.updated_at) || jsonb_strip_nulls(COALESCE(v_result.payload, '{}'::jsonb)));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.task_update(p_id text, p_patch jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_current plxdemo.task;
  v_p_row record;
  v_p_data jsonb;
  v_result record;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.task.modify');
  IF NOT (jsonb_typeof(p_patch) = 'object') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_invalid_task_payload';
  END IF;
  IF NOT ((NOT EXISTS (SELECT 1 FROM jsonb_object_keys(p_patch) AS k(key) WHERE k.key <> ALL (ARRAY['rank', 'note_id', 'title', 'description', 'priority', 'done']::text[])))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_unknown_task_field';
  END IF;
  IF NOT (NOT jsonb_exists(p_patch, 'id')) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_id_readonly';
  END IF;
  SELECT * INTO v_current FROM plxdemo.task WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id'));
  IF NOT FOUND THEN
    RAISE EXCEPTION 'plxdemo.err_not_found';
  END IF;
  v_p_row := jsonb_populate_record(v_current, p_patch);
  v_p_data := p_patch;
  IF NOT ((coalesce(p_data->>'priority', 'normal') in ('low', 'normal', 'high'))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'priority_valid';
  END IF;
  UPDATE plxdemo.task SET
      rank = v_p_row.rank,
      note_id = v_p_row.note_id,
      payload = (v_current.payload - array_remove(ARRAY[CASE WHEN p_patch ? 'title' AND p_patch->'title' = 'null'::jsonb THEN 'title' ELSE NULL END, CASE WHEN p_patch ? 'description' AND p_patch->'description' = 'null'::jsonb THEN 'description' ELSE NULL END, CASE WHEN p_patch ? 'priority' AND p_patch->'priority' = 'null'::jsonb THEN 'priority' ELSE NULL END, CASE WHEN p_patch ? 'done' AND p_patch->'done' = 'null'::jsonb THEN 'done' ELSE NULL END], NULL)) || CASE WHEN p_patch ? 'title' AND p_patch->'title' <> 'null'::jsonb THEN jsonb_build_object('title', p_patch->'title') ELSE '{}'::jsonb END || CASE WHEN p_patch ? 'description' AND p_patch->'description' <> 'null'::jsonb THEN jsonb_build_object('description', p_patch->'description') ELSE '{}'::jsonb END || CASE WHEN p_patch ? 'priority' AND p_patch->'priority' <> 'null'::jsonb THEN jsonb_build_object('priority', p_patch->'priority') ELSE '{}'::jsonb END || CASE WHEN p_patch ? 'done' AND p_patch->'done' <> 'null'::jsonb THEN jsonb_build_object('done', p_patch->'done') ELSE '{}'::jsonb END,
      updated_at = now()
      WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id'))
      RETURNING * INTO v_result;
  RETURN (jsonb_build_object('id', v_result.id, 'rank', v_result.rank, 'note_id', v_result.note_id, 'created_at', v_result.created_at, 'updated_at', v_result.updated_at) || jsonb_strip_nulls(COALESCE(v_result.payload, '{}'::jsonb)));
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
  RETURN (jsonb_build_object('id', v_result.id, 'rank', v_result.rank, 'note_id', v_result.note_id, 'created_at', v_result.created_at, 'updated_at', v_result.updated_at) || jsonb_strip_nulls(COALESCE(v_result.payload, '{}'::jsonb)));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.note_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE AS $$
BEGIN
  RETURN jsonb_build_object('uri', 'plxdemo://note', 'label', 'plxdemo.entity_note', 'icon', '✎', 'template', jsonb_build_object('compact', jsonb_build_object('fields', jsonb_build_array('title')), 'standard', jsonb_build_object('fields', jsonb_build_array('title', 'body')), 'expanded', jsonb_build_object('fields', jsonb_build_array('title', 'body', 'created_at', 'updated_at')), 'form', jsonb_build_object('sections', jsonb_build_array(jsonb_build_object('label', 'plxdemo.section_note', 'fields', jsonb_build_array(jsonb_build_object('key', 'title', 'type', 'text', 'label', 'plxdemo.field_title', 'required', true), jsonb_build_object('key', 'body', 'type', 'textarea', 'label', 'plxdemo.field_body')))))), 'actions', jsonb_build_object('edit', jsonb_build_object('label', 'plxdemo.action_edit', 'icon', '✏', 'variant', 'muted'), 'delete', jsonb_build_object('label', 'plxdemo.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'plxdemo.confirm_delete')));
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
    RETURN QUERY SELECT to_jsonb(t) FROM plxdemo.note t WHERE t.tenant_id = (SELECT current_setting('app.tenant_id')) ORDER BY t.created_at desc;
  ELSE
    RETURN QUERY EXECUTE 'SELECT to_jsonb(t) FROM plxdemo.note t WHERE ' || pgv.rsql_to_where(p_filter, 'plxdemo', 'note') || ' AND t.tenant_id = (SELECT current_setting(''app.tenant_id'')) ORDER BY t.created_at desc';
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
  SELECT to_jsonb(t) INTO v_result FROM plxdemo.note t WHERE t.id = p_id::int AND t.tenant_id = (SELECT current_setting('app.tenant_id'));
  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN v_result || jsonb_build_object('actions', jsonb_build_array(jsonb_build_object('method', 'edit', 'uri', 'plxdemo://note/' || p_id || '/edit'), jsonb_build_object('method', 'delete', 'uri', 'plxdemo://note/' || p_id || '/delete')));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.note_create(p_data jsonb)
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
  IF NOT (jsonb_typeof(p_data) = 'object') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_invalid_note_payload';
  END IF;
  IF NOT ((NOT EXISTS (SELECT 1 FROM jsonb_object_keys(p_data) AS k(key) WHERE k.key <> ALL (ARRAY['title', 'body']::text[])))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_unknown_note_field';
  END IF;
  IF NOT (NOT jsonb_exists(p_data, 'id')) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_id_readonly';
  END IF;
  IF NOT (jsonb_exists(p_data, 'title') AND p_data->>'title' IS NOT NULL) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_title_required';
  END IF;
  v_p_row := jsonb_populate_record(NULL::plxdemo.note, p_data);
  INSERT INTO plxdemo.note (title, body)
      VALUES (v_p_row.title, v_p_row.body)
      RETURNING * INTO v_result;
  RETURN (to_jsonb(v_result));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo.note_update(p_id text, p_patch jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = plxdemo, pg_catalog, pg_temp AS $$
DECLARE
  v_current plxdemo.note;
  v_p_row record;
  v_p_data jsonb;
  v_result record;
BEGIN
  IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF;
  PERFORM plxdemo.authorize('plxdemo.note.modify');
  IF NOT (jsonb_typeof(p_patch) = 'object') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_invalid_note_payload';
  END IF;
  IF NOT ((NOT EXISTS (SELECT 1 FROM jsonb_object_keys(p_patch) AS k(key) WHERE k.key <> ALL (ARRAY['title', 'body']::text[])))) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_unknown_note_field';
  END IF;
  IF NOT (NOT jsonb_exists(p_patch, 'id')) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = 'plxdemo.err_id_readonly';
  END IF;
  SELECT * INTO v_current FROM plxdemo.note WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id'));
  IF NOT FOUND THEN
    RAISE EXCEPTION 'plxdemo.err_not_found';
  END IF;
  v_p_row := jsonb_populate_record(v_current, p_patch);
  v_p_data := p_patch;
  UPDATE plxdemo.note SET
      title = v_p_row.title,
      body = v_p_row.body,
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
  DELETE FROM plxdemo.note WHERE id = p_id::int AND tenant_id = (SELECT current_setting('app.tenant_id')) RETURNING * INTO v_result;
  RETURN (to_jsonb(v_result));
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_health()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
BEGIN
  RETURN NEXT is(plxdemo.health()->>'name', 'plxdemo', 'assert line 17');
  RETURN NEXT is(plxdemo.health()->>'status', 'ok', 'assert line 18');
  RETURN NEXT is(plxdemo.health()->>'demo', 'crud', 'assert line 19');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_task_crud_lifecycle()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_n jsonb;
  v_c jsonb;
  v_r jsonb;
  v_u jsonb;
  v_d jsonb;
BEGIN
  v_n := plxdemo.note_create(jsonb_build_object('title', 'Linked note', 'body', 'Task dependency'));
  v_c := plxdemo.task_create(jsonb_build_object('title', 'Buy milk', 'priority', 'high', 'done', false, 'rank', 3, 'note_id', (v_n->>'id')::int));
  RETURN NEXT is(v_c->>'title', 'Buy milk', 'assert line 4');
  RETURN NEXT is(v_c->>'priority', 'high', 'assert line 5');
  RETURN NEXT is(v_c->>'done', 'false', 'assert line 6');
  RETURN NEXT is(v_c->>'rank', '3', 'assert line 7');
  RETURN NEXT is(v_c->>'note_id', v_n->>'id', 'assert line 8');
  v_r := plxdemo.task_read(v_c->>'id');
  RETURN NEXT is(v_r->>'title', 'Buy milk', 'assert line 11');
  RETURN NEXT isnt(v_r->>'actions', 'null', 'assert line 12');
  v_u := plxdemo.task_update(v_c->>'id', jsonb_build_object('title', 'Buy oat milk'));
  RETURN NEXT is(v_u->>'title', 'Buy oat milk', 'assert line 15');
  v_d := plxdemo.task_delete(v_c->>'id');
  RETURN NEXT is(v_d->>'title', 'Buy oat milk', 'assert line 18');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_task_list()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_n bigint;
BEGIN
  PERFORM plxdemo.task_create(jsonb_build_object('title', 'Alpha', 'priority', 'normal', 'done', false));
  PERFORM plxdemo.task_create(jsonb_build_object('title', 'Beta', 'priority', 'low', 'done', true));
  select count(*) INTO v_n from plxdemo.task_list();
  RETURN NEXT ok(v_n >= 2, 'assert line 24');
END;
$$;

CREATE OR REPLACE FUNCTION plxdemo_ut.test_note_crud_lifecycle()
 RETURNS SETOF text
 LANGUAGE plpgsql AS $$
DECLARE
  v_c jsonb;
  v_r jsonb;
  v_u jsonb;
  v_d jsonb;
BEGIN
  v_c := plxdemo.note_create(jsonb_build_object('title', 'Draft note', 'body', 'Hello'));
  RETURN NEXT is(v_c->>'title', 'Draft note', 'assert line 3');
  RETURN NEXT is(v_c->>'body', 'Hello', 'assert line 4');
  v_r := plxdemo.note_read(v_c->>'id');
  RETURN NEXT is(v_r->>'title', 'Draft note', 'assert line 7');
  RETURN NEXT isnt(v_r->>'actions', 'null', 'assert line 8');
  v_u := plxdemo.note_update(v_c->>'id', jsonb_build_object('title', 'Updated note'));
  RETURN NEXT is(v_u->>'title', 'Updated note', 'assert line 11');
  v_d := plxdemo.note_delete(v_c->>'id');
  RETURN NEXT is(v_d->>'title', 'Updated note', 'assert line 14');
END;
$$;
