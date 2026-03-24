CREATE OR REPLACE FUNCTION workbench.agent_message_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_msg record;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading('Messages'),
        pgv.ui_table('messages', jsonb_build_array(
          pgv.ui_col('id', '#', pgv.ui_link('#{id}', '/workbench/agent_message/{id}')),
          pgv.ui_col('from_module', 'De'),
          pgv.ui_col('to_module', 'A'),
          pgv.ui_col('msg_type', 'Type', pgv.ui_badge('{msg_type}')),
          pgv.ui_col('priority', 'Priorité', pgv.ui_badge('{priority}')),
          pgv.ui_col('subject', 'Sujet'),
          pgv.ui_col('issue_id', 'Issue', pgv.ui_link('#{issue_id}', '/workbench/issue_report/{issue_id}')),
          pgv.ui_col('status', 'Statut', pgv.ui_badge('{status}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'messages', pgv.ui_datasource('workbench://agent_message', 20, true, '-id')
      )
    );
  END IF;

  -- Detail mode
  SELECT m.*, ir.id AS issue_id, ir.issue_type, ir.status AS issue_status, ir.description AS issue_description
  INTO v_msg
  FROM workbench.agent_message m
  LEFT JOIN workbench.issue_report ir ON ir.message_id = m.id
  WHERE m.id = p_slug::integer;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← Messages', '/workbench/messages'),
        pgv.ui_heading('Message #' || v_msg.id)
      ),

      pgv.ui_heading('Informations', 3),
      pgv.ui_row(
        pgv.ui_badge(v_msg.msg_type),
        pgv.ui_badge(v_msg.status),
        pgv.ui_badge(v_msg.priority)
      ),
      pgv.ui_row(
        pgv.ui_text('De: ' || v_msg.from_module),
        pgv.ui_text('A: ' || v_msg.to_module)
      ),
      pgv.ui_text(v_msg.subject),

      pgv.ui_heading('Corps', 3),
      pgv.ui_text(coalesce(v_msg.body, '')),

      CASE WHEN v_msg.resolution IS NOT NULL THEN
        pgv.ui_column(
          pgv.ui_heading('Résolution', 3),
          pgv.ui_text(v_msg.resolution)
        )
      ELSE '{"type":"text","value":""}'::jsonb
      END,

      CASE WHEN v_msg.issue_id IS NOT NULL THEN
        pgv.ui_column(
          pgv.ui_heading('Issue liée', 3),
          pgv.ui_row(
            pgv.ui_link('#' || v_msg.issue_id || ' — ' || coalesce(v_msg.issue_description, ''), '/workbench/issue_report/' || v_msg.issue_id),
            pgv.ui_badge(coalesce(v_msg.issue_status, ''))
          )
        )
      ELSE '{"type":"text","value":""}'::jsonb
      END
    )
  );
END;
$function$;
