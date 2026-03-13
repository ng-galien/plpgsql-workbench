# Graphic Primitives & Features for Document Generation Engine

> Research document: what primitives and features are needed for a comprehensive engine
> that generates business documents (invoices, quotes, purchase orders, reports) AND
> creative documents (posters, flyers, brochures, banners).

**Priority key**: MUST = needed for basic documents, SHOULD = needed for professional documents, COULD = nice to have
**Phase key**: 1 = MVP, 2 = professional, 3 = advanced
**Complexity key**: L = Low, M = Medium, H = High

**Current state** (mcp-illustrator): text, image, rect, line, group. Single-page only. No tables, no rich text, no data binding, no multi-page. Two fonts (Libre Baskerville, Source Sans 3).

---

## 1. Text Primitives

Text is the foundation of every business document. The current engine has basic single-style text with word-wrap. Business and creative documents demand far more.

| # | Primitive | Description | Priority | Phase | Complexity | Current State |
|---|-----------|-------------|----------|-------|------------|---------------|
| 1.1 | **Single-line text** | Positioned text with font, size, color, anchor | MUST | 1 | L | EXISTS (`add_text`) |
| 1.2 | **Multi-line text (word-wrap)** | Auto-wrap to maxWidth, explicit `\n` breaks | MUST | 1 | L | EXISTS (`maxWidth`) |
| 1.3 | **Text alignment** | start/middle/end (horizontal anchor) | MUST | 1 | L | EXISTS (`textAnchor`) |
| 1.4 | **Rich text spans** | Bold, italic, color changes within a single text block. E.g. "Total: **1 480,80 EUR**" | MUST | 1 | H | MISSING -- currently entire block shares one style |
| 1.5 | **Paragraph text** | Multi-paragraph blocks with inter-paragraph spacing, first-line indent | SHOULD | 2 | M | MISSING -- `\n` exists but no paragraph-level control |
| 1.6 | **Justified text** | Full justification (left+right aligned) via Knuth-Plass or greedy algorithm | SHOULD | 2 | H | MISSING |
| 1.7 | **Multi-column text** | Text flowing across 2-3 columns (brochures, newsletters) | COULD | 3 | H | MISSING |
| 1.8 | **Bulleted lists** | Bullet character + hanging indent, nested levels | SHOULD | 2 | M | MISSING |
| 1.9 | **Numbered lists** | Auto-incrementing numbers/letters, nested levels | SHOULD | 2 | M | MISSING |
| 1.10 | **Merge fields / variables** | `{{client.name}}`, `{{facture.total}}` -- placeholder syntax resolved at generation time | MUST | 1 | M | MISSING -- currently done by orchestrator via `batch_update`, but no native support |
| 1.11 | **Text overflow: shrink-to-fit** | Auto-reduce font size if text exceeds bounding box | SHOULD | 2 | M | MISSING |
| 1.12 | **Text overflow: truncate + ellipsis** | Clip text with "..." when exceeding maxWidth | SHOULD | 2 | L | MISSING |
| 1.13 | **Text overflow: linked frames** | Text overflowing from one frame continues in another (multi-page) | COULD | 3 | H | MISSING |
| 1.14 | **Superscript / subscript** | For legal references (1), footnote markers, chemical formulas | SHOULD | 2 | M | MISSING |
| 1.15 | **Text decorations** | Underline, strikethrough, overline | SHOULD | 2 | L | MISSING |
| 1.16 | **RTL / BiDi text** | Right-to-left (Arabic, Hebrew), bidirectional mixing | COULD | 3 | H | MISSING |
| 1.17 | **CJK text** | Chinese/Japanese/Korean vertical and horizontal layout | COULD | 3 | H | MISSING |
| 1.18 | **Hyphenation** | Automatic word hyphenation per language rules (essential for justified text) | COULD | 3 | H | MISSING |

### Analysis

The biggest gap for business documents is **1.4 Rich text spans** -- every invoice needs "Total TTC: **1 480,80 EUR**" with the amount in bold. Without this, generating professional documents requires multiple separate text elements positioned manually, which is fragile.

**1.10 Merge fields** is architecturally important: currently the orchestrator does batch_update after cloning a template, which works but means Claude must understand every field mapping. A native `{{variable}}` system would make templates self-documenting and enable non-AI generation pipelines.

---

## 2. Table Primitives

Tables are the heart of business documents. Every invoice, quote, purchase order, and report has at least one. The current engine has **no table primitive** -- tables must be composed from individual text and line elements.

