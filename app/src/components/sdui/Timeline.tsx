import { useT } from "@/lib/i18n";

interface TimelineEvent {
  date: string;
  label: string;
  variant?: string;
  icon?: string;
}

const variantColors: Record<string, string> = {
  success: "bg-green-500",
  warning: "bg-amber-500",
  error: "bg-red-500",
  info: "bg-blue-500",
  default: "bg-muted-foreground",
};

export function Timeline({ events }: { events: TimelineEvent[] }) {
  const t = useT();

  if (!events?.length) return null;

  return (
    <div className="flex flex-col gap-0.5">
      {events.map((evt, i) => {
        const color = variantColors[evt.variant ?? "default"] ?? variantColors.default;
        const label = evt.label.includes(".") ? t(evt.label) : evt.label;
        const isLast = i === events.length - 1;

        return (
          <div key={i} className="flex gap-2.5 min-h-[24px]">
            {/* Dot + line */}
            <div className="flex flex-col items-center w-3 shrink-0">
              <div className={`w-2 h-2 rounded-full mt-1.5 shrink-0 ${color}`} />
              {!isLast && <div className="w-px flex-1 bg-border" />}
            </div>
            {/* Content */}
            <div className="flex-1 pb-2">
              <div className="flex items-baseline gap-2">
                <span className="text-xs font-medium">{label}</span>
                <span className="text-[10px] text-muted-foreground">{formatDate(evt.date)}</span>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function formatDate(d: string): string {
  try {
    return new Date(d).toLocaleDateString("fr-FR", { day: "numeric", month: "short" });
  } catch {
    return d;
  }
}
