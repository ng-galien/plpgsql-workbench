export type ResourceKind = "function" | "table" | "trigger" | "type";

export class PlUri {
  readonly schema: string;
  readonly kind?: ResourceKind;
  readonly name?: string;

  private constructor(schema: string, kind?: ResourceKind, name?: string) {
    this.schema = schema;
    this.kind = kind;
    this.name = name;
  }

  // --- Factories ---

  static catalog(): string {
    return "plpgsql://";
  }

  static schema(schema: string): PlUri {
    return new PlUri(schema);
  }

  static resource(schema: string, kind: ResourceKind, name: string): PlUri {
    return new PlUri(schema, kind, name);
  }

  static fn(schema: string, name: string): PlUri {
    return new PlUri(schema, "function", name);
  }

  static table(schema: string, name: string): PlUri {
    return new PlUri(schema, "table", name);
  }

  static trigger(schema: string, name: string): PlUri {
    return new PlUri(schema, "trigger", name);
  }

  static type(schema: string, name: string): PlUri {
    return new PlUri(schema, "type", name);
  }

  // --- Parse ---

  static parse(uri: string): PlUri | null {
    // plpgsql://schema/kind/name
    const full = uri.match(/^plpgsql:\/\/(\w+)\/(\w+)\/(\w+)$/);
    if (full) {
      const kind = full[2]!;
      if (["function", "table", "trigger", "type"].includes(kind)) {
        return new PlUri(full[1]!, kind as ResourceKind, full[3]!);
      }
      return null;
    }
    // plpgsql://schema
    const schemaOnly = uri.match(/^plpgsql:\/\/(\w+)\/?$/);
    if (schemaOnly) {
      return new PlUri(schemaOnly[1]!);
    }
    return null;
  }

  // --- Serialize ---

  toString(): string {
    if (this.kind && this.name) {
      return `plpgsql://${this.schema}/${this.kind}/${this.name}`;
    }
    return `plpgsql://${this.schema}`;
  }
}