| # | Primitive | Description | Priority | Phase | Complexity | Current State |
|---|-----------|-------------|----------|-------|------------|---------------|
| 2.1 | **Simple table** | Rows, columns, cells with text content | MUST | 1 | H | MISSING -- composed manually from text+lines |
| 2.2 | **Header row** | Distinct styling (bold, background), repeated on page break | MUST | 1 | M | MISSING |
| 2.3 | **Column widths: fixed** | Explicit width per column in mm | MUST | 1 | L | MISSING |
| 2.4 | **Column widths: proportional** | Star-sizing (`*`, `2*`, `3*`) to fill available width | SHOULD | 2 | M | MISSING |
| 2.5 | **Column widths: auto** | Shrink to content width | SHOULD | 2 | M | MISSING |
| 2.6 | **Cell alignment** | Horizontal (left, center, right) and vertical (top, middle, bottom) per cell | MUST | 1 | L | MISSING |
| 2.7 | **Cell borders** | Per-side border control (top, right, bottom, left), style (solid, dashed), width, color | MUST | 1 | M | MISSING |
| 2.8 | **Cell merge: colspan** | Cell spanning multiple columns | SHOULD | 2 | M | MISSING |
| 2.9 | **Cell merge: rowspan** | Cell spanning multiple rows | SHOULD | 2 | H | MISSING |
| 2.10 | **Alternating row colors** | Zebra striping for readability | SHOULD | 2 | L | MISSING |
| 2.11 | **Table footer row** | Summary/totals row with distinct styling | SHOULD | 2 | L | MISSING |
| 2.12 | **Table page break** | Table splits across pages with header repeated | MUST | 1 | H | MISSING (requires multi-page) |
| 2.13 | **Nested content in cells** | Images, sub-tables, rich text within cells | COULD | 3 | H | MISSING |
| 2.14 | **Row grouping** | Collapsible sections within a table (report subtotals) | COULD | 3 | M | MISSING |
| 2.15 | **Cell padding** | Inner spacing between cell border and content | MUST | 1 | L | MISSING |

### Analysis

Tables are the **single biggest gap** for business document generation. Building an invoice table from individual positioned text elements requires ~6 elements per row, manual Y calculation, and breaks completely on multi-page documents. A native table primitive is the highest priority addition.

The minimum viable table needs: rows/columns, header row, fixed column widths, cell alignment, cell borders, cell padding. This alone unblocks 80% of business documents.

---

## 3. Shape Primitives

| # | Primitive | Description | Priority | Phase | Complexity | Current State |
|---|-----------|-------------|----------|-------|------------|---------------|
| 3.1 | **Rectangle** | With position, size, fill, stroke, border-radius | MUST | 1 | L | EXISTS (`add_rect` with `rx`) |
| 3.2 | **Line** | With endpoints, stroke, width | MUST | 1 | L | EXISTS (`add_line`) |
| 3.3 | **Circle** | Center + radius, fill, stroke | SHOULD | 2 | L | MISSING -- can approximate with rect+rx but semantically different |
| 3.4 | **Ellipse** | Center + rx/ry | SHOULD | 2 | L | MISSING |
| 3.5 | **Polygon** | Arbitrary closed shape from point list | COULD | 3 | M | MISSING |
| 3.6 | **Polyline** | Open path from point list | COULD | 3 | M | MISSING |
| 3.7 | **Path** | SVG-style path data (M, L, C, Q, A, Z) for arbitrary shapes | COULD | 3 | M | MISSING |
| 3.8 | **Arrow** | Line with arrowhead (start, end, or both) | SHOULD | 2 | M | MISSING |
| 3.9 | **Dashed/dotted lines** | strokeDasharray equivalent (solid, dashed, dotted, dash-dot) | SHOULD | 2 | L | MISSING |
| 3.10 | **Separator / divider** | Horizontal/vertical rule with optional decorations | SHOULD | 2 | L | MISSING -- can be done with line but no semantic meaning |
| 3.11 | **Decorative elements** | Ornaments, brackets, flourishes (predefined SVG library) | COULD | 3 | M | MISSING |
| 3.12 | **Rounded rect variants** | Per-corner radius control (different radius per corner) | COULD | 3 | M | MISSING -- current `rx` is uniform |
| 3.13 | **Star / badge shape** | Configurable star/badge (n-points, inner/outer radius) | COULD | 3 | M | MISSING |

### Analysis

The existing shapes (rect, line) cover basics. The most impactful additions for business documents are **3.8 Arrows** (for flowcharts, diagrams in reports) and **3.9 Dashed lines** (visual separators, cut lines on documents). **3.3 Circle** is a frequent need for bullet points, status indicators, and creative layouts.

---

## 4. Image Primitives

