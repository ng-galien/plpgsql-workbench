CREATE OR REPLACE FUNCTION cad_qa.get_drawing_3d(p_id integer)
 RETURNS "text/html"
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body text;
  v_pieces text;
  v_piece_count int;
BEGIN
  -- Default to first drawing when no id provided
  IF p_id IS NULL THEN
    SELECT id INTO p_id FROM cad.drawing ORDER BY name LIMIT 1;
    IF p_id IS NULL THEN
      RETURN pgv.empty('Aucun dessin', 'Lancez le seed pour créer des données.');
    END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cad.drawing WHERE id = p_id) THEN
    RETURN pgv.error('404', 'Dessin non trouvé', 'Le dessin #' || p_id || ' n''existe pas.');
  END IF;

  v_body := cad.fragment_drawing_nav(p_id, 'Vue 3D');

  SELECT count(*) INTO v_piece_count FROM cad.piece WHERE drawing_id = p_id;

  -- 3D Viewer + Tree in cad-layout
  v_body := v_body || '<section><div class="cad-layout">'
    || cad.fragment_piece_tree(p_id)
    || '<div>' || cad.fragment_viewer(p_id) || '</div>'
    || '</div></section>';

  -- Wireframe projections in tabs
  IF v_piece_count > 0 THEN
    v_body := v_body || '<section>' || pgv.tabs(
      'Face (XZ)', pgv.svg_canvas(cad.render_wireframe(p_id, 'front', 800, 500)),
      'Dessus (XY)', pgv.svg_canvas(cad.render_wireframe(p_id, 'top', 800, 500)),
      'Côté (YZ)', pgv.svg_canvas(cad.render_wireframe(p_id, 'side', 800, 500))
    ) || '</section>';
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
    v_body := v_body || '<section><h4>Pièces</h4>'
      || '<md data-page="15">' || E'\n'
      || '| # | Label | Rôle | Section | Longueur | Essence | Groupe |' || E'\n'
      || '|---|-------|------|---------|----------|---------|--------|' || E'\n'
      || v_pieces || E'\n'
      || '</md></section>';
  END IF;

  RETURN v_body;
END;
$function$;
