CREATE OR REPLACE FUNCTION docman.tag(p_doc_id uuid, p_label text, p_kind text DEFAULT 'tag'::text, p_parent text DEFAULT NULL::text, p_confidence real DEFAULT 1.0, p_assigned_by text DEFAULT 'agent'::text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_label_id INT;
  v_parent_id INT;
BEGIN
  -- Resolve parent by name if provided
  IF p_parent IS NOT NULL THEN
    SELECT id INTO v_parent_id FROM docman.label
    WHERE name = p_parent AND kind = 'category'
    LIMIT 1;
  END IF;

  -- Try exact name match first
  SELECT id INTO v_label_id FROM docman.label
  WHERE name = p_label AND kind = p_kind
    AND (parent_id IS NOT DISTINCT FROM v_parent_id);

  -- Try alias match if not found
  IF v_label_id IS NULL THEN
    SELECT id INTO v_label_id FROM docman.label
    WHERE p_label = ANY(aliases) AND kind = p_kind
    LIMIT 1;
  END IF;

  -- Create if not found
  IF v_label_id IS NULL THEN
    INSERT INTO docman.label (name, kind, parent_id)
    VALUES (p_label, p_kind, v_parent_id)
    RETURNING id INTO v_label_id;
  END IF;

  -- Assign to document
  INSERT INTO docman.document_label (document_id, label_id, confidence, assigned_by)
  VALUES (p_doc_id, v_label_id, p_confidence, p_assigned_by)
  ON CONFLICT (document_id, label_id) DO UPDATE
  SET confidence = EXCLUDED.confidence,
      assigned_by = EXCLUDED.assigned_by,
      assigned_at = now();

  RETURN v_label_id;
END;
$function$;
