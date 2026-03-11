CREATE OR REPLACE FUNCTION cad.render_wireframe(p_drawing_id integer, p_axis text DEFAULT 'front'::text, p_width integer DEFAULT 900, p_height integer DEFAULT 700)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rec record;
  v_svg text;
  v_xmin float; v_xmax float; v_ymin float; v_ymax float;
  v_sx float; v_sy float;
  v_x1 float; v_y1 float; v_x2 float; v_y2 float;
  v_color text;
  v_range_x float; v_range_y float;
  v_label text;
  v_margin float := 60;
  v_gx float; v_gy float;
  v_tick float;
  v_axis_labels text[];
  v_grp_colors text[] := ARRAY['#6688cc','#cc8866','#66cc88','#cc66aa','#88cccc'];
  v_grp_idx int := 0;
BEGIN
  -- Bounds based on projection axis
  IF p_axis = 'front' THEN
    SELECT min(ST_XMin(geom)), max(ST_XMax(geom)), min(ST_ZMin(geom)), max(ST_ZMax(geom))
    INTO v_xmin, v_xmax, v_ymin, v_ymax FROM cad.piece WHERE drawing_id = p_drawing_id;
    v_axis_labels := ARRAY['X (mm)', 'Z (mm)', 'Front (XZ)'];
  ELSIF p_axis = 'top' THEN
    SELECT min(ST_XMin(geom)), max(ST_XMax(geom)), min(ST_YMin(geom)), max(ST_YMax(geom))
    INTO v_xmin, v_xmax, v_ymin, v_ymax FROM cad.piece WHERE drawing_id = p_drawing_id;
    v_axis_labels := ARRAY['X (mm)', 'Y (mm)', 'Top (XY)'];
  ELSE
    SELECT min(ST_YMin(geom)), max(ST_YMax(geom)), min(ST_ZMin(geom)), max(ST_ZMax(geom))
    INTO v_xmin, v_xmax, v_ymin, v_ymax FROM cad.piece WHERE drawing_id = p_drawing_id;
    v_axis_labels := ARRAY['Y (mm)', 'Z (mm)', 'Side (YZ)'];
  END IF;

  IF v_xmin IS NULL THEN
    RETURN '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="40"><rect width="100%" height="100%" fill="#1a1a2e"/><text fill="#fff" x="10" y="25" font-family="monospace">empty model</text></svg>';
  END IF;

  -- 5% padding
  v_range_x := greatest(v_xmax - v_xmin, 1);
  v_range_y := greatest(v_ymax - v_ymin, 1);
  v_xmin := v_xmin - v_range_x * 0.05;
  v_xmax := v_xmax + v_range_x * 0.05;
  v_ymin := v_ymin - v_range_y * 0.05;
  v_ymax := v_ymax + v_range_y * 0.05;
  v_range_x := v_xmax - v_xmin;
  v_range_y := v_ymax - v_ymin;

  v_sx := (p_width - 2 * v_margin) / v_range_x;
  v_sy := (p_height - 2 * v_margin) / v_range_y;

  -- SVG header
  v_svg := format(
    '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s">'
    || '<rect width="100%%" height="100%%" fill="#1a1a2e"/>',
    p_width, p_height
  );

  -- Title
  v_svg := v_svg || format(
    '<text x="%s" y="25" fill="#8888cc" font-family="monospace" font-size="14" font-weight="bold">%s  %s x %s mm</text>',
    v_margin, v_axis_labels[3], round(v_range_x::numeric), round(v_range_y::numeric)
  );

  -- Grid + axis tick labels
  FOR v_rec IN SELECT generate_series(0, 5) AS i LOOP
    v_gx := v_margin + (p_width - 2 * v_margin) * v_rec.i / 5.0;
    v_svg := v_svg || format(
      '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#2a2a44" stroke-width="0.5"/>',
      round(v_gx::numeric, 1), round(v_margin::numeric), round(v_gx::numeric, 1), round((p_height - v_margin)::numeric)
    );
    v_tick := v_xmin + v_range_x * v_rec.i / 5.0;
    v_svg := v_svg || format(
      '<text x="%s" y="%s" fill="#555" font-family="monospace" font-size="9" text-anchor="middle">%s</text>',
      round(v_gx::numeric, 1), p_height - v_margin + 14, round(v_tick::numeric)
    );

    v_gy := v_margin + (p_height - 2 * v_margin) * v_rec.i / 5.0;
    v_svg := v_svg || format(
      '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#2a2a44" stroke-width="0.5"/>',
      round(v_margin::numeric), round(v_gy::numeric, 1), round((p_width - v_margin)::numeric), round(v_gy::numeric, 1)
    );
    v_tick := v_ymax - v_range_y * v_rec.i / 5.0;
    v_svg := v_svg || format(
      '<text x="%s" y="%s" fill="#555" font-family="monospace" font-size="9" text-anchor="end">%s</text>',
      v_margin - 5, round(v_gy::numeric, 1) + 3, round(v_tick::numeric)
    );
  END LOOP;

  -- Axis names
  v_svg := v_svg || format(
    '<text x="%s" y="%s" fill="#666" font-family="monospace" font-size="10" text-anchor="middle">%s</text>',
    round((p_width / 2)::numeric), p_height - v_margin + 30, v_axis_labels[1]
  );

  -- Ground line (z=0)
  IF p_axis IN ('front', 'side') AND v_ymin <= 0 AND v_ymax >= 0 THEN
    v_gy := v_margin + (p_height - 2 * v_margin) * (1.0 - (0 - v_ymin) / v_range_y);
    v_svg := v_svg || format(
      '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#446644" stroke-width="1.5" stroke-dasharray="6,3"/>',
      round(v_margin::numeric), round(v_gy::numeric, 1), round((p_width - v_margin)::numeric), round(v_gy::numeric, 1)
    );
    v_svg := v_svg || format(
      '<text x="%s" y="%s" fill="#446644" font-family="monospace" font-size="9">sol</text>',
      p_width - v_margin + 4, round(v_gy::numeric, 1) + 3
    );
  END IF;

  -- Group bounding boxes (dashed, behind pieces)
  FOR v_rec IN
    SELECT g.id, g.label,
      CASE p_axis WHEN 'front' THEN min(ST_XMin(p.geom)) WHEN 'top' THEN min(ST_XMin(p.geom)) ELSE min(ST_YMin(p.geom)) END AS gx1,
      CASE p_axis WHEN 'front' THEN max(ST_XMax(p.geom)) WHEN 'top' THEN max(ST_XMax(p.geom)) ELSE max(ST_YMax(p.geom)) END AS gx2,
      CASE p_axis WHEN 'front' THEN min(ST_ZMin(p.geom)) WHEN 'top' THEN min(ST_YMin(p.geom)) ELSE min(ST_ZMin(p.geom)) END AS gy1,
      CASE p_axis WHEN 'front' THEN max(ST_ZMax(p.geom)) WHEN 'top' THEN max(ST_YMax(p.geom)) ELSE max(ST_ZMax(p.geom)) END AS gy2
    FROM cad.piece_group g
    JOIN cad.piece p ON p.group_id = g.id
    WHERE g.drawing_id = p_drawing_id
    GROUP BY g.id, g.label
    ORDER BY g.label
  LOOP
    v_grp_idx := v_grp_idx + 1;
    v_color := v_grp_colors[((v_grp_idx - 1) % array_length(v_grp_colors, 1)) + 1];

    v_x1 := v_margin + (v_rec.gx1 - v_xmin) * v_sx - 4;
    v_x2 := v_margin + (v_rec.gx2 - v_xmin) * v_sx + 4;
    v_y1 := v_margin + (p_height - 2 * v_margin) * (1.0 - (v_rec.gy2 - v_ymin) / v_range_y) - 4;
    v_y2 := v_margin + (p_height - 2 * v_margin) * (1.0 - (v_rec.gy1 - v_ymin) / v_range_y) + 4;

    v_svg := v_svg || format(
      '<rect x="%s" y="%s" width="%s" height="%s" fill="none" stroke="%s" stroke-width="1" stroke-dasharray="4,3" rx="3"/>',
      round(least(v_x1, v_x2)::numeric, 1), round(least(v_y1, v_y2)::numeric, 1),
      round(abs(v_x2 - v_x1)::numeric, 1), round(abs(v_y2 - v_y1)::numeric, 1),
      v_color
    );
    v_svg := v_svg || format(
      '<text x="%s" y="%s" fill="%s" font-family="monospace" font-size="9" font-style="italic">%s</text>',
      round(least(v_x1, v_x2)::numeric, 1), round(least(v_y1, v_y2)::numeric, 1) - 3,
      v_color, v_rec.label
    );
  END LOOP;

  -- Draw pieces (big first, small on top)
  FOR v_rec IN
    SELECT id, label, role, section,
      CASE p_axis WHEN 'front' THEN ST_XMin(geom) WHEN 'top' THEN ST_XMin(geom) ELSE ST_YMin(geom) END AS px1,
      CASE p_axis WHEN 'front' THEN ST_XMax(geom) WHEN 'top' THEN ST_XMax(geom) ELSE ST_YMax(geom) END AS px2,
      CASE p_axis WHEN 'front' THEN ST_ZMin(geom) WHEN 'top' THEN ST_YMin(geom) ELSE ST_ZMin(geom) END AS py1,
      CASE p_axis WHEN 'front' THEN ST_ZMax(geom) WHEN 'top' THEN ST_YMax(geom) ELSE ST_ZMax(geom) END AS py2
    FROM cad.piece WHERE drawing_id = p_drawing_id
    ORDER BY
      (CASE p_axis WHEN 'front' THEN (ST_XMax(geom)-ST_XMin(geom))*(ST_ZMax(geom)-ST_ZMin(geom))
                   WHEN 'top' THEN (ST_XMax(geom)-ST_XMin(geom))*(ST_YMax(geom)-ST_YMin(geom))
                   ELSE (ST_YMax(geom)-ST_YMin(geom))*(ST_ZMax(geom)-ST_ZMin(geom)) END) DESC
  LOOP
    v_color := CASE v_rec.role
      WHEN 'poteau' THEN '#c8956c'
      WHEN 'traverse' THEN '#a07850'
      WHEN 'chevron' THEN '#d4a76a'
      WHEN 'lisse' THEN '#b8925a'
      WHEN 'montant' THEN '#c8956c'
      ELSE '#c8a882'
    END;

    v_x1 := v_margin + (v_rec.px1 - v_xmin) * v_sx;
    v_x2 := v_margin + (v_rec.px2 - v_xmin) * v_sx;
    v_y1 := v_margin + (p_height - 2 * v_margin) * (1.0 - (v_rec.py2 - v_ymin) / v_range_y);
    v_y2 := v_margin + (p_height - 2 * v_margin) * (1.0 - (v_rec.py1 - v_ymin) / v_range_y);

    v_svg := v_svg || format(
      '<rect x="%s" y="%s" width="%s" height="%s" fill="%s" fill-opacity="0.5" stroke="%s" stroke-width="1.5" rx="1"/>',
      round(least(v_x1, v_x2)::numeric, 1), round(least(v_y1, v_y2)::numeric, 1),
      round(greatest(abs(v_x2 - v_x1), 1)::numeric, 1), round(greatest(abs(v_y2 - v_y1), 1)::numeric, 1),
      v_color, v_color
    );

    v_label := cad._abbrev(v_rec.label, v_rec.role);
    v_svg := v_svg || format(
      '<text x="%s" y="%s" fill="#fff" font-family="monospace" font-size="10" font-weight="bold" text-anchor="middle" dominant-baseline="central">%s</text>',
      round(((v_x1 + v_x2) / 2)::numeric, 1), round(((v_y1 + v_y2) / 2)::numeric, 1), v_label
    );
  END LOOP;

  -- Legend grouped by role+section
  v_gy := 20;
  FOR v_rec IN
    SELECT role, section,
      CASE role
        WHEN 'poteau' THEN '#c8956c' WHEN 'traverse' THEN '#a07850'
        WHEN 'chevron' THEN '#d4a76a' WHEN 'lisse' THEN '#b8925a'
        ELSE '#c8a882'
      END AS color,
      string_agg(cad._abbrev(label, role) || '=#' || id, '  ' ORDER BY label) AS items
    FROM cad.piece WHERE drawing_id = p_drawing_id
    GROUP BY role, section ORDER BY role, section
  LOOP
    v_svg := v_svg || format(
      '<rect x="%s" y="%s" width="10" height="10" fill="%s" fill-opacity="0.6" stroke="%s"/>',
      p_width - 260, v_margin + v_gy - 8, v_rec.color, v_rec.color
    );
    v_svg := v_svg || format(
      '<text x="%s" y="%s" fill="#aaa" font-family="monospace" font-size="9">%s %s: %s</text>',
      p_width - 245, v_margin + v_gy, v_rec.role, v_rec.section, v_rec.items
    );
    v_gy := v_gy + 16;
  END LOOP;

  v_svg := v_svg || '</svg>';
  RETURN v_svg;
END;
$function$;
