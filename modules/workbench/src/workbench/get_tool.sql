CREATE OR REPLACE FUNCTION workbench.get_tool(p_name text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_tool   record;
  v_html   text;
  v_params jsonb;
  v_key    text;
  v_prop   jsonb;
BEGIN
  SELECT * INTO v_tool FROM workbench.toolbox_tool WHERE tool_name = p_name;
  IF NOT FOUND THEN
    RETURN pgv.empty(pgv.t('workbench.label_no_tools'));
  END IF;

  v_html := pgv.breadcrumb(VARIADIC ARRAY[pgv.t('workbench.nav_tools'), pgv.call_ref('get_tools'), pgv.esc(p_name)]);

  v_html := v_html || pgv.grid(
    pgv.stat('Pack', pgv.badge(split_part(p_name, '_', 1), 'info')),
    pgv.stat('Outil', p_name)
  );

  IF v_tool.description IS NOT NULL THEN
    v_html := v_html || '<p>' || pgv.esc(v_tool.description) || '</p>';
  END IF;

  IF v_tool.input_schema IS NOT NULL AND v_tool.input_schema ? 'properties' THEN
    v_params := v_tool.input_schema -> 'properties';
    v_html := v_html || '<h4>Parametres</h4>';
    v_html := v_html || '<md>' || E'\n';
    v_html := v_html || '| Nom | Type | Requis | Description |' || E'\n';
    v_html := v_html || '|-----|------|--------|-------------|' || E'\n';

    FOR v_key, v_prop IN SELECT * FROM jsonb_each(v_params)
    LOOP
      v_html := v_html || '| `' || v_key || '`'
        || ' | ' || coalesce(v_prop ->> 'type', '-')
        || ' | ' || CASE WHEN v_tool.input_schema -> 'required' @> to_jsonb(v_key) THEN pgv.badge('oui','warning') ELSE '-' END
        || ' | ' || coalesce(v_prop ->> 'description', '-')
        || ' |' || E'\n';
    END LOOP;
    v_html := v_html || '</md>' || E'\n';
  END IF;

  v_html := v_html || '<h4>Utilisation recente</h4>';
  v_html := v_html || '<md data-page="10">' || E'\n';
  v_html := v_html || '| Module | Action | Autorise | Raison | Date |' || E'\n';
  v_html := v_html || '|--------|--------|----------|--------|------|' || E'\n';

  SELECT v_html || coalesce(string_agg(
    '| ' || h.module
    || ' | ' || h.action
    || ' | ' || CASE WHEN h.allowed THEN pgv.badge('oui','success') ELSE pgv.badge('non','error') END
    || ' | ' || coalesce(h.reason, '-')
    || ' | ' || to_char(h.created_at, 'DD/MM HH24:MI')
    || ' |', E'\n'
    ORDER BY h.created_at DESC
  ), '') || E'\n</md>'
  INTO v_html
  FROM workbench.hook_log h
  WHERE h.tool = p_name;

  RETURN v_html;
END;
$function$;
