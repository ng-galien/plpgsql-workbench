CREATE OR REPLACE FUNCTION project._next_numero()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT 'CHT-' || to_char(now(), 'YYYY') || '-' ||
         lpad((COALESCE(
           (SELECT MAX(substring(numero FROM '\d+$')::int)
            FROM project.chantier
            WHERE numero LIKE 'CHT-' || to_char(now(), 'YYYY') || '-%'),
           0) + 1)::text, 3, '0');
$function$;
