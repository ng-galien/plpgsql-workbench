CREATE OR REPLACE FUNCTION docs_ut.test_charter_read()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_c docs.charter; v_j jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.charter WHERE tenant_id = 'test';
  v_c := jsonb_populate_record(NULL::docs.charter, jsonb_build_object(
    'name', 'Read Test', 'color_bg', '#FAF6F1', 'color_main', '#2C3E2D', 'color_accent', '#C4956A',
    'color_text', '#3D3D3D', 'color_text_light', '#8A8A8A', 'color_border', '#E8E0D8',
    'font_heading', 'Cormorant Garamond', 'font_body', 'Source Sans 3',
    'spacing_page', '15mm', 'shadow_card', '0 1mm 4mm rgba(0,0,0,0.08)'
  ));
  v_c.color_extra := '{"olive":"#5C6B3C"}'::jsonb;
  v_j := docs.charter_create(v_c);
  v_j := docs.charter_read(v_j->>'id');
  RETURN NEXT ok(v_j->>'id' IS NOT NULL, 'charter_read by id');
  RETURN NEXT is(v_j->>'name', 'Read Test', 'name in result');
  v_j := docs.charter_read('read-test');
  RETURN NEXT ok(v_j->>'id' IS NOT NULL, 'charter_read by slug');
  RETURN NEXT is(v_j->>'color_bg', '#FAF6F1', 'color_bg');
  RETURN NEXT is(v_j->'color_extra'->>'olive', '#5C6B3C', 'color_extra olive');
  RETURN NEXT is(v_j->>'font_heading', 'Cormorant Garamond', 'font_heading');
  RETURN NEXT is(v_j->>'spacing_page', '15mm', 'spacing_page');
  RETURN NEXT ok(docs.charter_read('nonexistent') IS NULL, 'returns NULL for unknown charter');
  DELETE FROM docs.charter WHERE tenant_id = 'test';
END;
$function$;
