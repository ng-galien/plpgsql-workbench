CREATE OR REPLACE FUNCTION docman.unrelate(p_source_id uuid, p_target_id uuid, p_kind text)
 RETURNS void
 LANGUAGE sql
AS $function$
  DELETE FROM docman.document_relation
  WHERE source_id = p_source_id AND target_id = p_target_id AND kind = p_kind;
$function$;
