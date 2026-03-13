CREATE OR REPLACE FUNCTION cad.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_total int;
  v_nb_2d int;
  v_nb_3d int;
  v_rows_2d text[];
  v_rows_3d text[];
  r record;
BEGIN
  -- Stats
  SELECT count(*)::int INTO v_total FROM cad.drawing;

  SELECT count(*)::int INTO v_nb_2d FROM cad.drawing WHERE dimension = '2d';
  SELECT count(*)::int INTO v_nb_3d FROM cad.drawing WHERE dimension = '3d';

  v_body := pgv.grid(
    pgv.stat(pgv.t('cad.stat_total'), v_total::text),
    pgv.stat(pgv.t('cad.stat_dessins_2d'), v_nb_2d::text),
    pgv.stat(pgv.t('cad.stat_modeles_3d'), v_nb_3d::text)
  );

  -- Tab 2D
  v_rows_2d := ARRAY[]::text[];
  FOR r IN
    SELECT d.id, d.name, d.width, d.height, d.unit, d.scale,
      (SELECT count(*) FROM cad.shape s WHERE s.drawing_id = d.id) AS cnt,
      d.updated_at
    FROM cad.drawing d
    WHERE d.dimension = '2d'
    ORDER BY d.updated_at DESC
  LOOP
    v_rows_2d := v_rows_2d || ARRAY[
      format('<a href="%s">%s</a>',
        pgv.call_ref('get_drawing', jsonb_build_object('p_id', r.id)),
        pgv.esc(r.name)),
      r.width || ' × ' || r.height || ' ' || r.unit,
      '1:' || r.scale::text,
      r.cnt || ' shapes',
      to_char(r.updated_at, 'DD/MM/YYYY')
    ];
  END LOOP;

  -- Tab 3D
  v_rows_3d := ARRAY[]::text[];
  FOR r IN
    SELECT d.id, d.name,
      (SELECT count(*) FROM cad.piece p WHERE p.drawing_id = d.id) AS cnt,
      (SELECT round((sum(ST_Volume(p.geom)) / 1e9)::numeric, 4)
       FROM cad.piece p WHERE p.drawing_id = d.id) AS vol,
      d.updated_at
    FROM cad.drawing d
    WHERE d.dimension = '3d'
    ORDER BY d.updated_at DESC
  LOOP
    v_rows_3d := v_rows_3d || ARRAY[
      format('<a href="%s">%s</a>',
        pgv.call_ref('get_drawing_3d', jsonb_build_object('p_id', r.id)),
        pgv.esc(r.name)),
      r.cnt || ' ' || pgv.t('cad.stat_pieces'),
      COALESCE(r.vol::text, '0') || ' m³',
      to_char(r.updated_at, 'DD/MM/YYYY')
    ];
  END LOOP;

  -- Tabs
  v_body := v_body || pgv.tabs(
    pgv.t('cad.tab_2d'),
    CASE WHEN cardinality(v_rows_2d) = 0
      THEN pgv.empty(pgv.t('cad.empty_no_2d'))
      ELSE pgv.md_table(
        ARRAY[pgv.t('cad.col_nom'), pgv.t('cad.col_taille_dessin'), pgv.t('cad.col_echelle'), pgv.t('cad.col_elements'), pgv.t('cad.col_modifie')],
        v_rows_2d, 20)
    END,
    pgv.t('cad.tab_3d'),
    CASE WHEN cardinality(v_rows_3d) = 0
      THEN pgv.empty(pgv.t('cad.empty_no_3d'))
      ELSE pgv.md_table(
        ARRAY[pgv.t('cad.col_nom'), pgv.t('cad.col_elements'), pgv.t('cad.stat_volume'), pgv.t('cad.col_modifie')],
        v_rows_3d, 20)
    END
  );

  -- New drawing dialog
  v_body := v_body || pgv.form_dialog('dlg-new-drawing',
    pgv.t('cad.btn_nouveau_dessin'),
    pgv.input('name', 'text', pgv.t('cad.field_name'))
      || pgv.sel('dimension', pgv.t('cad.field_dimension'),
           jsonb_build_array(
             jsonb_build_object('value', '2d', 'label', pgv.t('cad.dim_2d')),
             jsonb_build_object('value', '3d', 'label', pgv.t('cad.dim_3d'))
           ), '2d'),
    'drawing_add');

  RETURN v_body;
END;
$function$;
