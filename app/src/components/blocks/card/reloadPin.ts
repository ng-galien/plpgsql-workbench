import { crud } from "@/lib/api";
import type { PinnedCard } from "@/lib/store";

export async function reloadPin(pin: PinnedCard, updatePinData: (id: string, data: Record<string, unknown>) => void) {
  const res = await crud("get", pin.uri);
  const row = Array.isArray(res?.data) ? res.data[0] : res?.data;
  if (row) {
    if (res.actions) row.actions = res.actions;
    updatePinData(pin.id, row);
  }
}
