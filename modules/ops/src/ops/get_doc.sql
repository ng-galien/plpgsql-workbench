CREATE OR REPLACE FUNCTION ops.get_doc(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_topic text;
BEGIN
  v_topic := p_params->>'topic';
  IF v_topic IS NULL THEN
    RETURN pgv.empty('Topic manquant', 'Param topic requis');
  END IF;
  RETURN pgv.doc(v_topic);
END;
$function$;