| # | Primitive | Description | Priority | Phase | Complexity | Current State |
|---|-----------|-------------|----------|-------|------------|---------------|
| 4.1 | **Raster images** | PNG, JPEG, WebP embedding | MUST | 1 | L | EXISTS (`add_image`) |
| 4.2 | **SVG embedding** | Inline SVG as an element (logos, icons) | SHOULD | 2 | M | MISSING -- logos must be raster |
| 4.3 | **Image crop** | Pan (cropX/cropY) and zoom (cropZoom) within frame | MUST | 1 | M | EXISTS (`objectFit`, `cropX/Y/Zoom`) |
| 4.4 | **Image filters** | Brightness, contrast, grayscale | SHOULD | 2 | M | EXISTS (`brightness`, `contrast`, `grayscale`) |
| 4.5 | **Image blur filter** | Gaussian blur (for background effects) | COULD | 3 | L | MISSING |
| 4.6 | **Image sepia / hue-rotate** | Color shift filters | COULD | 3 | L | MISSING |
| 4.7 | **Image mask: rounded rect** | Clip image to rounded rectangle | MUST | 1 | L | EXISTS (`borderRadius`) |
| 4.8 | **Image mask: circle** | Clip image to circular shape | SHOULD | 2 | L | MISSING -- approximate with large borderRadius |
| 4.9 | **Image mask: custom shape** | Clip to arbitrary path or SVG shape | COULD | 3 | H | MISSING |
| 4.10 | **Image shadow** | Drop shadow with offset, blur, color | SHOULD | 2 | L | EXISTS (`shadowX/Y/Blur/Color`) |
| 4.11 | **Image border** | Stroke around image with color and width | SHOULD | 2 | L | EXISTS (`borderWidth/Color`) |
| 4.12 | **Image flip** | Horizontal and vertical mirror | SHOULD | 2 | L | EXISTS (`flipH`, `flipV`) |
| 4.13 | **Watermark overlay** | Semi-transparent text/image overlaid on entire page | MUST | 1 | M | PARTIAL -- done via rotated text with low opacity, no dedicated primitive |
| 4.14 | **Background image** | Full-page or region background (cover, tile, stretch) | SHOULD | 2 | M | MISSING -- can place image at z=0 but no tiling |
| 4.15 | **QR code** | Generated QR from text/URL (payment, Factur-X, links) | MUST | 1 | M | MISSING |
| 4.16 | **Barcode: Code128** | Linear barcode for logistics, shipping labels | SHOULD | 2 | M | MISSING |
| 4.17 | **Barcode: EAN13** | Product barcode (retail, catalog) | SHOULD | 2 | M | MISSING |
| 4.18 | **Barcode: DataMatrix** | High-density 2D barcode | COULD | 3 | M | MISSING |
| 4.19 | **Image placeholder** | Named empty frame that shows dimensions/label until image is assigned | SHOULD | 2 | L | MISSING |
| 4.20 | **Tiled image pattern** | Repeating image as fill for a region (textures, wallpaper) | COULD | 3 | M | MISSING |

### Analysis

Image handling is the strongest area of the current engine. The critical missing pieces are:
- **4.15 QR code**: Every French invoice will need a QR code for Factur-X compliance (2026-2027). Also essential for flyers/posters (link to event page).
- **4.2 SVG embedding**: Logos are almost always delivered as SVG. Requiring raster conversion loses quality and increases file size.

---

## 5. Layout Primitives

| # | Primitive | Description | Priority | Phase | Complexity | Current State |
|---|-----------|-------------|----------|-------|------------|---------------|
| 5.1 | **Single page** | One canvas with format, orientation, background | MUST | 1 | L | EXISTS |
| 5.2 | **Multi-page document** | Multiple pages in one document, page navigation | MUST | 1 | H | MISSING -- critical gap, 1 doc = 1 page today |
| 5.3 | **Page headers** | Content repeated at top of every page (logo, company name) | MUST | 1 | M | MISSING (requires multi-page) |
| 5.4 | **Page footers** | Content at bottom of every page (page numbers, date, legal) | MUST | 1 | M | MISSING (requires multi-page) |
| 5.5 | **Page numbers** | Auto-incrementing "Page N/M" in headers/footers | MUST | 1 | L | MISSING (requires multi-page) |
| 5.6 | **Margins** | Page margins (top, right, bottom, left) defining printable area | MUST | 1 | L | MISSING -- implicit via element positioning |
| 5.7 | **Columns layout** | 2-col, 3-col text flow within a page region | COULD | 3 | H | MISSING |
| 5.8 | **Grid layout** | Snap grid for calendar, planning, inventory sheets | SHOULD | 2 | M | PARTIAL -- `distribute` with grid option exists |
| 5.9 | **Sections / blocks** | Named regions that flow vertically (header section, line items, totals, footer) | SHOULD | 2 | M | PARTIAL -- groups exist but don't "flow" |
| 5.10 | **Repeating sections** | A section template repeated for each item in a data array | MUST | 1 | H | MISSING -- manual batch_add per item today |
| 5.11 | **Page break control: keep-together** | Prevent breaking a group across pages | SHOULD | 2 | M | MISSING (requires multi-page) |
| 5.12 | **Page break control: break-before** | Force new page before a section | SHOULD | 2 | L | MISSING (requires multi-page) |
| 5.13 | **Bleed zone** | Extra area beyond trim for professional print | MUST | 1 | M | EXISTS (`bleed_mm` in export_pdf) |
| 5.14 | **Safe zone / inner margin** | Area inset from page edge where no content should be placed | SHOULD | 2 | L | EXISTS (`safe_margin_mm` in home_print) |
| 5.15 | **Master pages / templates** | Reusable page layout applied to multiple pages (different first page, left/right) | COULD | 3 | H | MISSING |
| 5.16 | **Relative positioning** | Place elements relative to other elements (below, right_of, gap) | MUST | 1 | M | EXISTS (below, above, right_of, left_of, gap, center_h/v) |
| 5.17 | **Alignment tools** | Align multiple elements to edges or centers | MUST | 1 | M | EXISTS (align tool) |
| 5.18 | **Distribution tools** | Equal spacing between elements | MUST | 1 | M | EXISTS (distribute tool) |
| 5.19 | **Z-ordering** | Front/back/forward/backward element order | MUST | 1 | L | EXISTS (reorder_element) |
| 5.20 | **Groups** | Hierarchical element grouping with nested groups | MUST | 1 | M | EXISTS (group_elements, ungroup, add_to_group) |
| 5.21 | **Snap-to-grid** | Automatic positioning to grid coordinates | SHOULD | 2 | L | EXISTS (client-side toggle) |
| 5.22 | **Guides / rulers** | Visual guides for alignment (non-printing) | COULD | 3 | L | MISSING |

