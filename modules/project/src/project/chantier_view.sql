CREATE OR REPLACE FUNCTION project.chantier_view()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_object(
    'uri', 'project://chantier',
    'icon', '◎',
    'label', 'project.entity_chantier',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('numero', 'objet', 'statut')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('numero', 'objet', 'adresse', 'date_debut', 'date_fin_prevue'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'avancement', 'label', 'project.stat_avancement'),
          jsonb_build_object('key', 'heures_total', 'label', 'project.stat_heures'),
          jsonb_build_object('key', 'jalons_count', 'label', 'project.stat_jalons')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'crm://client', 'label', 'project.rel_client', 'filter', 'id={client_id}'),
          jsonb_build_object('entity', 'quote://devis', 'label', 'project.rel_devis', 'filter', 'id={devis_id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('numero', 'objet', 'adresse', 'date_debut', 'date_fin_prevue', 'date_fin_reelle', 'notes', 'created_at', 'updated_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'avancement', 'label', 'project.stat_avancement'),
          jsonb_build_object('key', 'heures_total', 'label', 'project.stat_heures'),
          jsonb_build_object('key', 'jalons_count', 'label', 'project.stat_jalons')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'crm://client', 'label', 'project.rel_client', 'filter', 'id={client_id}'),
          jsonb_build_object('entity', 'quote://devis', 'label', 'project.rel_devis', 'filter', 'id={devis_id}'),
          jsonb_build_object('entity', 'planning://evenement', 'label', 'project.rel_planning', 'filter', 'chantier_id={id}')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'project.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'client_id', 'type', 'combobox', 'label', 'project.field_client', 'required', true, 'source', 'crm://client', 'display', 'name'),
            jsonb_build_object('key', 'devis_id', 'type', 'combobox', 'label', 'project.field_devis', 'source', 'quote://devis', 'display', 'numero'),
            jsonb_build_object('key', 'objet', 'type', 'text', 'label', 'project.field_objet', 'required', true),
            jsonb_build_object('key', 'adresse', 'type', 'text', 'label', 'project.field_adresse')
          )),
          jsonb_build_object('label', 'project.section_dates', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'date_debut', 'type', 'date', 'label', 'project.field_date_debut'),
            jsonb_build_object('key', 'date_fin_prevue', 'type', 'date', 'label', 'project.field_date_fin_prevue')
          )),
          jsonb_build_object('label', 'project.section_details', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'notes', 'type', 'textarea', 'label', 'project.field_notes')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'demarrer', jsonb_build_object('label', 'project.action_demarrer', 'icon', '▶', 'variant', 'primary', 'confirm', 'project.confirm_demarrer'),
      'reception', jsonb_build_object('label', 'project.action_reception', 'icon', '✓', 'variant', 'primary', 'confirm', 'project.confirm_reception'),
      'clore', jsonb_build_object('label', 'project.action_clore', 'icon', '■', 'variant', 'primary', 'confirm', 'project.confirm_clore'),
      'edit', jsonb_build_object('label', 'project.action_edit', 'icon', '✎', 'variant', 'outline'),
      'supprimer', jsonb_build_object('label', 'project.action_supprimer', 'icon', '×', 'variant', 'danger', 'confirm', 'project.confirm_supprimer')
    )
  );
$function$;
