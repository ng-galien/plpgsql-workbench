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
        'fields', jsonb_build_array('reference', 'designation', 'prix_vente', 'actif')
      ),

      'standard', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'designation', 'prix_vente', 'prix_achat', 'tva', 'unite', 'actif'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'categorie_nom', 'label', 'catalog.field_categorie'),
          jsonb_build_object('key', 'unite_label', 'label', 'catalog.field_unite')
        )
      ),

      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'designation', 'description', 'prix_vente', 'prix_achat', 'tva', 'unite', 'actif', 'created_at', 'updated_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'categorie_nom', 'label', 'catalog.field_categorie'),
          jsonb_build_object('key', 'unite_label', 'label', 'catalog.field_unite')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'quote://ligne', 'filter', 'article_id={id}', 'label', 'catalog.related_quotes'),
          jsonb_build_object('entity', 'stock://mouvement', 'filter', 'article_id={id}', 'label', 'catalog.related_stock'),
          jsonb_build_object('entity', 'purchase://ligne', 'filter', 'article_id={id}', 'label', 'catalog.related_purchases')
        )
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'catalog.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'reference', 'label', 'catalog.field_reference', 'type', 'text'),
            jsonb_build_object('key', 'designation', 'label', 'catalog.field_designation', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'description', 'label', 'catalog.field_description', 'type', 'textarea')
          )),
          jsonb_build_object('label', 'catalog.section_pricing', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'prix_vente', 'label', 'catalog.field_prix_vente', 'type', 'number'),
            jsonb_build_object('key', 'prix_achat', 'label', 'catalog.field_prix_achat', 'type', 'number'),
            jsonb_build_object('key', 'tva', 'label', 'catalog.field_tva', 'type', 'select',
              'options', jsonb_build_array(
                jsonb_build_object('label', '20%', 'value', '20.00'),
                jsonb_build_object('label', '10%', 'value', '10.00'),
                jsonb_build_object('label', '5,5%', 'value', '5.50'),
                jsonb_build_object('label', '0%', 'value', '0.00')
              ))
          )),
          jsonb_build_object('label', 'catalog.section_classification', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'categorie_id', 'label', 'catalog.field_categorie', 'type', 'combobox',
              'source', 'catalog://categorie', 'display', 'nom'),
            jsonb_build_object('key', 'unite', 'label', 'catalog.field_unite', 'type', 'select',
              'options', (SELECT COALESCE(jsonb_agg(jsonb_build_object('label', u.label, 'value', u.code) ORDER BY u.label), '[]'::jsonb) FROM catalog.unite u))
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
