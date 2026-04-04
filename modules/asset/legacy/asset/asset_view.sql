CREATE OR REPLACE FUNCTION asset.asset_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'asset://asset',
    'label', 'asset.entity_asset',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('title', 'mime_type', 'status')
      ),

      'standard', jsonb_build_object(
        'fields', jsonb_build_array('title', 'filename', 'mime_type', 'status', 'orientation', 'tags'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'width', 'label', 'asset.field_width'),
          jsonb_build_object('key', 'height', 'label', 'asset.field_height')
        )
      ),

      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('title', 'description', 'filename', 'path', 'mime_type',
          'status', 'orientation', 'tags', 'credit', 'season', 'usage_hint',
          'colors', 'created_at', 'classified_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'width', 'label', 'asset.field_width'),
          jsonb_build_object('key', 'height', 'label', 'asset.field_height')
        )
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'asset.section_file', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'path', 'label', 'asset.field_path', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'filename', 'label', 'asset.field_filename', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'mime_type', 'label', 'asset.field_mime', 'type', 'select',
              'options', jsonb_build_array(
                jsonb_build_object('label', 'image/jpeg', 'value', 'image/jpeg'),
                jsonb_build_object('label', 'image/png', 'value', 'image/png'),
                jsonb_build_object('label', 'image/svg+xml', 'value', 'image/svg+xml')
              ))
          )),
          jsonb_build_object('label', 'asset.section_metadata', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'title', 'label', 'asset.field_title', 'type', 'text'),
            jsonb_build_object('key', 'description', 'label', 'asset.field_description', 'type', 'textarea'),
            jsonb_build_object('key', 'credit', 'label', 'asset.field_credit', 'type', 'text'),
            jsonb_build_object('key', 'usage_hint', 'label', 'asset.field_usage_hint', 'type', 'text')
          )),
          jsonb_build_object('label', 'asset.section_classification', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'tags', 'label', 'asset.field_tags', 'type', 'text'),
            jsonb_build_object('key', 'season', 'label', 'asset.field_season', 'type', 'select',
              'options', jsonb_build_array(
                jsonb_build_object('label', 'asset.season_spring', 'value', 'spring'),
                jsonb_build_object('label', 'asset.season_summer', 'value', 'summer'),
                jsonb_build_object('label', 'asset.season_autumn', 'value', 'autumn'),
                jsonb_build_object('label', 'asset.season_winter', 'value', 'winter')
              )),
            jsonb_build_object('key', 'orientation', 'label', 'asset.field_orientation', 'type', 'select',
              'options', jsonb_build_array(
                jsonb_build_object('label', 'asset.orientation_landscape', 'value', 'landscape'),
                jsonb_build_object('label', 'asset.orientation_portrait', 'value', 'portrait'),
                jsonb_build_object('label', 'asset.orientation_square', 'value', 'square')
              ))
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'classify', jsonb_build_object('label', 'asset.action_classify', 'variant', 'primary'),
      'edit', jsonb_build_object('label', 'asset.action_edit'),
      'archive', jsonb_build_object('label', 'asset.action_archive', 'variant', 'warning', 'confirm', 'asset.confirm_archive'),
      'restore', jsonb_build_object('label', 'asset.action_restore'),
      'delete', jsonb_build_object('label', 'asset.action_delete', 'variant', 'danger', 'confirm', 'asset.confirm_delete')
    )
  );
END;
$function$;
