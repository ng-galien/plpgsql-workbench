CREATE OR REPLACE FUNCTION workbench.get_tools()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_total    integer;
  v_packs    integer;
  v_html     text;
  v_tree     jsonb := '[]'::jsonb;
  v_pack     text;
  v_pack_tools jsonb;
  r          record;
  v_tool_node jsonb;
  v_params   jsonb;
  v_key      text;
  v_prop     jsonb;
  v_detail   jsonb;
BEGIN
  SELECT count(*) INTO v_total FROM workbench.toolbox_tool;
  SELECT count(DISTINCT split_part(tool_name, '_', 1)) INTO v_packs FROM workbench.toolbox_tool;

  v_html := pgv.grid(
    pgv.stat(pgv.t('workbench.stat_tools'), v_total::text),
    pgv.stat('Packs', v_packs::text)
  );

  -- Build tree: pack > tool > (description + params)
  FOR v_pack IN
    SELECT DISTINCT
      CASE
        WHEN tool_name LIKE 'pg\_%' ESCAPE '\' THEN 'plpgsql'
        WHEN tool_name LIKE 'ws\_%' ESCAPE '\' THEN 'plpgsql'
        WHEN tool_name LIKE 'fs\_%' ESCAPE '\' THEN 'docstore'
        WHEN tool_name LIKE 'gmail\_%' ESCAPE '\' THEN 'google'
        WHEN tool_name LIKE 'doc\_%' ESCAPE '\' THEN 'docman'
        ELSE 'other'
      END
    FROM workbench.toolbox_tool
    ORDER BY 1
  LOOP
    v_pack_tools := '[]'::jsonb;

    FOR r IN
      SELECT tool_name, description, input_schema
        FROM workbench.toolbox_tool
       WHERE CASE
          WHEN tool_name LIKE 'pg\_%' ESCAPE '\' THEN 'plpgsql'
          WHEN tool_name LIKE 'ws\_%' ESCAPE '\' THEN 'plpgsql'
          WHEN tool_name LIKE 'fs\_%' ESCAPE '\' THEN 'docstore'
          WHEN tool_name LIKE 'gmail\_%' ESCAPE '\' THEN 'google'
          WHEN tool_name LIKE 'doc\_%' ESCAPE '\' THEN 'docman'
          ELSE 'other'
        END = v_pack
       ORDER BY tool_name
    LOOP
      -- Build children: description + params
      v_detail := '[]'::jsonb;

      IF r.description IS NOT NULL THEN
        v_detail := v_detail || jsonb_build_object('label', r.description);
      END IF;

      IF r.input_schema IS NOT NULL AND r.input_schema ? 'properties' THEN
        v_params := r.input_schema -> 'properties';
        FOR v_key, v_prop IN SELECT * FROM jsonb_each(v_params)
        LOOP
          v_detail := v_detail || jsonb_build_object(
            'label', v_key || ' (' || coalesce(v_prop ->> 'type', '?') || ')',
            'badge', CASE
              WHEN r.input_schema -> 'required' @> to_jsonb(v_key) THEN 'requis'
              ELSE null
            END
          );
        END LOOP;
      END IF;

      -- Tool node: branch if has detail, leaf link otherwise
      IF jsonb_array_length(v_detail) > 0 THEN
        v_tool_node := jsonb_build_object(
          'label', r.tool_name,
          'children', v_detail
        );
      ELSE
        v_tool_node := jsonb_build_object(
          'label', r.tool_name,
          'href', pgv.call_ref('get_tool', jsonb_build_object('p_name', r.tool_name)),
          'badge', '?'
        );
      END IF;

      v_pack_tools := v_pack_tools || v_tool_node;
    END LOOP;

    v_tree := v_tree || jsonb_build_object(
      'label', v_pack,
      'badge', jsonb_array_length(v_pack_tools)::text,
      'open', true,
      'children', v_pack_tools
    );
  END LOOP;

  v_html := v_html || pgv.tree(v_tree);

  RETURN v_html;
END;
$function$;