### Analysis

**5.2 Multi-page** is the most critical missing layout feature. Without it, a 15-line invoice works, but a 40-line invoice is impossible. Multi-page also unlocks headers, footers, page numbers, table continuation, and all the features that make documents professional.

**5.10 Repeating sections** is the second critical gap. Currently, generating table rows requires the orchestrator to call batch_add with calculated Y positions for each row. A native repeat mechanism would be transformative for template-based generation.

---

## 6. Data Binding

Data binding transforms a static design into a reusable template. The current engine has **no data binding** -- the orchestrator (Claude or script) performs all data injection via batch_update.

| # | Primitive | Description | Priority | Phase | Complexity | Current State |
|---|-----------|-------------|----------|-------|------------|---------------|
| 6.1 | **Merge fields** | `{{variable.path}}` syntax in text elements, resolved at generation time | MUST | 1 | M | MISSING -- orchestrator does it manually |
| 6.2 | **Repeating sections** | `{{#each lignes}}...{{/each}}` -- repeat a group of elements for each item in an array | MUST | 1 | H | MISSING |
| 6.3 | **Conditional visibility** | `{{#if total > 0}}` -- show/hide elements or sections based on data conditions | SHOULD | 2 | M | MISSING |
| 6.4 | **Computed fields** | `{{sum(lignes.total_ht)}}`, `{{page_count}}` -- calculated values | SHOULD | 2 | M | MISSING |
| 6.5 | **Number formatting** | Currency (`1 234,56 EUR`), percentage (`20,00%`), dates (`13 mars 2026`) | MUST | 1 | M | MISSING -- done by PL/pgSQL before injection |
| 6.6 | **Locale-aware formatting** | `fr_FR`: `1 234,56`, `en_US`: `1,234.56` -- ICU-based formatting | SHOULD | 2 | M | MISSING |
| 6.7 | **Image binding** | `{{entreprise.logo}}` resolving to an image path/URL | SHOULD | 2 | L | MISSING |
| 6.8 | **QR code binding** | `{{qr:facture.payment_url}}` generating QR from bound data | SHOULD | 2 | M | MISSING |
| 6.9 | **Conditional styling** | Change color/font based on data value (red if overdue, green if paid) | COULD | 3 | M | MISSING |
| 6.10 | **Data source declaration** | Template declares what data shape it expects (schema for validation) | COULD | 3 | L | MISSING |

### Analysis

The current approach (orchestrator does everything) works for AI-driven generation but fails for:
- **Batch generation**: Generate 200 invoices from a CSV -- no AI needed if templates self-bind
- **Non-developer users**: A template designer should see `{{client.nom}}` in the editor, not rely on Claude to know the field names
- **Validation**: A template with declared data schema can be validated before generation

Phase 1 should at minimum support merge fields (6.1) and repeating sections (6.2). These alone cover 90% of business document automation.

---

## 7. Typography

