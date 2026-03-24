CREATE OR REPLACE FUNCTION cad.drawing_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_d cad.drawing;
  v_shapes int;
  v_pieces int;
  v_layers int;
  v_groups int;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('cad.nav_dessins')),
        pgv.ui_table('drawings', jsonb_build_array(
          pgv.ui_col('name', pgv.t('cad.col_nom'), pgv.ui_link('{name}', '/cad/drawing/{id}')),
          pgv.ui_col('dimension', 'Type', pgv.ui_badge('{dimension}')),
          pgv.ui_col('shape_count', pgv.t('cad.stat_shapes')),
          pgv.ui_col('piece_count', pgv.t('cad.stat_pieces')),
          pgv.ui_col('layer_count', pgv.t('cad.stat_calques')),
          pgv.ui_col('updated_at', pgv.t('cad.col_modifie'))
        ))
      ),
      'datasources', jsonb_build_object(
        'drawings', pgv.ui_datasource('cad://drawing', 20, true, 'name')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_d FROM cad.drawing
  WHERE id = p_slug::int AND tenant_id = current_setting('app.tenant_id', true);

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  SELECT count(*)::int INTO v_shapes FROM cad.shape WHERE drawing_id = v_d.id;
  SELECT count(*)::int INTO v_pieces FROM cad.piece WHERE drawing_id = v_d.id;
  SELECT count(*)::int INTO v_layers FROM cad.layer WHERE drawing_id = v_d.id;
  SELECT count(*)::int INTO v_groups FROM cad.piece_group WHERE drawing_id = v_d.id;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      -- Header
      pgv.ui_row(
        pgv.ui_link('← ' || pgv.t('cad.nav_dessins'), '/cad'),
        pgv.ui_heading(v_d.name)
      ),
      pgv.ui_row(
        pgv.ui_badge(v_d.dimension),
        pgv.ui_text(v_d.width || ' × ' || v_d.height || ' ' || v_d.unit),
        pgv.ui_text(pgv.t('cad.stat_echelle') || ': 1:' || v_d.scale::text)
      ),

      -- Stats
      pgv.ui_heading(pgv.t('cad.col_elements'), 3),
      pgv.ui_row(
        pgv.ui_text(pgv.t('cad.stat_shapes') || ': ' || v_shapes),
        pgv.ui_text(pgv.t('cad.stat_pieces') || ': ' || v_pieces),
        pgv.ui_text(pgv.t('cad.stat_calques') || ': ' || v_layers),
        pgv.ui_text(pgv.t('cad.stat_groupes') || ': ' || v_groups)
      ),

      -- Timestamps
      pgv.ui_heading('Info', 3),
      pgv.ui_row(
        pgv.ui_text('Créé: ' || to_char(v_d.created_at, 'DD/MM/YYYY HH24:MI')),
        pgv.ui_text(pgv.t('cad.col_modifie') || ': ' || to_char(v_d.updated_at, 'DD/MM/YYYY HH24:MI'))
      )
    )
  );
END;
$function$;
