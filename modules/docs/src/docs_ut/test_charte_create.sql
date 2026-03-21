CREATE OR REPLACE FUNCTION docs_ut.test_charte_create()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_c docs.charte;
  v_r record;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.charte WHERE tenant_id = 'test';

  v_c := jsonb_populate_record(NULL::docs.charte, jsonb_build_object(
    'name', 'Test Provençal', 'description', 'Charte gîte provençal',
    'color_bg', '#FAF6F1', 'color_main', '#2C3E2D', 'color_accent', '#C4956A',
    'color_text', '#3D3D3D', 'color_text_light', '#8A8A8A', 'color_border', '#E8E0D8',
    'font_heading', 'Cormorant Garamond', 'font_body', 'Source Sans 3',
    'spacing_page', '15mm', 'voice_formality', 'semi-formel'
  ));
  v_c.color_extra := '{"olive":"#5C6B3C","lavande":"#9B8EC1"}'::jsonb;
  v_c.voice_personality := ARRAY['chaleureux','authentique'];
  v_c := docs.charte_create(v_c);

  RETURN NEXT ok(v_c.id IS NOT NULL, 'charte_create returns an id');
  RETURN NEXT is(v_c.slug, 'test-provencal', 'slug auto-generated from name');

  SELECT * INTO v_r FROM docs.charte WHERE id = v_c.id;
  RETURN NEXT is(v_r.name, 'Test Provençal', 'name stored');
  RETURN NEXT is(v_r.color_bg, '#FAF6F1', 'color_bg stored');
  RETURN NEXT is(v_r.color_main, '#2C3E2D', 'color_main stored');
  RETURN NEXT is(v_r.color_accent, '#C4956A', 'color_accent stored');
  RETURN NEXT is(v_r.font_heading, 'Cormorant Garamond', 'font_heading stored');
  RETURN NEXT is(v_r.color_extra->>'olive', '#5C6B3C', 'color_extra olive stored');
  RETURN NEXT is(v_r.spacing_page, '15mm', 'spacing_page stored');
  RETURN NEXT is(v_r.voice_personality[1], 'chaleureux', 'voice personality stored');

  -- Unique name per tenant
  BEGIN
    PERFORM docs.charte_create(jsonb_populate_record(NULL::docs.charte, jsonb_build_object(
      'name', 'Test Provençal', 'color_bg', '#fff', 'color_main', '#000',
      'color_accent', '#f00', 'color_text', '#333', 'color_text_light', '#888', 'color_border', '#eee',
      'font_heading', 'Inter', 'font_body', 'Inter'
    )));
    RETURN NEXT fail('duplicate name should raise');
  EXCEPTION WHEN unique_violation THEN
    RETURN NEXT pass('duplicate name raises unique_violation');
  END;

  DELETE FROM docs.charte WHERE tenant_id = 'test';
END;
$function$;
