import type { LucideIcon } from "lucide-react";
import { icons } from "lucide-react";
import { useMemo } from "react";
import { useT } from "@/lib/i18n";
import type { Module } from "@/lib/store";
import { useStore } from "@/lib/store";
import { Settings } from "lucide-react";

function Icon({ name, className }: { name?: string; className?: string }) {
  if (!name) return <span className={className}>·</span>;
  const pascal = name.replace(/(^|-)([a-z])/g, (_, _p, c: string) => c.toUpperCase());
  const LucideComp = icons[pascal as keyof typeof icons] as LucideIcon | undefined;
  if (!LucideComp) return <span className={className}>·</span>;
  return <LucideComp className={className} />;
}

const groupOrder = ["main", "commercial", "operations", "finance", "team", "admin"];

export function Sidebar() {
  const modules = useStore((s) => s.modules);
  const loading = useStore((s) => s.loading);
  const view = useStore((s) => s.view);
  const setView = useStore((s) => s.setView);
  const openOverlay = useStore((s) => s.openOverlay);
  const t = useT();

  const sortedGroups = useMemo(() => {
    const grouped = new Map<string, Module[]>();
    for (const m of modules) {
      const group = m.group ?? "main";
      if (!grouped.has(group)) grouped.set(group, []);
      grouped.get(group)!.push(m);
    }
    return Array.from(grouped.entries()).sort(([a], [b]) => {
      const ai = groupOrder.indexOf(a);
      const bi = groupOrder.indexOf(b);
      return (ai === -1 ? 99 : ai) - (bi === -1 ? 99 : bi);
    });
  }, [modules]);

  return (
    <aside className="w-52 bg-card border-r flex flex-col shrink-0 h-screen" data-debug="sidebar">
      <div className="px-4 h-12 flex items-center border-b">
        <span className="font-bold text-primary text-base">⬡ Kernail</span>
      </div>

      <div className="px-3 pt-3">
        <div className="px-3 py-1.5 bg-muted rounded-md text-xs text-muted-foreground flex items-center gap-2 cursor-pointer hover:bg-accent transition-colors">
          <span className="opacity-50">⌘K</span>
          <span>{t("app.search")}</span>
        </div>
      </div>

      <nav className="flex-1 overflow-auto px-3 py-3 flex flex-col gap-0.5 text-sm">
        {loading ? (
          <span className="text-xs text-muted-foreground px-2">Loading...</span>
        ) : (
          sortedGroups.map(([group, mods]) => (
            <div key={group} className="flex flex-col gap-0.5">
              {group !== "main" && (
                <>
                  <div className="h-px bg-border mx-2 mt-3 mb-1" />
                  <span className="text-[10px] text-muted-foreground uppercase tracking-widest font-semibold px-2 mb-1">
                    {t(`app.group_${group}`)}
                  </span>
                </>
              )}
              {mods.map((m) => (
                <ModuleNav key={m.schema} module={m} onOpen={openOverlay} t={t} />
              ))}
            </div>
          ))
        )}
      </nav>

      <div className="px-3 py-3 border-t flex flex-col gap-2">
        <button
          onClick={() => setView(view === "admin" ? "workspace" : "admin")}
          className={`w-full text-left px-2 py-1.5 rounded-md text-sm flex items-center gap-2 transition-colors ${
            view === "admin"
              ? "bg-primary/10 text-primary font-medium"
              : "text-muted-foreground hover:text-foreground hover:bg-accent"
          }`}
        >
          <Settings className="w-4 h-4" />
          <span>Admin</span>
        </button>
        <div className="px-2 py-1.5 bg-muted rounded-md flex items-center gap-2">
          <div className="w-6 h-6 rounded-full bg-gradient-to-br from-primary to-blue-500 flex items-center justify-center text-[10px] text-white font-bold shrink-0">
            AB
          </div>
          <span className="text-xs font-medium truncate">Alexandre</span>
        </div>
      </div>
    </aside>
  );
}

function ModuleNav({
  module: m,
  onOpen,
  t,
}: {
  module: Module;
  onOpen: (uri: string, mode?: "list" | "create") => void;
  t: (key: string) => string;
}) {
  return (
    <>
      {m.items
        .filter((item) => item.entity)
        .map((item, i) => {
          const uri = item.uri || `${m.schema}://${item.entity}`;
          return (
            <button
              key={i}
              onClick={() => onOpen(uri)}
              data-debug={`sidebar.item[${uri}]`}
              className="w-full text-left px-2 py-1.5 rounded-md text-sm text-muted-foreground hover:text-foreground hover:bg-accent transition-colors flex items-center gap-2"
            >
              <Icon name={item.icon} className="w-4 h-4 opacity-50" />
              <span className="truncate">{item.label ? t(item.label) : item.entity}</span>
            </button>
          );
        })}
    </>
  );
}
