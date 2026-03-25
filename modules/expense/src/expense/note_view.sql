CREATE OR REPLACE FUNCTION expense.note_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'expense://note',
    'icon', '📋',
    'label', 'expense.entity_note',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'auteur', 'statut', 'total_ttc')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'auteur', 'date_debut', 'date_fin', 'statut', 'commentaire'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'nb_lignes', 'label', 'expense.stat_nb_lignes'),
          jsonb_build_object('key', 'total_ht', 'label', 'expense.stat_total_ht'),
          jsonb_build_object('key', 'total_ttc', 'label', 'expense.stat_total_ttc')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'ledger://journal_entry', 'label', 'expense.stat_total', 'filter', 'expense_note_id={id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'auteur', 'date_debut', 'date_fin', 'statut', 'commentaire', 'created_at', 'updated_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'nb_lignes', 'label', 'expense.stat_nb_lignes'),
          jsonb_build_object('key', 'total_ht', 'label', 'expense.stat_total_ht'),
          jsonb_build_object('key', 'total_ttc', 'label', 'expense.stat_total_ttc')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'ledger://journal_entry', 'label', 'expense.stat_total', 'filter', 'expense_note_id={id}')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object(
            'label', 'expense.section_info',
            'fields', jsonb_build_array(
              jsonb_build_object('key', 'auteur', 'type', 'text', 'label', 'expense.field_auteur', 'required', true),
              jsonb_build_object('key', 'date_debut', 'type', 'date', 'label', 'expense.field_date_debut', 'required', true),
              jsonb_build_object('key', 'date_fin', 'type', 'date', 'label', 'expense.field_date_fin', 'required', true),
              jsonb_build_object('key', 'commentaire', 'type', 'textarea', 'label', 'expense.field_commentaire')
            )
          )
        )
      )
    ),

    'actions', jsonb_build_object(
      'edit',      jsonb_build_object('label', 'expense.action_edit', 'icon', '✏', 'variant', 'muted'),
      'add_ligne', jsonb_build_object('label', 'expense.action_add_ligne', 'icon', '+', 'variant', 'primary'),
      'submit',    jsonb_build_object('label', 'expense.action_submit', 'icon', '→', 'variant', 'primary', 'confirm', 'expense.confirm_soumettre'),
      'validate',  jsonb_build_object('label', 'expense.action_validate', 'icon', '✓', 'variant', 'primary', 'confirm', 'expense.confirm_valider'),
      'reject',    jsonb_build_object('label', 'expense.action_reject', 'icon', '✗', 'variant', 'danger', 'confirm', 'expense.confirm_rejeter'),
      'reimburse', jsonb_build_object('label', 'expense.action_reimburse', 'icon', '€', 'variant', 'primary', 'confirm', 'expense.confirm_rembourser'),
      'delete',    jsonb_build_object('label', 'expense.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'expense.confirm_delete')
    )
  );
END;
$function$;
