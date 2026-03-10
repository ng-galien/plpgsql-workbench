CREATE OR REPLACE FUNCTION cad_ut.test_render_svg()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
  v_lid int;
  v_svg text;
BEGIN
  INSERT INTO cad.drawing (name, width, height) VALUES ('test_svg', 500, 400) RETURNING id INTO v_did;
  INSERT INTO cad.layer (drawing_id, name, color) VALUES (v_did, 'L1', '#ff0000') RETURNING id INTO v_lid;

  PERFORM cad.add_shape(v_did, v_lid, 'line', '{"x1":0,"y1":0,"x2":100,"y2":100}');
  PERFORM cad.add_shape(v_did, v_lid, 'rect', '{"x":200,"y":50,"w":80,"h":60}');
  PERFORM cad.add_shape(v_did, v_lid, 'circle', '{"cx":300,"cy":200,"r":40}');

  v_svg := cad.render_svg(v_did);

  RETURN NEXT ok(v_svg LIKE '%<svg%', 'svg tag present');
  RETURN NEXT ok(v_svg LIKE '%viewBox="%', 'viewBox present');
  RETURN NEXT ok(v_svg LIKE '%<line%', 'contains line element');
  RETURN NEXT ok(v_svg LIKE '%<rect%', 'contains rect element');
  RETURN NEXT ok(v_svg LIKE '%<circle%', 'contains circle element');
  RETURN NEXT ok(v_svg LIKE '%stroke="#ff0000"%', 'layer color applied');
END;
$function$;
