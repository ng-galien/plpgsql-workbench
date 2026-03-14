CREATE OR REPLACE FUNCTION document_qa.seed_showcase()
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_c uuid; v_g uuid; v_e1 uuid; v_e2 uuid;
BEGIN
  v_c := document.canvas_create('Showcase Primitives', 'A3', 'paysage', NULL, NULL, '#f1faee', 'demo');
  PERFORM document.element_add(v_c, 'rect', 0, '{"x":0,"y":0,"width":1587,"height":120,"fill":"#1d3557","name":"bandeau"}'::jsonb);
  v_e1 := document.element_add(v_c, 'text', 1, '{"x":793,"y":70,"fill":"#f1faee","name":"titre","fontSize":48,"fontWeight":"bold","textAnchor":"middle","content":"SHOWCASE PRIMITIVES"}'::jsonb);
  v_e2 := document.element_add(v_c, 'text', 2, '{"x":793,"y":100,"fill":"#a8dadc","name":"sous-titre","fontSize":18,"fontStyle":"italic","textAnchor":"middle","content":"Toutes les primitives du moteur graphique"}'::jsonb);
  v_g := document.group_create(v_c, ARRAY[v_e1, v_e2], 'header-group');
  PERFORM document.element_add(v_c, 'line', 3, '{"x1":100,"y1":150,"x2":1487,"y2":150,"stroke":"#e63946","stroke_width":3,"name":"sep-top"}'::jsonb);
  PERFORM document.element_add(v_c, 'rect', 4, '{"x":100,"y":180,"width":200,"height":120,"fill":"#e63946","name":"rect-solid"}'::jsonb);
  PERFORM document.element_add(v_c, 'rect', 5, '{"x":330,"y":180,"width":200,"height":120,"fill":"#457b9d","opacity":0.5,"name":"rect-semi-transparent"}'::jsonb);
  PERFORM document.element_add(v_c, 'rect', 6, '{"x":560,"y":180,"width":200,"height":120,"fill":"none","stroke":"#1d3557","stroke_width":2,"stroke_dasharray":"5,3","name":"rect-dashed"}'::jsonb);
  PERFORM document.element_add(v_c, 'rect', 7, '{"x":790,"y":180,"width":200,"height":120,"fill":"#a8dadc","stroke":"#1d3557","stroke_width":2,"borderRadius":15,"name":"rect-rounded"}'::jsonb);
  PERFORM document.element_add(v_c, 'circle', 8, '{"cx":1100,"cy":240,"r":60,"fill":"#e63946","name":"circle-filled"}'::jsonb);
  PERFORM document.element_add(v_c, 'circle', 9, '{"cx":1280,"cy":240,"r":50,"fill":"none","stroke":"#457b9d","stroke_width":3,"name":"circle-outline"}'::jsonb);
  PERFORM document.element_add(v_c, 'circle', 10, '{"cx":1430,"cy":240,"r":45,"fill":"#a8dadc","opacity":0.3,"stroke":"#1d3557","stroke_width":2,"name":"circle-ghost"}'::jsonb);
  PERFORM document.element_add(v_c, 'ellipse', 11, '{"cx":200,"cy":480,"rx":80,"ry":35,"fill":"#a8dadc","stroke":"#1d3557","name":"ellipse-demo"}'::jsonb);
  PERFORM document.element_add(v_c, 'line', 12, '{"x1":400,"y1":350,"x2":700,"y2":350,"stroke":"#1d3557","stroke_width":0.5,"name":"line-hairline"}'::jsonb);
  PERFORM document.element_add(v_c, 'line', 13, '{"x1":400,"y1":380,"x2":700,"y2":380,"stroke":"#e63946","stroke_width":3,"name":"line-thick"}'::jsonb);
  PERFORM document.element_add(v_c, 'line', 14, '{"x1":400,"y1":410,"x2":700,"y2":410,"stroke":"#457b9d","stroke_width":2,"stroke_dasharray":"10,5","name":"line-dashed"}'::jsonb);
  PERFORM document.element_add(v_c, 'line', 15, '{"x1":400,"y1":350,"x2":700,"y2":440,"stroke":"#a8dadc","stroke_width":1,"name":"line-diagonal"}'::jsonb);
  PERFORM document.element_add(v_c, 'text', 16, '{"x":800,"y":400,"fill":"#e63946","rotation":15,"name":"text-rot15","fontSize":24,"fontWeight":"bold","content":"Rotation +15°"}'::jsonb);
  PERFORM document.element_add(v_c, 'text', 17, '{"x":800,"y":480,"fill":"#457b9d","rotation":-10,"name":"text-rot-10","fontSize":20,"fontStyle":"italic","content":"Rotation -10°"}'::jsonb);
  PERFORM document.element_add(v_c, 'image', 18, '{"x":1050,"y":350,"width":200,"height":130,"name":"image-placeholder"}'::jsonb);
  PERFORM document.element_add(v_c, 'path', 19, '{"fill":"#e63946","stroke":"#1d3557","stroke_width":1,"name":"star","d":"M1350 380 L1365 430 L1420 430 L1375 460 L1390 510 L1350 480 L1310 510 L1325 460 L1280 430 L1335 430 Z"}'::jsonb);
  PERFORM document.element_add(v_c, 'text', 20, '{"x":100,"y":560,"fill":"#1d3557","fontSize":10,"content":"rect · circle · ellipse · line · text · image · path · group"}'::jsonb);
  PERFORM document.element_add(v_c, 'text', 21, '{"x":100,"y":580,"fill":"#457b9d","fontSize":10,"content":"opacity · rotation · stroke_dasharray · fontWeight · fontStyle · textAnchor · borderRadius"}'::jsonb);
  RETURN v_c;
END;
$function$;
