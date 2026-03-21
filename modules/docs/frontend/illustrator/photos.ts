// ============================================================
// PHOTOS — photo library strip, metadata overlay, upload
// ============================================================

import "./styles/photos.css";
import "./styles/meta.css";

import { store, dispatch } from "./store/index.js";
import { wsSend } from "./ws.js";
import { esc } from "./utils.js";
import { showToast } from "./toast.js";

export async function loadAssets(): Promise<void> {
  try {
    const res = await fetch('/api/assets');
    const assets = await res.json();
    dispatch({ type: "SET_ASSETS", assets });
    renderPhototheque();
  } catch (e) { console.error('Failed to load assets:', e); }
}

export function renderPhototheque(): void {
  const assetsData = store.state.ui.assetsData;
  if (!assetsData) return;
  const images = assetsData.images || [];

  const grid = document.getElementById('photoGrid');
  if (!grid) return;
  grid.innerHTML = '';
  const countEl = document.getElementById('photoCount');
  if (countEl) countEl.textContent = `${images.length}`;

  images.forEach(img => {
    const thumb = document.createElement('div');
    thumb.className = 'photo-thumb';
    thumb.innerHTML = `
      <img src="/assets/thumbs/${esc(img.file)}" alt="${esc(img.title || img.file)}" loading="lazy">
      <div class="photo-thumb-label">${esc(img.title || img.file)}</div>
    `;
    thumb.addEventListener('click', () => showMeta(img));
    grid.appendChild(thumb);
  });
}

function sendSelectAsset(file: string | null): void {
  wsSend({ type: 'select_asset', file: file || null });
}

function showMeta(img: any): void {
  sendSelectAsset(img.file);
  const card = document.getElementById('metaCard')!;
  const tags = (img.tags || []).map((t: string) => `<span class="meta-tag">${esc(t)}</span>`).join('');
  card.innerHTML = `
    <img class="meta-card-img" src="/assets/thumbs/${esc(img.file)}" alt="${esc(img.title || '')}">
    <div class="meta-card-body">
      <div class="meta-card-title">${esc(img.title || img.file)}</div>
      <div class="meta-card-desc">${esc(img.description || '')}</div>
      ${tags ? `<div class="meta-card-tags">${tags}</div>` : ''}
      <div class="meta-card-info">
        <strong>Fichier :</strong> ${esc(img.file)}<br>
        ${img.width ? `<strong>Dimensions :</strong> ${img.width} x ${img.height} px<br>` : ''}
        ${img.orientation ? `<strong>Orientation :</strong> ${esc(img.orientation)}<br>` : ''}
        ${img.saison ? `<strong>Saison :</strong> ${esc(img.saison)}<br>` : ''}
        ${img.credit ? `<strong>Credit :</strong> ${esc(img.credit)}<br>` : ''}
      </div>
      ${img.usage_affiche ? `<div class="meta-card-usage">${esc(img.usage_affiche)}</div>` : ''}
    </div>
  `;
  document.getElementById('metaOverlay')!.classList.add('visible');
}

export function hideMeta(): void {
  document.getElementById('metaOverlay')!.classList.remove('visible');
  sendSelectAsset(null);
}

export async function uploadFile(file: File): Promise<void> {
  const reader = new FileReader();
  reader.onload = async () => {
    const base64 = (reader.result as string).split(',')[1];
    try {
      const res = await fetch('/api/upload', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename: file.name, data: base64 }),
      });
      const result = await res.json();
      if (result.ok) {
        showToast(result.replaced ? `Image "${file.name}" remplacee` : `Image "${file.name}" ajoutee`, result.replaced ? 'warning' : 'success');
        await loadAssets();
      }
    } catch (e) {
      console.error('Upload failed:', e);
      showToast(`Echec upload "${file.name}"`, 'warning');
    }
  };
  reader.readAsDataURL(file);
}
