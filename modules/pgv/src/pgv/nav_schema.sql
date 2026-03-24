CREATE OR REPLACE FUNCTION pgv.nav_schema()
 RETURNS json
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '{
    "type": "object",
    "required": ["module", "brand", "schema", "group", "items"],
    "properties": {
      "module": { "type": "string" },
      "brand": { "type": "string" },
      "schema": { "type": "string" },
      "group": { "type": ["string", "null"] },
      "items": {
        "type": "array",
        "items": {
          "type": "object",
          "required": ["label"],
          "properties": {
            "label": { "type": "string" },
            "href": { "type": "string" },
            "icon": { "type": ["string", "null"] },
            "entity": { "type": "string" },
            "uri": { "type": "string", "pattern": "^[a-z_]+://[a-z_]+$" }
          },
          "if": { "required": ["entity"] },
          "then": { "required": ["entity", "uri"] }
        }
      }
    }
  }'::json;
$function$;
