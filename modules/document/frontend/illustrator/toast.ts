// ============================================================
// TOAST — notification system
// ============================================================

import "./styles/toast.css";

let toastContainer: HTMLDivElement;

export function initToast(): void {
  toastContainer = document.createElement('div');
  toastContainer.className = 'toast-container';
  document.body.appendChild(toastContainer);
}

export function showToast(text: string, level = 'info', duration = 3000): void {
  const el = document.createElement('div');
  el.className = `toast toast-${level}`;
  el.textContent = text;
  toastContainer.appendChild(el);
  requestAnimationFrame(() => el.classList.add('visible'));
  setTimeout(() => {
    el.classList.remove('visible');
    el.addEventListener('transitionend', () => el.remove());
  }, duration);
}
