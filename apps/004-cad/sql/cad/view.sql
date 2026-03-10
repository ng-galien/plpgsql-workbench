CREATE OR REPLACE FUNCTION cad.view(p_drawing_id integer, p_axis text DEFAULT 'front'::text, p_width integer DEFAULT 80, p_height integer DEFAULT 40)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rec record;
  v_grid text[][];
  v_out text := '';
  v_xmin float; v_xmax float; v_ymin float; v_ymax float;
  v_sx float; v_sy float;  -- scale
  v_x1 int; v_y1 int; v_x2 int; v_y2 int;
  v_ch text;
  v_dx int; v_dy int; v_steps int; v_xi float; v_yi float;
  v_legend text := '';
  v_roles_seen text[] := '{}';
  v_is_thin boolean;
  v_step int;
  v_range_x float; v_range_y float;
BEGIN
  -- Init grid
  v_grid := array_fill(' '::text, ARRAY[p_height, p_width]);

  -- Bounds
  IF p_axis = 'front' THEN
    SELECT min(ST_XMin(geom)), max(ST_XMax(geom)), min(ST_ZMin(geom)), max(ST_ZMax(geom))
    INTO v_xmin, v_xmax, v_ymin, v_ymax FROM cad.piece WHERE drawing_id = p_drawing_id;
  ELSIF p_axis = 'top' THEN
    SELECT min(ST_XMin(geom)), max(ST_XMax(geom)), min(ST_YMin(geom)), max(ST_YMax(geom))
    INTO v_xmin, v_xmax, v_ymin, v_ymax FROM cad.piece WHERE drawing_id = p_drawing_id;
  ELSE
    SELECT min(ST_YMin(geom)), max(ST_YMax(geom)), min(ST_ZMin(geom)), max(ST_ZMax(geom))
    INTO v_xmin, v_xmax, v_ymin, v_ymax FROM cad.piece WHERE drawing_id = p_drawing_id;
  END IF;

  IF v_xmin IS NULL THEN RETURN 'empty model'; END IF;

  -- 5% margin
  v_range_x := greatest(v_xmax - v_xmin, 1);
  v_range_y := greatest(v_ymax - v_ymin, 1);
  v_xmin := v_xmin - v_range_x * 0.05;
  v_xmax := v_xmax + v_range_x * 0.05;
  v_ymin := v_ymin - v_range_y * 0.05;
  v_ymax := v_ymax + v_range_y * 0.05;
  v_range_x := v_xmax - v_xmin;
  v_range_y := v_ymax - v_ymin;

  v_sx := (p_width - 1) / v_range_x;
  v_sy := (p_height - 1) / v_range_y;

  -- Draw ground line at z=0 (for front/side views)
  IF p_axis IN ('front', 'side') AND v_ymin <= 0 AND v_ymax >= 0 THEN
    v_y1 := (p_height - 1) - round((0 - v_ymin) * v_sy)::int;
    IF v_y1 >= 0 AND v_y1 < p_height THEN
      FOR v_step IN 1..p_width LOOP
        IF v_grid[v_y1 + 1][v_step] = ' ' THEN
          v_grid[v_y1 + 1][v_step] := '.';
        END IF;
      END LOOP;
    END IF;
  END IF;

  -- Draw pieces: role-based characters
  -- Thick pieces = filled rect, thin pieces = line trace (Bresenham)
  FOR v_rec IN
    SELECT id, label, role, section,
      CASE p_axis WHEN 'front' THEN ST_XMin(geom) WHEN 'top' THEN ST_XMin(geom) ELSE ST_YMin(geom) END AS px1,
      CASE p_axis WHEN 'front' THEN ST_XMax(geom) WHEN 'top' THEN ST_XMax(geom) ELSE ST_YMax(geom) END AS px2,
      CASE p_axis WHEN 'front' THEN ST_ZMin(geom) WHEN 'top' THEN ST_YMin(geom) ELSE ST_ZMin(geom) END AS py1,
      CASE p_axis WHEN 'front' THEN ST_ZMax(geom) WHEN 'top' THEN ST_YMax(geom) ELSE ST_ZMax(geom) END AS py2,
      -- Centerline start/end for diagonal tracing
      CASE p_axis WHEN 'front' THEN (ST_XMin(geom)+ST_XMax(geom))/2 WHEN 'top' THEN (ST_XMin(geom)+ST_XMax(geom))/2 ELSE (ST_YMin(geom)+ST_YMax(geom))/2 END AS cx1,
      CASE p_axis WHEN 'front' THEN (ST_XMin(geom)+ST_XMax(geom))/2 WHEN 'top' THEN (ST_XMin(geom)+ST_XMax(geom))/2 ELSE (ST_YMin(geom)+ST_YMax(geom))/2 END AS cx2,
      CASE p_axis WHEN 'front' THEN ST_ZMin(geom) WHEN 'top' THEN ST_YMin(geom) ELSE ST_ZMin(geom) END AS cy1,
      CASE p_axis WHEN 'front' THEN ST_ZMax(geom) WHEN 'top' THEN ST_YMax(geom) ELSE ST_ZMax(geom) END AS cy2
    FROM cad.piece WHERE drawing_id = p_drawing_id
    ORDER BY
      -- Draw big pieces first so small ones appear on top
      (CASE p_axis WHEN 'front' THEN (ST_XMax(geom)-ST_XMin(geom))*(ST_ZMax(geom)-ST_ZMin(geom))
                   WHEN 'top' THEN (ST_XMax(geom)-ST_XMin(geom))*(ST_YMax(geom)-ST_YMin(geom))
                   ELSE (ST_YMax(geom)-ST_YMin(geom))*(ST_ZMax(geom)-ST_ZMin(geom)) END) DESC
  LOOP
    -- Role-based character
    v_ch := CASE v_rec.role
      WHEN 'poteau' THEN '|'
      WHEN 'lisse' THEN '-'
      WHEN 'traverse' THEN '='
      WHEN 'chevron' THEN '/'
      WHEN 'montant' THEN '|'
      ELSE '#'
    END;

    -- Screen coords of bbox
    v_x1 := round((v_rec.px1 - v_xmin) * v_sx)::int;
    v_x2 := round((v_rec.px2 - v_xmin) * v_sx)::int;
    v_y1 := (p_height-1) - round((v_rec.py2 - v_ymin) * v_sy)::int;
    v_y2 := (p_height-1) - round((v_rec.py1 - v_ymin) * v_sy)::int;

    -- Is this piece "thin" in projection? (diagonal beam seen from side)
    v_is_thin := (abs(v_x2 - v_x1) > 3 AND abs(v_y2 - v_y1) > 3);

    IF v_is_thin THEN
      -- Trace diagonal line (Bresenham-ish) through center
      v_dx := abs(v_x2 - v_x1);
      v_dy := abs(v_y2 - v_y1);
      v_steps := greatest(v_dx, v_dy);
      FOR v_step IN 0..v_steps LOOP
        v_xi := v_x1 + (v_x2 - v_x1) * v_step::float / greatest(v_steps, 1);
        v_yi := v_y1 + (v_y2 - v_y1) * v_step::float / greatest(v_steps, 1);
        -- Draw with 1px thickness
        IF round(v_xi)::int BETWEEN 0 AND p_width-1
           AND round(v_yi)::int BETWEEN 0 AND p_height-1 THEN
          v_grid[round(v_yi)::int + 1][round(v_xi)::int + 1] := v_ch;
        END IF;
      END LOOP;
    ELSE
      -- Fill rectangle
      v_x1 := greatest(0, least(v_x1, p_width-1));
      v_x2 := greatest(0, least(v_x2, p_width-1));
      v_y1 := greatest(0, least(v_y1, p_height-1));
      v_y2 := greatest(0, least(v_y2, p_height-1));
      FOR v_step IN v_y1..v_y2 LOOP
        FOR v_dx IN v_x1..v_x2 LOOP
          v_grid[v_step + 1][v_dx + 1] := v_ch;
        END LOOP;
      END LOOP;
    END IF;

    -- Legend: only first occurrence per role
    IF NOT v_rec.role = ANY(v_roles_seen) THEN
      v_roles_seen := v_roles_seen || v_rec.role;
      v_legend := v_legend || '  ' || v_ch || ' = ' || v_rec.role || E'\n';
    END IF;
  END LOOP;

  -- Header with scale
  v_out := CASE p_axis
    WHEN 'front' THEN format('Front (XZ)  %s x %s mm', round(v_range_x::numeric), round(v_range_y::numeric))
    WHEN 'top' THEN format('Top (XY)  %s x %s mm', round(v_range_x::numeric), round(v_range_y::numeric))
    ELSE format('Side (YZ)  %s x %s mm', round(v_range_x::numeric), round(v_range_y::numeric))
  END || E'\n';

  -- Render grid
  FOR v_step IN 1..p_height LOOP
    FOR v_dx IN 1..p_width LOOP
      v_out := v_out || v_grid[v_step][v_dx];
    END LOOP;
    v_out := v_out || E'\n';
  END LOOP;

  v_out := v_out || v_legend;
  RETURN v_out;
END;
$function$;
