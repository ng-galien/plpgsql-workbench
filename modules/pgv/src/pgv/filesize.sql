CREATE OR REPLACE FUNCTION pgv.filesize(p_bytes bigint)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE
    WHEN p_bytes IS NULL THEN '-'
    WHEN p_bytes < 1024 THEN p_bytes || ' B'
    WHEN p_bytes < 1048576 THEN round(p_bytes / 1024.0, 1) || ' KB'
    WHEN p_bytes < 1073741824 THEN round(p_bytes / 1048576.0, 1) || ' MB'
    ELSE round(p_bytes / 1073741824.0, 1) || ' GB'
  END;
$function$;
