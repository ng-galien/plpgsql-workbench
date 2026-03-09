CREATE OR REPLACE FUNCTION docman.relate(p_source_id uuid, p_target_id uuid, p_kind text, p_confidence real DEFAULT 1.0, p_assigned_by text DEFAULT 'agent'::text)
 RETURNS void
 LANGUAGE sql
AS $function$
  INSERT INTO docman.document_relation (source_id, target_id, kind, confidence, assigned_by)
  VALUES (p_source_id, p_target_id, p_kind, p_confidence, p_assigned_by)
  ON CONFLICT (source_id, target_id, kind) DO UPDATE
  SET confidence = EXCLUDED.confidence,
      assigned_by = EXCLUDED.assigned_by,
      assigned_at = now();
$function$;
