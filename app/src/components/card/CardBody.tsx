import { Currency } from "@/components/sdui/Currency";
import { Badge } from "@/components/ui/badge";
import type { ViewTemplate } from "@/lib/store";
import { fieldKey, fieldLabel, fieldType, formatDate, formatDatetime, resolveFieldLabel } from "@/lib/utils";

export function CardBody({
  data,
  tpl,
  view,
  t,
}: {
  data: Record<string, unknown>;
  tpl: NonNullable<NonNullable<ViewTemplate["template"]>["standard"]>;
  view: ViewTemplate | null;
  t: (key: string) => string;
}) {
  return (
    <>
      <div className="flex flex-col gap-1">
        {tpl.fields.map((f) => {
          const k = fieldKey(f);
          const val = data[k];
          if (val == null || val === "") return null;
          const ft = fieldType(f);
          const fl = fieldLabel(f);
          const label = fl ? t(fl) : resolveFieldLabel(k, view?.uri, view?.template?.form?.sections, t);
          return (
            <div key={k} className="flex justify-between gap-2">
              <span className="text-muted-foreground text-xs">{label}</span>
              <span className="text-xs text-right truncate max-w-[60%]">
                <FieldValue value={val} type={ft} />
              </span>
            </div>
          );
        })}
      </div>

      {tpl.stats && tpl.stats.length > 0 && (
        <div className="flex gap-3 pt-2 border-t mt-1">
          {tpl.stats.map((stat) => (
            <div key={stat.key} className="flex flex-col gap-0.5">
              <span
                className={`text-base font-bold ${stat.variant === "warning" ? "text-amber-600" : "text-foreground"}`}
              >
                {data[stat.key] != null ? String(data[stat.key]) : "—"}
              </span>
              <span className="text-[10px] text-muted-foreground">{t(stat.label)}</span>
            </div>
          ))}
        </div>
      )}

      {tpl.related && tpl.related.length > 0 && (
        <div className="flex gap-1.5 flex-wrap pt-2 border-t mt-1">
          {tpl.related.map((rel) => (
            <Badge
              key={rel.entity}
              variant="outline"
              className="text-[10px] font-normal cursor-pointer hover:bg-accent"
            >
              {t(rel.label)}
            </Badge>
          ))}
        </div>
      )}
    </>
  );
}

const HIDDEN_FIELDS = new Set(["id", "tenant_id", "created_at", "updated_at", "actions"]);

export function FallbackBody({ data }: { data: Record<string, unknown> }) {
  return (
    <>
      {Object.entries(data)
        .filter(([k]) => !HIDDEN_FIELDS.has(k))
        .slice(0, 8)
        .map(([key, val]) => (
          <div key={key} className="flex justify-between gap-2">
            <span className="text-muted-foreground text-xs">{key}</span>
            <span className="text-xs text-right truncate max-w-[60%]">{val == null ? "—" : String(val)}</span>
          </div>
        ))}
    </>
  );
}

function FieldValue({ value, type }: { value: unknown; type?: string }) {
  if (value === true)
    return (
      <Badge variant="default" className="text-[10px]">
        Yes
      </Badge>
    );
  if (value === false)
    return (
      <Badge variant="secondary" className="text-[10px]">
        No
      </Badge>
    );
  if (type === "date" && typeof value === "string") return <>{formatDate(value)}</>;
  if (type === "datetime" && typeof value === "string") return <>{formatDatetime(value)}</>;
  if (type === "currency" && typeof value === "number") return <Currency amount={value} />;
  if (typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value)) {
    return (
      <span className="inline-flex items-center gap-1">
        <span className="w-3 h-3 rounded-sm border inline-block" style={{ background: value }} />
        <code className="text-[10px]">{value}</code>
      </span>
    );
  }
  if (typeof value === "number" && Math.abs(value) >= 100) {
    return <Currency amount={value} />;
  }
  return <>{String(value)}</>;
}
