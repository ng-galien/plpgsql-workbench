CREATE OR REPLACE FUNCTION docs.library_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'docs://library',
    'icon', 'image',
    'label', 'docs.entity_library',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('name', 'asset_count')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('name', 'description', 'asset_count'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'asset_count', 'label', 'docs.stat_assets'),
          jsonb_build_object('key', 'document_count', 'label', 'docs.stat_linked_docs')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('name', 'description', 'asset_count', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'asset_count', 'label', 'docs.stat_assets'),
          jsonb_build_object('key', 'document_count', 'label', 'docs.stat_linked_docs')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'docs://document', 'label', 'docs.rel_documents', 'filter', 'library_id={id}')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'docs.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'name', 'type', 'text', 'label', 'docs.col_name', 'required', true),
            jsonb_build_object('key', 'description', 'type', 'textarea', 'label', 'docs.col_description')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'update', jsonb_build_object('label', 'docs.action_update', 'icon', 'edit', 'variant', 'primary'),
      'delete', jsonb_build_object('label', 'docs.action_delete', 'icon', 'trash', 'variant', 'danger', 'confirm', 'docs.confirm_delete')
    )
  );
END;
$function$;
