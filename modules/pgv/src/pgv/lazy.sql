CREATE OR REPLACE FUNCTION pgv.lazy(p_rpc text, p_params jsonb DEFAULT '{}'::jsonb, p_placeholder text DEFAULT 'Chargement...'::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<div class="pgv-lazy" data-lazy="' || pgv.esc(p_rpc) || '"'
    || CASE WHEN p_params <> '{}'::jsonb
         THEN ' data-params=''' || p_params::text || ''''
         ELSE '' END
    || '><p aria-busy="true">' || pgv.esc(p_placeholder) || '</p></div>';
$function$;