| # | Primitive | Description | Priority | Phase | Complexity | Current State |
|---|-----------|-------------|----------|-------|------------|---------------|
| 7.1 | **Font families** | Serif, sans-serif, monospace, custom fonts | MUST | 1 | M | PARTIAL -- 2 fonts only (Libre Baskerville, Source Sans 3) |
| 7.2 | **Font loading** | Load custom .ttf/.otf/.woff2 fonts | SHOULD | 2 | M | MISSING -- hardcoded font list |
| 7.3 | **Font weights** | 100 (thin) through 900 (black) | MUST | 1 | L | PARTIAL -- normal, bold, 300, 600, 700 |
| 7.4 | **Font styles** | Normal, italic, oblique | MUST | 1 | L | EXISTS (normal, italic) |
| 7.5 | **Line height / leading** | Space between lines in multi-line text | MUST | 1 | L | MISSING -- uses default from font metrics |
| 7.6 | **Letter spacing / tracking** | Space between characters | SHOULD | 2 | L | MISSING |
| 7.7 | **Text color** | Fill color for text | MUST | 1 | L | EXISTS (`fill`) |
| 7.8 | **Text opacity** | Transparency for text elements | MUST | 1 | L | EXISTS (`opacity`) |
| 7.9 | **Drop shadow on text** | Shadow behind text for contrast on images | SHOULD | 2 | M | MISSING -- images have shadow but text doesn't |
| 7.10 | **Outline / stroke text** | Text with visible outline (titles on photo backgrounds) | SHOULD | 2 | M | MISSING |
| 7.11 | **Text transform** | Uppercase, lowercase, capitalize (applied at render time) | SHOULD | 2 | L | MISSING |
| 7.12 | **OpenType features: ligatures** | fi, fl, ffi ligatures for professional typography | COULD | 3 | M | DEPENDS on font + opentype.js support |
| 7.13 | **OpenType features: small caps** | True small capitals (not scaled-down uppercase) | COULD | 3 | M | MISSING |
| 7.14 | **OpenType features: old-style numerals** | Text figures that blend with lowercase (for body text) | COULD | 3 | L | MISSING |
| 7.15 | **OpenType features: tabular numerals** | Fixed-width digits for aligned number columns in tables | SHOULD | 2 | L | MISSING -- critical for invoice amount columns |
| 7.16 | **Monospace font** | At least one mono font for codes, references, technical content | SHOULD | 2 | L | MISSING |
| 7.17 | **Web font loading** | Load fonts from Google Fonts or URLs at runtime | COULD | 3 | M | MISSING |

### Analysis

The current 2-font system is a significant limitation for professional documents. The minimum additions needed:
- **7.5 Line height**: Without explicit control, multi-line text blocks have unpredictable height, breaking layout calculations.
- **7.15 Tabular numerals**: Invoice columns look amateur when digits don't align. This is a make-or-break detail.
- **7.16 Monospace font**: Every business document has codes (invoice numbers, SIRET, IBAN) that look better in mono.

Font loading (7.2) is strategically important: customers will want their brand fonts.

---

## 8. Colors & Fills

| # | Primitive | Description | Priority | Phase | Complexity | Current State |
|---|-----------|-------------|----------|-------|------------|---------------|
| 8.1 | **Solid colors (hex)** | `#FF5500`, `#333` | MUST | 1 | L | EXISTS |
| 8.2 | **Solid colors (rgb/rgba)** | `rgb(255,85,0)`, `rgba(0,0,0,0.5)` | SHOULD | 2 | L | PARTIAL -- rgba in some shadow props |
| 8.3 | **Named colors** | CSS named colors (white, navy, etc.) | COULD | 3 | L | MISSING |
| 8.4 | **Linear gradient fill** | Gradient from point A to point B with color stops | SHOULD | 2 | M | MISSING |
| 8.5 | **Radial gradient fill** | Gradient radiating from center with color stops | COULD | 3 | M | MISSING |
| 8.6 | **Pattern fill** | Repeating pattern (hatching, dots, stripes) as fill | COULD | 3 | M | MISSING |
| 8.7 | **Opacity / transparency** | Per-element opacity control | MUST | 1 | L | EXISTS (`opacity`) |
| 8.8 | **CMYK color space** | Colors specified in CMYK for professional print | COULD | 3 | H | MISSING |
| 8.9 | **Color palette / swatches** | Predefined color sets for consistent design | COULD | 3 | L | MISSING |
| 8.10 | **HSL color specification** | `hsl(30, 100%, 50%)` for intuitive color manipulation | COULD | 3 | L | MISSING |

### Analysis

Hex colors cover 95% of business document needs. **8.4 Linear gradients** are the most impactful addition for creative documents (headers, backgrounds, decorative elements). CMYK (8.8) is only needed for professional print shops and can be deferred to Phase 3.

---

## 9. Print-Specific Features

| # | Primitive | Description | Priority | Phase | Complexity | Current State |
|---|-----------|-------------|----------|-------|------------|---------------|
| 9.1 | **Crop marks** | Trim marks outside page box indicating cut lines | MUST | 1 | M | EXISTS (`crop_marks` in export_pdf) |
| 9.2 | **Registration marks** | Cross-shaped alignment marks for multi-color printing | SHOULD | 2 | M | MISSING |
| 9.3 | **Bleed zone** | Area beyond trim (typically 3mm) for edge-to-edge printing | MUST | 1 | M | EXISTS (`bleed_mm`) |
| 9.4 | **Home print mode** | Scale content within safe margins, no bleed/marks | MUST | 1 | M | EXISTS (`home_print`) |
| 9.5 | **PDF/A-3 compliance** | Archival PDF supporting embedded files (required for Factur-X) | MUST | 2 | H | MISSING |
| 9.6 | **Factur-X embedding** | Attach CII XML invoice data inside PDF/A-3 | MUST | 2 | H | MISSING |
| 9.7 | **Spot colors** | Named Pantone/spot colors for brand consistency | COULD | 3 | H | MISSING |
| 9.8 | **Overprint** | Ink overprint control for trapping | COULD | 3 | H | MISSING |
| 9.9 | **Color bar** | Color calibration strip outside trim area | COULD | 3 | M | MISSING |
| 9.10 | **Signature zone (visual)** | Named placeholder area for handwritten/digital signature | MUST | 1 | L | MISSING |
| 9.11 | **Signature zone (digital)** | PDF signature field for cryptographic signing | SHOULD | 2 | H | MISSING |
| 9.12 | **Fold marks** | Marks indicating where to fold (tri-fold brochures) | SHOULD | 2 | L | MISSING |
| 9.13 | **PDF metadata** | Title, author, subject, keywords, creation date | MUST | 1 | L | MISSING |
| 9.14 | **PDF permissions** | Print/copy/edit restrictions | COULD | 3 | M | MISSING |

