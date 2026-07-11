## 2.0.0-dev — Complete Restructuring

> **⚠️ Breaking**: This release is a complete restructuring of the codebase.
> Multiple UI regressions are present and will be fixed in subsequent commits.

### Major Structural Changes

- **Monorepo consolidation**: Merged six standalone packages (`ce_xml`,
  `ce_zip`, `ce_opc`, `ce_docx`, `ce_fonts`, `ce_pdf`) into a single package
  under `lib/src/document/`, eliminating inter-package dependencies.
- **Assets relocated**: Moved SVG toolbar assets from `web/assets/` to
  `lib/assets/` and replaced individual SVG icons with the Tabler Icons 3.44.0
  webfont (`ti ti-*` CSS classes).
- **Old `web/` example removed**: The legacy `web/` Dart entry-point, including
  all SVG assets, `tabler_icons.dart`, `main.dart.js` (compiled output),
  `favicon.png`, `index.html` and `styles.css`, has been deleted.
- **New `example/` app**: A fresh, pure Dart Web demo with dynamic UI creation
  from `lib/src/components` — the HTML file only provides the host `<div>`.
  Features a settings panel to toggle editor features at runtime (title bar,
  compact/word appearance, toolbar, status bar, catalog).
- **New `example2/` app**: AngularDart 8 integration demo using `limitless_ui`
  and Limitless CSS assets, with live editor/viewer mode switching.
- **`CanvasEditorWidget` facade**: New high-level embeddable widget for Dart Web
  and AngularDart with explicit editor/viewer modes, scoped UI and lifecycle
  cleanup.
- **`CanvasEditorConfig`**: Configuration class with `appearance` (compact or
  word), `mode` (editor or viewer), `showToolbar`, `height`, `locale`,
  `documentTitle`, and callback hooks.
- **README translated to English**.

### Restored After Restructuring (widget shell)

The regressions introduced by the restructuring were fixed by porting the old
shell wiring into the new component architecture:

- **Component mini-framework**: `lib/src/components/core/ui_component.dart`
  defines the `UiComponent` lifecycle contract (single root element, tracked
  subscriptions, idempotent `dispose`) and a `UiScheduler` that coalesces UI
  invalidations into one DOM flush per animation frame.
- **Ribbon extracted as `WidgetRibbon`** (`widget_ribbon.dart`) with selection
  mirroring: `rangeStyleChange` is scheduled through `UiScheduler` and
  `syncRangeStyle` activates bold/italic/underline/strike/super/subscript,
  font family/size selects, alignment, list, title-level style cards and
  enables/disables undo/redo — without adding work to the typing hot path.
- **Status bar restored** (`widget_status_bar.dart`): current page/total
  pages, word count (debounced `getWordCount`), paginated/continuous toggle,
  zoom slider (50–300%), zoom −/+ and click-to-reset percentage.
- **Catalog sidebar restored** (`widget_side_panels.dart`):
  `getCatalog()`-driven navigation panel with nested headings, click →
  `executeLocationCatalog`, auto-refresh on content change.
- **Find & Replace restored**: sidebar panel with match counter
  (`getSearchNavigateInfo`), prev/next navigation, replace-one (indexed) and
  replace-all, wired to Ctrl+F / Ctrl+H inside the widget (works in viewer
  mode too via focusable scroll container).
- **Comments sidebar restored**: host-provided `CanvasEditorComment` data is
  matched against live document `groupIds`, with navigation, keyboard access,
  deletion callbacks and read-only viewer behavior.
- **Contextual text mini-toolbar**: non-collapsed canvas selections now show a
  lightweight floating toolbar for bold, italic, underline, strikeout, copy
  and clear-formatting. Positioning follows the selected page and zoom, DOM
  updates are frame-coalesced, and the component is omitted in viewer mode.
- **Loading overlay restored** (`widget_loading_overlay.dart`), shown on DOCX
  open/save and page-image export, yielding two animation frames before the
  heavy synchronous work.
- **DOCX open flow re-ported**: `loadDocx` now applies paper geometry via
  `setPaperOptionsSilently`, dynamic PAGE/NUMPAGES page numbering, header and
  footer distances and **floating header text boxes (carimbos)** before the
  single `executeSetValue` render — fixing the missing text boxes, the
  duplicated footer page numbers and the multi-relayout open cost.
- **DOCX save flow re-ported**: deferred pristine save reference
  (`buildSaveReferenceFromConverted` on first save) and model re-anchoring
  after each save.
