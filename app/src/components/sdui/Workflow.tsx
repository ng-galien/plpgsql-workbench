import { useT } from "@/lib/i18n";

export function Workflow({ states, current }: { states: string[]; current: string }) {
  const t = useT();
  const currentIdx = states.indexOf(current);

  return (
    <div className="flex items-center gap-0.5 w-full">
      {states.map((state, i) => {
        const isCurrent = i === currentIdx;
        const isDone = i < currentIdx;
        const label = state.includes(".") ? t(state) : state;

        return (
          <div key={state} className="flex items-center gap-0.5 flex-1 min-w-0">
            {/* Step */}
            <div
              className={`flex items-center justify-center rounded-md px-2 py-1 text-[10px] font-medium truncate flex-1 transition-colors ${
                isCurrent
                  ? "bg-primary text-primary-foreground"
                  : isDone
                    ? "bg-primary/15 text-primary"
                    : "bg-muted text-muted-foreground"
              }`}
            >
              {label}
            </div>
            {/* Arrow */}
            {i < states.length - 1 && (
              <div className={`text-[8px] shrink-0 ${isDone ? "text-primary" : "text-muted-foreground/40"}`}>›</div>
            )}
          </div>
        );
      })}
    </div>
  );
}