### Analysis

**9.5 PDF/A-3** and **9.6 Factur-X** are time-critical: French e-invoicing mandate begins September 2026. B2B invoices must be Factur-X (PDF/A-3 with embedded CII XML). This is a legal requirement, not a nice-to-have.

**9.10 Signature zone** is needed for quotes (client acceptance), contracts, and delivery receipts. Even a visual placeholder (dashed box with "Signature" label) covers 80% of the need.

---

## 10. Interactivity (Digital Documents)

| # | Primitive | Description | Priority | Phase | Complexity | Current State |
|---|-----------|-------------|----------|-------|------------|---------------|
| 10.1 | **Hyperlinks** | Clickable links in PDF (to URLs, emails, phone numbers) | MUST | 1 | M | MISSING |
| 10.2 | **Internal links** | Click to jump to another page/section within the document | SHOULD | 2 | M | MISSING |
| 10.3 | **Bookmarks / outlines** | PDF bookmark panel for navigation (chapters, sections) | SHOULD | 2 | M | MISSING |
| 10.4 | **Table of contents** | Auto-generated TOC with page numbers and links | COULD | 3 | H | MISSING |
| 10.5 | **Form fields: checkbox** | Interactive checkbox in PDF | COULD | 3 | M | MISSING |
| 10.6 | **Form fields: text input** | Fillable text field in PDF | COULD | 3 | M | MISSING |
| 10.7 | **Annotations** | Sticky notes, highlights, comments | COULD | 3 | M | MISSING |
| 10.8 | **Embedded files** | Attach files to PDF (XML for Factur-X, Excel data) | SHOULD | 2 | M | MISSING (overlaps with 9.6) |

### Analysis

**10.1 Hyperlinks** are surprisingly important for business documents: clickable "mailto:" for customer support, clickable payment links, clickable terms-and-conditions URLs. Most PDF generators support this and users expect it.

---

## 11. Export Formats

| # | Format | Description | Priority | Phase | Complexity | Current State |
|---|--------|-------------|----------|-------|------------|---------------|
| 11.1 | **SVG** | Standalone SVG with embedded images | MUST | 1 | L | EXISTS (`export_svg`) |
| 11.2 | **PNG** | Raster snapshot at configurable DPI | MUST | 1 | L | EXISTS (`snapshot`) |
| 11.3 | **PDF (vector)** | Vector PDF via headless Chrome | MUST | 1 | M | EXISTS (`export_pdf`) -- Puppeteer dependency |
| 11.4 | **PDF (native)** | Vector PDF via pdf-lib or similar (no Chrome dependency) | SHOULD | 2 | H | MISSING -- would remove heavy Puppeteer dep |
| 11.5 | **PDF/A-3** | Archival PDF for Factur-X | MUST | 2 | H | MISSING |
| 11.6 | **DOCX** | Word document export | SHOULD | 2 | M | EXISTS (`export_docx` via npm:docx) |
| 11.7 | **HTML** | Static HTML rendering of the document | COULD | 3 | M | MISSING |
| 11.8 | **Print-ready PDF** | PDF with crop marks, bleed, registration, correct color profile | SHOULD | 2 | M | PARTIAL (crop marks + bleed exist) |

### Analysis

The current Puppeteer-based PDF export is heavy (Chrome headless) and doesn't work in Deno/Edge environments. Moving to native PDF generation (pdf-lib, jsPDF, or similar) would reduce the deployment footprint dramatically and enable features like hyperlinks, bookmarks, and PDF/A that Puppeteer's print-to-PDF doesn't support well.

---

## 12. Document Operations

