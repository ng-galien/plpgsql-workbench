CREATE OR REPLACE FUNCTION pgv.route_crud(p_verb text, p_uri text, p_data jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_parsed jsonb;
  v_schema text;
  v_entity text;
  v_id text;
  v_method text;
  v_filter text;
  v_fragment text;
  v_fn text;
  v_fn_fallback text;
  v_result jsonb;
  v_actions jsonb := '[]';
  v_rec record;
  v_verb text := lower(p_verb);
BEGIN
  v_parsed := pgv._parse_uri(p_uri);
  v_schema := v_parsed->>'schema';
  v_entity := v_parsed->>'entity';
  v_id := v_parsed->>'id';
  v_method := v_parsed->>'method';
  v_filter := v_parsed->>'filter';
  v_fragment := v_parsed->>'fragment';

  -- get :// → catalog
  IF v_schema IS NULL AND v_entity IS NULL THEN
    RETURN jsonb_build_object('data', pgv.schema_catalog(), 'uri', p_uri);
  END IF;

  -- Validate schema exists
  IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = v_schema) THEN
    RETURN jsonb_build_object('error', 'not_found', 'message', format('schema "%s" does not exist', v_schema));
  END IF;

  -- get schema:// → discover
  IF v_entity IS NULL THEN
    RETURN jsonb_build_object('data', pgv.schema_discover(v_schema), 'uri', p_uri);
  END IF;

  -- get schema://entity#schema → schema_table
  IF v_fragment = 'schema' THEN
    RETURN jsonb_build_object('data', pgv.schema_table(v_schema, v_entity), 'uri', p_uri);
  END IF;

  -- Dispatch by verb
  CASE v_verb
    WHEN 'get' THEN
      IF v_id IS NOT NULL THEN
        -- get schema://entity/{id} → entity_read or entity_load
        v_fn := v_entity || '_read';
        v_fn_fallback := v_entity || '_load';
        IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
          v_fn := v_fn_fallback;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
          RETURN jsonb_build_object('error', 'not_found', 'message', format('function %s.%s_read() does not exist', v_schema, v_entity));
        END IF;
        EXECUTE format('SELECT to_jsonb(r) FROM %I.%I(%L) r', v_schema, v_fn, v_id) INTO v_result;
      ELSE
        -- get schema://entity → entity_list
        v_fn := v_entity || '_list';
        IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
          RETURN jsonb_build_object('error', 'not_found', 'message', format('function %s.%s() does not exist', v_schema, v_fn));
        END IF;
        IF v_filter IS NOT NULL THEN
          EXECUTE format('SELECT to_jsonb(r) FROM %I.%I(%L) r', v_schema, v_fn, v_filter) INTO v_result;
        ELSE
          EXECUTE format('SELECT to_jsonb(r) FROM %I.%I() r', v_schema, v_fn) INTO v_result;
        END IF;
      END IF;

    WHEN 'set' THEN
      -- set schema://entity → entity_create
      v_fn := v_entity || '_create';
      IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
        RETURN jsonb_build_object('error', 'not_found', 'message', format('function %s.%s() does not exist', v_schema, v_fn));
      END IF;
      EXECUTE format('SELECT to_jsonb(r) FROM %I.%I(%L::jsonb) r', v_schema, v_fn, p_data::text) INTO v_result;

    WHEN 'patch' THEN
      -- patch schema://entity/{id} → entity_update
      v_fn := v_entity || '_update';
      IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
        RETURN jsonb_build_object('error', 'not_found', 'message', format('function %s.%s() does not exist', v_schema, v_fn));
      END IF;
      EXECUTE format('SELECT to_jsonb(r) FROM %I.%I(%L, %L::jsonb) r', v_schema, v_fn, v_id, p_data::text) INTO v_result;

    WHEN 'delete' THEN
      -- delete schema://entity/{id} → entity_delete
      v_fn := v_entity || '_delete';
      IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
        RETURN jsonb_build_object('error', 'not_found', 'message', format('function %s.%s() does not exist', v_schema, v_fn));
      END IF;
      EXECUTE format('SELECT to_jsonb(r) FROM %I.%I(%L) r', v_schema, v_fn, v_id) INTO v_result;

    WHEN 'post' THEN
      -- post schema://entity/{id}/{method} → entity_{method}
      IF v_method IS NULL THEN
        RETURN jsonb_build_object('error', 'bad_request', 'message', 'POST requires a method in the URI');
      END IF;
      v_fn := v_entity || '_' || v_method;
      IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
        RETURN jsonb_build_object('error', 'not_found', 'message', format('function %s.%s() does not exist', v_schema, v_fn));
      END IF;
      IF v_id IS NOT NULL AND p_data IS NOT NULL THEN
        EXECUTE format('SELECT to_jsonb(r) FROM %I.%I(%L, %L::jsonb) r', v_schema, v_fn, v_id, p_data::text) INTO v_result;
      ELSIF v_id IS NOT NULL THEN
        EXECUTE format('SELECT to_jsonb(r) FROM %I.%I(%L) r', v_schema, v_fn, v_id) INTO v_result;
      ELSE
        EXECUTE format('SELECT to_jsonb(r) FROM %I.%I() r', v_schema, v_fn) INTO v_result;
      END IF;

    ELSE
      RETURN jsonb_build_object('error', 'bad_request', 'message', format('unsupported verb "%s"', p_verb));
  END CASE;

  -- HATEOAS: discover available actions
  IF v_id IS NOT NULL THEN
    -- Standard CRUD actions
    FOR v_rec IN
      SELECT p.proname FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = v_schema
        AND p.proname IN (v_entity || '_update', v_entity || '_delete', v_entity || '_read', v_entity || '_load')
    LOOP
      IF v_rec.proname = v_entity || '_update' THEN
        v_actions := v_actions || jsonb_build_object('verb', 'patch', 'uri', v_schema || '://' || v_entity || '/' || v_id);
      ELSIF v_rec.proname = v_entity || '_delete' THEN
        v_actions := v_actions || jsonb_build_object('verb', 'delete', 'uri', v_schema || '://' || v_entity || '/' || v_id);
      END IF;
    END LOOP;
    -- Custom methods
    FOR v_rec IN
      SELECT p.proname FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = v_schema
        AND p.proname LIKE v_entity || '_%'
        AND p.proname NOT IN (
          v_entity || '_list', v_entity || '_read', v_entity || '_load',
          v_entity || '_create', v_entity || '_update', v_entity || '_delete',
          v_entity || '_check'
        )
      ORDER BY p.proname
    LOOP
      v_actions := v_actions || jsonb_build_object(
        'method', replace(v_rec.proname, v_entity || '_', ''),
        'uri', v_schema || '://' || v_entity || '/' || v_id || '/' || replace(v_rec.proname, v_entity || '_', '')
      );
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'data', coalesce(v_result, 'null'::jsonb),
    'uri', p_uri,
    'actions', v_actions
  );
END;
$function$;
