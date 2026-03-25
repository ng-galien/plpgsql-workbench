CREATE OR REPLACE FUNCTION stock.depot_view()
 RETURNS jsonb
 LANGUAGE sql
AS $function$
  SELECT jsonb_build_object(
    'uri', 'stock://depot',
    'icon', '🏭',
    'label', 'stock.entity_depot',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('nom', 'type', 'nb_articles')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('nom', 'type', 'adresse', 'actif'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'nb_articles', 'label', 'stock.stat_nb_articles')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'stock://article', 'label', 'stock.rel_articles', 'filter', 'depot_id={id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('nom', 'type', 'adresse', 'actif', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'nb_articles', 'label', 'stock.stat_nb_articles')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'stock://article', 'label', 'stock.rel_articles', 'filter', 'depot_id={id}')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'stock.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'nom', 'type', 'text', 'label', 'stock.field_nom', 'required', true),
            jsonb_build_object('key', 'type', 'type', 'select', 'label', 'stock.field_type', 'required', true, 'options', 'stock.depot_type_options')
          )),
          jsonb_build_object('label', 'stock.section_location', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'adresse', 'type', 'text', 'label', 'stock.field_adresse')
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
