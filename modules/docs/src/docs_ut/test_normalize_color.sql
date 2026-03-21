CREATE OR REPLACE FUNCTION docs_ut.test_normalize_color()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT is(docs.normalize_color('#ff0080'), '#ff0080', 'hex 6 lowercase unchanged');
  RETURN NEXT is(docs.normalize_color('#FF0080'), '#ff0080', 'hex 6 uppercase');
  RETURN NEXT is(docs.normalize_color('#FFF'), '#ffffff', 'hex 3 → 6');
  RETURN NEXT is(docs.normalize_color('#abc'), '#aabbcc', 'hex 3 lowercase');
  RETURN NEXT is(docs.normalize_color('rgb(255, 0, 128)'), '#ff0080', 'rgb()');
  RETURN NEXT is(docs.normalize_color('rgb(0, 0, 0)'), '#000000', 'rgb black');
  RETURN NEXT ok(docs.normalize_color('not-a-color') IS NULL, 'invalid returns NULL');
  RETURN NEXT ok(docs.normalize_color('red') IS NULL, 'named color returns NULL');
END;
$function$;
