// ============================================================
// UTILS — shared constants and utility functions
// ============================================================

export function esc(s: string): string {
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

export function showConfirmBar(refEl: HTMLElement, message: string, onConfirm: () => void): void {
  document.querySelectorAll('.confirm-bar').forEach(b => b.remove());
  const bar = document.createElement('div');
  bar.className = 'confirm-bar';
  bar.innerHTML = `<span class="confirm-msg">${message}</span><button class="confirm-yes">Oui</button><button class="confirm-no">Non</button>`;
  refEl.after(bar);
  requestAnimationFrame(() => bar.classList.add('visible'));
  const dismiss = () => { bar.classList.remove('visible'); setTimeout(() => bar.remove(), 180); };
  (bar.querySelector('.confirm-yes') as HTMLButtonElement).onclick = (e) => { e.stopPropagation(); bar.remove(); onConfirm(); };
  (bar.querySelector('.confirm-no') as HTMLButtonElement).onclick = (e) => { e.stopPropagation(); dismiss(); };
}
