CREATE OR REPLACE FUNCTION catalog.category_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'catalog://category',
    'label', 'catalog.entity_category',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('name', 'parent_name', 'article_count')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('name', 'parent_name', 'article_count', 'sort_order')
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('name', 'parent_name', 'article_count', 'sort_order', 'created_at'),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'catalog://article', 'filter', 'category_id={id}', 'label', 'catalog.col_articles')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'catalog.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'name', 'label', 'catalog.field_name', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'parent_id', 'label', 'catalog.field_parent_category', 'type', 'combobox',
              'source', 'catalog://category', 'display', 'name'),
            jsonb_build_object('key', 'sort_order', 'label', 'catalog.field_sort_order', 'type', 'number')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'delete', jsonb_build_object('label', 'catalog.action_delete', 'variant', 'danger', 'confirm', 'catalog.confirm_delete')
    )
  );
END;
$function$;
