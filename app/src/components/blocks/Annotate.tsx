import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

interface AnnotationTarget {
  element: HTMLElement;
  debug: string;
  rect: DOMRect;
}

export function Annotate() {
  const [active, setActive] = useState(false);
  const [target, setTarget] = useState<AnnotationTarget | null>(null);
  const [message, setMessage] = useState("");
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState(false);

  // Toggle with Ctrl+Shift+A
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.ctrlKey && e.shiftKey && e.key === "A") {
        e.preventDefault();
        setActive((a) => !a);
        setTarget(null);
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, []);

  // Click handler in annotation mode
  const handleClick = useCallback(
    (e: MouseEvent) => {
      if (!active) return;

      const popover = (e.target as HTMLElement).closest("[data-annotate-popover]");
      if (popover) return;

      e.preventDefault();
      e.stopPropagation();

      let el = e.target as HTMLElement | null;
      while (el && !el.dataset.debug) {
        el = el.parentElement;
      }

      if (el) {
        setTarget({
          element: el,
          debug: el.dataset.debug!,
          rect: el.getBoundingClientRect(),
        });
        setMessage("");
      }
    },
    [active],
  );

  useEffect(() => {
    if (active) {
      document.addEventListener("click", handleClick, true);
      document.body.style.cursor = "crosshair";
    } else {
      document.body.style.cursor = "";
    }
    return () => {
      document.removeEventListener("click", handleClick, true);
      document.body.style.cursor = "";
    };
  }, [active, handleClick]);

  const send = async () => {
    if (!target || !message.trim()) return;
    setSending(true);
    const { error } = await supabase
      .schema("workbench")
      .from("issue_report")
      .insert({
        issue_type: "bug",
        module: "lead",
        description: message.trim(),
        context: {
          element_id: target.debug,
          page: window.location.pathname,
          source: "browser_annotation",
        },
      });
    setSending(false);
    if (!error) {
      setSent(true);
      setTimeout(() => {
        setTarget(null);
        setMessage("");
        setSent(false);
      }, 800);
    } else {
      console.error("Issue report failed:", error.message);
    }
  };

  if (!active && !target) return null;

  return (
    <>
      {active && !target && (
        <div className="fixed top-2 right-2 z-50 px-3 py-1.5 bg-destructive text-white text-xs rounded-md shadow-lg flex items-center gap-2">
          <span className="w-2 h-2 bg-white rounded-full animate-pulse" />
          Report mode — click an element
          <button onClick={() => setActive(false)} className="ml-2 opacity-70 hover:opacity-100">
            ×
          </button>
        </div>
      )}

      {active && target && (
        <>
          <div
            className="fixed z-50 border-2 border-destructive rounded pointer-events-none"
            style={{
              top: target.rect.top - 2,
              left: target.rect.left - 2,
              width: target.rect.width + 4,
              height: target.rect.height + 4,
            }}
          />

          <div
            data-annotate-popover
            className="fixed z-50 bg-card border rounded-lg shadow-xl p-3 flex flex-col gap-2 w-72"
            style={{
              top: Math.min(target.rect.bottom + 8, window.innerHeight - 160),
              left: Math.min(target.rect.left, window.innerWidth - 300),
            }}
          >
            <div className="text-xs text-muted-foreground font-mono truncate">{target.debug}</div>
            <textarea
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder="What's wrong?"
              className="w-full px-2 py-1.5 bg-muted rounded text-sm border-none outline-none resize-none"
              rows={2}
              autoFocus
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  send();
                }
                if (e.key === "Escape") {
                  setTarget(null);
                }
              }}
            />
            <div className="flex justify-between items-center">
              <button onClick={() => setTarget(null)} className="text-xs text-muted-foreground hover:text-foreground">
                Cancel
              </button>
              <button
                onClick={send}
                disabled={sending || !message.trim()}
                className="px-3 py-1 bg-primary text-primary-foreground text-xs rounded-md disabled:opacity-50"
              >
                {sent ? "Sent!" : sending ? "..." : "Send (↵)"}
              </button>
            </div>
          </div>
        </>
      )}
    </>
  );
}
