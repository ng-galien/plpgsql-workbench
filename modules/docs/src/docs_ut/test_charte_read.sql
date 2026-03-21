CREATE OR REPLACE FUNCTION docs_ut.test_charte_read()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_c docs.charte;
  v_r docs.charte;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.charte WHERE tenant_id = 'test';

  v_c := jsonb_populate_record(NULL::docs.charte, jsonb_build_object(
    'name', 'Read Test', 'color_bg', '#FAF6F1', 'color_main', '#2C3E2D', 'color_accent', '#C4956A',
    'color_text', '#3D3D3D', 'color_text_light', '#8A8A8A', 'color_border', '#E8E0D8',
    'font_heading', 'Cormorant Garamond', 'font_body', 'Source Sans 3',
    'spacing_page', '15mm', 'shadow_card', '0 1mm 4mm rgba(0,0,0,0.08)'
  ));
  v_c.color_extra := '{"olive":"#5C6B3C"}'::jsonb;
  v_c := docs.charte_create(v_c);

  v_r := docs.charte_read(v_c.id);

  RETURN NEXT ok(v_r.id IS NOT NULL, 'charte_read returns data');
  RETURN NEXT is(v_r.name, 'Read Test', 'name in result');
  RETURN NEXT is(v_r.color_bg, '#FAF6F1', 'color_bg');
  RETURN NEXT is(v_r.color_extra->>'olive', '#5C6B3C', 'color_extra olive');
  RETURN NEXT is(v_r.font_heading, 'Cormorant Garamond', 'font_heading');
  RETURN NEXT is(v_r.spacing_page, '15mm', 'spacing_page');

  -- Not found
  RETURN NEXT ok((docs.charte_read('nonexistent')).id IS NULL, 'returns NULL for unknown charte');

  DELETE FROM docs.charte WHERE tenant_id = 'test';
END;
$function$;
