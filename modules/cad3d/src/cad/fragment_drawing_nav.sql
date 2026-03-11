CREATE OR REPLACE FUNCTION cad.fragment_drawing_nav(p_id integer, p_current text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_html text;
  v_options text := '';
  v_rec record;
  v_page_fn text;
  v_base_url text;
BEGIN
  -- Determine current view for select navigation
  v_page_fn := CASE p_current
    WHEN 'Vue 2D' THEN 'get_drawing'
    WHEN 'Vue 3D' THEN 'get_drawing_3d'
    WHEN 'Liste de débit' THEN 'get_drawing_bom'
    ELSE 'get_drawing'
  END;

  -- Schema-prefixed base URL for the dropdown
  v_base_url := pgv.call_ref(v_page_fn);

  -- Drawing selector dropdown
  FOR v_rec IN SELECT id, name FROM cad.drawing ORDER BY name LOOP
    v_options := v_options || '<option value="' || v_rec.id || '"'
      || CASE WHEN v_rec.id = p_id THEN ' selected' ELSE '' END
      || '>' || pgv.esc(v_rec.name) || '</option>';
  END LOOP;

  v_html := '<section>'
    || '<p><select @change="go(''' || v_base_url || '?p_id='' + $el.value)">'
    || v_options || '</select></p>';

  -- BOM link (only when not already on BOM page)
  IF p_current <> 'Liste de débit' THEN
    v_html := v_html || '<p><small><a href="' || pgv.call_ref('get_drawing_bom', jsonb_build_object('p_id', p_id)) || '">Liste de débit</a></small></p>';
  END IF;

  v_html := v_html || '</section>';

  RETURN v_html;
END;
$function$;
