CREATE OR REPLACE FUNCTION docs.charte_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'docs://charte',
    'icon', 'palette',
    'label', 'docs.entity_charte',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('name', 'color_bg', 'color_main', 'color_accent', 'font_heading')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('name', 'description', 'color_bg', 'color_main', 'color_accent',
          'color_text', 'color_text_light', 'color_border', 'font_heading', 'font_body'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'document_count', 'label', 'docs.stat_linked_docs')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('name', 'description', 'color_bg', 'color_main', 'color_accent',
          'color_text', 'color_text_light', 'color_border', 'color_extra',
          'font_heading', 'font_body',
          'spacing_page', 'spacing_section', 'spacing_gap', 'spacing_card',
          'shadow_card', 'shadow_elevated', 'radius_card',
          'voice_formality', 'voice_personality', 'voice_do', 'voice_dont',
          'rules'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'document_count', 'label', 'docs.stat_linked_docs')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'docs://document', 'label', 'docs.rel_documents', 'filter', 'charte_id={id}')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'docs.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'name', 'type', 'text', 'label', 'docs.col_name', 'required', true),
            jsonb_build_object('key', 'description', 'type', 'textarea', 'label', 'docs.col_description')
          )),
          jsonb_build_object('label', 'docs.section_palette', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'color_bg', 'type', 'text', 'label', 'docs.col_bg', 'required', true),
            jsonb_build_object('key', 'color_main', 'type', 'text', 'label', 'docs.col_main', 'required', true),
            jsonb_build_object('key', 'color_accent', 'type', 'text', 'label', 'docs.col_accent', 'required', true),
            jsonb_build_object('key', 'color_text', 'type', 'text', 'label', 'docs.col_text', 'required', true),
            jsonb_build_object('key', 'color_text_light', 'type', 'text', 'label', 'docs.col_text_light', 'required', true),
            jsonb_build_object('key', 'color_border', 'type', 'text', 'label', 'docs.col_border', 'required', true)
          )),
          jsonb_build_object('label', 'docs.section_typography', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'font_heading', 'type', 'text', 'label', 'docs.col_heading_font', 'required', true),
            jsonb_build_object('key', 'font_body', 'type', 'text', 'label', 'docs.col_body_font', 'required', true)
          )),
          jsonb_build_object('label', 'docs.section_voice', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'voice_formality', 'type', 'select', 'label', 'docs.col_formality'),
            jsonb_build_object('key', 'voice_personality', 'type', 'textarea', 'label', 'docs.col_personality')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'update', jsonb_build_object('label', 'docs.action_update', 'icon', 'edit', 'variant', 'primary'),
      'duplicate', jsonb_build_object('label', 'docs.action_duplicate', 'icon', 'copy', 'variant', 'default'),
      'delete', jsonb_build_object('label', 'docs.action_delete', 'icon', 'trash', 'variant', 'danger', 'confirm', 'docs.confirm_delete')
    )
  );
END;
$function$;
