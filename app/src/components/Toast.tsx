import { useStore } from "../lib/store";
import { useNavigate } from "react-router-dom";

const levelColors: Record<string, { bg: string; border: string }> = {
  success: { bg: "#dcfce7", border: "#166534" },
  error: { bg: "#fee2e2", border: "#991b1b" },
  warning: { bg: "#fef3c7", border: "#92400e" },
  info: { bg: "#dbeafe", border: "#1e40af" },
};

export function Toast() {
  const toast = useStore((s) => s.toast);
  const clearToast = useStore((s) => s.clearToast);
  const navigate = useNavigate();

  if (!toast) return null;

  const colors = levelColors[toast.level] ?? levelColors.info;

  return (
    <div
      style={{
        position: "fixed",
        bottom: "1.5rem",
        right: "1.5rem",
        background: colors.bg,
        borderLeft: `4px solid ${colors.border}`,
        padding: "0.75rem 1rem",
        borderRadius: "6px",
        boxShadow: "0 4px 12px rgba(0,0,0,0.15)",
        maxWidth: "400px",
        zIndex: 9999,
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "start" }}>
        <strong>{toast.msg}</strong>
        <button
          onClick={clearToast}
          style={{ background: "none", border: "none", cursor: "pointer", fontSize: "1.1rem" }}
        >
          ×
        </button>
      </div>
      {toast.detail && (
        <div style={{ fontSize: "0.85rem", color: "#666", marginTop: "0.25rem" }}>
          {toast.detail}
        </div>
      )}
      {toast.href && (
        <a
          href={toast.href}
          onClick={(e) => {
            e.preventDefault();
            clearToast();
            navigate(toast.href!);
          }}
          style={{ fontSize: "0.85rem", marginTop: "0.25rem", display: "inline-block" }}
        >
          Ouvrir →
        </a>
      )}
    </div>
  );
}