- **Page setup in the Layout ribbon**: Word-style margin presets
  (Normal/Narrow/Moderate/Wide) plus a custom-margins form in cm, paper size
  menu (A4/Letter/Legal/A5) and portrait/landscape — dropdown menus anchored
  to the widget root so the ribbon overflow cannot clip them.
- **Paginated vs continuous mode**: first-class buttons in the View ribbon
  and in the status bar, kept in sync via `pageModeChange`.
- **Export page as PNG**: File ribbon action using `getImage`, downloading
  the currently visible page.
- **Export document as PDF**: File ribbon action rasterizes every page through
  the editor's print renderer and packages the JPEG pages with the new pure
  Dart `RasterPdfEncoder`. This preserves tables, images, floating text boxes,
  headers, footers and page geometry without requiring JavaScript PDF libraries.
- **Quill Delta interop**: new pure-Dart `QuillDeltaConverter`
  (`lib/src/word/quill_delta.dart`) exposed as
  `CanvasEditorWidget.toQuillDelta()` / `loadQuillDelta()` covering inline
  formatting, headers, lists, alignment, links, images and round-trip table
  interoperability with `quill-table-better`, including column widths,
  merged cells, TH cells, background colors, table headers/lists and
  multi-paragraph cell content, with VM unit tests.
- `example/` now uses the real widget APIs for the catalog and status bar
  toggles instead of the temporary DOM-class hacks.

Still pending from the original regression list: the remaining Word-mode
dialogs and a future searchable/vector PDF backend. The current PDF export is
page-faithful raster output.

### Embedding

- Added the public `CanvasEditorWidget` facade for Dart Web and AngularDart,
  with explicit editor/viewer modes, scoped dynamic UI and lifecycle cleanup.
- Replaced body-based scrolling with an owned, configurable internal scroll
  container suitable for cards, grids and modals.
- Moved the pure Dart XML, ZIP, OPC, DOCX, font and PDF modules from six path
  packages into `lib/src/document`, leaving a single package dependency.
- Replaced SVG toolbar assets with the pinned official Tabler Icons 3.44.0
  webfont and stable `ti ti-*` CSS classes.
- Added `example2`, an AngularDart 8 application using `limitless_ui` and the
  Limitless CSS assets, with live switching between editor and viewer modes.
- Rebuilt the plain Dart Web example around a host-only `index.html`; editor UI
  is now created dynamically from `lib/src/components`.
- Added `CanvasEditorAppearance.word`, with a dynamic Word-style title bar,
  tabs and ribbon groups, while retaining the compact embedded appearance.
- Moved DOCX file picking into the widget with a persistent DOM input and
  added Puppeteer UI coverage for file loading, viewer mode and bold
  undo/redo.

### Performance

- Added a release-oriented development server (`dart run tool/serve_web.dart`)
  so performance is measured on dart2js output instead of DDC.
- Optimized DOCX opening for large files by applying DOCX page settings before
  the single value render, showing the loading overlay before parse/layout, and
  paginating large documents progressively in 10 ms slices.
- Reduced text measurement overhead in hot layout paths by caching canvas font
  state, avoiding repeated DOM `ctx.font` reads, and cutting repeated font
  string/regex work in row computation.
- Added paragraph-level fast layout for common text edits, plus lazy element
  position coordinates and lighter visible-page detection during scroll.
- Reworked paste and rich text commands to use delta-style history for local
  edits instead of cloning the full document for every command.
- Optimized selected-word formatting commands (`bold`, font, size, italic,
  underline, strikeout, color, highlight, superscript/subscript) to choose
  between local paragraph relayout and repaint-only redraws, following the
  OnlyOffice `TextPr.Check_NeedRecalc` pattern.
- Optimized full table deletion with range/row deltas so undo/redo avoids a
  full document snapshot and skips `computeRowList` for the whole TR document.
- Extracted scroll-triggered page painting into a reusable `DirtyPageQueue`,
  matching the OnlyOffice-style separation between invalidating a page and
  painting it within a frame budget.
- Kept superscript/subscript inside the paragraph fast path and moved inline
  text backspace to delta history, avoiding full-document undo snapshots for
  the common backspace case.
- Changed progressive DOCX pagination to a Google Docs/Kix-style demand model:
  opening renders an initial page window, then discovers more pages only when
  scrolling nears the known end instead of computing the full page count in the
  background.
- Added command-latency benchmark coverage in
  `tool/bench/command_latency_bench.dart`.

### Benchmarks

