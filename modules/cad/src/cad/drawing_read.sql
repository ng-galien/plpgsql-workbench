CREATE OR REPLACE FUNCTION cad.drawing_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_row jsonb;
  v_actions jsonb;
BEGIN
  SELECT to_jsonb(d) || jsonb_build_object(
    'shape_count', (SELECT count(*) FROM cad.shape s WHERE s.drawing_id = d.id),
    'piece_count', (SELECT count(*) FROM cad.piece p WHERE p.drawing_id = d.id),
    'layer_count', (SELECT count(*) FROM cad.layer l WHERE l.drawing_id = d.id),
    'group_count', (SELECT count(*) FROM cad.piece_group g WHERE g.drawing_id = d.id)
  ) INTO v_row
  FROM cad.drawing d
  WHERE d.id = p_id::int
    AND d.tenant_id = current_setting('app.tenant_id', true);

  IF v_row IS NULL THEN
    RETURN NULL;
  END IF;

  -- HATEOAS actions (all drawings are editable — no status column yet)
  v_actions := jsonb_build_array(
    jsonb_build_object('method', 'delete', 'uri', 'cad://drawing/' || p_id || '/delete'),
    jsonb_build_object('method', 'duplicate', 'uri', 'cad://drawing/' || p_id || '/duplicate'),
    jsonb_build_object('method', 'export_bom', 'uri', 'cad://drawing/' || p_id || '/export_bom')
  );

  RETURN v_row || jsonb_build_object('actions', v_actions);
END;
$function$;