| # | Operation | Description | Priority | Phase | Complexity | Current State |
|---|-----------|-------------|----------|-------|------------|---------------|
| 12.1 | **Create** | New blank document | MUST | 1 | L | EXISTS (`doc_new`) |
| 12.2 | **Save / Load** | Persist and restore documents | MUST | 1 | L | EXISTS (`doc_save`, `doc_load`) |
| 12.3 | **Duplicate / Clone** | Copy document as template instance | MUST | 1 | L | EXISTS (`doc_duplicate`) |
| 12.4 | **Delete** | Remove document | MUST | 1 | L | EXISTS (`doc_delete`) |
| 12.5 | **List** | Browse saved documents | MUST | 1 | L | EXISTS (`doc_list`) |
| 12.6 | **Rename** | Change document name | MUST | 1 | L | EXISTS (`doc_rename`) |
| 12.7 | **Batch generate** | Generate N documents from template + data array | SHOULD | 2 | M | MISSING |
| 12.8 | **PDF merge** | Concatenate multiple single-page PDFs into one file | SHOULD | 2 | M | MISSING |
| 12.9 | **Version history** | Track revisions, revert to previous state | COULD | 3 | H | MISSING |
| 12.10 | **Template library** | Curated collection of reusable templates | SHOULD | 2 | L | MISSING -- templates are just documents today |
| 12.11 | **Lock elements** | Prevent accidental modification of certain elements | SHOULD | 2 | L | MISSING |

---

## 13. Measurement & Positioning

| # | Primitive | Description | Priority | Phase | Complexity | Current State |
|---|-----------|-------------|----------|-------|------------|---------------|
| 13.1 | **Absolute positioning (mm)** | x, y coordinates in millimeters | MUST | 1 | L | EXISTS |
| 13.2 | **Relative positioning** | below, above, right_of, left_of with gap | MUST | 1 | M | EXISTS |
| 13.3 | **Center on canvas** | center_h, center_v | MUST | 1 | L | EXISTS |
| 13.4 | **Text measurement** | Measure text dimensions before placing | MUST | 1 | M | EXISTS (`measure_text`) |
| 13.5 | **Bounding box** | Computed bbox for any element | MUST | 1 | M | EXISTS (internal) |
| 13.6 | **Layout analysis** | Collision detection, bleed violations, spacing check | SHOULD | 2 | M | EXISTS (`check_layout`) |
| 13.7 | **Percentage positioning** | Position at 50% of page width instead of absolute mm | SHOULD | 2 | M | MISSING |
| 13.8 | **Anchoring** | Anchor element to page edge (bottom-right, etc.) | SHOULD | 2 | M | MISSING |
| 13.9 | **Constraint-based layout** | "This element should always be 10mm below that one" (maintained through updates) | COULD | 3 | H | MISSING -- relative positioning is one-shot at creation |

---

## Priority Matrix Summary

### Phase 1 -- MVP (Business Document Generation)

The minimum set to generate a professional invoice, quote, or purchase order.

| Category | Must-Have Primitives |
|----------|---------------------|
| **Text** | Rich text spans (1.4), merge fields (1.10) |
| **Tables** | Simple table with headers, fixed widths, alignment, borders, padding (2.1-2.7, 2.15) |
| **Layout** | Multi-page (5.2), page headers/footers (5.3-5.4), page numbers (5.5), margins (5.6), repeating sections (5.10) |
| **Images** | QR code generation (4.15) |
| **Typography** | Line height control (7.5), at least 1 more sans-serif + 1 monospace font (7.1) |
| **Print** | Signature zone visual (9.10), PDF metadata (9.13) |
| **Interactive** | Hyperlinks in PDF (10.1) |
| **Data** | Merge fields (6.1), repeating sections (6.2), number formatting (6.5) |

### Phase 2 -- Professional

| Category | Key Additions |
|----------|---------------|
| **Text** | Paragraph text (1.5), justified text (1.6), bulleted/numbered lists (1.8-1.9), superscript/subscript (1.14), decorations (1.15) |
| **Tables** | Proportional/auto widths (2.4-2.5), cell merge (2.8-2.9), alternating rows (2.10), table footer (2.11), page break with header repeat (2.12) |
| **Shapes** | Circle (3.3), arrow (3.8), dashed lines (3.9) |
| **Images** | SVG embedding (4.2) |
| **Layout** | Page break control (5.11-5.12), sections/blocks (5.9) |
| **Typography** | Custom font loading (7.2), letter spacing (7.6), text shadow (7.9), outline text (7.10), tabular numerals (7.15) |
| **Colors** | Linear gradient (8.4) |
| **Print** | PDF/A-3 + Factur-X (9.5-9.6), registration marks (9.2), fold marks (9.12) |
| **Interactive** | Bookmarks (10.3), embedded files (10.8) |
| **Data** | Conditional visibility (6.3), computed fields (6.4), locale formatting (6.6) |
| **Export** | Native PDF generation (11.4), batch generate (12.7), PDF merge (12.8) |

### Phase 3 -- Advanced

| Category | Key Additions |
|----------|---------------|
| **Text** | Multi-column text (1.7), linked text frames (1.13), RTL/BiDi (1.16), CJK (1.17), hyphenation (1.18) |
| **Tables** | Nested content in cells (2.13), row grouping (2.14) |
| **Shapes** | Polygon/polyline/path (3.5-3.7), decorative elements (3.11) |
| **Images** | Custom shape masks (4.9), tiled patterns (4.20) |
| **Layout** | Column layout (5.7), master pages (5.15), constraint-based layout (13.9) |
| **Typography** | OpenType features (7.12-7.14), web font loading (7.17) |
| **Colors** | CMYK (8.8), pattern fills (8.6) |
| **Print** | Spot colors (9.7), overprint (9.8) |
| **Interactive** | Table of contents (10.4), form fields (10.5-10.6) |
| **Data** | Conditional styling (6.9), data source declaration (6.10) |

