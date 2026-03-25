CREATE OR REPLACE FUNCTION planning.intervenant_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'planning://intervenant',
    'label', 'planning.entity_intervenant',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('nom', 'role', 'actif')
      ),

      'standard', jsonb_build_object(
        'fields', jsonb_build_array('nom', 'role', 'telephone', 'couleur'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'nb_evt_actifs', 'label', 'planning.stat_evt_actifs')
        )
      ),

      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('nom', 'role', 'telephone', 'couleur', 'actif', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'nb_evt_actifs', 'label', 'planning.stat_evt_actifs')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'planning://evenement', 'filter', 'intervenant_id={id}', 'label', 'planning.title_evenements_venir')
        )
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'planning.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'nom', 'label', 'planning.field_nom', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'role', 'label', 'planning.field_role', 'type', 'text'),
            jsonb_build_object('key', 'telephone', 'label', 'planning.field_telephone', 'type', 'tel'),
            jsonb_build_object('key', 'couleur', 'label', 'planning.field_couleur', 'type', 'text'),
            jsonb_build_object('key', 'actif', 'label', 'planning.field_actif', 'type', 'checkbox')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'deactivate', jsonb_build_object('label', 'planning.action_deactivate', 'variant', 'warning', 'confirm', 'planning.confirm_deactivate'),
      'activate', jsonb_build_object('label', 'planning.action_activate'),
      'delete', jsonb_build_object('label', 'planning.action_delete', 'variant', 'danger', 'confirm', 'planning.confirm_delete_intervenant')
    )
  );
END;
$function$;
