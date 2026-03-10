CREATE OR REPLACE FUNCTION cad.bill_of_materials(p_drawing_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rec record;
  v_out text := '';
  v_total_vol float := 0;
  v_total_len float := 0;
  v_count int := 0;
BEGIN
  v_out := 'Bill of Materials — Drawing #' || p_drawing_id || E'\n';
  v_out := v_out || '========================================' || E'\n';

  FOR v_rec IN
    SELECT
      role,
      section,
      wood_type,
      count(*) AS qty,
      round(sum(length_mm)::numeric) AS total_length_mm,
      round((sum(ST_Volume(geom)) / 1e9)::numeric, 6) AS total_vol_m3
    FROM cad.piece
    WHERE drawing_id = p_drawing_id
    GROUP BY role, section, wood_type
    ORDER BY role, section
  LOOP
    v_out := v_out || v_rec.qty || 'x ' || v_rec.section || ' ' || v_rec.wood_type
      || ' [' || v_rec.role || ']'
      || '  L=' || v_rec.total_length_mm || 'mm'
      || '  V=' || v_rec.total_vol_m3 || ' m3'
      || E'\n';
    v_total_vol := v_total_vol + v_rec.total_vol_m3;
    v_total_len := v_total_len + v_rec.total_length_mm;
    v_count := v_count + v_rec.qty;
  END LOOP;

  v_out := v_out || '----------------------------------------' || E'\n';
  v_out := v_out || 'Total: ' || v_count || ' pieces'
    || '  L=' || round(v_total_len::numeric) || 'mm'
    || '  V=' || round(v_total_vol::numeric, 6) || ' m3';

  RETURN v_out;
END;
$function$;
