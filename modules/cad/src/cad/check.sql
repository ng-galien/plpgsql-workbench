CREATE OR REPLACE FUNCTION cad."check"(p_drawing_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_out text := '';
  v_rec record;
  v_issues int := 0;
  v_orphans int := 0;
BEGIN
  -- 1. Collisions (pièces qui se chevauchent en volume, pas juste se touchent)
  FOR v_rec IN
    SELECT a.label AS a_label, b.label AS b_label,
      round(ST_Volume(ST_3DIntersection(a.geom, b.geom))::numeric) AS overlap_vol
    FROM cad.piece a, cad.piece b
    WHERE a.drawing_id = p_drawing_id AND b.drawing_id = p_drawing_id
      AND a.id < b.id AND ST_3DIntersects(a.geom, b.geom)
  LOOP
    IF v_rec.overlap_vol > 100 THEN  -- > 100mm³ = vraie collision, pas juste un contact
      v_out := v_out || format('  COLLISION: %s & %s overlap %s mm3',
        v_rec.a_label, v_rec.b_label, v_rec.overlap_vol) || E'\n';
      v_issues := v_issues + 1;
    END IF;
  END LOOP;

  -- 2. Pièces orphelines (ne touchent aucune autre pièce)
  FOR v_rec IN
    SELECT p.id, p.label
    FROM cad.piece p
    WHERE p.drawing_id = p_drawing_id
      AND NOT EXISTS (
        SELECT 1 FROM cad.piece o
        WHERE o.drawing_id = p_drawing_id AND o.id <> p.id
          AND ST_3DIntersects(p.geom, o.geom)
      )
  LOOP
    v_out := v_out || format('  ORPHAN: %s is not connected to any piece', v_rec.label) || E'\n';
    v_orphans := v_orphans + 1;
  END LOOP;

  -- 3. Pièces sous le sol (z < 0)
  FOR v_rec IN
    SELECT label, round(ST_ZMin(geom)::numeric) AS z_min
    FROM cad.piece WHERE drawing_id = p_drawing_id AND ST_ZMin(geom) < -1
  LOOP
    v_out := v_out || format('  UNDERGROUND: %s z_min=%smm', v_rec.label, v_rec.z_min) || E'\n';
    v_issues := v_issues + 1;
  END LOOP;

  -- 4. Pièces flottantes (ne touchent pas le sol et ne sont connectées qu'à des pièces flottantes)
  -- Simplifié: pièces dont z_min > 0 et qui ne touchent aucune pièce au sol
  FOR v_rec IN
    SELECT p.id, p.label, round(ST_ZMin(p.geom)::numeric) AS z_min
    FROM cad.piece p
    WHERE p.drawing_id = p_drawing_id
      AND ST_ZMin(p.geom) > 1  -- pas au sol
      AND NOT EXISTS (
        SELECT 1 FROM cad.piece ground
        WHERE ground.drawing_id = p_drawing_id
          AND ground.id <> p.id
          AND ST_ZMin(ground.geom) < 1  -- pièce au sol
          AND ST_3DIntersects(p.geom, ground.geom)
      )
  LOOP
    v_out := v_out || format('  FLOATING: %s at z=%smm not connected to ground', v_rec.label, v_rec.z_min) || E'\n';
    v_issues := v_issues + 1;
  END LOOP;

  IF v_out = '' THEN
    RETURN format('check: OK (%s pieces, 0 issues)', (SELECT count(*) FROM cad.piece WHERE drawing_id = p_drawing_id));
  END IF;

  RETURN format('check: %s issues found', v_issues + v_orphans) || E'\n' || v_out;
END;
$function$;
