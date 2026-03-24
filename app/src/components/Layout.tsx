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
    <div className="min-h-screen flex flex-col">
      {/* App bar */}
      <nav className="px-4 h-11 border-b flex items-center gap-1 bg-background/80 backdrop-blur-sm text-sm overflow-hidden sticky top-0 z-50">
        <Link
          to="/"
          className="no-underline font-bold text-primary mr-3 text-base"
        >
          ⬡
        </Link>
        {!loading &&
          modules.map((m) => (
            <Link
              key={m.schema}
              to={`/${m.schema}/`}
              className={`no-underline px-2.5 py-1 rounded-md transition-colors ${
                currentSchema === m.schema
                  ? "text-primary bg-primary/8 font-semibold"
                  : "text-muted-foreground hover:text-foreground hover:bg-accent"
              }`}
            >
              {m.brand}
            </Link>
          ))}
      </nav>

      {/* Module sub-nav */}
      {modules
        .filter((m) => m.schema === currentSchema)
        .map((m) => (
          <nav
            key={m.schema}
            className="px-4 h-9 border-b flex items-center gap-4 text-xs"
          >
            {m.items.map((item, i) => (
              <Link
                key={i}
                to={`/${m.schema}${item.href || "/"}`}
                className="no-underline text-muted-foreground hover:text-foreground transition-colors"
              >
                {item.label}
              </Link>
            ))}
          </nav>
        ))}

      {/* Content */}
      <main className="flex-1 py-6 px-6 max-w-5xl mx-auto w-full">
        <Outlet />
      </main>

      <Toast />
    </div>
  );
}
