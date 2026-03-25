CREATE OR REPLACE FUNCTION stock.article_view()
 RETURNS jsonb
 LANGUAGE sql
AS $function$
  SELECT jsonb_build_object(
    'uri', 'stock://article',
    'icon', '📦',
    'label', 'stock.entity_article',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'designation', 'stock_actuel', 'unite')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'designation', 'categorie', 'unite', 'fournisseur_name'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'stock_actuel', 'label', 'stock.stat_stock_total'),
          jsonb_build_object('key', 'pmp', 'label', 'stock.stat_pmp'),
          jsonb_build_object('key', 'seuil_mini', 'label', 'stock.stat_seuil_mini')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'crm://client', 'label', 'stock.rel_fournisseur', 'filter', 'id={fournisseur_id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'designation', 'categorie', 'unite', 'prix_achat', 'pmp', 'seuil_mini', 'fournisseur_name', 'notes', 'active', 'created_at', 'updated_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'stock_actuel', 'label', 'stock.stat_stock_total'),
          jsonb_build_object('key', 'pmp', 'label', 'stock.stat_pmp'),
          jsonb_build_object('key', 'seuil_mini', 'label', 'stock.stat_seuil_mini')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'crm://client', 'label', 'stock.rel_fournisseur', 'filter', 'id={fournisseur_id}'),
          jsonb_build_object('entity', 'catalog://article', 'label', 'stock.rel_catalog', 'filter', 'id={catalog_article_id}')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'stock.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'reference', 'type', 'text', 'label', 'stock.field_reference', 'required', true),
            jsonb_build_object('key', 'designation', 'type', 'text', 'label', 'stock.field_designation', 'required', true),
            jsonb_build_object('key', 'categorie', 'type', 'select', 'label', 'stock.field_categorie', 'required', true, 'options', 'stock.categorie_options'),
            jsonb_build_object('key', 'unite', 'type', 'select', 'label', 'stock.field_unite', 'required', true, 'options', 'stock.unite_options')
          )),
          jsonb_build_object('label', 'stock.section_pricing', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'prix_achat', 'type', 'number', 'label', 'stock.field_prix_achat'),
            jsonb_build_object('key', 'seuil_mini', 'type', 'number', 'label', 'stock.field_seuil_mini')
          )),
          jsonb_build_object('label', 'stock.section_links', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'fournisseur_id', 'type', 'combobox', 'label', 'stock.field_fournisseur', 'source', 'crm://client', 'display', 'name', 'filter', 'type=company;active=true'),
            jsonb_build_object('key', 'catalog_article_id', 'type', 'combobox', 'label', 'stock.field_article_catalog', 'source', 'catalog://article', 'display', 'designation'),
            jsonb_build_object('key', 'notes', 'type', 'textarea', 'label', 'stock.field_notes')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'deactivate', jsonb_build_object('label', 'stock.action_deactivate', 'icon', '▾', 'variant', 'warning', 'confirm', 'stock.confirm_deactivate'),
      'activate', jsonb_build_object('label', 'stock.action_activate', 'icon', '▴', 'variant', 'primary'),
      'delete', jsonb_build_object('label', 'stock.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'stock.confirm_delete')
    )
  );
$function$;
