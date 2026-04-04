CREATE OR REPLACE FUNCTION query_ut.test_rsql_fk()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
BEGIN
  -- Simple FK traversal
  v_result := query.rsql_to_where('charte.name==ocean', 'docs', 'document');
  RETURN NEXT is(v_result,
    'EXISTS (SELECT 1 FROM docs.charte WHERE id = document.charte_id AND name = ''ocean'')',
    'fk simple: charte.name==ocean');

  -- FK + local filter combined
  v_result := query.rsql_to_where('charte.font_heading=like=*Garamond*;status==draft', 'docs', 'document');
  RETURN NEXT is(v_result,
    'EXISTS (SELECT 1 FROM docs.charte WHERE id = document.charte_id AND font_heading LIKE ''%Garamond%'') AND status = ''draft''',
    'fk combined: charte.font + local status');

  -- Invalid relation → RAISE
  BEGIN
    v_result := query.rsql_to_where('nonexistent.name==test', 'docs', 'document');
    RETURN NEXT fail('invalid FK should raise');
  EXCEPTION WHEN OTHERS THEN
    RETURN NEXT ok(SQLERRM LIKE '%not a column or FK relation%', 'invalid FK raises exception');
  END;

  -- Invalid column on target table → RAISE
  BEGIN
    v_result := query.rsql_to_where('charte.fakecol==test', 'docs', 'document');
    RETURN NEXT fail('invalid FK column should raise');
  EXCEPTION WHEN OTHERS THEN
    RETURN NEXT ok(SQLERRM LIKE '%does not exist%', 'invalid FK target column raises');
  END;
END;
$function$;
