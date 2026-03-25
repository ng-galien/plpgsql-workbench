CREATE OR REPLACE FUNCTION planning.evenement_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'planning://evenement',
    'label', 'planning.entity_evenement',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('titre', 'type', 'date_debut', 'date_fin')
      ),

      'standard', jsonb_build_object(
        'fields', jsonb_build_array('titre', 'type', 'date_debut', 'date_fin', 'heure_debut', 'heure_fin', 'lieu'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'nb_intervenants', 'label', 'planning.stat_intervenants')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'project://chantier', 'filter', 'id={chantier_id}', 'label', 'planning.rel_chantier')
        )
      ),

      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('titre', 'type', 'date_debut', 'date_fin', 'heure_debut', 'heure_fin', 'lieu', 'notes', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'nb_intervenants', 'label', 'planning.stat_intervenants')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'project://chantier', 'filter', 'id={chantier_id}', 'label', 'planning.rel_chantier'),
          jsonb_build_object('entity', 'planning://intervenant', 'filter', 'evenement_id={id}', 'label', 'planning.title_equipe_affectee')
        )
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'planning.section_general', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'titre', 'label', 'planning.field_titre', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'type', 'label', 'planning.field_type', 'type', 'select',
              'options', jsonb_build_array(
                jsonb_build_object('label', 'planning.type_chantier', 'value', 'chantier'),
                jsonb_build_object('label', 'planning.type_livraison', 'value', 'livraison'),
                jsonb_build_object('label', 'planning.type_reunion', 'value', 'reunion'),
                jsonb_build_object('label', 'planning.type_conge', 'value', 'conge'),
                jsonb_build_object('label', 'planning.type_autre', 'value', 'autre')
              ))
          )),
          jsonb_build_object('label', 'planning.section_schedule', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'date_debut', 'label', 'planning.field_date_debut', 'type', 'date', 'required', true),
            jsonb_build_object('key', 'date_fin', 'label', 'planning.field_date_fin', 'type', 'date', 'required', true),
            jsonb_build_object('key', 'heure_debut', 'label', 'planning.field_heure_debut', 'type', 'text'),
            jsonb_build_object('key', 'heure_fin', 'label', 'planning.field_heure_fin', 'type', 'text')
          )),
          jsonb_build_object('label', 'planning.section_location', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'lieu', 'label', 'planning.field_lieu', 'type', 'text'),
            jsonb_build_object('key', 'chantier_id', 'label', 'planning.field_chantier', 'type', 'combobox',
              'source', 'project://chantier', 'display', 'numero'),
            jsonb_build_object('key', 'notes', 'label', 'planning.field_notes', 'type', 'textarea')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'delete', jsonb_build_object('label', 'planning.action_delete', 'variant', 'danger', 'confirm', 'planning.confirm_delete_evenement')
    )
  );
END;
$function$;
