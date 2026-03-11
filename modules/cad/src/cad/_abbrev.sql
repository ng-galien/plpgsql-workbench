CREATE OR REPLACE FUNCTION cad._abbrev(p_label text, p_role text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE
    WHEN p_label LIKE 'Poteau %' THEN replace(substr(p_label, 8), ' ', '')
    WHEN p_label LIKE 'Traverse %' THEN 't' || replace(substr(p_label, 10), ' ', '')
    WHEN p_label LIKE 'Lisse bas %' THEN 'b' || replace(substr(p_label, 11), ' ', '')
    WHEN p_label LIKE 'Lisse mid %' THEN 'm' || replace(substr(p_label, 11), ' ', '')
    WHEN p_label LIKE 'Lisse haut %' THEN 'h' || replace(substr(p_label, 12), ' ', '')
    WHEN p_label LIKE 'Chevron AV-%' THEN 'V' || replace(substr(p_label, 12), '-', '')
    WHEN p_label LIKE 'Chevron AR-%' THEN 'R' || replace(substr(p_label, 12), '-', '')
    WHEN p_label LIKE 'Chevron %' THEN 'C' || replace(substr(p_label, 9), ' ', '')
    WHEN p_label = 'Faitiere' THEN 'F'
    WHEN p_label IS NOT NULL THEN left(p_label, 3)
    ELSE left(COALESCE(p_role, '?'), 1)
  END
$function$;
