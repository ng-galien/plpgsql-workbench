CREATE OR REPLACE FUNCTION workbench.issue_report_view()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_object(
    'uri', 'workbench://issue_report',
    'icon', '⚑',
    'label', 'workbench.entity_issue_report',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('id', 'issue_type', 'module', 'description', 'status')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('id', 'issue_type', 'module', 'description', 'status', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'related_message_count', 'label', 'workbench.stat_related_messages')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'workbench://agent_message', 'label', 'workbench.rel_dispatch_message', 'filter', 'id={message_id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('id', 'issue_type', 'module', 'description', 'context', 'status', 'created_at', 'message_id'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'related_message_count', 'label', 'workbench.stat_related_messages')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'workbench://agent_message', 'label', 'workbench.rel_dispatch_message', 'filter', 'id={message_id}'),
          jsonb_build_object('entity', 'workbench://agent_message', 'label', 'workbench.rel_related_messages', 'filter', 'payload.issue_id={id}')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object(
            'label', 'workbench.section_issue_info',
            'fields', jsonb_build_array(
              jsonb_build_object('key', 'issue_type', 'type', 'select', 'label', 'workbench.field_issue_type', 'required', true,
                'options', jsonb_build_array('bug', 'enhancement', 'question')),
              jsonb_build_object('key', 'module', 'type', 'text', 'label', 'workbench.field_module'),
              jsonb_build_object('key', 'description', 'type', 'textarea', 'label', 'workbench.field_description', 'required', true),
              jsonb_build_object('key', 'status', 'type', 'select', 'label', 'workbench.field_status',
                'options', jsonb_build_array('open', 'acknowledged', 'resolved', 'closed'))
            )
          )
        )
      )
    ),

    'actions', jsonb_build_object(
      'acknowledge', jsonb_build_object('label', 'workbench.action_acknowledge', 'icon', '✓', 'variant', 'default'),
      'resolve',     jsonb_build_object('label', 'workbench.action_resolve', 'icon', '✔', 'variant', 'primary'),
      'close',       jsonb_build_object('label', 'workbench.action_close', 'icon', '×', 'variant', 'muted'),
      'reopen',      jsonb_build_object('label', 'workbench.action_reopen', 'icon', '↺', 'variant', 'warning'),
      'delete',      jsonb_build_object('label', 'workbench.action_delete', 'icon', '🗑', 'variant', 'danger', 'confirm', 'workbench.confirm_delete_issue')
    )
  );
$function$;
