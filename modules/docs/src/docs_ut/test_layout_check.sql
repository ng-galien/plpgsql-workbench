CREATE OR REPLACE FUNCTION docs_ut.test_layout_check()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_result text;
BEGIN
  -- Within bounds
  v_html := '<div data-id="ok" style="width:200mm;height:290mm">Fits</div>';
  v_result := docs.layout_check(v_html, 210, 297);
  RETURN NEXT ok(v_result IS NULL, 'within bounds returns NULL');

  -- Width overflow
  v_html := '<div data-id="wide" style="width:220mm;height:100mm">Wide</div>';
  v_result := docs.layout_check(v_html, 210, 297);
  RETURN NEXT ok(v_result IS NOT NULL, 'width overflow detected');
  RETURN NEXT ok(v_result LIKE '%[wide]%', 'overflow references data-id');

  -- Height overflow
  v_html := '<div data-id="tall" style="width:100mm;height:300mm">Tall</div>';
  v_result := docs.layout_check(v_html, 210, 297);
  RETURN NEXT ok(v_result LIKE '%height%', 'height overflow detected');

  -- No dimensions = no overflow
  v_html := '<div data-id="nodim" style="color:red">No dims</div>';
  v_result := docs.layout_check(v_html, 210, 297);
  RETURN NEXT ok(v_result IS NULL, 'no dimensions = no overflow');
END;
$function$;
