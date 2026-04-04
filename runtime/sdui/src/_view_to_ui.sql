CREATE OR REPLACE FUNCTION sdui._view_level_to_ui(p_level jsonb, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_children jsonb := '[]'::jsonb;
  v_stats jsonb;
  v_related jsonb;
BEGIN
  IF p_level IS NULL OR jsonb_typeof(p_level) <> 'object' THEN
    RETURN NULL;
  END IF;

  IF p_level ? 'fields' AND jsonb_typeof(p_level->'fields') = 'array' AND jsonb_array_length(p_level->'fields') > 0 THEN
    v_children := v_children || jsonb_build_array(
      jsonb_build_object('type', 'detail', 'source', 'self', 'fields', p_level->'fields')
    );
  END IF;

  IF p_level ? 'stats' AND jsonb_typeof(p_level->'stats') = 'array' AND jsonb_array_length(p_level->'stats') > 0 THEN
    SELECT coalesce(
      jsonb_agg(
        jsonb_build_object(
          'type', 'stat',
          'value', coalesce(p_data->>(entry->>'key'), '—'),
          'label', entry->>'label'
        ) || CASE
          WHEN entry ? 'variant' THEN jsonb_build_object('variant', entry->>'variant')
          ELSE '{}'::jsonb
        END
      ),
      '[]'::jsonb
    )
      INTO v_stats
    FROM jsonb_array_elements(p_level->'stats') AS entry;

    IF jsonb_array_length(v_stats) > 0 THEN
      v_children := v_children || jsonb_build_array(
        jsonb_build_object('type', 'row', 'children', v_stats)
      );
    END IF;
  END IF;

  IF p_level ? 'related' AND jsonb_typeof(p_level->'related') = 'array' AND jsonb_array_length(p_level->'related') > 0 THEN
    SELECT coalesce(
      jsonb_agg(
        jsonb_build_object('type', 'badge', 'text', entry->>'label', 'variant', 'outline')
      ),
      '[]'::jsonb
    )
      INTO v_related
    FROM jsonb_array_elements(p_level->'related') AS entry;

    IF jsonb_array_length(v_related) > 0 THEN
      v_children := v_children || jsonb_build_array(
        jsonb_build_object('type', 'row', 'children', v_related)
      );
    END IF;
  END IF;

  IF jsonb_array_length(v_children) = 0 THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object('type', 'column', 'children', v_children);
END;
$function$;

CREATE OR REPLACE FUNCTION sdui._view_to_ui(p_view jsonb, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_template jsonb;
  v_compact jsonb;
  v_standard jsonb;
  v_expanded jsonb;
  v_result jsonb;
BEGIN
  IF p_view IS NULL OR jsonb_typeof(p_view) <> 'object' THEN
    RETURN NULL;
  END IF;

  v_template := p_view->'template';
  IF v_template IS NULL OR jsonb_typeof(v_template) <> 'object' THEN
    RETURN NULL;
  END IF;

  v_compact := sdui._view_level_to_ui(v_template->'compact', p_data);
  v_standard := sdui._view_level_to_ui(v_template->'standard', p_data);
  v_expanded := sdui._view_level_to_ui(v_template->'expanded', p_data);

  v_result := jsonb_strip_nulls(
    jsonb_build_object(
      'compact', v_compact,
      'standard', v_standard,
      'expanded', v_expanded
    )
  );

  IF v_result = '{}'::jsonb THEN
    RETURN NULL;
  END IF;

  RETURN v_result;
END;
$function$;
