/**
 * SDUI JSON schema for form field validation at PLX compile time.
 * Source of truth for what properties a form field can have.
 */

import type { Loc } from "./ast.js";

export const formFieldSchema = {
  required: ["key", "type", "label"],
  properties: {
    key: { type: "string" },
    type: {
      type: "string",
      enum: ["text", "email", "tel", "number", "date", "select", "textarea", "checkbox"],
    },
    label: { type: "string" },
    required: { type: "boolean" },
    options: { type: ["string", "object"] },
    search: { type: "boolean" },
  },
  additionalProperties: false,
} as const;

const VALID_PROP_KEYS = new Set(Object.keys(formFieldSchema.properties));
const VALID_PROP_LIST = [...VALID_PROP_KEYS].join(", ");
const VALID_FIELD_TYPES = new Set<string>(formFieldSchema.properties.type.enum);
const VALID_TYPE_LIST = [...VALID_FIELD_TYPES].join(", ");

export interface FormFieldError {
  code: string;
  message: string;
  loc: Loc;
}

export function validateFormField(
  entries: Record<string, string | boolean | Record<string, string>>,
  loc: Loc,
): FormFieldError[] {
  const errors: FormFieldError[] = [];

  for (const key of Object.keys(entries)) {
    if (!VALID_PROP_KEYS.has(key)) {
      errors.push({
        code: "parse.invalid-form-field-property",
        message: `unknown form field property '${key}'; allowed: ${VALID_PROP_LIST}`,
        loc,
      });
    }
  }

  for (const req of formFieldSchema.required) {
    if (!(req in entries)) {
      errors.push({
        code: "parse.invalid-form-field",
        message: `form field missing required property '${req}'`,
        loc,
      });
    }
  }

  const fieldType = entries.type;
  if (typeof fieldType === "string" && !VALID_FIELD_TYPES.has(fieldType)) {
    errors.push({
      code: "parse.invalid-form-field-type",
      message: `invalid value '${fieldType}' for 'type'; allowed: ${VALID_TYPE_LIST}`,
      loc,
    });
  }

  return errors;
}
