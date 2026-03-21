CREATE OR REPLACE FUNCTION docs_ut.test_charte_list()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.charte WHERE tenant_id = 'test';

  PERFORM docs.charte_create(p_name := 'List A', p_color_bg := '#fff', p_color_main := '#000',
    p_color_accent := '#f00', p_color_text := '#333', p_color_text_light := '#888', p_color_border := '#eee',
    p_font_heading := 'Inter', p_font_body := 'Inter');
  PERFORM docs.charte_create(p_name := 'List B', p_color_bg := '#eee', p_color_main := '#111',
    p_color_accent := '#0f0', p_color_text := '#222', p_color_text_light := '#777', p_color_border := '#ddd',
    p_font_heading := 'Oswald', p_font_body := 'Lato');

  v_result := docs.charte_list();

  RETURN NEXT is(jsonb_array_length(v_result), 2, '2 chartes listed');
  RETURN NEXT is(v_result->0->>'name', 'List A', 'first sorted by name');
  RETURN NEXT ok(v_result->0->'colors' ? 'bg', 'colors.bg present');
  RETURN NEXT ok(v_result->1->'fonts' ? 'heading', 'fonts.heading present');

  DELETE FROM docs.charte WHERE tenant_id = 'test';
END;
$function$;
