CREATE OR REPLACE FUNCTION cad.drawing_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'cad://drawing',
    'icon', '📐',
    'label', 'cad.entity_drawing',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('name', 'dimension', 'updated_at')
      ),

      'standard', jsonb_build_object(
        'fields', jsonb_build_array('name', 'dimension', 'width', 'height', 'unit', 'scale'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'shape_count', 'label', 'cad.stat_shapes'),
          jsonb_build_object('key', 'piece_count', 'label', 'cad.stat_pieces'),
          jsonb_build_object('key', 'layer_count', 'label', 'cad.stat_calques'),
          jsonb_build_object('key', 'group_count', 'label', 'cad.stat_groupes')
        )
      ),

      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('name', 'dimension', 'width', 'height', 'unit', 'scale', 'created_at', 'updated_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'shape_count', 'label', 'cad.stat_shapes'),
          jsonb_build_object('key', 'piece_count', 'label', 'cad.stat_pieces'),
          jsonb_build_object('key', 'layer_count', 'label', 'cad.stat_calques'),
          jsonb_build_object('key', 'group_count', 'label', 'cad.stat_groupes')
        )
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object(
            'label', 'cad.section_general',
            'fields', jsonb_build_array(
              jsonb_build_object('key', 'name', 'type', 'text', 'label', 'cad.field_name', 'required', true),
              jsonb_build_object('key', 'dimension', 'type', 'select', 'label', 'cad.field_dimension', 'required', true,
                'options', jsonb_build_array(
                  jsonb_build_object('value', '2d', 'label', 'cad.dim_2d'),
                  jsonb_build_object('value', '3d', 'label', 'cad.dim_3d')
                ))
            )
          ),
          jsonb_build_object(
            'label', 'cad.section_canvas',
            'fields', jsonb_build_array(
              jsonb_build_object('key', 'width', 'type', 'number', 'label', 'cad.field_width'),
              jsonb_build_object('key', 'height', 'type', 'number', 'label', 'cad.field_height'),
              jsonb_build_object('key', 'unit', 'type', 'select', 'label', 'cad.field_unit',
                'options', jsonb_build_array(
                  jsonb_build_object('value', 'mm', 'label', 'mm'),
                  jsonb_build_object('value', 'cm', 'label', 'cm'),
                  jsonb_build_object('value', 'm', 'label', 'm')
                )),
              jsonb_build_object('key', 'scale', 'type', 'number', 'label', 'cad.field_scale')
            )
          )
        )
      )
    ),

    'actions', jsonb_build_object(
      'delete', jsonb_build_object('label', 'cad.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'cad.confirm_delete'),
      'duplicate', jsonb_build_object('label', 'cad.action_duplicate', 'icon', '+', 'variant', 'primary'),
      'export_bom', jsonb_build_object('label', 'cad.action_export_bom', 'icon', '↓', 'variant', 'muted')
    )
  );
END;
$function$;
