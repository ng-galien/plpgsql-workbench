CREATE OR REPLACE FUNCTION cad.get_drawing_3d(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_drawing cad.drawing;
  v_body text;
  v_pieces text;
  v_piece_count int;
  v_group_count int;
  v_total_vol float;
  v_options text;
  v_rec record;
BEGIN
  SELECT * INTO v_drawing FROM cad.drawing WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.error('404', 'Dessin non trouvé', 'Le dessin #' || p_id || ' n''existe pas.');
  END IF;

  -- Breadcrumb: Dessins > [nom] > Vue 3D
  v_body := pgv.breadcrumb(
    'Dessins', '/cad/',
    pgv.esc(v_drawing.name), '/cad/drawing?p_id=' || p_id,
    'Vue 3D'
  );

  -- Drawing selector
  v_options := '';
  FOR v_rec IN SELECT id, name FROM cad.drawing ORDER BY name LOOP
    v_options := v_options || '<option value="' || v_rec.id || '"'
      || CASE WHEN v_rec.id = p_id THEN ' selected' ELSE '' END
      || '>' || pgv.esc(v_rec.name) || '</option>';
  END LOOP;
  v_body := v_body || '<p><select @change="go(''get_drawing_3d?p_id='' + $el.value)">'
    || v_options || '</select></p>';

  -- View tabs: 2D | 3D | BOM
  v_body := v_body || '<p>'
    || '<a href="/cad/drawing?p_id=' || p_id || '">Vue 2D</a>'
    || ' | <strong>Vue 3D</strong>'
    || ' | <a href="/cad/drawing_bom?p_id=' || p_id || '">Liste de débit</a>'
    || '</p>';

  -- Stats
  SELECT count(*), COALESCE(round((sum(ST_Volume(geom)) / 1e9)::numeric, 6), 0)
  INTO v_piece_count, v_total_vol
  FROM cad.piece WHERE drawing_id = p_id;

  SELECT count(*) INTO v_group_count
  FROM cad.piece_group WHERE drawing_id = p_id;

  v_body := v_body || pgv.grid(
    pgv.stat('Pièces', COALESCE(v_piece_count, 0)::text),
    pgv.stat('Groupes', COALESCE(v_group_count, 0)::text),
    pgv.stat('Volume', COALESCE(v_total_vol, 0) || ' m³'),
    pgv.stat('Échelle', '1:' || v_drawing.scale::text)
  );

  -- 3D Viewer + Tree in cad-layout
  v_body := v_body || '<div class="cad-layout">'
    || cad.fragment_piece_tree(p_id)
    || '<div>' || cad.fragment_viewer(p_id) || '</div>'
    || '</div>';

  -- Wireframe projections in tabs
  IF v_piece_count > 0 THEN
    v_body := v_body || pgv.tabs(
      'Face (XZ)', pgv.svg_canvas(cad.render_wireframe(p_id, 'front', 800, 500)),
      'Dessus (XY)', pgv.svg_canvas(cad.render_wireframe(p_id, 'top', 800, 500)),
      'Côté (YZ)', pgv.svg_canvas(cad.render_wireframe(p_id, 'side', 800, 500))
    );
  END IF;

  -- BOM table
  SELECT string_agg(line, E'\n' ORDER BY grp_label NULLS LAST, role, section) INTO v_pieces
  FROM (
    SELECT
      COALESCE(g.label, '') AS grp_label,
      p.role,
      p.section,
      format('| %s | %s | %s | %s | %s | %s | %s |',
        p.id,
        COALESCE(p.label, '-'),
        p.role,
        p.section,
        p.length_mm || ' mm',
        p.wood_type,
        COALESCE(g.label, '-')
      ) AS line
    FROM cad.piece p
    LEFT JOIN cad.piece_group g ON g.id = p.group_id
    WHERE p.drawing_id = p_id
  ) sub;

  IF v_pieces IS NOT NULL THEN
    v_body := v_body || '<h4>Pièces</h4>'
      || '<md data-page="15">' || E'\n'
      || '| # | Label | Rôle | Section | Longueur | Essence | Groupe |' || E'\n'
      || '|---|-------|------|---------|----------|---------|--------|' || E'\n'
      || v_pieces || E'\n'
      || '</md>';
  END IF;

  RETURN v_body;
END;
$function$;
