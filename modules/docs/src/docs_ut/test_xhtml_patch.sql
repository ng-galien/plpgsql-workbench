CREATE OR REPLACE FUNCTION docs_ut.test_xhtml_patch()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_result text;
BEGIN
  -- STYLE: add style to element without style
  v_html := '<div data-id="a">Hello</div>';
  v_result := docs.xhtml_patch(v_html, '[{"id":"a","style":{"color":"red"}}]'::jsonb);
  RETURN NEXT ok(v_result LIKE '%style="color:red"%', 'style added to unstyled element');

  -- STYLE: merge with existing
  v_html := '<div data-id="a" style="width:10mm">Hello</div>';
  v_result := docs.xhtml_patch(v_html, '[{"id":"a","style":{"color":"blue"}}]'::jsonb);
  RETURN NEXT ok(v_result LIKE '%color:blue%', 'style merged: new prop');
  RETURN NEXT ok(v_result LIKE '%width:10mm%', 'style merged: existing prop preserved');

  -- CONTENT: replace innerHTML
  v_html := '<div data-id="a">Old content</div>';
  v_result := docs.xhtml_patch(v_html, '[{"id":"a","content":"New content"}]'::jsonb);
  RETURN NEXT ok(v_result LIKE '%New content%', 'content replaced');
  RETURN NEXT ok(v_result NOT LIKE '%Old content%', 'old content gone');

  -- REMOVE: delete element
  v_html := '<div data-id="keep">Keep</div><div data-id="rm">Remove me</div>';
  v_result := docs.xhtml_patch(v_html, '[{"id":"rm","remove":true}]'::jsonb);
  RETURN NEXT ok(v_result LIKE '%Keep%', 'kept element preserved');
  RETURN NEXT ok(v_result NOT LIKE '%Remove me%', 'removed element gone');

  -- INSERT: add before closing tag
  v_html := '<div data-id="container"><p>Existing</p></div>';
  v_result := docs.xhtml_patch(v_html, '[{"id":"container","insert":"<p>Added</p>"}]'::jsonb);
  RETURN NEXT ok(v_result LIKE '%<p>Existing</p><p>Added</p>%', 'inserted before end');

  -- REPLACE: replace entire element
  v_html := '<div data-id="old">Old</div>';
  v_result := docs.xhtml_patch(v_html, '[{"id":"old","replace":"<span data-id=\"new\">New</span>"}]'::jsonb);
  RETURN NEXT ok(v_result LIKE '%<span data-id="new">New</span>%', 'element replaced');
  RETURN NEXT ok(v_result NOT LIKE '%data-id="old"%', 'old element gone');

  -- INVALID: patch that breaks XML
  BEGIN
    v_html := '<div data-id="a">Hello</div>';
    PERFORM docs.xhtml_patch(v_html, '[{"id":"a","content":"<b>unclosed"}]'::jsonb);
    RETURN NEXT fail('should raise on invalid XML');
  EXCEPTION WHEN OTHERS THEN
    RETURN NEXT pass('raises on invalid XML result');
  END;

  -- Unknown data-id: no-op
  v_html := '<div data-id="a">Hello</div>';
  v_result := docs.xhtml_patch(v_html, '[{"id":"unknown","content":"X"}]'::jsonb);
  RETURN NEXT is(v_result, v_html, 'unknown data-id is no-op');
END;
$function$;
