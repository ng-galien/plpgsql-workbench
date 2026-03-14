CREATE OR REPLACE FUNCTION document_qa.seed_carte_visite()
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_c uuid;
BEGIN
  v_c := document.canvas_create('Carte de visite', 'CUSTOM', 'paysage', 321, 208, '#ffffff', 'carte');
  PERFORM document.element_add(v_c, 'rect', 0, '{"x":0,"y":0,"width":8,"height":208,"fill":"#0984e3","name":"accent-left"}'::jsonb);
  PERFORM document.element_add(v_c, 'text', 1, '{"x":30,"y":60,"fill":"#2d3436","name":"nom","fontSize":18,"fontWeight":"bold","content":"Alexandre Boyer"}'::jsonb);
  PERFORM document.element_add(v_c, 'text', 2, '{"x":30,"y":82,"fill":"#636e72","name":"poste","fontSize":11,"fontStyle":"italic","content":"Architecte Logiciel"}'::jsonb);
  PERFORM document.element_add(v_c, 'line', 3, '{"x1":30,"y1":100,"x2":200,"y2":100,"stroke":"#dfe6e9","stroke_width":1,"name":"sep"}'::jsonb);
  PERFORM document.element_add(v_c, 'text', 4, '{"x":30,"y":125,"fill":"#636e72","name":"email","fontSize":9,"content":"alex@example.com"}'::jsonb);
  PERFORM document.element_add(v_c, 'text', 5, '{"x":30,"y":142,"fill":"#636e72","name":"phone","fontSize":9,"content":"+33 6 12 34 56 78"}'::jsonb);
  PERFORM document.element_add(v_c, 'text', 6, '{"x":30,"y":159,"fill":"#636e72","name":"web","fontSize":9,"content":"github.com/aboyer"}'::jsonb);
  RETURN v_c;
END;
$function$;
