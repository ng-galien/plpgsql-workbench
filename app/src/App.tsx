import { useEffect } from "react";
import { useStore } from "@/lib/store";
import { useI18n } from "@/lib/i18n";
import { Sidebar } from "@/components/Sidebar";
import { Canvas } from "@/components/Canvas";
import { Overlay } from "@/components/Overlay";
import { Toast } from "@/components/Toast";
import { Annotate } from "@/components/Annotate";
import { initRealtime } from "@/lib/realtime";

export function App() {
  const loadModules = useStore((s) => s.loadModules);
  const loadI18n = useI18n((s) => s.load);

  useEffect(() => {
    loadModules();
    loadI18n();
    const cleanup = initRealtime();
    return cleanup;
  }, []);

  return (
    <div className="h-screen flex overflow-hidden">
      <Sidebar />
      <main className="flex-1 relative">
        <Canvas />
        <Overlay />
      </main>
      <Toast />
      <Annotate />
    </div>
  );
}
