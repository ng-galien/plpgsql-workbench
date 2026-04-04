import type { FormFieldValue, PlxEntity, ViewField, ViewSection } from "./ast.js";
import type { SduiActionMeta, SduiFormField, SduiTemplateLevel, SduiViewTemplate } from "./generated/sdui-contract.js";

export function buildEntityViewPayload(entity: PlxEntity): SduiViewTemplate {
  const compactFields = entity.view.compact.length > 0 ? entity.view.compact : entity.fields.map((field) => field.name);
  const standardSection = entity.view.standard ?? { fields: compactFields };
  const template: NonNullable<SduiViewTemplate["template"]> = {
    compact: buildTemplateLevel({ fields: compactFields }),
    standard: buildTemplateLevel(standardSection),
  };

  const payload: SduiViewTemplate = {
    uri: entity.uri,
    label: entity.label,
    entity_type: "crud",
    template,
  };

  if (entity.icon) payload.icon = entity.icon;
  if (entity.view.expanded) {
    template.expanded = buildTemplateLevel(entity.view.expanded);
  }
  if (entity.view.form) {
    template.form = {
      sections: entity.view.form.map((section) => ({
        label: section.label,
        fields: section.fields.map((field) => buildFormField(field.entries)),
      })),
    };
  }

  const actions = buildActions(entity);
  if (Object.keys(actions).length > 0) payload.actions = actions;

  return payload;
}

function buildTemplateLevel(section: ViewSection): SduiTemplateLevel {
  const level: SduiTemplateLevel = {
    fields: section.fields.map(buildViewField),
  };

  if (section.stats?.length) {
    level.stats = section.stats.map((stat) => ({
      key: stat.key,
      label: stat.label,
      ...(stat.variant ? { variant: stat.variant } : {}),
    }));
  }

  if (section.related?.length) {
    level.related = section.related.map((related) => ({
      entity: related.entity,
      label: related.label,
      filter: related.filter,
    }));
  }

  return level;
}

function buildViewField(field: ViewField): ViewField {
  return typeof field === "string" ? field : { ...field };
}

function buildFormField(entries: Record<string, FormFieldValue>): SduiFormField {
  return Object.fromEntries(
    Object.entries(entries).map(([key, value]) => [key, cloneFormFieldValue(value)]),
  ) as unknown as SduiFormField;
}

function cloneFormFieldValue(value: FormFieldValue): FormFieldValue {
  return typeof value === "object" && value !== null ? { ...value } : value;
}

function buildActions(entity: PlxEntity): Record<string, SduiActionMeta> {
  const actions = new Map<string, SduiActionMeta>();

  for (const action of entity.actions) {
    actions.set(action.name, {
      label: action.label,
      ...(action.icon ? { icon: action.icon } : {}),
      ...(action.variant ? { variant: action.variant as SduiActionMeta["variant"] } : {}),
      ...(action.confirm ? { confirm: action.confirm } : {}),
    });
  }

  if (entity.states) {
    for (const transition of entity.states.transitions) {
      if (actions.has(transition.name)) continue;
      actions.set(transition.name, {
        label: `${entity.schema}.action_${transition.name}`,
        variant: "primary",
      });
    }
  }

  return Object.fromEntries(actions);
}
