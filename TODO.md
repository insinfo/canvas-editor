comece a implementar os recursos auzentes que fora perdidos devido a ultima restruturação para almentar a paridade com o word ## 2.0.0-dev — Complete Restructuring

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

### Known UI Regressions

The following Word-mode interface features are **not currently working** and
will be addressed in the next commit:

- **Page setup**: Paper size, margins, and orientation dialogs/controls do not
  apply changes to the document layout.
- **Page mode vs continuous mode**: Switching between paginated and non-paginated
  (continuous/scroll) rendering modes is broken.
- **Catalog sidebar**: The table of contents / document catalog panel does not
  open or render.
- **Comments sidebar**: The comments/annotations panel is not functional.
- **Loading animation**: The loading overlay/spinner that was shown when opening
  or saving DOCX files is no longer displayed.
- **Text box rendering**: The text-box rendering in documents like
  `PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública` stopped working — floating text
  boxes are not displayed.
- **Status bar**: The bottom status bar (page count, word count, zoom slider) is
  not rendered.
- **Find & Replace**: The sidebar search/replace panel may be non-functional.
- **Page number footer**: Dynamic page numbering in footers may show duplicated
  or missing values.
- **Many other UI elements** from the previous Word-mode interface have not yet
  been ported to the new component architecture.

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

## 1.0.0

- Initial version.
 C:\MyDartProjects\canvas-editor-port\resources\Captura de tela 2026-07-08 045750.png  C:\MyDartProjects\canvas-editor-port\resources\Captura de tela 2026-07-08 045816.png  C:\MyDartProjects\canvas-editor-port\resources\Captura de tela 2026-07-08 045849.png C:\MyDartProjects\canvas-editor-port\resources incluindo menus flutuantes  contextuais para edição de tabela edião rapida de texto imagem etc, alem de melhorar o modo somente visualizador para otimizar para visulização e busca de testo zoom expotar pagina para imagem expotar documento para o formato delta do quill importar delta do quill exportação para PDF etc referencias C:\MyDartProjects\dart_quill e C:\MyDartProjects\  C:\MyDartProjects\canvas-editor-port\doc

 alem disso é bom organizar o C:\MyDartProjects\canvas-editor-port\lib\src\components para ter uma estrutura paronizada e bem orginzada com cliclos de vida etc tipo um mini frameork para que todos os componentes erdem de uma intreface padrnizada etc ou seja um codimo performatico e manutenivel pois é interecante ter uma option que ao clicar em um texto bold a opção bold da ribbom bar fica ativo assim como o tamanho da fonte e font famili e assim por diante ao licar no texto chama uma função que agenda a atualização da sehll ribom bar de froma eficiente sem causar travamentos e lentidão no clico de edição e digital etc

 "tabelas são achatadas em texto no export" isso esta errado tem que suportar os recuros do quill quill_table_better  as referencias voce encontra aqui  C:\MyDartProjects\new_sali\frontend\web\assets\js\quill  C:\MyDartProjects\new_sali\core\lib\dependencies C:\MyDartProjects\new_sali\frontend\web\assets\js\quill_table_better para lidar com  O que ainda falta (próximos passos sugeridos)
Sidebar de comentários — a infra (executeLocationGroup/executeDeleteGroup) existe; falta definir a fonte de dados no widget (o antigo usava mock).
Menus contextuais flutuantes de tabela/texto/imagem — o context menu de clique-direito do core já está ativo; os mini-toolbars flutuantes estilo Word são feature nova.
Exportação PDF — nunca existiu (lib/src/document/pdf/ está vazio); é um projeto à parte.
Otimizações específicas do modo viewer (pular estruturas de edição no layout). o modo de expotação de PDF existiu no original C:\MyDartProjects\canvas-editor-port\referencias\canvas-editor-feature-pdf e

## Estado atualizado — 2026-07-10

- [x] Delta de tabelas compatível com `quill-table-better`, incluindo merges,
  TH, cores, títulos/listas e múltiplos parágrafos.
- [x] Sidebar de comentários com fonte de dados explícita no widget.
- [x] Exportação PDF multipágina fiel ao canvas (raster, Dart puro).
- [x] Mini-toolbar contextual para seleção de texto.
- [ ] Mini-toolbars contextuais específicas para tabela e imagem.
- [ ] PDF vetorial pesquisável/selecionável com subset de fontes TTF.
- [ ] Otimizações adicionais do layout no modo viewer.
