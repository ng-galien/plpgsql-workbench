CREATE OR REPLACE FUNCTION project._next_code()
 RETURNS text
 LANGUAGE sql
AS $function$
  SELECT 'PRJ-' || to_char(CURRENT_DATE, 'YYYY') || '-' ||
    lpad((COALESCE(
      (SELECT max(substring(code FROM '\d+$')::int) FROM project.project
       WHERE code LIKE 'PRJ-' || to_char(CURRENT_DATE, 'YYYY') || '-%'), 0) + 1)::text, 3, '0');
$function$;
