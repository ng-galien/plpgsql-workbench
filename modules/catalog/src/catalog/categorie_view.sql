CREATE OR REPLACE FUNCTION catalog.categorie_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'catalog://categorie',
    'label', 'catalog.entity_categorie',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('nom', 'parent_nom', 'nb_articles')
      ),

      'standard', jsonb_build_object(
        'fields', jsonb_build_array('nom', 'parent_nom', 'nb_articles', 'ordre')
      ),

      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('nom', 'parent_nom', 'nb_articles', 'ordre', 'created_at'),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'catalog://article', 'filter', 'categorie_id={id}', 'label', 'catalog.col_articles')
        )
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'catalog.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'nom', 'label', 'catalog.field_nom', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'parent_id', 'label', 'catalog.field_categorie_parente', 'type', 'combobox',
              'source', 'catalog://categorie', 'display', 'nom'),
            jsonb_build_object('key', 'ordre', 'label', 'catalog.field_ordre', 'type', 'number')
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
