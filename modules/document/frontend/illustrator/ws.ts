// ============================================================
// WEBSOCKET — connection, message helpers
// ============================================================

import { showToast } from "./toast.js";
import { store, dispatch, getEventLog } from "./store/index.js";

const _onNextStateQueue: Array<() => void> = [];
let _lastStateJson = '';

/** Register a one-shot callback for the next state update (used by paste/delete undo) */
export function onNextStateUpdate(fn: () => void): void { _onNextStateQueue.push(fn); }

export function initWs(): void {
  connect();
}

function connect(): void {
  const ws = new WebSocket(`ws://${location.host}`);
  dispatch({ type: "SET_WS", ws });

  ws.onopen = () => {
    document.getElementById('statusDot')!.classList.add('connected');
  };
  ws.onclose = () => {
    document.getElementById('statusDot')!.classList.remove('connected');
    dispatch({ type: "SET_WS", ws: null });
    setTimeout(connect, 2000);
  };
  ws.onerror = () => {};
  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data);
    if (msg.type === 'reload') { location.reload(); return; }
    if (msg.type === 'toast') { showToast(msg.text, msg.level, msg.duration); return; }

    // Server requests (MCP audit/injection tools)
    if (msg.type === 'inspect_request') {
      const s = store.state;
      const slices = msg.slices as string[] | undefined;
      const resp: any = { type: 'inspect_response', _reqId: msg._reqId };
      if (!slices || slices.includes('phase')) resp.phase = s.phase;
      if (!slices || slices.includes('ui')) {
        resp.ui = {
          selectedIds: s.ui.selectedIds,
          showNames: s.ui.showNames,
          showBleed: s.ui.showBleed,
          snapEnabled: s.ui.snapEnabled,
          photoCollapsed: s.ui.photoCollapsed,
        };
      }
      if (!slices || slices.includes('doc')) {
        resp.doc = {
          name: s.doc.currentDoc?.name ?? null,
          elementCount: s.doc.currentDoc?.elements.length ?? 0,
          docListCount: s.doc.docList.length,
        };
      }
      if (!slices || slices.includes('ephemeral')) {
        resp.ephemeral = { snapGuideCount: s.ephemeral.snapGuides.length };
      }
      ws.send(JSON.stringify(resp));
      return;
    }
    if (msg.type === 'dispatch_request') {
      dispatch(msg.event);
      ws.send(JSON.stringify({
        type: 'dispatch_response',
        _reqId: msg._reqId,
        phase: store.state.phase,
        selectedIds: store.state.ui.selectedIds,
      }));
      return;
    }
    if (msg.type === 'log_request') {
      let entries = getEventLog();
      if (msg.filter) entries = entries.filter((e: any) => e.type.includes(msg.filter));
      if (msg.blocked_only) entries = entries.filter((e: any) => e.blocked);
      const limit = Math.min(msg.limit || 30, 200);
      entries = entries.slice(-limit);
      ws.send(JSON.stringify({ type: 'log_response', _reqId: msg._reqId, entries }));
      return;
    }

    if (msg.type === 'state') {
      const raw = e.data as string;
      if (raw === _lastStateJson) return;
      _lastStateJson = raw;

      dispatch({ type: "SERVER_STATE", doc: msg.doc, docList: msg.docList || [] });

      // Fire queued one-shot callbacks (paste/delete undo)
      if (_onNextStateQueue.length > 0) {
        const fns = _onNextStateQueue.splice(0);
        for (const fn of fns) fn();
      }

      const loader = document.getElementById('loader');
      if (loader && !loader.classList.contains('hidden')) setTimeout(() => loader.classList.add('hidden'), 2600);
    }
  };
}

export function wsSend(msg: object): void {
  const ws = store.state.refs.ws;
  if (ws && ws.readyState === 1) {
    ws.send(JSON.stringify(msg));
  }
}

export function sendUpdate(id: string, props: object): void { wsSend({ type: 'update_element', id, props }); }
export function sendDelete(id: string): void { wsSend({ type: 'delete_element', id }); }
export function sendClear(): void { wsSend({ type: 'clear_canvas' }); }
export function sendDeleteDoc(name: string): void { wsSend({ type: 'delete_document', name }); }
export function sendLoadDoc(name: string): void { wsSend({ type: 'load_document', name }); }
export function sendSave(): void { wsSend({ type: 'save_document' }); }
export function sendUpdateCanvas(props: object): void { wsSend({ type: 'update_canvas', ...props }); }
export function sendUpdateMeta(props: object): void { wsSend({ type: 'update_meta', ...props }); }

export function sendAddElement(element: any): void { wsSend({ type: 'add_element', element }); }
export function sendPasteElements(elements: any[]): void { wsSend({ type: 'paste_elements', elements }); }

export function setSelection(id: string | null, toggle = false): void {
  dispatch({ type: "SELECT_ELEMENT", id, toggle });
}
