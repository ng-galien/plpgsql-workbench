CREATE OR REPLACE FUNCTION docs_ut.test_charte_create()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id text;
  v_c record;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.charte WHERE tenant_id = 'test';

  -- Create with all mandatory fields
  v_id := docs.charte_create(
    p_name := 'Test Provençal',
    p_description := 'Charte gîte provençal',
    p_color_bg := '#FAF6F1',
    p_color_main := '#2C3E2D',
    p_color_accent := '#C4956A',
    p_color_text := '#3D3D3D',
    p_color_text_light := '#8A8A8A',
    p_color_border := '#E8E0D8',
    p_color_extra := '{"olive":"#5C6B3C","lavande":"#9B8EC1"}'::jsonb,
    p_font_heading := 'Cormorant Garamond',
    p_font_body := 'Source Sans 3',
    p_spacing_page := '15mm',
    p_voice_personality := ARRAY['chaleureux','authentique'],
    p_voice_formality := 'semi-formel'
  );

  RETURN NEXT ok(v_id IS NOT NULL, 'charte_create returns an id');

  SELECT * INTO v_c FROM docs.charte WHERE id = v_id;
  RETURN NEXT is(v_c.name, 'Test Provençal', 'name stored');
  RETURN NEXT is(v_c.color_bg, '#FAF6F1', 'color_bg stored');
  RETURN NEXT is(v_c.color_main, '#2C3E2D', 'color_main stored');
  RETURN NEXT is(v_c.color_accent, '#C4956A', 'color_accent stored');
  RETURN NEXT is(v_c.font_heading, 'Cormorant Garamond', 'font_heading stored');
  RETURN NEXT is(v_c.color_extra->>'olive', '#5C6B3C', 'color_extra olive stored');
  RETURN NEXT is(v_c.spacing_page, '15mm', 'spacing_page stored');
  RETURN NEXT is(v_c.voice_personality[1], 'chaleureux', 'voice personality stored');

  -- Unique name per tenant
  BEGIN
    PERFORM docs.charte_create(p_name := 'Test Provençal', p_color_bg := '#fff', p_color_main := '#000',
      p_color_accent := '#f00', p_color_text := '#333', p_color_text_light := '#888', p_color_border := '#eee',
      p_font_heading := 'Inter', p_font_body := 'Inter');
    RETURN NEXT fail('duplicate name should raise');
  EXCEPTION WHEN unique_violation THEN
    RETURN NEXT pass('duplicate name raises unique_violation');
  END;

  DELETE FROM docs.charte WHERE tenant_id = 'test';
END;
$function$;
