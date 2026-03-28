import { X } from "lucide-react";
import { useT } from "@/lib/i18n";
import type { PinnedCard } from "@/lib/store";
import { fieldKey, getCompactDisplayName } from "@/lib/utils";
import { CardActions } from "./CardActions";
import { CardBody, FallbackBody } from "./CardBody";
import { CardMessages } from "./CardMessages";

export function PinCard({ pin, onClose }: { pin: PinnedCard; onClose: () => void }) {
  const t = useT();
  const data = pin.data;
  if (!data) return null;

  const view = pin.view;
  const tpl = view?.template?.standard;
  const compactKeys = view?.template?.compact?.fields?.map(fieldKey);
  const name = getCompactDisplayName(data, compactKeys);

  return (
    <div
      className="bg-card border rounded-lg shadow-sm w-80 flex flex-col overflow-hidden"
      data-debug={`canvas.pin[${pin.uri}]`}
    >
      <div className="px-4 py-3 border-b flex items-center gap-2">
        <span className="font-semibold text-sm truncate flex-1">{name}</span>
        <button onClick={onClose} className="text-muted-foreground hover:text-foreground">
          <X className="w-3.5 h-3.5" />
        </button>
      </div>

      <div className="px-4 py-3 text-sm flex flex-col gap-2">
        {tpl ? <CardBody data={data} tpl={tpl} view={view} t={t} /> : <FallbackBody data={data} />}
      </div>

      {pin.messages.length > 0 && <CardMessages messages={pin.messages} pin={pin} />}

      <CardActions pin={pin} data={data} view={view} t={t} />
    </div>
  );
}
