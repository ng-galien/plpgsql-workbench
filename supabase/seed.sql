-- Seed data for Supabase local dev
-- Run automatically after supabase db reset

SELECT set_config('app.tenant_id', 'dev', false);
SELECT set_config('app.user_id', 'dev', false);

-- Canvas: Test Illustrator
SELECT document.canvas_create('Test Illustrator', 'A4', 'portrait', 210, 297, '#f9f2e8', 'test');

-- Get the canvas ID
DO $$
DECLARE
  v_cid uuid;
BEGIN
  SELECT id INTO v_cid FROM document.canvas WHERE name = 'Test Illustrator' LIMIT 1;

  -- Header rect
  PERFORM document.element_add(v_cid, 'rect', 1,
    '{"x":0,"y":0,"width":210,"height":50,"fill":"#033345","name":"header"}'::jsonb);

  -- Title text
  PERFORM document.element_add(v_cid, 'text', 2,
    '{"x":105,"y":30,"content":"MY FRENCH TOUR","fontSize":14,"fill":"#ffffff","textAnchor":"middle","fontWeight":"bold","name":"title"}'::jsonb);

  -- Subtitle
  PERFORM document.element_add(v_cid, 'text', 3,
    '{"x":105,"y":42,"content":"Oenotourisme en Bourgogne","fontSize":6,"fill":"#f9f2e8","fontStyle":"italic","textAnchor":"middle","name":"subtitle"}'::jsonb);

  -- Accent line
  PERFORM document.element_add(v_cid, 'line', 4,
    '{"x1":60,"y1":55,"x2":150,"y2":55,"stroke":"#e53150","stroke_width":2}'::jsonb);

  -- Decorative circle
  PERFORM document.element_add(v_cid, 'circle', 5,
    '{"cx":105,"cy":150,"r":40,"fill":"#e53150","opacity":0.2,"name":"deco"}'::jsonb);

  -- Body text
  PERFORM document.element_add(v_cid, 'text', 6,
    '{"x":30,"y":100,"content":"Découvrez les vignobles de la Côte de Beaune à bord de nos véhicules vintage.","fontSize":5,"fill":"#033345","maxWidth":150,"name":"body"}'::jsonb);

  -- Footer rect
  PERFORM document.element_add(v_cid, 'rect', 7,
    '{"x":0,"y":270,"width":210,"height":27,"fill":"#033345","name":"footer"}'::jsonb);

  -- Footer text
  PERFORM document.element_add(v_cid, 'text', 8,
    '{"x":105,"y":287,"content":"contact@myfrenchtour.com · +33 6 58 00 78 46","fontSize":3.5,"fill":"#ffffff","textAnchor":"middle"}'::jsonb);

  RAISE NOTICE 'Seeded canvas % with 8 elements', v_cid;
END $$;
