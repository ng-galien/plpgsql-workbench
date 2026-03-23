import { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import { get } from "../lib/api";

interface Page {
  doc_id: string;
  page_index: number;
  name: string;
  html: string;
}

interface DocData {
  id: string;
  name: string;
  slug: string;
  format: string;
  orientation: string;
  width: number;
  height: number;
  bg: string;
  status: string;
}

export function DocumentView() {
  const { slug } = useParams<{ slug: string }>();
  const [doc, setDoc] = useState<DocData | null>(null);
  const [pages, setPages] = useState<Page[]>([]);
  const [css, setCss] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!slug) return;

    // Load document
    get(`docs://document/${slug}`)
      .then((res) => {
        const d = res?.data;
        if (!d) throw new Error("Document not found");
        setDoc(d);

        // Load charte CSS if linked
        if (d.charte_id) {
          return get(`docs://charte/${d.charte_id}/tokens_to_css`).then((cssRes) => {
            setCss(cssRes?.data ?? "");
          });
        }
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));

    // Load pages separately (not in route_crud yet — use supabase direct)
    import("../lib/supabase").then(({ supabase }) => {
      supabase
        .schema("docs")
        .rpc("document_read", { p_id: slug })
        .then(({ data }) => {
          // document_read returns the row, we need pages separately
          // For now, fetch via direct table access
          supabase
            .from("page")
            .select("*")
            .eq("doc_id", data?.id ?? slug)
            .order("page_index")
            .then(({ data: pageData }) => {
              if (pageData) setPages(pageData);
            });
        });
    });
  }, [slug]);

  if (loading) return <p>Chargement...</p>;
  if (error) return <p style={{ color: "red" }}>Erreur: {error}</p>;
  if (!doc) return <p>Document introuvable.</p>;

  return (
    <div>
      <p><Link to="/docs">← Documents</Link></p>
      <h2>{doc.name}</h2>
      <p style={{ color: "#666", fontSize: "0.9rem" }}>
        {doc.format} {doc.orientation} · {doc.width}×{doc.height}mm ·
        <span style={{
          padding: "0.1rem 0.4rem",
          borderRadius: "3px",
          marginLeft: "0.3rem",
          background: doc.status === "draft" ? "#e7e5e4" : "#dcfce7",
          fontSize: "0.8rem",
        }}>
          {doc.status}
        </span>
      </p>

      {/* Charte CSS */}
      {css && <style dangerouslySetInnerHTML={{ __html: css }} />}

      {/* Pages */}
      {pages.map((page) => (
        <div
          key={page.page_index}
          style={{
            width: `${doc.width}mm`,
            height: `${doc.height}mm`,
            background: doc.bg,
            margin: "20px auto",
            boxShadow: "0 2px 8px rgba(0,0,0,0.12)",
            overflow: "hidden",
            position: "relative",
          }}
          dangerouslySetInnerHTML={{ __html: page.html }}
        />
      ))}
    </div>
  );
}
