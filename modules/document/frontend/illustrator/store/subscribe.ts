// ============================================================
// STORE SUBSCRIBE — slice-level and selector-level helpers
// ============================================================

import type { AppState } from "./types.js";
import type { AppEvent } from "./events.js";
import { store } from "./store.js";

type SliceKey = keyof AppState;

/**
 * Subscribe to changes in specific slices only.
 * Listener fires only when at least one slice has a different reference.
 */
export function subscribeToSlices(
  slices: SliceKey[],
  listener: (state: AppState, event: AppEvent) => void,
): () => void {
  return store.subscribe((state, prevState, event) => {
    const changed = slices.some(key => state[key] !== prevState[key]);
    if (changed) listener(state, event);
  });
}

/**
 * Subscribe to a derived value (selector).
 * Listener fires only when the derived value changes (Object.is).
 */
export function subscribeToSelector<T>(
  selector: (s: AppState) => T,
  listener: (value: T, state: AppState, event: AppEvent) => void,
): () => void {
  let prevValue = selector(store.state);
  return store.subscribe((state, _prevState, event) => {
    const value = selector(state);
    if (!Object.is(value, prevValue)) {
      prevValue = value;
      listener(value, state, event);
    }
  });
}
