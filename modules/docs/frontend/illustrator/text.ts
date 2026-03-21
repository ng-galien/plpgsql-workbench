// ============================================================
// TEXT — client-side text measurement and wrapping (Canvas API)
// ============================================================

const _measureCtx = document.createElement('canvas').getContext('2d')!;

export function wrapTextClient(
  text: string, maxWidth: number, fontSize: number,
  fontFamily: string, fontWeight: string, fontStyle: string
): string[] {
  if (!maxWidth) return text.split('\n');
  const style = fontStyle === 'italic' ? 'italic ' : '';
  _measureCtx.font = `${style}${fontWeight} ${fontSize}px "${fontFamily}"`;
  const paragraphs = text.split('\n');
  const lines: string[] = [];
  for (const para of paragraphs) {
    const words = para.split(/\s+/).filter(Boolean);
    if (!words.length) { lines.push(''); continue; }
    let cur = words[0];
    for (let i = 1; i < words.length; i++) {
      const test = cur + ' ' + words[i];
      if (_measureCtx.measureText(test).width <= maxWidth) {
        cur = test;
      } else {
        lines.push(cur);
        cur = words[i];
      }
    }
    lines.push(cur);
  }
  return lines;
}
