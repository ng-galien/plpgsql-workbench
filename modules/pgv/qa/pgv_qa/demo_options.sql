CREATE OR REPLACE FUNCTION pgv_qa.demo_options(p_search text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_all jsonb := '[
    {"value":"1","label":"Aluminium 6061","detail":"Metal / Profiles"},
    {"value":"2","label":"Acier inox 304","detail":"Metal / Toles"},
    {"value":"3","label":"Bois chene massif","detail":"Bois / Panneaux"},
    {"value":"4","label":"PVC blanc","detail":"Plastique / Profiles"},
    {"value":"5","label":"Verre trempe 6mm","detail":"Verre / Securite"},
    {"value":"6","label":"Beton C25/30","detail":"Materiaux / Gros oeuvre"},
    {"value":"7","label":"Isolant laine roche","detail":"Isolation / Thermique"},
    {"value":"8","label":"Plaque BA13","detail":"Platrerie / Cloisons"}
  ]'::jsonb;
BEGIN
  IF p_search = '' THEN
    RETURN v_all;
  END IF;
  RETURN (
    SELECT coalesce(jsonb_agg(item), '[]'::jsonb)
    FROM jsonb_array_elements(v_all) AS item
    WHERE (item->>'label') ILIKE '%' || p_search || '%'
       OR (item->>'detail') ILIKE '%' || p_search || '%'
  );
END;
$function$;
