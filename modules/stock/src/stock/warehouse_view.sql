CREATE OR REPLACE FUNCTION stock.warehouse_view()
 RETURNS jsonb
 LANGUAGE sql
AS $function$
  SELECT jsonb_build_object(
    'uri', 'stock://warehouse',
    'icon', '🏭',
    'label', 'stock.entity_depot',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('name', 'type', 'article_count')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('name', 'type', 'address', 'active'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'article_count', 'label', 'stock.stat_nb_articles')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'stock://article', 'label', 'stock.rel_articles', 'filter', 'warehouse_id={id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('name', 'type', 'address', 'active', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'article_count', 'label', 'stock.stat_nb_articles')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'stock://article', 'label', 'stock.rel_articles', 'filter', 'warehouse_id={id}')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'stock.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'name', 'type', 'text', 'label', 'stock.field_nom', 'required', true),
            jsonb_build_object('key', 'type', 'type', 'select', 'label', 'stock.field_type', 'required', true, 'options', 'stock.depot_type_options')
          )),
          jsonb_build_object('label', 'stock.section_location', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'address', 'type', 'text', 'label', 'stock.field_adresse')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'deactivate', jsonb_build_object('label', 'stock.action_deactivate', 'icon', '▾', 'variant', 'warning', 'confirm', 'stock.confirm_deactivate'),
      'activate', jsonb_build_object('label', 'stock.action_activate', 'icon', '▴', 'variant', 'primary'),
      'inventory', jsonb_build_object('label', 'stock.action_inventory', 'icon', '☰', 'variant', 'default'),
      'delete', jsonb_build_object('label', 'stock.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'stock.confirm_delete')
    )
  );
$function$;
