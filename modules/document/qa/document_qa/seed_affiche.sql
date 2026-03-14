CREATE OR REPLACE FUNCTION document_qa.seed_affiche()
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_c uuid; v_g uuid;
BEGIN
  v_c := document.canvas_create('Affiche Concert', 'A4', 'portrait', NULL, NULL, '#1a1a2e', 'affiche');
  PERFORM document.element_add(v_c, 'rect', 0, '{"x":200,"y":450,"width":400,"height":400,"fill":"#264653","opacity":0.15,"rotation":45,"name":"deco-rect-rotated"}'::jsonb);
  PERFORM document.element_add(v_c, 'circle', 1, '{"cx":400,"cy":400,"r":300,"fill":"#264653","opacity":0.3,"name":"deco-circle"}'::jsonb);
  PERFORM document.element_add(v_c, 'rect', 2, '{"x":80,"y":280,"width":634,"height":8,"fill":"#e76f51","name":"accent-bar"}'::jsonb);
  PERFORM document.element_add(v_c, 'text', 3, '{"x":397,"y":230,"fill":"#f4a261","name":"titre","fontSize":72,"fontWeight":"bold","textAnchor":"middle","content":"JAZZ NIGHT"}'::jsonb);
  PERFORM document.element_add(v_c, 'text', 4, '{"x":397,"y":330,"fill":"#e9c46a","name":"sous-titre","fontSize":24,"fontStyle":"italic","textAnchor":"middle","content":"Live at Le Petit Journal"}'::jsonb);
  PERFORM document.element_add(v_c, 'text', 5, '{"x":397,"y":400,"fill":"#ffffff","name":"date","fontSize":18,"textAnchor":"middle","content":"SAMEDI 22 MARS 2026"}'::jsonb);
  v_g := document.element_add(v_c, 'group', 6, '{"name":"info-block"}'::jsonb);
  PERFORM document.element_add(v_c, 'text', 7, jsonb_build_object('x',397,'y',700,'fill','#a8dadc','parent_id',v_g,'name','lieu','fontSize',14,'textAnchor','middle','content','5 rue du Petit Journal — Paris 5e'));
  PERFORM document.element_add(v_c, 'text', 8, jsonb_build_object('x',397,'y',730,'fill','#a8dadc','parent_id',v_g,'name','horaire','fontSize',14,'textAnchor','middle','content','Ouverture des portes 20h — Concert 21h'));
  PERFORM document.element_add(v_c, 'text', 9, jsonb_build_object('x',397,'y',760,'fill','#f4a261','parent_id',v_g,'name','prix','fontSize',18,'fontWeight','bold','textAnchor','middle','content','Entrée 25€ — Préventes 18€'));
  PERFORM document.element_add(v_c, 'line', 10, '{"x1":150,"y1":800,"x2":644,"y2":800,"stroke":"#ffffff","stroke_width":0.5,"name":"line-bottom"}'::jsonb);
  RETURN v_c;
END;
$function$;
