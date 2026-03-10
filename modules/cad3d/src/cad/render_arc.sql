CREATE OR REPLACE FUNCTION cad.render_arc(p_g jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cx real := (p_g->>'cx')::real;
  v_cy real := (p_g->>'cy')::real;
  v_r  real := (p_g->>'r')::real;
  v_sa real := (p_g->>'start_angle')::real;
  v_ea real := (p_g->>'end_angle')::real;
  v_x1 real; v_y1 real; v_x2 real; v_y2 real;
  v_large int;
BEGIN
  v_x1 := v_cx + v_r * cos(radians(v_sa));
  v_y1 := v_cy + v_r * sin(radians(v_sa));
  v_x2 := v_cx + v_r * cos(radians(v_ea));
  v_y2 := v_cy + v_r * sin(radians(v_ea));
  v_large := CASE WHEN abs(v_ea - v_sa) > 180 THEN 1 ELSE 0 END;

  RETURN format('<path d="M %s %s A %s %s 0 %s 1 %s %s"/>',
    v_x1, v_y1, v_r, v_r, v_large, v_x2, v_y2);
END;
$function$;
