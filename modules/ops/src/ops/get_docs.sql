CREATE OR REPLACE FUNCTION ops.get_docs()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_rows text := '';
  v_rec record;
  v_count int := 0;
BEGIN
  FOR v_rec IN
    SELECT topic, length(content) AS size FROM workbench.doc ORDER BY topic
  LOOP
    v_rows := v_rows
      || '| [' || pgv.esc(v_rec.topic) || '](/ops/doc?topic=' || pgv.esc(v_rec.topic) || ')'
      || ' | ' || pgv.filesize(v_rec.size) || ' |' || chr(10);
    v_count := v_count + 1;
  END LOOP;

  IF v_count = 0 THEN
    RETURN pgv.empty('Aucune documentation', 'workbench.doc est vide');
  END IF;

  RETURN '<md>' || chr(10)
    || '| Topic | Taille |' || chr(10)
    || '|-------|--------|' || chr(10)
    || v_rows
    || '</md>';
END;
$function$;
