CREATE OR REPLACE FUNCTION document.element_move(p_element_id uuid, p_dx real, p_dy real)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_count int := 0;
BEGIN
  -- Recursive CTE: collect this element + all descendants
  WITH RECURSIVE tree AS (
    SELECT id, type FROM document.element WHERE id = p_element_id
    UNION ALL
    SELECT e.id, e.type FROM document.element e JOIN tree t ON e.parent_id = t.id
  )
  -- Update leaf elements based on their type
  UPDATE document.element e SET
    x  = CASE WHEN e.type IN ('text','rect','image') THEN e.x + p_dx ELSE e.x END,
    y  = CASE WHEN e.type IN ('text','rect','image') THEN e.y + p_dy ELSE e.y END,
    x1 = CASE WHEN e.type = 'line' THEN e.x1 + p_dx ELSE e.x1 END,
    y1 = CASE WHEN e.type = 'line' THEN e.y1 + p_dy ELSE e.y1 END,
    x2 = CASE WHEN e.type = 'line' THEN e.x2 + p_dx ELSE e.x2 END,
    y2 = CASE WHEN e.type = 'line' THEN e.y2 + p_dy ELSE e.y2 END,
    cx = CASE WHEN e.type IN ('circle','ellipse') THEN e.cx + p_dx ELSE e.cx END,
    cy = CASE WHEN e.type IN ('circle','ellipse') THEN e.cy + p_dy ELSE e.cy END
  FROM tree t
  WHERE e.id = t.id AND t.type != 'group';

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;
