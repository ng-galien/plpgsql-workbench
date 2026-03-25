CREATE OR REPLACE FUNCTION workbench.agent_message_view()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_object(
    'uri', 'workbench://agent_message',
    'icon', '✉',
    'label', 'workbench.entity_agent_message',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('id', 'msg_type', 'from_module', 'to_module', 'subject', 'status')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('id', 'msg_type', 'from_module', 'to_module', 'subject', 'priority', 'status', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'reply_count', 'label', 'workbench.stat_replies')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'workbench://issue_report', 'label', 'workbench.rel_linked_issue', 'filter', 'message_id={id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('id', 'msg_type', 'from_module', 'to_module', 'subject', 'body', 'priority', 'status', 'resolution', 'created_at', 'acknowledged_at', 'resolved_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'reply_count', 'label', 'workbench.stat_replies')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'workbench://issue_report', 'label', 'workbench.rel_linked_issue', 'filter', 'message_id={id}'),
          jsonb_build_object('entity', 'workbench://agent_message', 'label', 'workbench.rel_thread', 'filter', 'reply_to={id}')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object(
            'label', 'workbench.section_message_info',
            'fields', jsonb_build_array(
              jsonb_build_object('key', 'to_module', 'type', 'text', 'label', 'workbench.field_to', 'required', true),
              jsonb_build_object('key', 'msg_type', 'type', 'select', 'label', 'workbench.field_msg_type', 'required', true,
                'options', jsonb_build_array('task', 'info', 'bug_report', 'feature_request', 'question', 'breaking_change')),
              jsonb_build_object('key', 'priority', 'type', 'select', 'label', 'workbench.field_priority',
                'options', jsonb_build_array('normal', 'high')),
              jsonb_build_object('key', 'subject', 'type', 'text', 'label', 'workbench.field_subject', 'required', true),
              jsonb_build_object('key', 'body', 'type', 'textarea', 'label', 'workbench.field_body')
            )
          )
        )
      )
    ),

    'actions', jsonb_build_object(
      'acknowledge', jsonb_build_object('label', 'workbench.action_acknowledge', 'icon', '✓', 'variant', 'default'),
      'resolve',     jsonb_build_object('label', 'workbench.action_resolve', 'icon', '✔', 'variant', 'primary'),
      'delete',      jsonb_build_object('label', 'workbench.action_delete', 'icon', '🗑', 'variant', 'danger', 'confirm', 'workbench.confirm_delete_message')
    )
  );
$function$;
