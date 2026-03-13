CREATE OR REPLACE FUNCTION workbench.get_messages(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_from     text := p_params->>'p_from';
  v_to       text := p_params->>'p_to';
  v_status   text := p_params->>'p_status';
  v_type     text := p_params->>'p_type';
  v_search   text := p_params->>'p_search';
  v_total    integer;
  v_new      integer;
  v_ack      integer;
  v_resolved integer;
  v_html     text;
  v_filter   text;
  v_opt      text;
  r          record;
BEGIN
  -- Stats (global, unfiltered)
  SELECT count(*),
         count(*) FILTER (WHERE status = 'new'),
         count(*) FILTER (WHERE status = 'acknowledged'),
         count(*) FILTER (WHERE status = 'resolved')
    INTO v_total, v_new, v_ack, v_resolved
    FROM workbench.agent_message;

  v_html := pgv.grid(
    pgv.stat('Total', v_total::text),
    pgv.stat('Nouveaux', v_new::text),
    pgv.stat('En cours', v_ack::text),
    pgv.stat('Resolus', v_resolved::text)
  );

  -- Filter form content (selects)
  v_opt := '<option value="">Tous</option>';
  FOR r IN SELECT DISTINCT from_module FROM workbench.agent_message ORDER BY 1 LOOP
    v_opt := v_opt || '<option value="' || pgv.esc(r.from_module) || '"'
      || CASE WHEN r.from_module = v_from THEN ' selected' ELSE '' END
      || '>' || pgv.esc(r.from_module) || '</option>';
  END LOOP;
  v_filter := '<label>De<select name="p_from">' || v_opt || '</select></label>';

  v_opt := '<option value="">Tous</option>';
  FOR r IN SELECT DISTINCT to_module FROM workbench.agent_message ORDER BY 1 LOOP
    v_opt := v_opt || '<option value="' || pgv.esc(r.to_module) || '"'
      || CASE WHEN r.to_module = v_to THEN ' selected' ELSE '' END
      || '>' || pgv.esc(r.to_module) || '</option>';
  END LOOP;
  v_filter := v_filter || '<label>A<select name="p_to">' || v_opt || '</select></label>';

  v_filter := v_filter || '<label>Statut<select name="p_status">'
    || '<option value="">Tous</option>'
    || '<option value="new"'          || CASE WHEN v_status = 'new'          THEN ' selected' ELSE '' END || '>Nouveau</option>'
    || '<option value="acknowledged"' || CASE WHEN v_status = 'acknowledged' THEN ' selected' ELSE '' END || '>En cours</option>'
    || '<option value="resolved"'     || CASE WHEN v_status = 'resolved'     THEN ' selected' ELSE '' END || '>Resolu</option>'
    || '</select></label>';

  v_filter := v_filter || '<label>Type<select name="p_type">'
    || '<option value="">Tous</option>'
    || '<option value="task"'            || CASE WHEN v_type = 'task'            THEN ' selected' ELSE '' END || '>task</option>'
    || '<option value="info"'            || CASE WHEN v_type = 'info'            THEN ' selected' ELSE '' END || '>info</option>'
    || '<option value="bug_report"'      || CASE WHEN v_type = 'bug_report'      THEN ' selected' ELSE '' END || '>bug_report</option>'
    || '<option value="feature_request"' || CASE WHEN v_type = 'feature_request' THEN ' selected' ELSE '' END || '>feature_request</option>'
    || '<option value="question"'        || CASE WHEN v_type = 'question'        THEN ' selected' ELSE '' END || '>question</option>'
    || '<option value="breaking_change"' || CASE WHEN v_type = 'breaking_change' THEN ' selected' ELSE '' END || '>breaking_change</option>'
    || '</select></label>';

  v_filter := v_filter || pgv.input('p_search', 'search', 'Recherche', v_search);

  -- Filter form (inline)
  v_html := v_html || pgv.filter_form(v_filter);

  -- Message table (with issue cross-link)
  v_html := v_html || '<md data-page="20">' || E'\n';
  v_html := v_html || '| # | De | A | Type | Priorite | Sujet | Issue | Statut | Date |' || E'\n';
  v_html := v_html || '|---|----|----|------|----------|-------|-------|--------|------|' || E'\n';

  SELECT v_html || coalesce(string_agg(
    '| [' || m.id || '](' || pgv.call_ref('get_message', jsonb_build_object('p_id', m.id)) || ')'
    || ' | ' || m.from_module
    || ' | ' || CASE WHEN m.to_module = 'owner' THEN pgv.badge('owner', 'primary') ELSE m.to_module END
    || ' | ' || pgv.badge(m.msg_type, CASE m.msg_type
        WHEN 'task' THEN 'info'
        WHEN 'bug_report' THEN 'danger'
        WHEN 'feature_request' THEN 'warning'
        WHEN 'breaking_change' THEN 'danger'
        WHEN 'info' THEN 'muted'
        ELSE 'muted' END)
    || ' | ' || CASE WHEN m.priority = 'high' THEN pgv.badge('HIGH','danger') ELSE 'normal' END
    || ' | ' || pgv.md_esc(m.subject, 60)
    || ' | ' || CASE WHEN ir.id IS NOT NULL
                  THEN '[#' || ir.id || '](' || pgv.call_ref('get_issue', jsonb_build_object('p_id', ir.id)) || ')'
                  ELSE '-'
                END
    || ' | ' || pgv.badge(m.status, CASE m.status
        WHEN 'new' THEN 'warning'
        WHEN 'acknowledged' THEN 'info'
        WHEN 'resolved' THEN 'success'
        ELSE 'muted' END)
    || ' | ' || to_char(m.created_at, 'DD/MM HH24:MI')
    || ' |', E'\n'
    ORDER BY
      CASE WHEN m.to_module = 'owner' AND m.status <> 'resolved' THEN 0 ELSE 1 END,
      m.id DESC
  ), '') || E'\n</md>'
  INTO v_html
  FROM workbench.agent_message m
  LEFT JOIN workbench.issue_report ir ON ir.message_id = m.id
  WHERE (v_from IS NULL OR m.from_module = v_from)
    AND (v_to IS NULL OR m.to_module = v_to)
    AND (v_status IS NULL OR m.status = v_status)
    AND (v_type IS NULL OR m.msg_type = v_type)
    AND (v_search IS NULL OR m.subject ILIKE '%' || v_search || '%');

  RETURN v_html;
END;
$function$;
