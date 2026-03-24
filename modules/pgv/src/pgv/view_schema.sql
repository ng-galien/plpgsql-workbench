CREATE OR REPLACE FUNCTION pgv.view_schema()
 RETURNS json
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '{
    "type": "object",
    "required": ["uri", "label", "template"],
    "additionalProperties": false,
    "properties": {
      "uri": { "type": "string", "pattern": "^[a-z_]+://[a-z_]+$" },
      "icon": { "type": "string" },
      "label": { "type": "string", "pattern": "^[a-z_]+\\." },

      "template": {
        "type": "object",
        "required": ["compact", "standard", "form"],
        "additionalProperties": false,
        "properties": {

          "compact": {
            "type": "object",
            "required": ["fields"],
            "additionalProperties": false,
            "properties": {
              "fields": { "type": "array", "items": { "type": "string" }, "minItems": 1 }
            }
          },

          "standard": {
            "type": "object",
            "required": ["fields"],
            "additionalProperties": false,
            "properties": {
              "fields": { "type": "array", "items": { "type": "string" }, "minItems": 1 },
              "stats": {
                "type": "array",
                "items": {
                  "type": "object",
                  "required": ["key", "label"],
                  "properties": {
                    "key": { "type": "string" },
                    "label": { "type": "string", "pattern": "^[a-z_]+\\." },
                    "variant": { "type": "string" }
                  }
                }
              },
              "related": {
                "type": "array",
                "items": {
                  "type": "object",
                  "required": ["entity", "label", "filter"],
                  "properties": {
                    "entity": { "type": "string", "pattern": "^[a-z_]+://[a-z_]+$" },
                    "label": { "type": "string", "pattern": "^[a-z_]+\\." },
                    "filter": { "type": "string" }
                  }
                }
              }
            }
          },

          "expanded": {
            "type": "object",
            "required": ["fields"],
            "additionalProperties": false,
            "properties": {
              "fields": { "type": "array", "items": { "type": "string" }, "minItems": 1 },
              "stats": {
                "type": "array",
                "items": {
                  "type": "object",
                  "required": ["key", "label"],
                  "properties": {
                    "key": { "type": "string" },
                    "label": { "type": "string", "pattern": "^[a-z_]+\\." },
                    "variant": { "type": "string" }
                  }
                }
              },
              "related": {
                "type": "array",
                "items": {
                  "type": "object",
                  "required": ["entity", "label", "filter"],
                  "properties": {
                    "entity": { "type": "string", "pattern": "^[a-z_]+://[a-z_]+$" },
                    "label": { "type": "string", "pattern": "^[a-z_]+\\." },
                    "filter": { "type": "string" }
                  }
                }
              }
            }
          },

          "form": {
            "type": "object",
            "required": ["sections"],
            "additionalProperties": false,
            "properties": {
              "sections": {
                "type": "array",
                "minItems": 1,
                "items": {
                  "type": "object",
                  "required": ["label", "fields"],
                  "additionalProperties": false,
                  "properties": {
                    "label": { "type": "string", "pattern": "^[a-z_]+\\." },
                    "fields": {
                      "type": "array",
                      "minItems": 1,
                      "items": {
                        "type": "object",
                        "required": ["key", "type", "label"],
                        "properties": {
                          "key": { "type": "string" },
                          "type": { "type": "string", "enum": ["text", "email", "tel", "number", "date", "select", "textarea", "checkbox", "combobox"] },
                          "label": { "type": "string", "pattern": "^[a-z_]+\\." },
                          "required": { "type": "boolean" },
                          "options": {},
                          "source": { "type": "string" },
                          "display": { "type": "string" },
                          "filter": { "type": "string" }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

        }
      },

      "actions": {
        "type": "object",
        "additionalProperties": {
          "type": "object",
          "required": ["label"],
          "properties": {
            "label": { "type": "string", "pattern": "^[a-z_]+\\." },
            "icon": { "type": "string" },
            "variant": { "type": "string", "enum": ["primary", "warning", "danger", "muted"] },
            "confirm": { "type": "string", "pattern": "^[a-z_]+\\." }
          }
        }
      }

    }
  }'::json;
$function$;
