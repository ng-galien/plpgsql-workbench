CREATE OR REPLACE FUNCTION cad.assembly_order(p_drawing_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rec record;
  v_out text := 'Assembly Order — Drawing #' || p_drawing_id || E'\n';
  v_step int := 0;
  v_placed int[] := '{}';
  v_remaining int[];
  v_next_id int;
  v_total int;
  v_iter int := 0;
BEGIN
  SELECT array_agg(id ORDER BY id) INTO v_remaining
  FROM cad.piece WHERE drawing_id = p_drawing_id;

  IF v_remaining IS NULL THEN
    RETURN 'no pieces in drawing #' || p_drawing_id;
  END IF;

  v_total := array_length(v_remaining, 1);
  v_out := v_out || v_total || ' pieces to assemble' || E'\n';
  v_out := v_out || '========================================' || E'\n';

  WHILE array_length(v_remaining, 1) > 0 AND v_iter < 100 LOOP
    v_iter := v_iter + 1;
    v_next_id := NULL;

    IF v_step = 0 THEN
      SELECT id INTO v_next_id
      FROM cad.piece
      WHERE id = ANY(v_remaining)
      ORDER BY ST_ZMin(geom), id
      LIMIT 1;
    ELSE
      SELECT p.id INTO v_next_id
      FROM cad.piece p
      WHERE p.id = ANY(v_remaining)
      ORDER BY
        (SELECT count(*) FROM cad.piece p2
         WHERE p2.id = ANY(v_placed) AND ST_3DIntersects(p.geom, p2.geom)) DESC,
        ST_ZMin(p.geom) ASC,
        p.id ASC
      LIMIT 1;
    END IF;

    IF v_next_id IS NULL THEN EXIT; END IF;

    v_step := v_step + 1;

    SELECT * INTO v_rec FROM cad.piece WHERE id = v_next_id;
    v_out := v_out || E'\nStep ' || v_step || ': '
      || coalesce(v_rec.label, '#' || v_next_id) || ' [' || v_rec.role || '] '
      || v_rec.section || ' L=' || v_rec.length_mm || 'mm';

    IF v_step = 1 THEN
      v_out := v_out || E'\n  -> Place on ground at ['
        || round(ST_XMin(v_rec.geom)::numeric,0) || ', '
        || round(ST_YMin(v_rec.geom)::numeric,0) || ', '
        || round(ST_ZMin(v_rec.geom)::numeric,0) || ']';
    ELSE
      FOR v_rec IN
        SELECT p2.id, p2.label, p2.role
        FROM cad.piece p2
        WHERE p2.id = ANY(v_placed)
          AND ST_3DIntersects(p2.geom, (SELECT geom FROM cad.piece WHERE id = v_next_id))
        ORDER BY p2.id
      LOOP
        v_out := v_out || E'\n  -> Connect to ' || coalesce(v_rec.label, '#' || v_rec.id) || ' [' || v_rec.role || ']';
      END LOOP;
    END IF;

    v_placed := v_placed || v_next_id;
    v_remaining := array_remove(v_remaining, v_next_id);
  END LOOP;

  v_out := v_out || E'\n\n========================================';
  v_out := v_out || E'\nDone: ' || v_step || '/' || v_total || ' pieces assembled';

  RETURN v_out;
END;
$function$;
