## Unreleased

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

## 1.0.0

- Initial version.
