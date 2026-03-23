import { useEffect, useState } from "react";
import { useParams, Link, useNavigate } from "react-router-dom";
import { get } from "../lib/api";

interface Column {
  name: string;
  type: string;
  comment: string | null;
  nullable: boolean;
}

interface Action {
  verb?: string;
  method?: string;
  uri: string;
}

/** Generic list page — driven by route_crud + schema_inspect */
export function CrudList({ schema, entity }: { schema: string; entity: string }) {
  const [rows, setRows] = useState<Record<string, unknown>[]>([]);
  const [columns, setColumns] = useState<Column[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([
      get(`${schema}://${entity}`),
      get(`${schema}://${entity}#schema`),
    ])
      .then(([listRes, schemaRes]) => {
        setRows(listRes?.data ?? []);
        // Pick visible columns: skip tenant_id, id, created_at, updated_at
        const hide = new Set(["tenant_id", "created_at", "updated_at"]);
        const cols = (schemaRes?.data?.columns ?? []).filter(
          (c: Column) => !hide.has(c.name)
        );
        setColumns(cols.slice(0, 8)); // max 8 columns for readability
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [schema, entity]);

  if (loading) return <p>Chargement...</p>;
  if (error) return <p style={{ color: "red" }}>{error}</p>;

  const slugCol = columns.find((c) => c.name === "slug");
  const nameCol = columns.find((c) => c.name === "name") ?? columns[0];
  const displayCols = columns.filter(
    (c) => c.name !== "id" && c.name !== "slug"
  );

  return (
    <div>
      <h2 style={{ textTransform: "capitalize" }}>{entity}s</h2>
      {rows.length === 0 ? (
        <p style={{ color: "#888" }}>Aucun {entity}.</p>
      ) : (
        <table style={{ width: "100%", borderCollapse: "collapse" }}>
          <thead>
            <tr style={{ borderBottom: "2px solid #e5e5e5", textAlign: "left" }}>
              {displayCols.map((col) => (
                <th key={col.name} style={{ padding: "0.5rem", fontSize: "0.85rem", color: "#666" }}>
                  {col.comment?.split("—")[0]?.trim() || col.name}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row, i) => {
              const slug = (slugCol ? row.slug : row.id) as string;
              return (
                <tr key={i} style={{ borderBottom: "1px solid #eee" }}>
                  {displayCols.map((col) => {
                    const val = row[col.name];
                    const isName = col.name === nameCol?.name;
                    return (
                      <td key={col.name} style={{ padding: "0.5rem" }}>
                        {isName ? (
                          <Link to={`/${schema}/${entity}/${slug}`}>
                            {String(val ?? "")}
                          </Link>
                        ) : (
                          <CellValue value={val} type={col.type} />
                        )}
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </div>
  );
}

/** Generic detail page */
export function CrudDetail({ schema, entity }: { schema: string; entity: string }) {
  const { slug } = useParams<{ slug: string }>();
  const navigate = useNavigate();
  const [data, setData] = useState<Record<string, unknown> | null>(null);
  const [columns, setColumns] = useState<Column[]>([]);
  const [actions, setActions] = useState<Action[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!slug) return;
    Promise.all([
      get(`${schema}://${entity}/${slug}`),
      get(`${schema}://${entity}#schema`),
    ])
      .then(([readRes, schemaRes]) => {
        setData(readRes?.data ?? null);
        setActions(readRes?.actions ?? []);
        const hide = new Set(["tenant_id", "created_at", "updated_at", "id"]);
        setColumns(
          (schemaRes?.data?.columns ?? []).filter((c: Column) => !hide.has(c.name))
        );
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [schema, entity, slug]);

  if (loading) return <p>Chargement...</p>;
  if (error) return <p style={{ color: "red" }}>{error}</p>;
  if (!data) return <p>{entity} introuvable.</p>;

  return (
    <div>
      <p>
        <Link to={`/${schema}/${entity}`}>← {entity}s</Link>
      </p>
      <h2>{String(data.name ?? data.slug ?? slug)}</h2>

      <dl style={{ display: "grid", gridTemplateColumns: "200px 1fr", gap: "0.25rem 1rem" }}>
        {columns.map((col) => {
          const val = data[col.name];
          if (val === null || val === undefined) return null;
          return (
            <div key={col.name} style={{ display: "contents" }}>
              <dt style={{ color: "#888", fontSize: "0.85rem", padding: "0.25rem 0" }}>
                {col.comment?.split("—")[0]?.trim() || col.name}
              </dt>
              <dd style={{ margin: 0, padding: "0.25rem 0" }}>
                <CellValue value={val} type={col.type} />
              </dd>
            </div>
          );
        })}
      </dl>

      {/* HATEOAS actions */}
      {actions.length > 0 && (
        <div style={{ marginTop: "1.5rem", display: "flex", gap: "0.5rem" }}>
          {actions.map((a, i) => (
            <button
              key={i}
              onClick={() => {
                if (a.verb === "delete") {
                  if (confirm(`Supprimer ${entity} ?`)) {
                    import("../lib/api").then(({ crud }) => {
                      crud("delete", a.uri).then(() => navigate(`/${schema}/${entity}`));
                    });
                  }
                } else if (a.method) {
                  import("../lib/api").then(({ crud }) => {
                    crud("post", a.uri).then((res) => {
                      alert(JSON.stringify(res?.data, null, 2));
                    });
                  });
                }
              }}
              style={{
                padding: "0.4rem 0.8rem",
                border: "1px solid #ddd",
                borderRadius: "4px",
                background: a.verb === "delete" ? "#fee2e2" : "#fff",
                cursor: "pointer",
                fontSize: "0.85rem",
              }}
            >
              {a.method ?? a.verb}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

/** Render a cell value based on PG type */
function CellValue({ value, type }: { value: unknown; type: string }) {
  if (value === null || value === undefined) return <span style={{ color: "#ccc" }}>—</span>;

  // Boolean
  if (type === "bool") return <span>{value ? "✓" : "—"}</span>;

  // Badge for status-like text
  if (type === "text" && typeof value === "string" && ["draft", "generated", "signed", "archived", "active", "inactive"].includes(value)) {
    const colors: Record<string, { bg: string; fg: string }> = {
      draft: { bg: "#e7e5e4", fg: "#44403c" },
      generated: { bg: "#dbeafe", fg: "#1e40af" },
      signed: { bg: "#dcfce7", fg: "#166534" },
      archived: { bg: "#f3f4f6", fg: "#6b7280" },
      active: { bg: "#dcfce7", fg: "#166534" },
      inactive: { bg: "#fee2e2", fg: "#991b1b" },
    };
    const c = colors[value] ?? colors.draft;
    return (
      <span style={{ padding: "0.1rem 0.4rem", borderRadius: "3px", background: c.bg, color: c.fg, fontSize: "0.8rem" }}>
        {value}
      </span>
    );
  }

  // Color swatch
  if (typeof value === "string" && /^#[0-9a-fA-F]{3,8}$/.test(value)) {
    return (
      <span style={{ display: "inline-flex", alignItems: "center", gap: "0.4rem" }}>
        <span style={{ width: 16, height: 16, borderRadius: 3, background: value, border: "1px solid #ddd", display: "inline-block" }} />
        <code style={{ fontSize: "0.8rem" }}>{value}</code>
      </span>
    );
  }

  // Array
  if (Array.isArray(value)) {
    return <span>{value.join(", ")}</span>;
  }

  // JSON
  if (typeof value === "object") {
    return <code style={{ fontSize: "0.75rem" }}>{JSON.stringify(value)}</code>;
  }

  return <span>{String(value)}</span>;
}