---

## Gap Analysis: Current Engine vs. Business Document Requirements

### Critical Gaps (blocks basic invoice/quote generation)

| Gap | Impact | Effort |
|-----|--------|--------|
| **No multi-page** | Cannot generate invoices >1 page, no headers/footers/page numbers | HIGH |
| **No tables** | Must compose from individual elements (fragile, no reflow) | HIGH |
| **No rich text** | Cannot mix bold/normal in same text block | MEDIUM |
| **No merge fields** | Template filling requires Claude to know every field | MEDIUM |
| **No QR codes** | Missing for Factur-X compliance and modern documents | MEDIUM |

### Important Gaps (blocks professional quality)

| Gap | Impact | Effort |
|-----|--------|--------|
| **2 fonts only** | Cannot match brand guidelines | LOW-MEDIUM |
| **No line height control** | Unpredictable multi-line layout | LOW |
| **No hyperlinks in PDF** | No clickable URLs/emails | MEDIUM |
| **No PDF/A-3** | Cannot generate Factur-X invoices (legal requirement Sept 2026) | HIGH |
| **No native PDF** | Depends on Puppeteer/Chrome -- heavy, not Edge-compatible | HIGH |

### Strategic Gaps (blocks product differentiation)

| Gap | Impact | Effort |
|-----|--------|--------|
| **No batch generation** | Cannot generate 200 invoices at once without AI | MEDIUM |
| **No template library** | Customers must build every template from scratch | LOW |
| **No conditional visibility** | Cannot hide/show sections based on data | MEDIUM |
| **No gradient fills** | Creative documents look flat | MEDIUM |

---

## Architectural Recommendation

### Document Model Evolution

The current flat element model (text, image, rect, line, group) needs to evolve toward a **flow-based model** for business documents:

```
Document
  Pages[]
    Page
      MasterRegions[]        -- header, footer (repeated)
      ContentRegion          -- main body
        Blocks[]             -- flow vertically
          TextBlock          -- rich text with spans
          Table              -- rows, columns, cells
          ImageBlock          -- image with caption
          Spacer             -- explicit vertical space
          PageBreak          -- force new page
          RepeatBlock        -- data-bound repeating section
```

This coexists with the existing **absolute positioning model** for creative documents:
- Business documents: flow-based, data-bound, multi-page
- Creative documents: absolute positioning, single-page (or few pages), design-driven

The engine should support both modes, selected per document type.

### Rendering Pipeline

```
Template (document + merge fields)
  + Data (JSON from PL/pgSQL)
  -> Data Binding (resolve {{variables}}, expand repeats, evaluate conditions)
  -> Layout Engine (compute pages, flow content, break tables)
  -> Render (SVG for preview, PDF for export)
```

---

## References

Research based on analysis of:
- [pdfmake](https://github.com/bpampuch/pdfmake) -- declarative PDF generation in JS
- [pdfmake documentation](https://pdfmake.github.io/docs/0.1/)
- [Apache FOP / XSL-FO](https://xmlgraphics.apache.org/fop/) -- complete formatting object specification
- [XSL-FO Compliance](https://xmlgraphics.apache.org/fop/compliance-static.html)
- [Typst](https://typst.app/) -- modern typesetting system
- [Typst automated PDF generation](https://typst.app/blog/2025/automated-generation/)
- [ReportLab](https://docs.reportlab.com/) -- Python PDF generation
- [CSS Paged Media Level 3](https://www.w3.org/TR/css-page-3/) -- W3C print specification
- [Prince XML](https://www.princexml.com/) -- CSS-to-PDF converter
- [WeasyPrint](https://weasyprint.org/) -- open-source CSS-to-PDF
- [Factur-X / ZUGFeRD](https://fnfe-mpe.org/factur-x/factur-x_en/) -- hybrid PDF invoice standard
- [PDF/A specification](https://en.wikipedia.org/wiki/PDF/A) -- archival PDF standard
- [Knuth-Plass line-breaking algorithm](https://en.wikipedia.org/wiki/Knuth%E2%80%93Plass_line-breaking_algorithm)
- [OpenType font features (MDN)](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Fonts/OpenType_fonts)
- [SVG Filter Effects](https://www.w3.org/TR/SVG11/filters.html)
- [SVG Gradients and Patterns](https://www.w3.org/TR/SVG11/pservers.html)
- [French e-invoicing requirements (Stripe)](https://stripe.com/resources/more/mandatory-information-invoice-france)
- [PDF digital signatures](https://itextpdf.com/sites/default/files/2018-12/digitalsignatures20130304.pdf)
- Current mcp-illustrator source (`src/types.ts`, `src/tools.ts`)
