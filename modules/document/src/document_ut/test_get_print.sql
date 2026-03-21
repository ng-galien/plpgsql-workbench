CREATE OR REPLACE FUNCTION document_ut.test_get_print()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_charte_id text;
  v_id text;
  v_html text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM document.document WHERE tenant_id = 'test';
  DELETE FROM document.charte WHERE tenant_id = 'test';

  v_charte_id := document.charte_create(p_name := 'Print Charte', p_color_bg := '#FAF6F1', p_color_main := '#2C3E2D',
    p_color_accent := '#C4956A', p_color_text := '#333', p_color_text_light := '#888', p_color_border := '#eee',
    p_font_heading := 'Inter', p_font_body := 'Inter');

  v_id := document.doc_create('Print Doc', p_charte_id := v_charte_id, p_html := '<p data-id="p1">Page 1</p>');
  PERFORM document.page_add(v_id, 'Page 2', '<p data-id="p2">Page 2</p>');

  v_html := document.get_print(v_id);

  RETURN NEXT ok(v_html LIKE '%--charte-color-bg%', 'charte CSS present');
  RETURN NEXT ok(v_html LIKE '%@media print%', 'print CSS present');
  RETURN NEXT ok(v_html LIKE '%doc-print-page%', 'page containers present');
  RETURN NEXT ok(v_html LIKE '%Page 1%', 'page 1 content');
  RETURN NEXT ok(v_html LIKE '%Page 2%', 'page 2 content');
  RETURN NEXT ok(v_html LIKE '%window.print()%', 'auto-print script');

  DELETE FROM document.document WHERE tenant_id = 'test';
  DELETE FROM document.charte WHERE tenant_id = 'test';
END;
$function$;
