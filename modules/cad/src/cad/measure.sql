CREATE OR REPLACE FUNCTION cad.measure(p_a integer, p_b integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_a cad.piece;
  v_b cad.piece;
  v_dist float;
  v_touches boolean;
BEGIN
  SELECT * INTO v_a FROM cad.piece WHERE id = p_a;
  IF NOT FOUND THEN RETURN 'error: piece #' || p_a || ' not found'; END IF;
  SELECT * INTO v_b FROM cad.piece WHERE id = p_b;
  IF NOT FOUND THEN RETURN 'error: piece #' || p_b || ' not found'; END IF;

  v_dist := ST_3DDistance(v_a.geom, v_b.geom);
  v_touches := ST_3DIntersects(v_a.geom, v_b.geom);

  RETURN coalesce(v_a.label, '#' || p_a) || ' <-> ' || coalesce(v_b.label, '#' || p_b)
    || E'\ndistance: ' || round(v_dist::numeric, 1) || ' mm'
    || E'\ntouching: ' || CASE WHEN v_touches THEN 'yes' ELSE 'no' END;
END;
$function$;
