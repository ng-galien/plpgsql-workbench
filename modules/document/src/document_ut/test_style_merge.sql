CREATE OR REPLACE FUNCTION document_ut.test_style_merge()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- jsonb keys are sorted alphabetically
  RETURN NEXT is(document.style_merge('width:210mm;color:red', 'color:blue;font-size:4mm'),
    'color:blue;width:210mm;font-size:4mm', 'merge with overwrite');
  RETURN NEXT is(document.style_merge('', 'color:red'), 'color:red', 'empty existing');
  RETURN NEXT is(document.style_merge('width:10mm', ''), 'width:10mm', 'empty new');
  RETURN NEXT is(document.style_merge(NULL, 'a:b'), 'a:b', 'NULL existing');
  RETURN NEXT is(document.style_merge('a:1;b:2', 'b:3;c:4'), 'a:1;b:3;c:4', 'partial overwrite');
END;
$function$;
