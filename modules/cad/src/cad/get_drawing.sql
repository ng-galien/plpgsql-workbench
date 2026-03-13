CREATE OR REPLACE FUNCTION cad.get_drawing(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_drawing cad.drawing;
  v_body text;
  v_shapes text;
  v_layers jsonb;
  v_form text;
BEGIN
  SELECT * INTO v_drawing FROM cad.drawing WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.error('404', pgv.t('cad.err_not_found'), format(pgv.t('cad.err_not_found_detail'), p_id));
  END IF;

  -- Navigation
  v_body := '<p>'
    || '<strong>' || pgv.t('cad.vue_2d') || '</strong>'
    || ' | <a href="' || pgv.call_ref('get_drawing_3d', jsonb_build_object('p_id', p_id)) || '">' || pgv.t('cad.vue_3d') || '</a>'
    || ' | <a href="' || pgv.call_ref('get_drawing_bom', jsonb_build_object('p_id', p_id)) || '">' || pgv.t('cad.liste_debit') || '</a>'
    || '</p>';

  -- Layout: tree + canvas
  v_body := v_body || '<div class="cad-layout">'
    || cad.fragment_tree(p_id)
    || '<div>' || pgv.svg_canvas(cad.render_svg(p_id)) || '</div>'
    || '</div>';

  -- Stats
  v_body := v_body || pgv.grid(
    pgv.stat(pgv.t('cad.stat_shapes'), (SELECT count(*)::text FROM cad.shape WHERE drawing_id = p_id)),
    pgv.stat(pgv.t('cad.stat_calques'), (SELECT count(*)::text FROM cad.layer WHERE drawing_id = p_id)),
    pgv.stat(pgv.t('cad.stat_echelle'), '1:' || v_drawing.scale::text),
    pgv.stat(pgv.t('cad.stat_taille'), v_drawing.width || ' × ' || v_drawing.height || ' ' || v_drawing.unit)
  );

  -- Liste des shapes
  SELECT string_agg(line, E'\n' ORDER BY sid) INTO v_shapes
  FROM (
    SELECT s.id AS sid,
      format('| %s | %s | %s | %s | %s |',
        s.id, s.type,
        COALESCE(s.label, '-'),
        l.name,
        pgv.action('shape_delete', pgv.t('cad.btn_suppr'),
          jsonb_build_object('shape_id', s.id, 'drawing_id', p_id),
          pgv.t('cad.confirm_delete_shape'), 'danger')
      ) AS line
    FROM cad.shape s
    JOIN cad.layer l ON l.id = s.layer_id
    WHERE s.drawing_id = p_id
  ) sub;

  IF v_shapes IS NOT NULL THEN
    v_body := v_body || '<md>' || E'\n'
      || format('| %s | %s | %s | %s | %s |',
           pgv.t('cad.col_id'), pgv.t('cad.col_type'), pgv.t('cad.col_label'),
           pgv.t('cad.col_calque'), pgv.t('cad.col_action')) || E'\n'
      || '|----|------|-------|--------|--------|' || E'\n'
      || v_shapes || E'\n'
      || '</md>';
  END IF;

  -- Options calques en jsonb pour pgv.sel
  SELECT jsonb_agg(jsonb_build_object('value', l.id::text, 'label', l.name) ORDER BY l.sort_order)
  INTO v_layers
  FROM cad.layer l WHERE l.drawing_id = p_id;

  -- Build form body
  v_form := format('<input type="hidden" name="drawing_id" value="%s">', p_id)
    || '<div class="grid">'
    || pgv.sel('layer_id', pgv.t('cad.col_calque'), COALESCE(v_layers, '[]'::jsonb))
    || pgv.sel('type', pgv.t('cad.col_type'), jsonb_build_array(
         jsonb_build_object('value', 'line', 'label', pgv.t('cad.shape_line')),
         jsonb_build_object('value', 'rect', 'label', pgv.t('cad.shape_rect')),
         jsonb_build_object('value', 'circle', 'label', pgv.t('cad.shape_circle')),
         jsonb_build_object('value', 'text', 'label', pgv.t('cad.shape_text')),
         jsonb_build_object('value', 'dimension', 'label', pgv.t('cad.shape_dimension'))
       ))
    || '</div>'
    || pgv.input('label', 'text', pgv.t('cad.field_label'))
    || pgv.accordion(
         pgv.t('cad.title_geometry'), pgv.textarea('geometry', pgv.t('cad.field_geometry'), '{"x1":0,"y1":0,"x2":100,"y2":0}'),
         pgv.t('cad.title_props'), pgv.textarea('props', pgv.t('cad.field_props'), '{}')
       );

  -- Form dialog (modal) instead of inline accordion+form
  v_body := v_body || pgv.form_dialog('dlg-add-shape',
    pgv.t('cad.title_add_shape'),
    v_form,
    'shape_add',
    pgv.t('cad.btn_ajouter'));

  RETURN v_body;
END;
$function$;