- TR DOCX (`PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx`)
  command benchmark, release dart2js:
  - selected-word bold: 16.9 ms;
  - undo/redo bold: 20.5 ms / 21.0 ms;
  - inline paste 3x: 371.8 ms total;
  - undo/redo paste: 31.5 ms / 46.8 ms;
  - delete table / undo delete table: 256.0 ms / 180.3 ms.
- Expanded command benchmark matrix now measures formatting commands
  (`font`, `size`, `bold`, `italic`, `underline`, `strikeout`,
  `superscript`, `subscript`, `color`, `highlight`) in fast-path and fallback
  selections, plus inline insert, backspace, and table row/column/table edits.
  Latest TR run: fast backspace / undo 31.5 ms / 38.4 ms; fast
  superscript/subscript 36.9 ms / 66.1 ms. Fallback/full layout and table
  row/column operations still expose multi-second global-layout work.
- Full E2E smoke suite passes: 39/39.

### Architecture

- Added an OnlyOffice-based architecture/performance plan in
  `doc/plano_arquitetura_performance_onlyoffice.md`.
- Documented the next extraction path for the current monoliths:
  `draw.dart` should be split around document model, delta history, layout
  scheduler/cache, page rendering, and viewport/canvas management; `editor.dart`
  should be split into UI controllers for DOCX, toolbar, search, page controls,
  dialogs, and persistence.

### UI and DOCX Fidelity

- Made the ribbon tabs functional: File, Home, Insert, Layout, Review, and View
  now filter the toolbar commands instead of changing only the active tab label.
- Promoted Word-like page setup controls into the Layout ribbon: paper size,
  orientation, margin presets/custom margins, paginated/continuous mode, and
  explicit header/footer edit/close actions.
- Replaced the mixed toolbar artwork with a local Tabler Icons set, removed
  external UI CDN dependencies from the shell, and made primary ribbon commands
  larger with short Word-style labels.
- Fixed ribbon dropdown positioning after the Word-style toolbar redesign:
  menus now open below the ribbon, are no longer clipped by the toolbar, and can
  be toggled closed by clicking the owning command again.
- Added Word-like horizontal and vertical rulers aligned to the page canvas,
  with centimeter ticks and automatic resize/scroll synchronization.
- Fixed duplicated DOCX footer pagination by stripping cached Word
  `Página X | Y` text when PAGE/NUMPAGES is rendered by the editor's dynamic
  page-number layer.
- Made the header/footer zone activate on click so users can place the caret in
  editable header/footer content without relying on a hidden double-click flow.
- Added a quick action to remove imported floating header text boxes/carimbos
  when they block editing while the full Word-style floating-object editor is
  still pending.
- Fixed table UI controls that stretched across long paginated tables by using
  valid div-based insert cells, keeping quick-add/select controls compact, and
  clipping the row/border overlay to the visible page segment.
- Extended the contextual mini toolbar with Word-style table and image modes:
  selecting inside a table now offers row/column insert/delete, merge/unmerge
  and delete-table; clicking an image offers change/save and the five
  text-wrap displays, with the active display highlighted.

### PDF Export (vector)

- Replaced the raster (JPEG-per-page) PDF export with a **vector PDF
  exporter** in pure Dart: real, selectable and searchable text using the
  standard-14 fonts with WinAnsiEncoding (Arial→Helvetica, Times New
  Roman→Times, monospace→Courier — metrically compatible), positioned from
  the editor's own computed layout so pagination and alignment match the
  canvas exactly. The old raster encoder remains only as a fallback.
- Vector output covers highlights, underline/strikeout, table cell
  backgrounds/borders (including dash, external/internal modes, slashes and
  per-cell borders), list markers, checkbox/radio, separators, header/footer
  rows, header text boxes (carimbos), page numbers, watermark and floating
  images; hyperlinks become real clickable link annotations.
- Images are embedded without recompression: JPEG via DCTDecode (RGB, gray
  and CMYK) and PNG via Flate passthrough with PNG predictors; RGBA/LA PNGs
  are defiltered in Dart and split into image + SMask (alpha preserved).
- Added `CanvasEditorWidget.exportPdfBytes()` for programmatic export and
  made `downloadPdf` await full progressive pagination before exporting so
  large documents are not truncated.
- New pure-Dart PDF core (`PdfWriter`, `PdfContentBuilder`, image decoding,
  zlib/Adler-32 around the existing Deflate codec) exported from `ce_pdf.dart`
  and covered by VM unit tests; the E2E suite validates that the generated
  PDF contains the document text as extractable `Tj` operators.

## 1.0.0

- Initial version.
