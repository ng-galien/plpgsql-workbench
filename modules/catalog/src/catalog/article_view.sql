CREATE OR REPLACE FUNCTION catalog.article_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'catalog://article',
    'label', 'catalog.entity_article',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'name', 'sale_price', 'active')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'name', 'sale_price', 'purchase_price', 'vat_rate', 'unit', 'active'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'category_name', 'label', 'catalog.field_category'),
          jsonb_build_object('key', 'unit_label', 'label', 'catalog.field_unit')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'name', 'description', 'sale_price', 'purchase_price', 'vat_rate', 'unit', 'active', 'created_at', 'updated_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'category_name', 'label', 'catalog.field_category'),
          jsonb_build_object('key', 'unit_label', 'label', 'catalog.field_unit')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'quote://line_item', 'filter', 'article_id={id}', 'label', 'catalog.related_quotes'),
          jsonb_build_object('entity', 'stock://movement', 'filter', 'article_id={id}', 'label', 'catalog.related_stock'),
          jsonb_build_object('entity', 'purchase://order_line', 'filter', 'article_id={id}', 'label', 'catalog.related_purchases')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'catalog.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'reference', 'label', 'catalog.field_reference', 'type', 'text'),
            jsonb_build_object('key', 'name', 'label', 'catalog.field_name', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'description', 'label', 'catalog.field_description', 'type', 'textarea')
          )),
          jsonb_build_object('label', 'catalog.section_pricing', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'sale_price', 'label', 'catalog.field_sale_price', 'type', 'number'),
            jsonb_build_object('key', 'purchase_price', 'label', 'catalog.field_purchase_price', 'type', 'number'),
            jsonb_build_object('key', 'vat_rate', 'label', 'catalog.field_vat_rate', 'type', 'select',
              'options', jsonb_build_array(
                jsonb_build_object('label', '20%', 'value', '20.00'),
                jsonb_build_object('label', '10%', 'value', '10.00'),
                jsonb_build_object('label', '5,5%', 'value', '5.50'),
                jsonb_build_object('label', '0%', 'value', '0.00')
              ))
          )),
          jsonb_build_object('label', 'catalog.section_classification', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'category_id', 'label', 'catalog.field_category', 'type', 'combobox',
              'source', 'catalog://category', 'display', 'name'),
            jsonb_build_object('key', 'unit', 'label', 'catalog.field_unit', 'type', 'select',
              'options', (SELECT COALESCE(jsonb_agg(jsonb_build_object('label', u.label, 'value', u.code) ORDER BY u.label), '[]'::jsonb) FROM catalog.unit u))
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'deactivate', jsonb_build_object('label', 'catalog.action_deactivate', 'variant', 'warning', 'confirm', 'catalog.confirm_deactivate'),
      'activate', jsonb_build_object('label', 'catalog.action_activate', 'variant', 'primary'),
      'delete', jsonb_build_object('label', 'catalog.action_delete', 'variant', 'danger', 'confirm', 'catalog.confirm_delete')
    )
  );
END;
$function$;
