import { useEffect } from "react";
import { Link, Outlet, useLocation } from "react-router-dom";
import { useStore } from "../lib/store";
import { initRealtime } from "../lib/realtime";
import { Toast } from "./Toast";

export function Layout() {
  const { pathname } = useLocation();
  const modules = useStore((s) => s.modules);
  const loading = useStore((s) => s.loading);
  const loadModules = useStore((s) => s.loadModules);

  useEffect(() => {
    loadModules();
    const cleanup = initRealtime();
    return cleanup;
  }, []);

  const currentSchema = pathname.split("/")[1] || "";

  return (
    <div style={{ minHeight: "100vh", display: "flex", flexDirection: "column" }}>
      {/* App bar */}
      <nav style={{
        padding: "0 1rem",
        height: "2.5rem",
        borderBottom: "1px solid #e5e5e5",
        display: "flex",
        gap: "0.25rem",
        alignItems: "center",
        background: "#faf9f6",
        fontSize: "0.85rem",
        overflow: "hidden",
      }}>
        <Link to="/" style={{
          textDecoration: "none",
          fontWeight: 700,
          color: "#b45309",
          marginRight: "0.75rem",
        }}>
          ⬡
        </Link>
        {!loading && modules.map((m) => (
          <Link
            key={m.schema}
            to={`/${m.schema}/`}
            style={{
              textDecoration: "none",
              padding: "0.25rem 0.5rem",
              borderRadius: "4px",
              color: currentSchema === m.schema ? "#b45309" : "#555",
              background: currentSchema === m.schema ? "rgba(180,83,9,0.08)" : "transparent",
              fontWeight: currentSchema === m.schema ? 600 : 400,
            }}
          >
            {m.brand}
          </Link>
        ))}
      </nav>

      {/* Module nav */}
      {modules.filter((m) => m.schema === currentSchema).map((m) => (
        <nav key={m.schema} style={{
          padding: "0 1rem",
          height: "2rem",
          borderBottom: "1px solid #eee",
          display: "flex",
          gap: "1rem",
          alignItems: "center",
          fontSize: "0.8rem",
        }}>
          {m.items.map((item, i) => (
            <Link
              key={i}
              to={`/${m.schema}${item.href || "/"}`}
              style={{
                textDecoration: "none",
                color: "#666",
              }}
            >
              {item.label}
            </Link>
          ))}
        </nav>
      ))}

      {/* Content */}
      <main style={{ flex: 1, padding: "1.5rem", maxWidth: "1100px", margin: "0 auto", width: "100%" }}>
        <Outlet />
      </main>

      <Toast />
    </div>
  );
}
