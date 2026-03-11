CREATE OR REPLACE FUNCTION pgv.tree(p_items jsonb, p_open boolean DEFAULT false, p_depth integer DEFAULT 0, p_root_attrs text DEFAULT ''::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_html text;
  v_item jsonb;
  v_label text;
  v_href text;
  v_open boolean;
  v_icon text;
  v_badge text;
  v_action jsonb;
  v_attrs text;
  v_prefix text;
  v_suffix text;
  v_li_open text;
BEGIN
  IF p_depth = 0 THEN
    v_html := '<ul class="pgv-tree"' || CASE WHEN p_root_attrs <> '' THEN ' ' || p_root_attrs ELSE '' END || '>';
  ELSE
    v_html := '<ul>';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_label := v_item->>'label';
    v_href := v_item->>'href';
    v_open := coalesce((v_item->>'open')::boolean, p_open);
    v_icon := v_item->>'icon';
    v_badge := v_item->>'badge';
    v_action := v_item->'action';
    v_attrs := coalesce(v_item->>'attrs', '');

    -- Build prefix (icon = raw HTML, caller is responsible for content)
    v_prefix := CASE WHEN v_icon IS NOT NULL THEN '<span class="pgv-tree-icon">' || v_icon || '</span> ' ELSE '' END;
    v_suffix := '';
    IF v_badge IS NOT NULL THEN
      v_suffix := v_suffix || ' ' || pgv.badge(v_badge);
    END IF;
    IF v_action IS NOT NULL THEN
      IF jsonb_typeof(v_action) = 'string' THEN
        -- Raw HTML string (e.g. Alpine button)
        v_suffix := v_suffix || ' ' || (v_action #>> '{}');
      ELSE
        -- Object -> pgv.action()
        v_suffix := v_suffix || ' ' || pgv.action(
          v_action->>'rpc',
          coalesce(v_action->>'label', v_action->>'rpc'),
          CASE WHEN v_action ? 'params' THEN v_action->'params' ELSE NULL END,
          v_action->>'confirm'
        );
      END IF;
    END IF;

    v_li_open := '<li' || CASE WHEN v_attrs <> '' THEN ' ' || v_attrs ELSE '' END || '>';

    IF v_item ? 'children' THEN
      v_html := v_html || v_li_open || '<details'
        || CASE WHEN v_open THEN ' open' ELSE '' END
        || '><summary>' || v_prefix || pgv.esc(v_label) || v_suffix || '</summary>'
        || pgv.tree(v_item->'children', p_open, p_depth + 1)
        || '</details></li>';
    ELSIF v_href IS NOT NULL THEN
      v_html := v_html || v_li_open || v_prefix || '<a href="' || v_href || '">' || pgv.esc(v_label) || '</a>' || v_suffix || '</li>';
    ELSE
      v_html := v_html || v_li_open || v_prefix || pgv.esc(v_label) || v_suffix || '</li>';
    END IF;
  END LOOP;

  v_html := v_html || '</ul>';
  RETURN v_html;
END;
$function$;
