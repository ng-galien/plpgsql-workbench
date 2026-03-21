CREATE OR REPLACE FUNCTION document_ut.test_charte_check()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_charte_id text;
  v_html text;
  v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM document.charte WHERE tenant_id = 'test';

  v_charte_id := document.charte_create(p_name := 'Check Test', p_color_bg := '#fff', p_color_main := '#000',
    p_color_accent := '#f00', p_color_text := '#333', p_color_text_light := '#888', p_color_border := '#eee',
    p_font_heading := 'Inter', p_font_body := 'Inter');

  -- Compliant HTML
  v_html := '<div data-id="a" style="color:var(--charte-color-text);font-family:var(--charte-font-heading)">OK</div>';
  v_result := document.charte_check(v_html, v_charte_id);
  RETURN NEXT ok(v_result IS NULL, 'compliant HTML returns NULL');

  -- Transparent/inherit are OK
  v_html := '<div data-id="a" style="color:transparent;background:inherit">OK</div>';
  v_result := document.charte_check(v_html, v_charte_id);
  RETURN NEXT ok(v_result IS NULL, 'transparent/inherit are allowed');

  -- Hardcoded color = violation
  v_html := '<div data-id="bad" style="color:#ff0000">Bad</div>';
  v_result := document.charte_check(v_html, v_charte_id);
  RETURN NEXT ok(v_result IS NOT NULL, 'hardcoded color detected');
  RETURN NEXT ok(v_result LIKE '%[bad]%', 'violation references data-id');

  -- Hardcoded font = violation
  v_html := '<p data-id="f" style="font-family:Arial">Bad</p>';
  v_result := document.charte_check(v_html, v_charte_id);
  RETURN NEXT ok(v_result LIKE '%font-family%', 'hardcoded font detected');

  -- No charte = NULL (no check)
  RETURN NEXT ok(document.charte_check(v_html, NULL) IS NULL, 'NULL charte_id skips check');

  DELETE FROM document.charte WHERE tenant_id = 'test';
END;
$function$;
