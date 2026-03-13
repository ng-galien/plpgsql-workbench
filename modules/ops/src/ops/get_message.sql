CREATE OR REPLACE FUNCTION ops.get_message(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_msg record;
  v_type_variant text;
  v_status_variant text;
  v_reply record;
  v_reply_rows text[];
  v_issue record;
BEGIN
  SELECT * INTO v_msg FROM workbench.agent_message WHERE id = p_id;

  IF v_msg IS NULL THEN
    RETURN pgv.empty('Message #' || p_id::text || ' introuvable');
  END IF;

  v_type_variant := CASE v_msg.msg_type
    WHEN 'feature_request' THEN 'info'
    WHEN 'bug_report' THEN 'danger'
    WHEN 'issue_report' THEN 'danger'
    WHEN 'question' THEN 'warning'
    WHEN 'task' THEN 'success'
    ELSE 'default'
  END;
  v_status_variant := CASE v_msg.status
    WHEN 'new' THEN 'danger'
    WHEN 'acknowledged' THEN 'warning'
    WHEN 'resolved' THEN 'success'
    ELSE 'default'
  END;

  -- Breadcrumb
  v_body := pgv.breadcrumb(VARIADIC ARRAY['Messages', '/ops/messages', '#' || p_id::text]);

  -- Header stats
  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.stat('De', v_msg.from_module),
    pgv.stat('A', v_msg.to_module),
    pgv.stat('Type', v_msg.msg_type),
    pgv.stat('Status', v_msg.status)
  ]);

  -- Subject + badges
  v_body := v_body || '<h3>' || pgv.esc(v_msg.subject) || ' '
    || pgv.badge(v_msg.msg_type, v_type_variant) || ' '
    || pgv.badge(v_msg.status, v_status_variant);

  IF v_msg.priority <> 'normal' THEN
    v_body := v_body || ' ' || pgv.badge(v_msg.priority, 'danger');
  END IF;

  v_body := v_body || '</h3>';

  -- Linked issue (when payload has issue_id)
  IF v_msg.payload IS NOT NULL AND (v_msg.payload->>'issue_id') IS NOT NULL THEN
    SELECT * INTO v_issue
      FROM workbench.issue_report
     WHERE id = (v_msg.payload->>'issue_id')::int;

    IF v_issue IS NOT NULL THEN
      v_body := v_body || pgv.card(
        'Issue #' || v_issue.id::text || ' ' || pgv.badge(v_issue.issue_type,
          CASE v_issue.issue_type WHEN 'bug' THEN 'danger' WHEN 'enhancement' THEN 'info' ELSE 'default' END)
        || ' ' || pgv.badge(v_issue.status,
          CASE v_issue.status WHEN 'open' THEN 'danger' WHEN 'closed' THEN 'success' ELSE 'warning' END),
        '<p>' || pgv.esc(v_issue.description) || '</p>'
          || CASE WHEN v_issue.context IS NOT NULL THEN
               '<details><summary>Contexte</summary><pre>' || pgv.esc(jsonb_pretty(v_issue.context)) || '</pre></details>'
             ELSE '' END,
        COALESCE(v_issue.module, 'global') || ' · ' || to_char(v_issue.created_at, 'DD/MM/YYYY HH24:MI')
      );
    END IF;
  ELSE
    -- Body (only when no linked issue)
    IF v_msg.body IS NOT NULL THEN
      v_body := v_body || pgv.card('Contenu', '<pre>' || pgv.esc(v_msg.body) || '</pre>', NULL);
    END IF;

    -- Payload (only when no linked issue)
    IF v_msg.payload IS NOT NULL THEN
      v_body := v_body || pgv.card('Payload', '<pre>' || pgv.esc(jsonb_pretty(v_msg.payload)) || '</pre>', NULL);
    END IF;
  END IF;

  -- Resolution
  IF v_msg.status = 'resolved' THEN
    v_body := v_body || pgv.card(
      'Resolution ' || pgv.badge('resolved', 'success'),
      '<pre>' || pgv.esc(COALESCE(v_msg.resolution, '-')) || '</pre>'
        || CASE WHEN v_msg.result IS NOT NULL
             THEN '<h4>Result</h4><pre>' || pgv.esc(jsonb_pretty(v_msg.result)) || '</pre>'
             ELSE ''
           END,
      CASE WHEN v_msg.resolved_at IS NOT NULL
        THEN 'Resolu le ' || to_char(v_msg.resolved_at, 'DD/MM/YYYY HH24:MI')
        ELSE NULL
      END
    );
  END IF;

  -- Reply chain (messages that reply to this one)
  v_reply_rows := ARRAY[]::text[];
  FOR v_reply IN
    SELECT m.id, m.from_module, m.to_module, m.msg_type, m.subject, m.status,
           to_char(m.created_at, 'DD/MM HH24:MI') AS dt
      FROM workbench.agent_message m
     WHERE m.reply_to = p_id
     ORDER BY m.created_at
  LOOP
    v_reply_rows := v_reply_rows || ARRAY[
      '<a href="' || pgv.call_ref('get_message', jsonb_build_object('p_id', v_reply.id)) || '">#' || v_reply.id::text || '</a>',
      pgv.badge(v_reply.from_module, 'default'),
      pgv.esc(v_reply.subject),
      pgv.badge(v_reply.status, CASE v_reply.status WHEN 'resolved' THEN 'success' WHEN 'new' THEN 'danger' ELSE 'warning' END),
      v_reply.dt
    ];
  END LOOP;

  IF array_length(v_reply_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h4>Reponses</h4>'
      || pgv.md_table(ARRAY['#', 'De', 'Sujet', 'Status', 'Date'], v_reply_rows);
  END IF;

  -- Parent link
  IF v_msg.reply_to IS NOT NULL THEN
    v_body := v_body || '<p>En reponse a <a href="'
      || pgv.call_ref('get_message', jsonb_build_object('p_id', v_msg.reply_to))
      || '">#' || v_msg.reply_to::text || '</a></p>';
  END IF;

  -- Timestamps
  v_body := v_body || '<p class="ops-timestamps">'
    || 'Cree: ' || to_char(v_msg.created_at, 'DD/MM/YYYY HH24:MI')
    || CASE WHEN v_msg.acknowledged_at IS NOT NULL
         THEN ' · Ack: ' || to_char(v_msg.acknowledged_at, 'DD/MM/YYYY HH24:MI')
         ELSE ''
       END
    || CASE WHEN v_msg.resolved_at IS NOT NULL
         THEN ' · Resolu: ' || to_char(v_msg.resolved_at, 'DD/MM/YYYY HH24:MI')
         ELSE ''
       END
    || '</p>';

  RETURN v_body;
END;
$function$;
