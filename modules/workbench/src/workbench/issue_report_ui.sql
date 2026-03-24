CREATE OR REPLACE FUNCTION workbench.issue_report_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_iss record;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading('Issues'),
        pgv.ui_table('issues', jsonb_build_array(
          pgv.ui_col('id', '#', pgv.ui_link('#{id}', '/workbench/issue_report/{id}')),
          pgv.ui_col('issue_type', 'Type', pgv.ui_badge('{issue_type}')),
          pgv.ui_col('module', 'Module'),
          pgv.ui_col('description', 'Description'),
          pgv.ui_col('status', 'Statut', pgv.ui_badge('{status}')),
          pgv.ui_col('message_subject', 'Message', pgv.ui_link('{message_subject}', '/workbench/agent_message/{message_id}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'issues', pgv.ui_datasource('workbench://issue_report', 20, true, '-id')
      )
    );
  END IF;

  -- Detail mode
  SELECT i.*, m.subject AS message_subject, m.from_module AS message_from, m.status AS message_status
  INTO v_iss
  FROM workbench.issue_report i
  LEFT JOIN workbench.agent_message m ON m.id = i.message_id
  WHERE i.id = p_slug::integer;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← Issues', '/workbench/issues'),
        pgv.ui_heading('Issue #' || v_iss.id)
      ),

      pgv.ui_heading('Informations', 3),
      pgv.ui_row(
        pgv.ui_badge(v_iss.issue_type),
        pgv.ui_badge(v_iss.status),
        pgv.ui_text(coalesce(v_iss.module, '-'))
      ),
      pgv.ui_text(v_iss.description),

      pgv.ui_heading('Message de dispatch', 3),
      CASE WHEN v_iss.message_id IS NOT NULL THEN
        pgv.ui_row(
          pgv.ui_link('#' || v_iss.message_id || ' — ' || coalesce(v_iss.message_subject, ''), '/workbench/agent_message/' || v_iss.message_id),
          pgv.ui_badge(coalesce(v_iss.message_status, ''))
        )
      ELSE
        pgv.ui_text('Aucun message lié')
      END
    )
  );
END;
$function$;
