/**
 * SDUI JSON schema for form field validation at PLX compile time.
 * Source of truth for what properties a form field can have.
 */

import type { Loc } from "./ast.js";
import {
  type SduiViewTemplate,
  sduiActionPropertyKeys,
  sduiActionVariants,
  sduiFormFieldPropertyKeys,
  sduiFormFieldTypes,
  sduiViewFieldPropertyKeys,
  sduiViewFieldTypes,
  sduiViewSchema,
} from "./generated/sdui-contract.js";

export const formFieldSchema = {
  required: ["key", "type", "label"],
  properties: {
    key: { type: "string" },
    type: { type: "string", enum: [...sduiFormFieldTypes] },
    label: { type: "string" },
    required: { type: "boolean" },
    search: { type: "boolean" },
    options: { type: ["string", "object"] },
    source: { type: "string" },
    display: { type: "string" },
    filter: { type: "string" },
  },
  additionalProperties: false,
} as const;

const VALID_PROP_KEYS = new Set<string>(sduiFormFieldPropertyKeys);
const VALID_PROP_LIST = [...VALID_PROP_KEYS].join(", ");
const VALID_FIELD_TYPES = new Set<string>(sduiFormFieldTypes);
const VALID_TYPE_LIST = [...VALID_FIELD_TYPES].join(", ");
const VALID_ACTION_PROP_KEYS = new Set<string>(sduiActionPropertyKeys);
const VALID_ACTION_PROP_LIST = [...VALID_ACTION_PROP_KEYS].join(", ");
const VALID_ACTION_VARIANTS = new Set<string>(sduiActionVariants);
const VALID_ACTION_VARIANT_LIST = [...VALID_ACTION_VARIANTS].join(", ");
const VALID_VIEW_FIELD_PROP_KEYS = new Set<string>(sduiViewFieldPropertyKeys);
const VALID_VIEW_FIELD_PROP_LIST = [...VALID_VIEW_FIELD_PROP_KEYS].join(", ");
const VALID_VIEW_FIELD_TYPES = new Set<string>(sduiViewFieldTypes);
const VALID_VIEW_FIELD_TYPE_LIST = [...VALID_VIEW_FIELD_TYPES].join(", ");

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

export function validateActionDef(entries: Record<string, string>, loc: Loc): FormFieldError[] {
  const errors: FormFieldError[] = [];

  for (const key of Object.keys(entries)) {
    if (!VALID_ACTION_PROP_KEYS.has(key)) {
      errors.push({
        code: "parse.invalid-action-property",
        message: `unknown action property '${key}'; allowed: ${VALID_ACTION_PROP_LIST}`,
        loc,
      });
    }
  }

  if (!("label" in entries)) {
    errors.push({
      code: "parse.invalid-action",
      message: "action missing required property 'label'",
      loc,
    });
  }

  const variant = entries.variant;
  if (variant !== undefined && !VALID_ACTION_VARIANTS.has(variant)) {
    errors.push({
      code: "parse.invalid-action-variant",
      message: `invalid value '${variant}' for 'variant'; allowed: ${VALID_ACTION_VARIANT_LIST}`,
      loc,
    });
  }

  return errors;
}

export function validateViewField(entries: Record<string, string>, loc: Loc): FormFieldError[] {
  const errors: FormFieldError[] = [];

  for (const key of Object.keys(entries)) {
    if (!VALID_VIEW_FIELD_PROP_KEYS.has(key)) {
      errors.push({
        code: "parse.invalid-view-field-property",
        message: `unknown view field property '${key}'; allowed: ${VALID_VIEW_FIELD_PROP_LIST}`,
        loc,
      });
    }
  }

  if (!("key" in entries)) {
    errors.push({
      code: "parse.invalid-view-field",
      message: "view field missing required property 'key'",
      loc,
    });
  }

  const fieldType = entries.type;
  if (fieldType !== undefined && !VALID_VIEW_FIELD_TYPES.has(fieldType)) {
    errors.push({
      code: "parse.invalid-view-field-type",
      message: `invalid value '${fieldType}' for 'type'; allowed: ${VALID_VIEW_FIELD_TYPE_LIST}`,
      loc,
    });
  }

  return errors;
}

