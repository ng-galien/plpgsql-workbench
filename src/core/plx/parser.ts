import type {
  ActionDef,
  AppendStatement,
  ArrayLiteral,
  AssignStatement,
  CaseExpr,
  EntityField,
  EntityHook,
  EntityHookEvent,
  Expression,
  FieldAccess,
  ForInStatement,
  FormField,
  FormSection,
  FuncAttribute,
  Identifier,
  IfStatement,
  ImportAlias,
  JsonLiteral,
  Loc,
  MatchStatement,
  Param,
  PlxEntity,
  PlxFunction,
  PlxModule,
  PlxTrait,
  RaiseStatement,
  RelatedDef,
  ReturnMode,
  ReturnStatement,
  SqlBlockExpr,
  SqlStatement,
  StatDef,
  StateBlock,
  Statement,
  StateTransition,
  StrategyDecl,
  StringInterp,
  ViewBlock,
  ViewSection,
} from "./ast.js";
import type { Token, TokenType } from "./lexer.js";
import { sqlEscape } from "./util.js";

// Hoisted regexes for parseSqlBlock
const ELSE_RAISE_RE = /\nelse\s+raise\s+['"](.*?)['"]\s*$/i;
const TABLE_INFER_RE = /select\s+\*\s+from\s+(\w+\.\w+)/i;
const VALID_FUNC_ATTRS = new Set(["stable", "immutable", "volatile", "definer", "strict"]);

class ParseError extends Error {
  constructor(
    msg: string,
    public loc: Loc,
  ) {
    super(`plx:${loc.line}:${loc.col}: ${msg}`);
  }
}

export function parse(tokens: Token[]): PlxModule {
  const p = new Parser(tokens);
  return p.parseProgram();
}

class Parser {
  private pos = 0;

  constructor(private tokens: Token[]) {}

  parseProgram(): PlxModule {
    const imports: ImportAlias[] = [];
    const functions: PlxFunction[] = [];
    this.skipNewlines();

    // Parse imports at top of file
    while (this.isAt("IMPORT")) {
      imports.push(this.parseImport());
      this.skipNewlines();
    }

    const traits: PlxTrait[] = [];
    const entities: PlxEntity[] = [];

    while (!this.isAt("EOF")) {
      if (this.isAt("TRAIT")) {
        traits.push(this.parseTrait());
      } else if (this.isAt("ENTITY")) {
        entities.push(this.parseEntity());
      } else {
        functions.push(this.parseFunction());
      }
      this.skipNewlines();
    }
    return { imports, traits, entities, functions };
  }

  /** import original as alias */
  private parseImport(): ImportAlias {
    const loc = this.loc();
    this.expect("IMPORT");

    // Parse qualified name: ident or ident.ident
    let original = this.expect("IDENT").value;
    if (this.isAt("DOT")) {
      this.advance();
      original += `.${this.expect("IDENT").value}`;
    }

    this.expect("AS");
    const alias = this.expect("IDENT").value;
    this.skipNewlines();
    return { original, alias, loc };
  }

  // ---------- Trait parsing ----------

  private parseTrait(): PlxTrait {
    const loc = this.loc();
    this.expect("TRAIT");
    const name = this.expect("IDENT").value;
    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");

    const fields: PlxTrait["fields"] = [];
    const hooks: PlxTrait["hooks"] = [];
    let defaultScope: string | undefined;

    while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
      this.skipNewlines();
      if (this.isAt("DEDENT")) break;
      const kw = this.peek().value;

      if (kw === "fields") {
        this.advance();
        this.expect("COLON");
        this.skipNewlines();
        this.expect("INDENT");
        while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
          this.skipNewlines();
          if (this.isAt("DEDENT")) break;
          fields.push(this.parseFieldDef());
          this.skipNewlines();
        }
        this.expect("DEDENT");
      } else if (kw === "default_scope") {
        this.advance();
        this.expect("COLON");
        defaultScope = this.expect("IDENT", "STRING").value;
        this.skipNewlines();
      } else {
        // Skip unknown for now
        this.advance();
        this.skipNewlines();
      }
    }

    this.expect("DEDENT");
    return { kind: "trait", name, fields, hooks, defaultScope, loc };
  }

  private parseFieldDef(): PlxTrait["fields"][number] {
    const loc = this.loc();
    const name = this.expect("IDENT").value;
    let type = this.expect("IDENT").value;
    if (this.isAt("DOT")) {
      this.advance();
      type += `.${this.expect("IDENT").value}`;
    }
    let nullable = false;
    if (this.isAt("QUESTION")) {
      this.advance();
      nullable = true;
    }
    let defaultValue: string | undefined;
    if (this.isAt("IDENT") && this.peek().value === "default") {
      this.advance();
      this.expect("LPAREN");
      // Collect default expression tokens until )
      let expr = "";
      let depth = 1;
      while (depth > 0 && !this.isAt("EOF")) {
        const t = this.advance();
        if (t.type === "LPAREN") depth++;
        else if (t.type === "RPAREN") {
          depth--;
          if (depth === 0) break;
        }
        expr += (expr ? " " : "") + t.value;
      }
      defaultValue = expr;
    }
    return { name, type, nullable, defaultValue, loc };
  }

  // ---------- Entity parsing ----------

  private parseEntity(): PlxEntity {
    const loc = this.loc();
    this.expect("ENTITY");

    // schema.name
    const schema = this.expect("IDENT").value;
    this.expect("DOT");
    const name = this.expect("IDENT").value;

    // Optional: uses trait1, trait2
    const traits: string[] = [];
    if (this.isAt("USES")) {
      this.advance();
      traits.push(this.expect("IDENT").value);
      while (this.isAt("COMMA")) {
        this.advance();
        traits.push(this.expect("IDENT").value);
      }
    }

    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");

    // Entity body — key-value pairs and sub-blocks
    let table = `${schema}.${name}`;
    let uri = `${schema}://${name}`;
    let icon: string | undefined;
    let label = `${schema}.entity_${name}`;
    let listOrder = "id";
    let readKey: string | undefined;
    const fields: EntityField[] = [];
    let states: StateBlock | undefined;
    let updateStates: string[] | undefined;
    let view: ViewBlock = { compact: [] };
    const actions: ActionDef[] = [];
    const strategies: StrategyDecl[] = [];
    const hooks: EntityHook[] = [];

    while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
      this.skipNewlines();
      if (this.isAt("DEDENT") || this.isAt("EOF")) break;

      const kw = this.peek().value;

      if (kw === "table") {
        this.advance();
        this.expect("COLON");
        table = this.expect("IDENT").value;
        if (this.isAt("DOT")) {
          this.advance();
          table += `.${this.expect("IDENT").value}`;
        }
      } else if (kw === "uri") {
        this.advance();
        this.expect("COLON");
        uri = this.expect("STRING").value;
      } else if (kw === "icon") {
        this.advance();
        this.expect("COLON");
        icon = this.expect("STRING").value;
      } else if (kw === "label") {
        this.advance();
        this.expect("COLON");
        label = this.expect("STRING").value;
      } else if (kw === "list_order") {
        this.advance();
        this.expect("COLON");
        listOrder = this.expect("STRING").value;
      } else if (kw === "read_key") {
        this.advance();
        this.expect("COLON");
        readKey = this.expect("STRING").value;
      } else if (kw === "fields") {
        this.advance();
        this.expect("COLON");
        this.skipNewlines();
        this.expect("INDENT");
        while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
          this.skipNewlines();
          if (this.isAt("DEDENT")) break;
          fields.push(this.parseEntityField());
          this.skipNewlines();
        }
        this.expect("DEDENT");
      } else if (kw === "states") {
        states = this.parseStateBlock();
      } else if (kw === "update_states") {
        this.advance();
        this.expect("COLON");
        this.expect("LBRACKET");
        updateStates = [];
        while (!this.isAt("RBRACKET") && !this.isAt("EOF")) {
          updateStates.push(this.expect("IDENT").value);
          if (this.isAt("COMMA")) this.advance();
        }
        this.expect("RBRACKET");
      } else if (kw === "view") {
        view = this.parseViewBlock();
      } else if (kw === "actions") {
        this.advance();
        this.expect("COLON");
        this.skipNewlines();
        this.expect("INDENT");
        while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
          this.skipNewlines();
          if (this.isAt("DEDENT")) break;
          actions.push(this.parseActionDef());
          this.skipNewlines();
        }
        this.expect("DEDENT");
      } else if (kw === "strategies") {
        this.advance();
        this.expect("COLON");
        this.skipNewlines();
        this.expect("INDENT");
        while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
          this.skipNewlines();
          if (this.isAt("DEDENT")) break;
          strategies.push(this.parseStrategyDecl());
          this.skipNewlines();
        }
        this.expect("DEDENT");
      } else if (kw === "before" || kw === "after") {
        hooks.push(this.parseEntityHook());
      } else {
        // Unknown key — skip line
        this.advance();
      }
      this.skipNewlines();
    }

    this.expect("DEDENT");

    return {
      kind: "entity",
      schema,
      name,
      table,
      uri,
      icon,
      label,
      traits,
      fields,
      states,
      updateStates,
      view,
      actions,
      strategies,
      hooks,
      listOrder,
      readKey,
      loc,
    };
  }

  private parseEntityField(): EntityField {
    const loc = this.loc();
    const name = this.expect("IDENT").value;
    let type = this.expect("IDENT").value;
    if (this.isAt("DOT")) {
      this.advance();
      type += `.${this.expect("IDENT").value}`;
    }

    let nullable = false;
    let required = false;
    let unique = false;
    let createOnly = false;
    let readOnly = false;
    let defaultValue: string | undefined;

    // Parse modifiers: required, unique, create_only, read_only, default(...)
    while (this.isAt("IDENT") || this.isAt("QUESTION")) {
      if (this.isAt("QUESTION")) {
        this.advance();
        nullable = true;
        continue;
      }
      const mod = this.peek().value;
      if (mod === "required") {
        this.advance();
        required = true;
      } else if (mod === "unique") {
        this.advance();
        unique = true;
      } else if (mod === "create_only") {
        this.advance();
        createOnly = true;
      } else if (mod === "read_only") {
        this.advance();
        readOnly = true;
      } else if (mod === "default") {
        this.advance();
        this.expect("LPAREN");
        let expr = "";
        let depth = 1;
        while (depth > 0 && !this.isAt("EOF")) {
          const t = this.advance();
          if (t.type === "LPAREN") depth++;
          else if (t.type === "RPAREN") {
            depth--;
            if (depth === 0) break;
          }
          expr += (expr ? " " : "") + t.value;
        }
        defaultValue = expr;
      } else {
        break;
      }
    }

    return { name, type, nullable, required, unique, createOnly, readOnly, defaultValue, loc };
  }

  private parseStateBlock(): StateBlock {
    const loc = this.loc();
    this.advance(); // "states"

    // Parse state values: draft -> submitted -> validated -> reimbursed
    const values: string[] = [];
    values.push(this.expect("IDENT").value);
    while (this.isAt("ARROW")) {
      this.advance();
      values.push(this.expect("IDENT").value);
    }

    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");

    const transitions: StateTransition[] = [];
    while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
      this.skipNewlines();
      if (this.isAt("DEDENT")) break;

      const trLoc = this.loc();
      const trName = this.expect("IDENT").value;
      this.expect("LPAREN");
      const from = this.expect("IDENT").value;
      this.expect("ARROW");
      const to = this.expect("IDENT").value;
      this.expect("RPAREN");

      let guard: string | undefined;
      let body: Statement[] | undefined;

      // Optional colon + indent for guard/body
      if (this.isAt("COLON")) {
        this.advance();
        this.skipNewlines();
        this.expect("INDENT");
        while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
          this.skipNewlines();
          if (this.isAt("DEDENT")) break;
          if (this.peek().value === "guard") {
            this.advance();
            this.expect("COLON");
            // Collect guard expression as raw text until newline
            let guardExpr = "";
            while (!this.isAt("NEWLINE") && !this.isAt("DEDENT") && !this.isAt("EOF")) {
              guardExpr += (guardExpr ? " " : "") + this.advance().value;
            }
            guard = guardExpr;
          } else {
            // Body statement
            if (!body) body = [];
            body.push(this.parseStatement());
          }
          this.skipNewlines();
        }
        this.expect("DEDENT");
      }

      transitions.push({ name: trName, from, to, guard, body, loc: trLoc });
      this.skipNewlines();
    }

    this.expect("DEDENT");

    return { column: "status", initial: values[0]!, values, transitions, loc };
  }

  private parseViewBlock(): ViewBlock {
    this.advance(); // "view"
    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");

    let compact: string[] = [];
    let standard: ViewSection | undefined;
    let expanded: ViewSection | undefined;
    let form: FormSection[] | undefined;

    while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
      this.skipNewlines();
      if (this.isAt("DEDENT")) break;
      const kw = this.peek().value;

      if (kw === "compact") {
        this.advance();
        this.expect("COLON");
        compact = this.parseStringList();
      } else if (kw === "standard") {
        this.advance();
        this.expect("COLON");
        standard = this.parseViewSection();
      } else if (kw === "expanded") {
        this.advance();
        this.expect("COLON");
        expanded = this.parseViewSection();
      } else if (kw === "form") {
        this.advance();
        this.expect("COLON");
        form = this.parseFormSections();
      } else {
        this.advance(); // skip unknown
      }
      this.skipNewlines();
    }

    this.expect("DEDENT");
    return { compact, standard, expanded, form };
  }

  /** Parse [ident, ident, ...] as string names (NOT as PLX expressions) */
  private parseStringList(): string[] {
    this.expect("LBRACKET");
    this.skipExprWs();
    const items: string[] = [];
    while (!this.isAt("RBRACKET") && !this.isAt("EOF")) {
      // Accept ident or {key: ...} object as string
      if (this.isAt("IDENT")) {
        items.push(this.advance().value);
      } else if (this.isAt("LBRACE")) {
        // Skip complex field objects in compact — just capture the key
        this.advance();
        while (!this.isAt("RBRACE") && !this.isAt("EOF")) this.advance();
        this.expect("RBRACE");
      }
      this.skipExprWs();
      if (this.isAt("COMMA")) {
        this.advance();
        this.skipExprWs();
      }
    }
    this.expect("RBRACKET");
    return items;
  }

  private parseViewSection(): ViewSection {
    this.skipNewlines();
    // Can be inline [fields] or indented block with fields/stats/related
    if (this.isAt("LBRACKET")) {
      return { fields: this.parseStringList() };
    }

    this.expect("INDENT");
    let fields: string[] = [];
    let stats: StatDef[] | undefined;
    let related: RelatedDef[] | undefined;

    while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
      this.skipNewlines();
      if (this.isAt("DEDENT")) break;
      const kw = this.peek().value;

      if (kw === "fields") {
        this.advance();
        this.expect("COLON");
        fields = this.parseStringList();
      } else if (kw === "stats") {
        this.advance();
        this.expect("COLON");
        stats = this.parseStatDefs();
      } else if (kw === "related") {
        this.advance();
        this.expect("COLON");
        related = this.parseRelatedDefs();
      } else {
        this.advance();
      }
      this.skipNewlines();
    }
    this.expect("DEDENT");
    return { fields, stats, related };
  }

  private parseStatDefs(): StatDef[] {
    this.skipNewlines();
    this.expect("INDENT");
    const defs: StatDef[] = [];
    while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
      this.skipNewlines();
      if (this.isAt("DEDENT")) break;
      // {key: x, label: y}
      this.expect("LBRACE");
      let key = "";
      let label = "";
      while (!this.isAt("RBRACE") && !this.isAt("EOF")) {
        const k = this.expect("IDENT").value;
        this.expect("COLON");
        let v = this.expect("IDENT", "STRING").value;
        if (this.isAt("DOT")) {
          this.advance();
          v += `.${this.expect("IDENT").value}`;
        }
        if (k === "key") key = v;
        else if (k === "label") label = v;
        if (this.isAt("COMMA")) this.advance();
      }
      this.expect("RBRACE");
      defs.push({ key, label });
      this.skipNewlines();
    }
    this.expect("DEDENT");
    return defs;
  }

  private parseRelatedDefs(): RelatedDef[] {
    this.skipNewlines();
    this.expect("INDENT");
    const defs: RelatedDef[] = [];
    while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
      this.skipNewlines();
      if (this.isAt("DEDENT")) break;
      this.expect("LBRACE");
      let entity = "";
      let label = "";
      let filter = "";
      while (!this.isAt("RBRACE") && !this.isAt("EOF")) {
        const k = this.expect("IDENT").value;
        this.expect("COLON");
        const v = this.expect("IDENT", "STRING").value;
        if (k === "entity") entity = v;
        else if (k === "label") label = v;
        else if (k === "filter") filter = v;
        if (this.isAt("COMMA")) this.advance();
      }
      this.expect("RBRACE");
      defs.push({ entity, label, filter });
      this.skipNewlines();
    }
    this.expect("DEDENT");
    return defs;
  }

  private parseFormSections(): FormSection[] {
    this.skipNewlines();
    this.expect("INDENT");
    const sections: FormSection[] = [];
    while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
      this.skipNewlines();
      if (this.isAt("DEDENT")) break;
      // "section.label":
      const label = this.expect("STRING").value;
      this.expect("COLON");
      this.skipNewlines();
      this.expect("INDENT");
      const fields: FormField[] = [];
      while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
        this.skipNewlines();
        if (this.isAt("DEDENT")) break;
        fields.push(this.parseFormField());
        this.skipNewlines();
      }
      this.expect("DEDENT");
      sections.push({ label, fields });
      this.skipNewlines();
    }
    this.expect("DEDENT");
    return sections;
  }

  private parseFormField(): FormField {
    this.expect("LBRACE");
    this.skipExprWs();
    let key = "";
    let type = "text";
    let label = "";
    let required: boolean | undefined;
    while (!this.isAt("RBRACE") && !this.isAt("EOF")) {
      const k = this.expect("IDENT").value;
      this.expect("COLON");
      if (k === "required") {
        // boolean value
        const v = this.advance().value;
        required = v === "true";
      } else {
        let v = this.expect("IDENT", "STRING").value;
        // Qualified names: expense.field_name
        if (this.isAt("DOT")) {
          this.advance();
          v += `.${this.expect("IDENT").value}`;
        }
        if (k === "key") key = v;
        else if (k === "type") type = v;
        else if (k === "label") label = v;
      }
      this.skipExprWs();
      if (this.isAt("COMMA")) {
        this.advance();
        this.skipExprWs();
      }
    }
    this.expect("RBRACE");
    return { key, type, label, required };
  }

  private parseActionDef(): ActionDef {
    const name = this.expect("IDENT").value;
    this.expect("COLON");
    this.expect("LBRACE");
    this.skipExprWs();
    let label = "";
    let icon: string | undefined;
    let variant: string | undefined;
    let confirm: string | undefined;
    while (!this.isAt("RBRACE") && !this.isAt("EOF")) {
      const k = this.expect("IDENT").value;
      this.expect("COLON");
      let v = this.expect("IDENT", "STRING").value;
      if (this.isAt("DOT")) {
        this.advance();
        v += `.${this.expect("IDENT").value}`;
      }
      if (k === "label") label = v;
      else if (k === "icon") icon = v;
      else if (k === "variant") variant = v;
      else if (k === "confirm") confirm = v;
      this.skipExprWs();
      if (this.isAt("COMMA")) {
        this.advance();
        this.skipExprWs();
      }
    }
    this.expect("RBRACE");
    return { name, label, icon, variant, confirm };
  }

  private parseStrategyDecl(): StrategyDecl {
    const loc = this.loc();
    // slot.name: fn_name
    let slot = this.expect("IDENT").value;
    if (this.isAt("DOT")) {
      this.advance();
      slot += `.${this.expect("IDENT").value}`;
    }
    this.expect("COLON");
    let fn = this.expect("IDENT").value;
    if (this.isAt("DOT")) {
      this.advance();
      fn += `.${this.expect("IDENT").value}`;
    }
    return { slot, fn, loc };
  }

  private parseEntityHook(): EntityHook {
    const loc = this.loc();
    const event = this.advance().value; // "before" or "after"
    const action = this.expect("IDENT").value; // "create", "update"
    const hookEvent = `${event}_${action}` as EntityHookEvent;

    // Optional params: (p_row)
    const params: string[] = [];
    if (this.isAt("LPAREN")) {
      this.advance();
      while (!this.isAt("RPAREN") && !this.isAt("EOF")) {
        params.push(this.expect("IDENT").value);
        if (this.isAt("COMMA")) this.advance();
      }
      this.expect("RPAREN");
    }

    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");
    const body = this.parseBlock();
    this.expect("DEDENT");

    return { event: hookEvent, params, body, loc };
  }

  // ---------- Function parsing ----------

  private parseFunction(): PlxFunction {
    const loc = this.loc();
    this.expect("FN");

    const firstName = this.expect("IDENT").value;
    this.expect("DOT");
    const funcName = this.expect("IDENT").value;

    this.expect("LPAREN");
    const params = this.parseParams();
    this.expect("RPAREN");

    this.expect("ARROW");
    let setof = false;
    if (this.isAt("SETOF")) {
      this.advance();
      setof = true;
    }
    const returnType = this.parseType();

    // Optional attributes: [stable, definer]
    const attributes: FuncAttribute[] = [];
    if (this.isAt("LBRACKET")) {
      this.advance();
      while (!this.isAt("RBRACKET") && !this.isAt("EOF")) {
        const tok = this.expect("IDENT");
        const attr = tok.value.toLowerCase();
        if (!VALID_FUNC_ATTRS.has(attr)) {
          throw new ParseError(`unknown function attribute '${attr}' (valid: ${[...VALID_FUNC_ATTRS].join(", ")})`, {
            line: tok.line,
            col: tok.col,
          });
        }
        attributes.push(attr as FuncAttribute);
        if (this.isAt("COMMA")) this.advance();
      }
      this.expect("RBRACKET");
    }

    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");
    const body = this.parseBlock();
    this.expect("DEDENT");

    return { kind: "function", schema: firstName, name: funcName, params, returnType, setof, attributes, body, loc };
  }

  private parseParams(): Param[] {
    const params: Param[] = [];
    if (this.isAt("RPAREN")) return params;

    params.push(this.parseParam());
    while (this.isAt("COMMA")) {
      this.advance();
      params.push(this.parseParam());
    }
    return params;
  }

  private parseParam(): Param {
    const name = this.expect("IDENT").value;
    const type = this.parseType();
    let nullable = false;
    if (this.isAt("QUESTION")) {
      this.advance();
      nullable = true;
    }
    let defaultValue: string | undefined;
    if (this.isAt("OPERATOR") && this.peek().value === "=") {
      this.advance();
      const tok = this.peek();
      if (tok.type === "STRING") {
        this.advance();
        defaultValue = `'${sqlEscape(tok.value)}'`;
      } else if (tok.type === "NUMBER") {
        this.advance();
        defaultValue = tok.value;
      } else if (tok.type === "IDENT") {
        this.advance();
        // null → NULL, null on nullable type → NULL::type
        if (tok.value === "null") {
          defaultValue = nullable ? `NULL::${type}` : "NULL";
        } else {
          defaultValue = tok.value;
        }
      }
    }
    return { name, type, nullable, defaultValue };
  }

  private parseType(): string {
    let type = this.expect("IDENT").value;
    if (this.isAt("DOT")) {
      this.advance();
      type += `.${this.expect("IDENT").value}`;
    }
    if (this.isAt("LBRACKET") && this.peekAt(1)?.type === "RBRACKET") {
      this.advance();
      this.advance();
      type += "[]";
    }
    return type;
  }

  private parseBlock(): Statement[] {
    const stmts: Statement[] = [];
    this.skipNewlines();
    while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
      stmts.push(this.parseStatement());
      this.skipNewlines();
    }
    return stmts;
  }

  private parseStatement(): Statement {
    const tok = this.peek();

    if (tok.type === "IF") return this.parseIf();
    if (tok.type === "FOR") return this.parseFor();
    if (tok.type === "RETURN") return this.parseReturn();
    if (tok.type === "YIELD") return this.parseYield();
    if (tok.type === "RAISE") return this.parseRaise();
    if (tok.type === "MATCH") return this.parseMatch();
    if (tok.type === "SQL_BLOCK") return this.parseSqlStatement();

    if (tok.type === "IDENT") {
      const next = this.peekAt(1);
      if (next?.type === "ASSIGN") return this.parseAssign();
      if (next?.type === "APPEND") return this.parseAppend();
    }

    const expr = this.parseExpression();
    this.skipNewlines();
    return { kind: "assign", target: "_", value: expr, loc: expr.loc } as AssignStatement;
  }

  private parseAssign(): AssignStatement {
    const loc = this.loc();
    const target = this.expect("IDENT").value;
    this.expect("ASSIGN");

    if (this.isAt("SQL_BLOCK")) {
      const sqlTok = this.advance();
      const value = parseSqlBlock(sqlTok);
      this.skipNewlines();
      return { kind: "assign", target, value, loc };
    }

    const value = this.parseExpression();
    this.skipNewlines();
    return { kind: "assign", target, value, loc };
  }

  private parseAppend(): AppendStatement {
    const loc = this.loc();
    const target = this.expect("IDENT").value;
    this.expect("APPEND");
    const value = this.parseExpression();
    this.skipNewlines();
    return { kind: "append", target, value, loc };
  }

  private parseIf(): IfStatement {
    const loc = this.loc();
    this.expect("IF");
    const condition = this.parseExpression();
    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");
    const body = this.parseBlock();
    this.expect("DEDENT");
    this.skipNewlines();

    const elsifs: { condition: Expression; body: Statement[] }[] = [];
    while (this.isAt("ELSIF")) {
      this.advance();
      const elsifCond = this.parseExpression();
      this.expect("COLON");
      this.skipNewlines();
      this.expect("INDENT");
      const elsifBody = this.parseBlock();
      this.expect("DEDENT");
      this.skipNewlines();
      elsifs.push({ condition: elsifCond, body: elsifBody });
    }

    let elseBody: Statement[] | undefined;
    if (this.isAt("ELSE")) {
      this.advance();
      this.expect("COLON");
      this.skipNewlines();
      this.expect("INDENT");
      elseBody = this.parseBlock();
      this.expect("DEDENT");
      this.skipNewlines();
    }

    return { kind: "if", condition, body, elsifs, elseBody, loc };
  }

  private parseFor(): ForInStatement {
    const loc = this.loc();
    this.expect("FOR");
    const variable = this.expect("IDENT").value;
    this.expect("IN");

    if (this.isAt("SQL_BLOCK")) {
      const sqlTok = this.advance();
      this.expect("COLON");
      this.skipNewlines();
      this.expect("INDENT");
      const body = this.parseBlock();
      this.expect("DEDENT");
      return { kind: "for_in", variable, query: sqlTok.value, body, loc };
    }

    // Fallback: collect tokens until ":"
    const parts: string[] = [];
    while (!this.isAt("COLON") && !this.isAt("EOF")) {
      parts.push(this.advance().value);
    }
    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");
    const body = this.parseBlock();
    this.expect("DEDENT");

    return { kind: "for_in", variable, query: parts.join(" "), body, loc };
  }

  private parseReturn(): ReturnStatement {
    const loc = this.loc();
    this.expect("RETURN");

    // Bare return
    if (this.isAt("NEWLINE") || this.isAt("DEDENT") || this.isAt("EOF")) {
      return {
        kind: "return",
        value: { kind: "literal", value: null, type: "null", loc },
        isYield: false,
        mode: "value",
        loc,
      };
    }

    let mode: ReturnMode = "value";
    if (this.isAt("IDENT") && this.peek().value === "query") {
      this.advance();
      // return query execute → RETURN QUERY EXECUTE
      if (this.isAt("IDENT") && this.peek().value === "execute") {
        this.advance();
        mode = "execute";
      } else {
        mode = "query";
      }
    } else if (this.isAt("IDENT") && this.peek().value === "execute") {
      this.advance();
      mode = "execute";
    }

    // SQL block after return query (not execute — execute expects a string expression)
    if (mode === "query" && this.isAt("SQL_BLOCK")) {
      const sqlTok = this.advance();
      this.skipNewlines();
      return {
        kind: "return",
        value: { kind: "sql_block", sql: sqlTok.value, loc } as SqlBlockExpr,
        isYield: false,
        mode,
        loc,
      };
    }

    const value = this.parseExpression();
    this.skipNewlines();
    return { kind: "return", value, isYield: false, mode, loc };
  }

  private parseYield(): ReturnStatement {
    const loc = this.loc();
    this.expect("YIELD");
    const value = this.parseExpression();
    this.skipNewlines();
    return { kind: "return", value, isYield: true, mode: "value", loc };
  }

  private parseRaise(): RaiseStatement {
    const loc = this.loc();
    this.expect("RAISE");
    const msg = this.expect("STRING").value;
    this.skipNewlines();
    return { kind: "raise", message: msg, loc };
  }

  private parseMatch(): MatchStatement {
    const loc = this.loc();
    this.expect("MATCH");
    const subject = this.parseExpression();
    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");

    const arms: { pattern: Expression; body: Statement[] }[] = [];
    let elseBody: Statement[] | undefined;

    while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
      this.skipNewlines();
      if (this.isAt("DEDENT") || this.isAt("EOF")) break;

      if (this.isAt("ELSE")) {
        this.advance();
        this.expect("COLON", "ARROW");
        this.skipNewlines();
        this.expect("INDENT");
        elseBody = this.parseBlock();
        this.expect("DEDENT");
      } else {
        const pattern = this.parseExpression();
        this.expect("COLON", "ARROW");
        this.skipNewlines();
        this.expect("INDENT");
        const body = this.parseBlock();
        this.expect("DEDENT");
        arms.push({ pattern, body });
      }
      this.skipNewlines();
    }

    this.expect("DEDENT");
    return { kind: "match", subject, arms, elseBody, loc };
  }

  private parseSqlStatement(): SqlStatement {
    const loc = this.loc();
    const tok = this.advance();
    this.skipNewlines();
    return { kind: "sql_statement", sql: tok.value, loc };
  }

  // ---------- Expression parsing ----------

  private parseExpression(): Expression {
    return this.parseBinary();
  }

  private parseBinary(): Expression {
    let left = this.parsePrimary();

    while (true) {
      const tok = this.peek();
      if (tok.type === "OPERATOR") {
        const op = this.advance().value;
        const right = this.parsePrimary();
        left = { kind: "binary", op, left, right, loc: left.loc };
      } else if (tok.type === "IDENT" && (tok.value === "and" || tok.value === "or")) {
        const op = this.advance().value.toUpperCase();
        const right = this.parsePrimary();
        left = { kind: "binary", op, left, right, loc: left.loc };
      } else {
        break;
      }
    }

    return left;
  }

  private parsePrimary(): Expression {
    const tok = this.peek();

    if (tok.type === "CASE") return this.parseCaseExpr();
    if (tok.type === "LBRACE") return this.parseJsonLiteral();
    if (tok.type === "LBRACKET") return this.parseArrayLiteral();
    if (tok.type === "INTERP_STRING") return this.parseInterpString();

    if (tok.type === "STRING") {
      this.advance();
      return { kind: "literal", value: tok.value, type: "text", loc: { line: tok.line, col: tok.col } };
    }

    if (tok.type === "NUMBER") {
      this.advance();
      if (tok.value === "true" || tok.value === "false") {
        return { kind: "literal", value: tok.value === "true", type: "boolean", loc: { line: tok.line, col: tok.col } };
      }
      return { kind: "literal", value: Number(tok.value), type: "int", loc: { line: tok.line, col: tok.col } };
    }

    if (tok.type === "NOT") {
      this.advance();
      const expr = this.parsePrimary();
      return {
        kind: "binary",
        op: "NOT",
        left: { kind: "literal", value: true, type: "boolean", loc: { line: tok.line, col: tok.col } },
        right: expr,
        loc: { line: tok.line, col: tok.col },
      };
    }

    if (tok.type === "IDENT") {
      this.advance();
      const loc: Loc = { line: tok.line, col: tok.col };

      if (this.isAt("DOT")) {
        this.advance();
        const second = this.expect("IDENT").value;

        // schema.func(args)
        if (this.isAt("LPAREN")) {
          const args = this.parseArgList();
          return { kind: "call", name: `${tok.value}.${second}`, args, loc };
        }

        // ident.field.subfield
        if (this.isAt("DOT")) {
          this.advance();
          const subfield = this.expect("IDENT").value;
          const fa: Expression = { kind: "field_access", object: `${tok.value}.${second}`, field: subfield, loc };
          if (this.isAt("QUESTION")) {
            this.advance();
            return nullCheck(fa, loc);
          }
          return fa;
        }

        // ident.field?
        if (this.isAt("QUESTION")) {
          this.advance();
          return nullCheck({ kind: "field_access", object: tok.value, field: second, loc }, loc);
        }

        return { kind: "field_access", object: tok.value, field: second, loc };
      }

      // func(args)
      if (this.isAt("LPAREN")) {
        const args = this.parseArgList();
        return { kind: "call", name: tok.value, args, loc };
      }

      // ident?
      if (this.isAt("QUESTION")) {
        this.advance();
        return nullCheck({ kind: "identifier", name: tok.value, loc }, loc);
      }

      return { kind: "identifier", name: tok.value, loc };
    }

    if (tok.type === "LPAREN") {
      this.advance();
      const expr = this.parseExpression();
      this.expect("RPAREN");
      return expr;
    }

    throw new ParseError(`unexpected token: ${tok.type} '${tok.value}'`, { line: tok.line, col: tok.col });
  }

  /** Parse CASE expr WHEN val THEN result ... ELSE result END */
  private parseCaseExpr(): CaseExpr {
    const loc = this.loc();
    this.expect("CASE");
    const subject = this.parseExpression();
    this.skipExprWs();

    const arms: { pattern: Expression; result: Expression }[] = [];
    let elseResult: Expression | undefined;

    while (this.isAt("WHEN")) {
      this.advance();
      const pattern = this.parseExpression();
      this.expect("THEN");
      const result = this.parseExpression();
      arms.push({ pattern, result });
      this.skipExprWs();
    }

    if (this.isAt("ELSE")) {
      this.advance();
      elseResult = this.parseExpression();
      this.skipExprWs();
    }

    this.expect("END");
    return { kind: "case_expr", subject, arms, elseResult, loc };
  }

  private parseArgList(): Expression[] {
    this.expect("LPAREN");
    this.skipExprWs();
    const args: Expression[] = [];
    if (!this.isAt("RPAREN")) {
      args.push(this.parseExpression());
      this.skipExprWs();
      while (this.isAt("COMMA")) {
        this.advance();
        this.skipExprWs();
        args.push(this.parseExpression());
        this.skipExprWs();
      }
    }
    this.skipExprWs();
    this.expect("RPAREN");
    return args;
  }

  private parseJsonLiteral(): JsonLiteral {
    const loc = this.loc();
    this.expect("LBRACE");
    const entries: { key: string; value: Expression }[] = [];

    if (!this.isAt("RBRACE")) {
      entries.push(this.parseJsonEntry());
      while (this.isAt("COMMA")) {
        this.advance();
        if (this.isAt("RBRACE")) break;
        entries.push(this.parseJsonEntry());
      }
    }

    this.expect("RBRACE");
    return { kind: "json_literal", entries, loc };
  }

  private parseJsonEntry(): { key: string; value: Expression } {
    const key = this.expect("IDENT").value;
    if (!this.isAt("COLON")) {
      return { key, value: { kind: "identifier", name: key, loc: this.loc() } };
    }
    this.expect("COLON");
    return { key, value: this.parseExpression() };
  }

  private parseArrayLiteral(): ArrayLiteral {
    const loc = this.loc();
    this.expect("LBRACKET");
    const elements: Expression[] = [];
    if (!this.isAt("RBRACKET")) {
      elements.push(this.parseExpression());
      while (this.isAt("COMMA")) {
        this.advance();
        elements.push(this.parseExpression());
      }
    }
    this.expect("RBRACKET");
    return { kind: "array_literal", elements, loc };
  }

  private parseInterpString(): StringInterp {
    const tok = this.advance();
    const loc: Loc = { line: tok.line, col: tok.col };
    const parts: (string | Expression)[] = [];
    const raw = tok.value;

    let i = 0;
    let current = "";
    while (i < raw.length) {
      if (raw[i] === "#" && raw[i + 1] === "{") {
        if (current) {
          parts.push(current);
          current = "";
        }
        i += 2;
        let expr = "";
        let depth = 1;
        while (i < raw.length && depth > 0) {
          if (raw[i] === "{") depth++;
          if (raw[i] === "}") depth--;
          if (depth > 0) expr += raw[i];
          i++;
        }
        if (expr.includes(".")) {
          const [obj, field] = expr.split(".", 2);
          parts.push({ kind: "field_access", object: obj!, field: field!, loc } as FieldAccess);
        } else {
          parts.push({ kind: "identifier", name: expr, loc } as Identifier);
        }
      } else {
        current += raw[i];
        i++;
      }
    }
    if (current) parts.push(current);

    return { kind: "string_interp", parts, loc };
  }

  // ---------- Helpers ----------

  private peek(): Token {
    return this.tokens[this.pos] ?? { type: "EOF" as const, value: "", line: 0, col: 0 };
  }
  private peekAt(offset: number): Token | undefined {
    return this.tokens[this.pos + offset];
  }
  private loc(): Loc {
    const t = this.peek();
    return { line: t.line, col: t.col };
  }

  private isAt(type: TokenType): boolean {
    return this.peek().type === type;
  }

  private advance(): Token {
    const t = this.tokens[this.pos]!;
    this.pos++;
    return t;
  }

  private expect(...types: TokenType[]): Token {
    const tok = this.peek();
    if (types.length === 1 ? tok.type !== types[0] : !types.includes(tok.type)) {
      throw new ParseError(`expected ${types.join(" or ")}, got ${tok.type} '${tok.value}'`, {
        line: tok.line,
        col: tok.col,
      });
    }
    return this.advance();
  }

  private skipNewlines(): void {
    while (this.peek().type === "NEWLINE") this.pos++;
  }

  /** Skip NEWLINE + INDENT + DEDENT — for multi-line expressions inside parens/case */
  private skipExprWs(): void {
    while (this.peek().type === "NEWLINE" || this.peek().type === "INDENT" || this.peek().type === "DEDENT") {
      this.pos++;
    }
  }
}

function nullCheck(expr: Expression, loc: Loc): Expression {
  return {
    kind: "binary",
    op: "IS NOT NULL",
    left: expr,
    right: { kind: "literal", value: null, type: "null", loc },
    loc,
  };
}

function parseSqlBlock(tok: Token): SqlBlockExpr {
  let sql = tok.value;
  let elseRaise: string | undefined;
  let inferredTable: string | undefined;

  const elseMatch = sql.match(ELSE_RAISE_RE);
  if (elseMatch) {
    elseRaise = elseMatch[1];
    sql = sql.slice(0, elseMatch.index!).trim();
  }

  const tableMatch = sql.match(TABLE_INFER_RE);
  if (tableMatch) {
    inferredTable = tableMatch[1];
  }

  return { kind: "sql_block", sql: sql.trim(), elseRaise, inferredTable, loc: { line: tok.line, col: tok.col } };
}
