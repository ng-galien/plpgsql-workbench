import { Link, Outlet, useLocation } from "react-router-dom";

const nav = [
  { href: "/", label: "Home" },
  { href: "/docs", label: "Documents" },
];

export function Layout() {
  const { pathname } = useLocation();

  return (
    <div style={{ minHeight: "100vh", display: "flex", flexDirection: "column" }}>
      <nav style={{
        padding: "0.5rem 1rem",
        borderBottom: "1px solid #e5e5e5",
        display: "flex",
        gap: "1rem",
        alignItems: "center",
        background: "#faf9f6"
      }}>
        <strong>Workbench</strong>
        {nav.map((n) => (
          <Link
            key={n.href}
            to={n.href}
            style={{
              textDecoration: "none",
              fontWeight: pathname === n.href ? 600 : 400,
              color: pathname === n.href ? "#b45309" : "#555",
            }}
          >
            {n.label}
          </Link>
        ))}
      </nav>
      <main style={{ flex: 1, padding: "1.5rem", maxWidth: "1100px", margin: "0 auto", width: "100%" }}>
        <Outlet />
      </main>
    </div>
  );
}
