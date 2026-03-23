import { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import { supabase } from "../lib/supabase";

interface Page {
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
  charte_id: string | null;
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

    async function load() {
      // 1. Load document by slug
      const { data: docData, error: docErr } = await supabase
        .schema("docs")
        .rpc("document_read", { p_id: slug });

      if (docErr) throw docErr;
      if (!docData) throw new Error("Document not found");
      setDoc(docData);

      // 2. Load pages
      const { data: pageData } = await supabase
        .schema("docs")
        .from("page")
        .select("page_index, name, html")
        .eq("doc_id", docData.id)
        .order("page_index");

      setPages(pageData ?? []);

      // 3. Load charte CSS if linked
      if (docData.charte_id) {
        const { data: cssData } = await supabase
          .schema("docs")
          .rpc("charte_tokens_to_css", { p_charte_id: docData.charte_id });

        setCss(cssData ?? "");
      }
    }

    load()
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [slug]);

  if (loading) return <p>Chargement...</p>;
  if (error) return <p style={{ color: "red" }}>Erreur: {error}</p>;
  if (!doc) return <p>Document introuvable.</p>;

  return (
    <div>
      <p><Link to="/docs">← Documents</Link></p>
      <h2>{doc.name}</h2>
      <p style={{ color: "#666", fontSize: "0.9rem" }}>
        {doc.format} {doc.orientation} · {doc.width}×{doc.height}mm ·{" "}
        <span style={{
          padding: "0.1rem 0.4rem",
          borderRadius: "3px",
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
        <div key={page.page_index} style={{ marginBottom: "20px" }}>
          <h4 style={{ color: "#888", fontSize: "0.85rem" }}>
            Page {page.page_index + 1} — {page.name}
          </h4>
          <div
            style={{
              width: `${doc.width}mm`,
              height: `${doc.height}mm`,
              background: doc.bg,
              margin: "0 auto",
              boxShadow: "0 2px 8px rgba(0,0,0,0.12)",
              overflow: "hidden",
            }}
            dangerouslySetInnerHTML={{ __html: page.html }}
          />
        </div>
      ))}
    </div>
  );
}
