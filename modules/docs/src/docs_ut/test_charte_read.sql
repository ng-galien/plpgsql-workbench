CREATE OR REPLACE FUNCTION docs_ut.test_charte_read()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id text;
  v_result jsonb;
  v_css text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.charte WHERE tenant_id = 'test';

  v_id := docs.charte_create(
    p_name := 'Load Test',
    p_color_bg := '#FAF6F1',
    p_color_main := '#2C3E2D',
    p_color_accent := '#C4956A',
    p_color_text := '#3D3D3D',
    p_color_text_light := '#8A8A8A',
    p_color_border := '#E8E0D8',
    p_color_extra := '{"olive":"#5C6B3C"}'::jsonb,
    p_font_heading := 'Cormorant Garamond',
    p_font_body := 'Source Sans 3',
    p_spacing_page := '15mm',
    p_shadow_card := '0 1mm 4mm rgba(0,0,0,0.08)'
  );

  v_result := docs.charte_read('Load Test');

  RETURN NEXT ok(v_result IS NOT NULL, 'charte_read returns data');
  RETURN NEXT is(v_result->>'name', 'Load Test', 'name in result');
  RETURN NEXT ok(v_result->>'context_token' IS NOT NULL, 'context_token present');
  RETURN NEXT is(length(v_result->>'context_token'), 32, 'context_token is md5 (32 chars)');

  -- CSS check
  v_css := v_result->>'css';
  RETURN NEXT ok(v_css LIKE '%--charte-color-bg: #FAF6F1%', 'CSS contains color_bg variable');
  RETURN NEXT ok(v_css LIKE '%--charte-color-olive: #5C6B3C%', 'CSS contains color_extra olive');
  RETURN NEXT ok(v_css LIKE '%--charte-font-heading%', 'CSS contains font_heading');
  RETURN NEXT ok(v_css LIKE '%--charte-spacing-page: 15mm%', 'CSS contains spacing');
  RETURN NEXT ok(v_css LIKE '%--charte-shadow-card%', 'CSS contains shadow');
  RETURN NEXT ok(v_css LIKE '%@import url%Cormorant+Garamond%', 'Google Font import for heading');
  RETURN NEXT ok(v_css LIKE '%@import url%Source+Sans+3%', 'Google Font import for body');

  -- Colors
  RETURN NEXT is(v_result->'colors'->>'bg', '#FAF6F1', 'colors.bg');
  RETURN NEXT is(v_result->'colors'->'extra'->>'olive', '#5C6B3C', 'colors.extra.olive');

  -- Not found
  RETURN NEXT ok(docs.charte_read('Nonexistent') IS NULL, 'returns NULL for unknown charte');

  DELETE FROM docs.charte WHERE tenant_id = 'test';
END;
$function$;
