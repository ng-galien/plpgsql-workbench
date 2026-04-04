CREATE OR REPLACE FUNCTION sdui.view_schema()
 RETURNS json
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '{
  "type": "object",
  "required": [
    "uri",
    "label",
    "template"
  ],
  "additionalProperties": false,
  "properties": {
    "uri": {
      "type": "string",
      "pattern": "^[a-z_]+://[a-z_]+$"
    },
    "icon": {
      "type": "string"
    },
    "label": {
      "type": "string",
      "pattern": "^[a-z_]+\\."
    },
    "readonly": {
      "type": "boolean"
    },
    "entity_type": {
      "type": "string",
      "enum": [
        "crud",
        "event"
      ]
    },
    "template": {
      "type": "object",
      "required": [
        "compact",
        "standard"
      ],
      "additionalProperties": false,
      "properties": {
        "compact": {
          "type": "object",
          "required": [
            "fields"
          ],
          "additionalProperties": false,
          "properties": {
            "fields": {
              "type": "array",
              "minItems": 1,
              "items": {
                "oneOf": [
                  {
                    "type": "string"
                  },
                  {
                    "type": "object",
                    "required": [
                      "key"
                    ],
                    "properties": {
                      "key": {
                        "type": "string"
                      },
                      "type": {
                        "type": "string",
                        "enum": [
                          "text",
                          "date",
                          "datetime",
                          "currency",
                          "number",
                          "status",
                          "email",
                          "tel"
                        ]
                      },
                      "label": {
                        "type": "string",
                        "pattern": "^[a-z_]+\\."
                      }
                    }
                  }
                ]
              }
            }
          }
        },
        "standard": {
          "type": "object",
          "required": [
            "fields"
          ],
          "additionalProperties": false,
          "properties": {
            "fields": {
              "type": "array",
              "minItems": 1,
              "items": {
                "oneOf": [
                  {
                    "type": "string"
                  },
                  {
                    "type": "object",
                    "required": [
                      "key"
                    ],
                    "properties": {
                      "key": {
                        "type": "string"
                      },
                      "type": {
                        "type": "string",
                        "enum": [
                          "text",
                          "date",
                          "datetime",
                          "currency",
                          "number",
                          "status",
                          "email",
                          "tel"
                        ]
                      },
                      "label": {
                        "type": "string",
                        "pattern": "^[a-z_]+\\."
                      }
                    }
                  }
                ]
              }
            },
            "stats": {
              "type": "array",
              "items": {
                "type": "object",
                "required": [
                  "key",
                  "label"
                ],
                "properties": {
                  "key": {
                    "type": "string"
                  },
                  "label": {
                    "type": "string",
                    "pattern": "^[a-z_]+\\."
                  },
                  "variant": {
                    "type": "string"
                  }
                }
              }
            },
            "related": {
              "type": "array",
              "items": {
                "type": "object",
                "required": [
                  "entity",
                  "label",
                  "filter"
                ],
                "properties": {
                  "entity": {
                    "type": "string",
                    "pattern": "^[a-z_]+://[a-z_]+$"
                  },
                  "label": {
                    "type": "string",
                    "pattern": "^[a-z_]+\\."
                  },
                  "filter": {
                    "type": "string"
                  }
                }
              }
            }
          }
        },
        "expanded": {
          "type": "object",
          "required": [
            "fields"
          ],
          "additionalProperties": false,
          "properties": {
            "fields": {
              "type": "array",
              "minItems": 1,
              "items": {
                "oneOf": [
                  {
                    "type": "string"
                  },
                  {
                    "type": "object",
                    "required": [
                      "key"
                    ],
                    "properties": {
                      "key": {
                        "type": "string"
                      },
                      "type": {
                        "type": "string",
                        "enum": [
                          "text",
                          "date",
                          "datetime",
                          "currency",
                          "number",
                          "status",
                          "email",
                          "tel"
                        ]
                      },
                      "label": {
                        "type": "string",
                        "pattern": "^[a-z_]+\\."
                      }
                    }
                  }
                ]
              }
            },
            "stats": {
              "type": "array",
              "items": {
                "type": "object",
                "required": [
                  "key",
                  "label"
                ],
                "properties": {
                  "key": {
                    "type": "string"
                  },
                  "label": {
                    "type": "string",
                    "pattern": "^[a-z_]+\\."
                  },
                  "variant": {
                    "type": "string"
                  }
                }
              }
            },
            "related": {
              "type": "array",
              "items": {
                "type": "object",
                "required": [
                  "entity",
                  "label",
                  "filter"
                ],
                "properties": {
                  "entity": {
                    "type": "string",
                    "pattern": "^[a-z_]+://[a-z_]+$"
                  },
                  "label": {
                    "type": "string",
                    "pattern": "^[a-z_]+\\."
                  },
                  "filter": {
                    "type": "string"
                  }
                }
              }
            }
          }
        },
        "form": {
          "type": "object",
          "required": [
            "sections"
          ],
          "additionalProperties": false,
          "properties": {
            "sections": {
              "type": "array",
              "minItems": 1,
              "items": {
                "type": "object",
                "required": [
                  "label",
                  "fields"
                ],
                "additionalProperties": false,
                "properties": {
                  "label": {
                    "type": "string",
                    "pattern": "^[a-z_]+\\."
                  },
                  "fields": {
                    "type": "array",
                    "minItems": 1,
                    "items": {
                      "type": "object",
                      "required": [
                        "key",
                        "type",
                        "label"
                      ],
                      "properties": {
                        "key": {
                          "type": "string"
                        },
                        "type": {
                          "type": "string",
                          "enum": [
                            "text",
                            "email",
                            "tel",
                            "number",
                            "date",
                            "select",
                            "textarea",
                            "checkbox"
                          ]
                        },
                        "label": {
                          "type": "string",
                          "pattern": "^[a-z_]+\\."
                        },
                        "required": {
                          "type": "boolean"
                        },
                        "search": {
                          "type": "boolean"
                        },
                        "options": {},
                        "source": {
                          "type": "string"
                        },
                        "display": {
                          "type": "string"
                        },
                        "filter": {
                          "type": "string"
                        }
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
        "required": [
          "label"
        ],
        "properties": {
          "label": {
            "type": "string",
            "pattern": "^[a-z_]+\\."
          },
          "icon": {
            "type": "string"
          },
          "variant": {
            "type": "string",
            "enum": [
              "default",
              "primary",
              "warning",
              "danger",
              "muted"
            ]
          },
          "confirm": {
            "type": "string",
            "pattern": "^[a-z_]+\\."
          }
        }
      }
    }
  }
}'::json;
$function$;
