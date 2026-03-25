CREATE OR REPLACE FUNCTION docs.document_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'docs://document',
    'icon', 'file-text',
    'label', 'docs.entity_document',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('name', 'format', 'status', 'charter_name')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('name', 'category', 'format', 'status', 'charter_name', 'updated_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'page_count', 'label', 'docs.stat_pages')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'docs://charter', 'label', 'docs.rel_charter', 'filter', 'id={charter_id}'),
          jsonb_build_object('entity', 'docs://library', 'label', 'docs.rel_library', 'filter', 'id={library_id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('name', 'category', 'format', 'orientation', 'width', 'height',
          'status', 'bg', 'charter_name', 'design_notes', 'team_notes', 'email_to', 'ref_module', 'ref_id'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'page_count', 'label', 'docs.stat_pages')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'docs://charter', 'label', 'docs.rel_charter', 'filter', 'id={charter_id}'),
          jsonb_build_object('entity', 'docs://library', 'label', 'docs.rel_library', 'filter', 'id={library_id}')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'docs.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'name', 'type', 'text', 'label', 'docs.col_name', 'required', true),
            jsonb_build_object('key', 'category', 'type', 'select', 'label', 'docs.col_category', 'options', 'docs.category_options'),
            jsonb_build_object('key', 'charter_id', 'type', 'combobox', 'label', 'docs.col_charte', 'source', 'docs://charter', 'display', 'name'),
            jsonb_build_object('key', 'library_id', 'type', 'combobox', 'label', 'docs.rel_library', 'source', 'docs://library', 'display', 'name')
          )),
          jsonb_build_object('label', 'docs.section_canvas', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'format', 'type', 'select', 'label', 'docs.col_format', 'options', 'docs.format_options'),
            jsonb_build_object('key', 'orientation', 'type', 'select', 'label', 'docs.col_orientation', 'options', 'docs.orientation_options')
          )),
          jsonb_build_object('label', 'docs.section_email', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'email_to', 'type', 'email', 'label', 'docs.col_email_to'),
            jsonb_build_object('key', 'design_notes', 'type', 'textarea', 'label', 'docs.col_design_notes'),
            jsonb_build_object('key', 'team_notes', 'type', 'textarea', 'label', 'docs.col_team_notes')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'generate', jsonb_build_object('label', 'docs.action_generate', 'icon', 'zap', 'variant', 'primary', 'confirm', 'docs.confirm_generate'),
      'sign', jsonb_build_object('label', 'docs.action_sign', 'icon', 'check', 'variant', 'warning', 'confirm', 'docs.confirm_sign'),
      'revert', jsonb_build_object('label', 'docs.action_revert', 'icon', 'undo', 'variant', 'muted'),
      'archive', jsonb_build_object('label', 'docs.action_archive', 'icon', 'archive', 'variant', 'muted'),
      'duplicate', jsonb_build_object('label', 'docs.action_duplicate', 'icon', 'copy', 'variant', 'muted'),
      'delete', jsonb_build_object('label', 'docs.action_delete', 'icon', 'trash', 'variant', 'danger', 'confirm', 'docs.confirm_delete')
    )
  );
END;
$function$;
