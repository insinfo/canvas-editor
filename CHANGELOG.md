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
- Full E2E smoke suite passes: 39/39.

### Architecture

- Added an OnlyOffice-based architecture/performance plan in
  `doc/plano_arquitetura_performance_onlyoffice.md`.
- Documented the next extraction path for the current monoliths:
  `draw.dart` should be split around document model, delta history, layout
  scheduler/cache, page rendering, and viewport/canvas management; `editor.dart`
  should be split into UI controllers for DOCX, toolbar, search, page controls,
  dialogs, and persistence.

## 1.0.0

- Initial version.
