CREATE OR REPLACE FUNCTION shop.path_segment(p_path text, p_pos integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT (string_to_array(trim(LEADING '/' FROM p_path), '/'))[p_pos];
$function$;