export function validateViewPayload(payload: SduiViewTemplate, loc: Loc): FormFieldError[] {
  return validateSchemaNode(payload, sduiViewSchema, loc, "view");
}

type JsonSchemaNode = {
  type?: string | readonly string[];
  required?: readonly string[];
  additionalProperties?: boolean | JsonSchemaNode;
  properties?: Record<string, JsonSchemaNode>;
  items?: JsonSchemaNode;
  oneOf?: readonly JsonSchemaNode[];
  enum?: readonly unknown[];
  pattern?: string;
  minItems?: number;
};

function validateSchemaNode(value: unknown, schema: JsonSchemaNode, loc: Loc, path: string): FormFieldError[] {
  if (schema.oneOf) {
    const variants = schema.oneOf
      .map((candidate) => validateSchemaNode(value, candidate, loc, path))
      .filter((errors) => errors.length === 0);
    if (variants.length > 0) return [];
    return [
      {
        code: "validate.invalid-view-payload",
        message: `invalid ${path}; value does not match any allowed SDUI schema variant`,
        loc,
      },
    ];
  }

  const errors: FormFieldError[] = [];

  if (schema.type && !matchesSchemaType(value, schema.type)) {
    errors.push({
      code: "validate.invalid-view-payload",
      message: `invalid ${path}; expected ${formatSchemaType(schema.type)}`,
      loc,
    });
    return errors;
  }

  if (schema.enum && !schema.enum.includes(value)) {
    errors.push({
      code: "validate.invalid-view-payload",
      message: `invalid ${path}; expected one of ${schema.enum.map((item) => `'${String(item)}'`).join(", ")}`,
      loc,
    });
  }

  if (typeof value === "string" && schema.pattern && !new RegExp(schema.pattern).test(value)) {
    errors.push({
      code: "validate.invalid-view-payload",
      message: `invalid ${path}; value '${value}' does not match pattern ${schema.pattern}`,
      loc,
    });
  }

  if (Array.isArray(value)) {
    if (schema.minItems !== undefined && value.length < schema.minItems) {
      errors.push({
        code: "validate.invalid-view-payload",
        message: `invalid ${path}; expected at least ${schema.minItems} item(s)`,
        loc,
      });
    }
    if (schema.items) {
      value.forEach((item, index) => {
        errors.push(...validateSchemaNode(item, schema.items as JsonSchemaNode, loc, `${path}[${index}]`));
      });
    }
    return errors;
  }

  if (isRecord(value)) {
    for (const key of schema.required ?? []) {
      if (!(key in value)) {
        errors.push({
          code: "validate.invalid-view-payload",
          message: `invalid ${path}; missing required property '${key}'`,
          loc,
        });
      }
    }

    const properties = schema.properties ?? {};
    const additionalProperties = schema.additionalProperties;

    for (const [key, propertyValue] of Object.entries(value)) {
      const propertySchema = properties[key];
      if (propertySchema) {
        errors.push(...validateSchemaNode(propertyValue, propertySchema, loc, `${path}.${key}`));
        continue;
      }

      if (additionalProperties === false) {
        errors.push({
          code: "validate.invalid-view-payload",
          message: `invalid ${path}; unknown property '${key}'`,
          loc,
        });
        continue;
      }

      if (additionalProperties && typeof additionalProperties === "object") {
        errors.push(
          ...validateSchemaNode(propertyValue, additionalProperties as JsonSchemaNode, loc, `${path}.${key}`),
        );
      }
    }
  }

  return errors;
}

function matchesSchemaType(value: unknown, type: string | readonly string[]): boolean {
  const expected = Array.isArray(type) ? type : [type];
  return expected.some((candidate) => matchesSingleType(value, candidate));
}

function matchesSingleType(value: unknown, type: string): boolean {
  switch (type) {
    case "array":
      return Array.isArray(value);
    case "object":
      return isRecord(value);
    case "string":
      return typeof value === "string";
    case "boolean":
      return typeof value === "boolean";
    case "number":
      return typeof value === "number";
    case "null":
      return value === null;
    default:
      return true;
  }
}

function formatSchemaType(type: string | readonly string[]): string {
  return (Array.isArray(type) ? type : [type]).join(" | ");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
