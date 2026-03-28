import { Pin } from "lucide-react";
import { useStore } from "@/lib/store";
import { PinCard } from "./card/PinCard";

export function Canvas() {
  const pins = useStore((s) => s.pins);
  const unpin = useStore((s) => s.unpin);

  if (pins.length === 0) {
    return (
      <div className="h-full flex items-center justify-center bg-muted/30">
        <div className="text-center text-muted-foreground">
          <Pin className="w-8 h-8 mx-auto mb-3 opacity-30" />
          <p className="text-lg font-medium mb-1">Workspace</p>
          <p className="text-sm">Select an item from the sidebar to pin it here.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full bg-muted/30 relative overflow-auto p-6">
      <div className="flex flex-wrap gap-4 items-start">
        {pins.map((pin) => (
          <PinCard key={pin.id} pin={pin} onClose={() => unpin(pin.id)} />
        ))}
      </div>
    </div>
  );
}
