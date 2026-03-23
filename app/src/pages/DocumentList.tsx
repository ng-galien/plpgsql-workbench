import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { get } from "../lib/api";

interface Doc {
  id: string;
  name: string;
  slug: string;
  format: string;
  orientation: string;
  status: string;
  category: string;
}

export function DocumentList() {
  const [docs, setDocs] = useState<Doc[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    get("docs://document")
      .then((res) => {
        setDocs(res?.data ?? []);
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <p>Chargement...</p>;
  if (error) return <p style={{ color: "red" }}>Erreur: {error}</p>;

  return (
    <div>
      <h2>Documents</h2>
      {docs.length === 0 ? (
        <p>Aucun document.</p>
      ) : (
        <table style={{ width: "100%", borderCollapse: "collapse" }}>
          <thead>
            <tr style={{ borderBottom: "2px solid #e5e5e5", textAlign: "left" }}>
              <th style={{ padding: "0.5rem" }}>Nom</th>
              <th style={{ padding: "0.5rem" }}>Format</th>
              <th style={{ padding: "0.5rem" }}>Catégorie</th>
              <th style={{ padding: "0.5rem" }}>Status</th>
            </tr>
          </thead>
          <tbody>
            {docs.map((doc) => (
              <tr key={doc.id} style={{ borderBottom: "1px solid #eee" }}>
                <td style={{ padding: "0.5rem" }}>
                  <Link to={`/docs/${doc.slug}`}>{doc.name}</Link>
                </td>
                <td style={{ padding: "0.5rem" }}>{doc.format} {doc.orientation}</td>
                <td style={{ padding: "0.5rem" }}>{doc.category}</td>
                <td style={{ padding: "0.5rem" }}>
                  <span style={{
                    padding: "0.15rem 0.5rem",
                    borderRadius: "4px",
                    fontSize: "0.8rem",
                    background: doc.status === "draft" ? "#e7e5e4" : "#dcfce7",
                    color: doc.status === "draft" ? "#44403c" : "#166534",
                  }}>
                    {doc.status}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
