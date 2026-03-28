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
  v_verb text := lower(p_verb);
  v_is_jsonb boolean;
  v_existing jsonb;
  v_merged jsonb;
  v_id_key text;
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

  IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = v_schema) THEN
    PERFORM pgv.throw_not_found(format('schema "%s" does not exist', v_schema));
  END IF;

  IF v_entity IS NULL THEN
    RETURN jsonb_build_object('data', pgv.schema_discover(v_schema), 'uri', p_uri);
  END IF;

  IF v_fragment = 'schema' THEN
    RETURN jsonb_build_object('data', pgv.schema_table(v_schema, v_entity), 'uri', p_uri);
  END IF;

  CASE v_verb
    WHEN 'get' THEN
      IF v_id IS NOT NULL THEN
        v_fn := v_entity || '_read';
        v_fn_fallback := v_entity || '_load';
        IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
          v_fn := v_fn_fallback;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
          PERFORM pgv.throw_not_found(format('function %s.%s_read() does not exist', v_schema, v_entity));
        END IF;
        -- Check if function returns jsonb directly
        SELECT t.typname = 'jsonb' INTO v_is_jsonb
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_type t ON t.oid = p.prorettype
        WHERE n.nspname = v_schema AND p.proname = v_fn;
        IF v_is_jsonb THEN
          EXECUTE format('SELECT %I.%I(%L)', v_schema, v_fn, v_id) INTO v_result;
        ELSE
          EXECUTE format('SELECT to_jsonb(r) FROM %I.%I(%L) r', v_schema, v_fn, v_id) INTO v_result;
        END IF;
      ELSE
        v_fn := v_entity || '_list';
        IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
          PERFORM pgv.throw_not_found(format('function %s.%s() does not exist', v_schema, v_fn));
        END IF;
        IF v_filter IS NOT NULL THEN
          EXECUTE format('SELECT coalesce(jsonb_agg(t), ''[]''::jsonb) FROM %I.%I(%L) t', v_schema, v_fn, v_filter) INTO v_result;
        ELSE
          EXECUTE format('SELECT coalesce(jsonb_agg(t), ''[]''::jsonb) FROM %I.%I() t', v_schema, v_fn) INTO v_result;
        END IF;
      END IF;

    WHEN 'set' THEN
      v_fn := v_entity || '_create';
      IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
        PERFORM pgv.throw_not_found(format('function %s.%s() does not exist', v_schema, v_fn));
      END IF;
      SELECT t.typname = 'jsonb' INTO v_is_jsonb
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_type t ON t.oid = p.prorettype
      WHERE n.nspname = v_schema AND p.proname = v_fn;
      IF v_is_jsonb THEN
        EXECUTE format('SELECT %I.%I(jsonb_populate_record(NULL::%I.%I, $1))', v_schema, v_fn, v_schema, v_entity) USING p_data INTO v_result;
      ELSE
        EXECUTE format('SELECT to_jsonb(r) FROM %I.%I(jsonb_populate_record(NULL::%I.%I, $1)) r', v_schema, v_fn, v_schema, v_entity) USING p_data INTO v_result;
      END IF;

    WHEN 'patch' THEN
      v_fn := v_entity || '_update';
      IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
        PERFORM pgv.throw_not_found(format('function %s.%s() does not exist', v_schema, v_fn));
      END IF;
      SELECT t.typname = 'jsonb' INTO v_is_jsonb
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_type t ON t.oid = p.prorettype
      WHERE n.nspname = v_schema AND p.proname = v_fn;
      -- Merge patch onto existing row (load current, overlay p_data)
      v_id_key := CASE WHEN EXISTS (
        SELECT 1 FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = v_schema AND c.relname = v_entity AND a.attname = 'slug' AND a.attnum > 0 AND NOT a.attisdropped
      ) THEN 'slug' ELSE 'id' END;
      EXECUTE format('SELECT to_jsonb(t) FROM %I.%I t WHERE %I::text = $1 LIMIT 1', v_schema, v_entity, v_id_key) USING v_id INTO v_existing;
      IF v_existing IS NULL THEN
        PERFORM pgv.throw_not_found(format('%s.%s %s=%s not found', v_schema, v_entity, v_id_key, v_id));
      END IF;
      v_merged := v_existing || p_data;
      IF v_is_jsonb THEN
        EXECUTE format('SELECT %I.%I(jsonb_populate_record(NULL::%I.%I, $1))', v_schema, v_fn, v_schema, v_entity) USING v_merged INTO v_result;
      ELSE
        EXECUTE format('SELECT to_jsonb(r) FROM %I.%I(jsonb_populate_record(NULL::%I.%I, $1)) r', v_schema, v_fn, v_schema, v_entity) USING v_merged INTO v_result;
      END IF;

    WHEN 'delete' THEN
      v_fn := v_entity || '_delete';
      IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
        PERFORM pgv.throw_not_found(format('function %s.%s() does not exist', v_schema, v_fn));
      END IF;
      SELECT t.typname = 'jsonb' INTO v_is_jsonb
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_type t ON t.oid = p.prorettype
      WHERE n.nspname = v_schema AND p.proname = v_fn;
      IF v_is_jsonb THEN
        EXECUTE format('SELECT %I.%I(%L)', v_schema, v_fn, v_id) INTO v_result;
      ELSE
        EXECUTE format('SELECT to_jsonb(r) FROM %I.%I(%L) r', v_schema, v_fn, v_id) INTO v_result;
      END IF;

    WHEN 'post' THEN
      IF v_method IS NULL THEN
        PERFORM pgv.throw_invalid('POST requires a method in the URI');
      END IF;
      v_fn := v_entity || '_' || v_method;
      IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = v_schema AND p.proname = v_fn) THEN
        PERFORM pgv.throw_not_found(format('function %s.%s() does not exist', v_schema, v_fn));
      END IF;
      SELECT t.typname = 'jsonb' INTO v_is_jsonb
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_type t ON t.oid = p.prorettype
      WHERE n.nspname = v_schema AND p.proname = v_fn;
      IF v_id IS NOT NULL AND p_data IS NOT NULL THEN
        IF v_is_jsonb THEN
          EXECUTE format('SELECT %I.%I(%L, %L::jsonb)', v_schema, v_fn, v_id, p_data::text) INTO v_result;
        ELSE
          EXECUTE format('SELECT to_jsonb(r) FROM %I.%I(%L, %L::jsonb) r', v_schema, v_fn, v_id, p_data::text) INTO v_result;
        END IF;
      ELSIF v_id IS NOT NULL THEN
        IF v_is_jsonb THEN
          EXECUTE format('SELECT %I.%I(%L)', v_schema, v_fn, v_id) INTO v_result;
        ELSE
          EXECUTE format('SELECT to_jsonb(r) FROM %I.%I(%L) r', v_schema, v_fn, v_id) INTO v_result;
        END IF;
      ELSE
        IF v_is_jsonb THEN
          EXECUTE format('SELECT %I.%I()', v_schema, v_fn) INTO v_result;
        ELSE
          EXECUTE format('SELECT to_jsonb(r) FROM %I.%I() r', v_schema, v_fn) INTO v_result;
        END IF;
      END IF;

    ELSE
      PERFORM pgv.throw_invalid(format('unsupported verb "%s"', p_verb));
  END CASE;

  -- HATEOAS: extract actions from _read() response (module is responsible)
  IF v_result IS NOT NULL AND v_result ? 'actions' THEN
    v_actions := v_result->'actions';
    v_result := v_result - 'actions';
  END IF;

  RETURN jsonb_build_object(
    'data', coalesce(v_result, 'null'::jsonb),
    'uri', p_uri,
    'actions', v_actions
  );
EXCEPTION WHEN OTHERS THEN
  DECLARE
    v_errcode text := SQLSTATE;
    v_msg text;
    v_detail text;
    v_status int;
  BEGIN
    GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT, v_detail = PG_EXCEPTION_DETAIL;
    v_status := CASE
      WHEN v_errcode = 'P0400' THEN 400
      WHEN v_errcode = 'P0404' THEN 404
      WHEN v_errcode = 'P0403' THEN 403
      WHEN v_errcode = 'P0409' THEN 409
      ELSE 500
    END;
    RETURN jsonb_build_object(
      'type', 'about:blank',
      'title', v_msg,
      'status', v_status,
      'detail', coalesce(v_detail, v_msg),
      'instance', p_uri
    );
  END;
END;
$function$;
