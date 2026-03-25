CREATE OR REPLACE FUNCTION docs_ut.test_charte_check()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_j jsonb;
  v_html text;
  v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.charte WHERE tenant_id = 'test';

  v_j := docs.charte_create(jsonb_populate_record(NULL::docs.charte, jsonb_build_object(
    'name', 'Check Test', 'color_bg', '#fff', 'color_main', '#000', 'color_accent', '#f00',
    'color_text', '#333', 'color_text_light', '#888', 'color_border', '#eee',
    'font_heading', 'Inter', 'font_body', 'Inter'
  )));

  v_html := '<div data-id="a" style="color:var(--charte-color-text);font-family:var(--charte-font-heading)">OK</div>';
  v_result := docs.charte_check(v_html, v_j->>'id');
  RETURN NEXT ok(v_result IS NULL, 'compliant HTML returns NULL');

  v_html := '<div data-id="a" style="color:transparent;background:inherit">OK</div>';
  v_result := docs.charte_check(v_html, v_j->>'id');
  RETURN NEXT ok(v_result IS NULL, 'transparent/inherit are allowed');

  v_html := '<div data-id="bad" style="color:#ff0000">Bad</div>';
  v_result := docs.charte_check(v_html, v_j->>'id');
  RETURN NEXT ok(v_result IS NOT NULL, 'hardcoded color detected');
  RETURN NEXT ok(v_result LIKE '%[bad]%', 'violation references data-id');

  v_html := '<p data-id="f" style="font-family:Arial">Bad</p>';
  v_result := docs.charte_check(v_html, v_j->>'id');
  RETURN NEXT ok(v_result LIKE '%font-family%', 'hardcoded font detected');

  RETURN NEXT ok(docs.charte_check(v_html, NULL) IS NULL, 'NULL charte_id skips check');

  DELETE FROM docs.charte WHERE tenant_id = 'test';
END;
$function$;
