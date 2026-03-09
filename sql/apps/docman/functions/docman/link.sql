CREATE OR REPLACE FUNCTION docman.link(p_doc_id uuid, p_kind text, p_name text, p_role text, p_confidence real DEFAULT 1.0, p_assigned_by text DEFAULT 'agent'::text, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_entity_id INT;
BEGIN
  -- Try exact name match
  SELECT id INTO v_entity_id FROM docman.entity
  WHERE kind = p_kind AND name = p_name;

  -- Try alias match
  IF v_entity_id IS NULL THEN
    SELECT id INTO v_entity_id FROM docman.entity
    WHERE kind = p_kind AND p_name = ANY(aliases)
    LIMIT 1;
  END IF;

  -- Create if not found
  IF v_entity_id IS NULL THEN
    INSERT INTO docman.entity (kind, name, metadata)
    VALUES (p_kind, p_name, p_metadata)
    RETURNING id INTO v_entity_id;
  END IF;

  -- Link to document
  INSERT INTO docman.document_entity (document_id, entity_id, role, confidence, assigned_by)
  VALUES (p_doc_id, v_entity_id, p_role, p_confidence, p_assigned_by)
  ON CONFLICT (document_id, entity_id, role) DO UPDATE
  SET confidence = EXCLUDED.confidence,
      assigned_by = EXCLUDED.assigned_by,
      assigned_at = now();

  RETURN v_entity_id;
END;
$function$;
