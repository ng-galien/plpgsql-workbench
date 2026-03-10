CREATE OR REPLACE FUNCTION cad.render_perspective(p_drawing_id integer, p_piece_ids integer[], p_mvp real[], p_width integer DEFAULT 900, p_height integer DEFAULT 700)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rec record;
  v_svg text;
  v_color text;
  v_label text;
  -- Box corners in Three.js space (8 per piece)
  v_corners float[8][3];
  v_screen float[8][2];
  v_clip_w float;
  v_cx float; v_cy float; v_cz float;
  v_sx float; v_sy float;
  v_i int; v_j int;
  v_behind boolean;
  -- 12 edges of a box: pairs of corner indices
  v_e1 int[] := ARRAY[1,2,4,3,5,6,8,7,1,2,3,4];
  v_e2 int[] := ARRAY[2,4,3,1,6,8,7,5,5,6,7,8];
  -- Depth for sorting
  v_depths float[];
  v_order int[];
  v_min_depth float; v_min_idx int;
  v_piece_ids int[];
  v_tmp int;
  v_tmpf float;
  -- Center label screen coords
  v_lcx float; v_lcy float;
  v_margin float := 20;
BEGIN
  IF array_length(p_mvp, 1) != 16 THEN
    RETURN '<svg xmlns="http://www.w3.org/2000/svg"><text fill="red" x="10" y="20">MVP matrix must have 16 elements</text></svg>';
  END IF;

  -- Collect piece IDs and their depths for back-to-front sorting
  v_piece_ids := p_piece_ids;
  v_depths := ARRAY[]::float[];
  FOR v_rec IN
    SELECT id,
      (ST_XMin(geom) + ST_XMax(geom)) / 2.0 AS mx,
      (ST_YMin(geom) + ST_YMax(geom)) / 2.0 AS my,
      (ST_ZMin(geom) + ST_ZMax(geom)) / 2.0 AS mz
    FROM cad.piece WHERE drawing_id = p_drawing_id AND id = ANY(p_piece_ids)
    ORDER BY id
  LOOP
    -- Convert center to Three.js: (mx, mz, -my)
    v_cx := v_rec.mx; v_cy := v_rec.mz; v_cz := -v_rec.my;
    -- Depth = distance to camera (z in clip space)
    v_clip_w := p_mvp[4]*v_cx + p_mvp[8]*v_cy + p_mvp[12]*v_cz + p_mvp[16];
    v_depths := v_depths || v_clip_w;
  END LOOP;

  -- Sort by depth descending (far first = painter's algorithm)
  v_order := ARRAY[]::int[];
  FOR v_i IN 1..array_length(v_piece_ids, 1) LOOP
    v_order := v_order || v_i;
  END LOOP;
  -- Bubble sort (small N)
  FOR v_i IN 1..array_length(v_order, 1)-1 LOOP
    FOR v_j IN v_i+1..array_length(v_order, 1) LOOP
      IF v_depths[v_order[v_i]] < v_depths[v_order[v_j]] THEN
        v_tmp := v_order[v_i]; v_order[v_i] := v_order[v_j]; v_order[v_j] := v_tmp;
      END IF;
    END LOOP;
  END LOOP;

  -- SVG header
  v_svg := format(
    '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s">'
    || '<rect width="100%%" height="100%%" fill="#1a1a2e"/>',
    p_width, p_height
  );

  -- Draw each piece as wireframe box
  FOR v_i IN 1..array_length(v_order, 1) LOOP
    SELECT INTO v_rec id, label, role, section, wood_type,
      ST_XMin(geom)::float AS xn, ST_YMin(geom)::float AS yn, ST_ZMin(geom)::float AS zn,
      ST_XMax(geom)::float AS xx, ST_YMax(geom)::float AS yx, ST_ZMax(geom)::float AS zx
    FROM cad.piece
    WHERE id = v_piece_ids[v_order[v_i]];

    IF NOT FOUND THEN CONTINUE; END IF;

    v_color := CASE v_rec.role
      WHEN 'poteau' THEN '#c8956c' WHEN 'traverse' THEN '#a07850'
      WHEN 'chevron' THEN '#d4a76a' WHEN 'lisse' THEN '#b8925a'
      ELSE '#c8a882'
    END;

    -- 8 corners: PostGIS (x,y,z) -> Three.js (x,z,-y)
    -- Corner 1: (xn, zn, -yn), 2: (xx, zn, -yn), 3: (xn, zn, -yx), 4: (xx, zn, -yx)
    -- Corner 5: (xn, zx, -yn), 6: (xx, zx, -yn), 7: (xn, zx, -yx), 8: (xx, zx, -yx)
    v_behind := false;
    FOR v_j IN 1..8 LOOP
      v_cx := CASE WHEN v_j IN (1,3,5,7) THEN v_rec.xn ELSE v_rec.xx END;
      v_cy := CASE WHEN v_j <= 4 THEN v_rec.zn ELSE v_rec.zx END;
      v_cz := CASE WHEN v_j IN (1,2,5,6) THEN -v_rec.yn ELSE -v_rec.yx END;

      -- MVP projection (column-major): clip = M * [x,y,z,1]
      v_clip_w := p_mvp[4]*v_cx + p_mvp[8]*v_cy + p_mvp[12]*v_cz + p_mvp[16];
      IF v_clip_w < 0.1 THEN v_behind := true; END IF;

      v_sx := (p_mvp[1]*v_cx + p_mvp[5]*v_cy + p_mvp[9]*v_cz + p_mvp[13]) / v_clip_w;
      v_sy := (p_mvp[2]*v_cx + p_mvp[6]*v_cy + p_mvp[10]*v_cz + p_mvp[14]) / v_clip_w;

      -- NDC -> screen
      v_screen[v_j][1] := (v_sx + 1.0) / 2.0 * p_width;
      v_screen[v_j][2] := (1.0 - v_sy) / 2.0 * p_height;
    END LOOP;

    IF v_behind THEN CONTINUE; END IF;

    -- Draw filled polygon (front face approximation using projected quad)
    v_svg := v_svg || format(
      '<polygon points="%s,%s %s,%s %s,%s %s,%s" fill="%s" fill-opacity="0.15" stroke="none"/>',
      round(v_screen[1][1]::numeric,1), round(v_screen[1][2]::numeric,1),
      round(v_screen[2][1]::numeric,1), round(v_screen[2][2]::numeric,1),
      round(v_screen[6][1]::numeric,1), round(v_screen[6][2]::numeric,1),
      round(v_screen[5][1]::numeric,1), round(v_screen[5][2]::numeric,1),
      v_color
    );

    -- Draw 12 edges
    FOR v_j IN 1..12 LOOP
      v_svg := v_svg || format(
        '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="1.5" stroke-opacity="0.8"/>',
        round(v_screen[v_e1[v_j]][1]::numeric, 1), round(v_screen[v_e1[v_j]][2]::numeric, 1),
        round(v_screen[v_e2[v_j]][1]::numeric, 1), round(v_screen[v_e2[v_j]][2]::numeric, 1),
        v_color
      );
    END LOOP;

    -- Label at center of 8 corners
    v_lcx := 0; v_lcy := 0;
    FOR v_j IN 1..8 LOOP
      v_lcx := v_lcx + v_screen[v_j][1]; v_lcy := v_lcy + v_screen[v_j][2];
    END LOOP;
    v_lcx := v_lcx / 8.0; v_lcy := v_lcy / 8.0;

    v_label := cad._abbrev(v_rec.label, v_rec.role);
    v_svg := v_svg || format(
      '<text x="%s" y="%s" fill="#fff" font-family="monospace" font-size="12" font-weight="bold" '
      || 'text-anchor="middle" dominant-baseline="central" '
      || 'stroke="#000" stroke-width="3" paint-order="stroke">%s</text>',
      round(v_lcx::numeric, 1), round(v_lcy::numeric, 1), v_label
    );
  END LOOP;

  -- Legend
  v_sy := 20;
  FOR v_rec IN
    SELECT role, section,
      CASE role WHEN 'poteau' THEN '#c8956c' WHEN 'traverse' THEN '#a07850'
        WHEN 'chevron' THEN '#d4a76a' WHEN 'lisse' THEN '#b8925a' ELSE '#c8a882' END AS color,
      string_agg(cad._abbrev(label, role) || '=#' || id, '  ' ORDER BY label) AS items
    FROM cad.piece WHERE id = ANY(p_piece_ids)
    GROUP BY role, section ORDER BY role, section
  LOOP
    v_svg := v_svg || format(
      '<rect x="%s" y="%s" width="10" height="10" fill="%s" fill-opacity="0.6" stroke="%s"/>',
      v_margin, v_sy - 8, v_rec.color, v_rec.color
    );
    v_svg := v_svg || format(
      '<text x="%s" y="%s" fill="#aaa" font-family="monospace" font-size="9">%s %s: %s</text>',
      v_margin + 15, v_sy, v_rec.role, v_rec.section, v_rec.items
    );
    v_sy := v_sy + 16;
  END LOOP;

  v_svg := v_svg || '</svg>';
  RETURN v_svg;
END;
$function$;
