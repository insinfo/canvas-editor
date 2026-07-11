import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:typed_data';

import 'package:canvas_text_editor/ce_docx.dart';
import 'package:canvas_text_editor/ce_pdf.dart';

import '../../editor/core/draw/pdf/vector_pdf_exporter.dart';
import '../../editor/core/listener/listener.dart';
import '../../editor/index.dart';
import '../../editor/interface/draw.dart' show IDrawOption, IGetImageOption;
import '../../editor/interface/footer.dart';
import '../../editor/interface/header.dart' as header_model;
import '../../editor/interface/page_number.dart';
import '../../editor/interface/page_break.dart';
import '../../word/docx_to_element.dart';
import '../../word/element_to_docx.dart';
import '../../word/quill_delta.dart';
import '../core/ui_component.dart';
import 'widget_loading_overlay.dart';
import 'widget_floating_toolbar.dart';
import 'widget_ribbon.dart';
import 'widget_ruler.dart';
import 'widget_side_panels.dart';
import 'widget_status_bar.dart';
import 'widget_viewer_toolbar.dart';

/// High-level mode used by [CanvasEditorWidget].
enum CanvasEditorWidgetMode { editor, viewer }

/// Amount of editor chrome rendered around the document.
enum CanvasEditorAppearance { compact, word }

/// Configuration for an editor that can safely live inside a page or modal.
class CanvasEditorConfig {
  CanvasEditorConfig({
    this.mode = CanvasEditorWidgetMode.editor,
    this.appearance = CanvasEditorAppearance.compact,
    this.height = '640px',
    this.showToolbar = true,
    this.showStatusBar = true,
    this.locale = 'ptBR',
    this.documentTitle = 'Documento — Canvas Editor',
    this.onDocumentLoaded,
    this.onError,
    this.data,
    this.editorOptions,
    this.comments = const <CanvasEditorComment>[],
    this.onCommentDeleted,
    this.showFloatingToolbar = true,
    this.showRulers = true,
  });

  final CanvasEditorWidgetMode mode;
  final CanvasEditorAppearance appearance;
  final String height;
  final bool showToolbar;
  final bool showStatusBar;
  final String locale;
  final String documentTitle;
  final void Function(String fileName)? onDocumentLoaded;
  final void Function(Object error)? onError;
  final IEditorData? data;
  final IEditorOption? editorOptions;
  final List<CanvasEditorComment> comments;
  final void Function(CanvasEditorComment comment)? onCommentDeleted;
  final bool showFloatingToolbar;
  final bool showRulers;
}

/// Embeddable facade for Dart Web and AngularDart applications.
///
/// The widget owns only [host], never relies on body scrolling and does not
/// query toolbar elements outside its own root. A shell é composta por
/// componentes com ciclo de vida próprio ([UiComponent]): ribbon/toolbar,
/// painéis laterais, barra de status e overlay de carregamento. Eventos do
/// editor que espelham estado na shell (ex.: `rangeStyleChange`) passam por
/// um [UiScheduler], que coalesce as atualizações em um flush por frame.
class CanvasEditorWidget
    implements CanvasEditorShellActions, CanvasViewerActions {
  CanvasEditorWidget(HtmlElement host, {CanvasEditorConfig? config})
      : _host = host,
        config = config ?? CanvasEditorConfig() {
    _mount();
  }

  static const String stylesheet =
      'packages/canvas_text_editor/assets/canvas_editor.css';
  static const String iconStylesheet =
      'packages/canvas_text_editor/assets/icons/tabler/tabler-icons.css';

  static int _nextId = 0;

  final HtmlElement _host;
  final CanvasEditorConfig config;
  late final DivElement root;
  late final DivElement body;
  late final DivElement scrollContainer;
  late final DivElement editorSurface;
  late final Editor editor;
  late final FileUploadInputElement fileInput;

  late final UiScheduler _scheduler;
  late final WidgetLoadingOverlay loading;
  late final WidgetStatusBar statusBar;
  late final WidgetCatalogPanel catalogPanel;
  late final WidgetFindPanel findPanel;
  late final WidgetCommentsPanel commentsPanel;
  WidgetFloatingToolbar? _floatingToolbar;
  WidgetRibbon? _ribbon;
  WidgetCompactToolbar? _compactToolbar;
  late final WidgetViewerToolbar _viewerToolbar;
  WidgetRuler? _ruler;
  bool _rulersVisible = true;

  StreamSubscription<Event>? _fileInputSubscription;
  Timer? _wordCountDebounce;
  IRangeStyle? _pendingRangeStyle;

  DocxFile? _openedDocx;
  String? _openedDocxName;
  List<IElement>? _openedConvertedMain;
  List<IElement>? _openedOriginalMain;

  @override
  Command get command => editor.command;
  IEditorResult get value => editor.getDraw().getValue();

  void _mount() {
    _ensureStylesheet(stylesheet, 'canvas-editor-embed');
    _ensureStylesheet(iconStylesheet, 'canvas-editor-tabler-icons');
    final int id = _nextId++;
    final String scrollId = 'ce-embed-scroll-$id';

    _scheduler = UiScheduler();

    root = DivElement()..classes.add('ce-embed');
    if (config.mode == CanvasEditorWidgetMode.viewer) {
      root.classes.add('ce-embed--viewer');
    }
    if (config.appearance == CanvasEditorAppearance.word &&
        config.mode == CanvasEditorWidgetMode.editor) {
      root.classes.add('ce-embed--word');
      root.append(_buildWordTitlebar());
    }

    fileInput = FileUploadInputElement()
      ..accept =
          '.docx,application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      ..classes.add('ce-embed__file-input')
      ..setAttribute('aria-hidden', 'true');
    _fileInputSubscription = fileInput.onChange.listen(_handleFileSelection);

    scrollContainer = DivElement()
      ..id = scrollId
      ..classes.add('ce-embed__scroll')
      // Focável por clique (tabindex -1): garante que Ctrl+F/Ctrl+H cheguem
      // ao root também no modo viewer, onde a inputarea do editor fica oculta.
      ..tabIndex = -1
      ..style.height = config.height;
    editorSurface = DivElement()..classes.add('ce-embed__surface');
    scrollContainer.append(editorSurface);
    body = DivElement()
      ..classes.add('ce-embed__body')
      ..append(scrollContainer);

    _host.children.clear();

    final IEditorOption options = config.editorOptions ?? IEditorOption();
    options
      ..mode = config.mode == CanvasEditorWidgetMode.viewer
          ? EditorMode.readonly
          : EditorMode.edit
      ..locale = config.locale
      ..scrollContainerSelector = '#$scrollId';
    final IEditorData initialData =
        config.data ?? IEditorData(main: <IElement>[IElement(value: '')]);

    // O editor precisa do DOM montado; monta a árvore antes de instanciá-lo.
    root.append(fileInput);
    root.append(body);
    _host.append(root);
    editor = Editor(editorSurface, initialData, options);

    if (config.showToolbar && config.mode == CanvasEditorWidgetMode.editor) {
      if (config.appearance == CanvasEditorAppearance.word) {
        _ribbon = WidgetRibbon(this, menuHost: root);
        root.insertBefore(_ribbon!.root, fileInput);
      } else {
        _compactToolbar = WidgetCompactToolbar(this);
        root.insertBefore(_compactToolbar!.root, fileInput);
      }
    }

    _viewerToolbar = WidgetViewerToolbar(this)
      ..setVisible(config.mode == CanvasEditorWidgetMode.viewer);
    root.insertBefore(_viewerToolbar.root, fileInput);

    _rulersVisible = config.showRulers;
    if (config.appearance == CanvasEditorAppearance.word) {
      _ruler = WidgetRuler(command, editor.getDraw())
        ..setVisible(
            config.mode == CanvasEditorWidgetMode.editor && _rulersVisible);
      scrollContainer.insertBefore(_ruler!.root, editorSurface);
    }

    catalogPanel = WidgetCatalogPanel(command, onClose: closeCatalog);
    findPanel = WidgetFindPanel(command, onClose: () {});
    commentsPanel = WidgetCommentsPanel(
      command,
      comments: config.comments,
      onClose: () {},
      onDelete: config.onCommentDeleted,
      readOnly: config.mode == CanvasEditorWidgetMode.viewer,
    );
    body
      ..insertBefore(findPanel.root, scrollContainer)
      ..insertBefore(catalogPanel.root, findPanel.root)
      ..insertBefore(commentsPanel.root, catalogPanel.root);

    statusBar = WidgetStatusBar(command)
      ..setVisible(
          config.showStatusBar && config.mode == CanvasEditorWidgetMode.editor);
    root.append(statusBar.root);

    loading = WidgetLoadingOverlay(root);

    if (config.showFloatingToolbar &&
        config.mode == CanvasEditorWidgetMode.editor) {
      _floatingToolbar = WidgetFloatingToolbar(command, editor.getDraw(), root);
      root.append(_floatingToolbar!.root);
    }

    _attachListeners();
    _attachKeyboardShortcuts();
    _scheduleWordCount();
  }

  // ---------------------------------------------------------------------
  // Listeners e atalhos
  // ---------------------------------------------------------------------

  void _attachListeners() {
    final Listener listener = editor.listener;
    listener.intersectionPageNoChange = (int pageNo) {
      statusBar.setCurrentPage(pageNo + 1);
    };
    listener.pageSizeChange = (num pageCount) {
      statusBar.setPageCount(pageCount.toInt());
    };
    listener.pageScaleChange = (double scale) {
      statusBar.setScale(scale);
      _ruler?.refresh();
    };
    listener.pageModeChange = (PageMode mode) {
      statusBar.setPageMode(mode);
      _ribbon?.syncPageMode(mode);
    };
    listener.contentChange = _handleContentChange;
    // Estado da seleção → shell: guarda só o último payload e agenda UM
    // flush por frame; clique/tecla nunca paga o custo do DOM na hora.
    listener.rangeStyleChange = (IRangeStyle payload) {
      _pendingRangeStyle = payload;
      _scheduler.schedule(_flushRangeStyle);
    };
  }

  void _flushRangeStyle() {
    final IRangeStyle? style = _pendingRangeStyle;
    if (style == null) return;
    _pendingRangeStyle = null;
    _ribbon?.syncRangeStyle(style);
    _compactToolbar?.syncRangeStyle(style);
    _floatingToolbar?.syncStyle(style);
    _scheduler.schedule(_floatingToolbar?.refresh ?? () {});
  }

  void _handleContentChange() {
    _scheduleWordCount();
    if (catalogPanel.isVisible) {
      unawaited(catalogPanel.refresh());
    }
    if (commentsPanel.isVisible) {
      unawaited(commentsPanel.refresh());
    }
  }

  void _scheduleWordCount() {
    _wordCountDebounce?.cancel();
    _wordCountDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        statusBar.setWordCount(await command.getWordCount());
      } catch (_) {
        // Contagem de palavras é acessória; nunca derruba a edição.
      }
    });
  }

  void _attachKeyboardShortcuts() {
    listenToRootMouseUp();
    root.onKeyDown.listen((KeyboardEvent event) {
      if (!(event.ctrlKey || event.metaKey)) return;
      final String? key = event.key?.toLowerCase();
      if (key == 'f') {
        event.preventDefault();
        openFind();
      } else if (key == 'h') {
        event.preventDefault();
        openFind(focusReplace: true);
      }
    });
  }

  void listenToRootMouseUp() {
    root.onMouseUp.listen((_) {
      _scheduler.schedule(_floatingToolbar?.refresh ?? () {});
    });
    scrollContainer.onScroll.listen((_) => _floatingToolbar?.hide());
  }

  // ---------------------------------------------------------------------
  // Painéis laterais
  // ---------------------------------------------------------------------

  /// Abre/fecha o painel de navegação (catálogo de títulos).
  @override
  void toggleCatalog() {
    if (catalogPanel.isVisible) {
      closeCatalog();
    } else {
      if (findPanel.isVisible) findPanel.close();
      if (commentsPanel.isVisible) commentsPanel.hide();
      catalogPanel.show();
      unawaited(catalogPanel.refresh());
    }
  }

  void closeCatalog() => catalogPanel.hide();

  /// Abre/fecha os comentários associados aos `groupIds` do documento.
  @override
  void toggleComments() {
    if (commentsPanel.isVisible) {
      commentsPanel.hide();
      return;
    }
    if (catalogPanel.isVisible) catalogPanel.hide();
    if (findPanel.isVisible) findPanel.close();
    unawaited(commentsPanel.show());
  }

  void setComments(Iterable<CanvasEditorComment> comments) =>
      commentsPanel.setComments(comments);

  /// Abre o painel Localizar/Substituir (Ctrl+F / Ctrl+H).
  @override
  void openFind({bool focusReplace = false}) {
    if (catalogPanel.isVisible) catalogPanel.hide();
    if (commentsPanel.isVisible) commentsPanel.hide();
    findPanel.open(focusReplace: focusReplace);
  }

  void setStatusBarVisible(bool visible) => statusBar.setVisible(visible);

  @override
  void togglePageBreakMarkers() {
    final draw = editor.getDraw();
    final IPageBreak pageBreak = draw.getOptions().pageBreak ?? IPageBreak();
    pageBreak.showMarker = pageBreak.showMarker == false;
    draw.getOptions().pageBreak = pageBreak;
    draw.render(IDrawOption(
      isCompute: false,
      isSetCursor: false,
      isSubmitHistory: false,
    ));
  }

  @override
  void toggleRulers() {
    _rulersVisible = !_rulersVisible;
    _ruler?.setVisible(_rulersVisible &&
        !root.classes.contains('ce-embed--viewer') &&
        !root.classes.contains('ce-view-draft'));
  }

  @override
  void setDocumentViewMode(CanvasDocumentViewMode mode) {
    root.classes
      ..toggle('ce-view-web', mode == CanvasDocumentViewMode.webLayout)
      ..toggle('ce-view-draft', mode == CanvasDocumentViewMode.draft);
    command.executePageMode(mode == CanvasDocumentViewMode.printLayout
        ? PageMode.paging
        : PageMode.continuity);
    _ruler?.setVisible(_rulersVisible && mode != CanvasDocumentViewMode.draft);
  }

  /// Reavalia a mini-toolbar após uma seleção criada programaticamente.
  void refreshFloatingToolbar() => _floatingToolbar?.refresh();

  DivElement _buildWordTitlebar() => DivElement()
    ..classes.add('ce-word-titlebar')
    ..children.addAll(<Element>[
      SpanElement()
        ..classes.addAll(<String>['ti', 'ti-file-type-docx'])
        ..setAttribute('aria-hidden', 'true'),
      SpanElement()
        ..classes.add('ce-word-titlebar__title')
        ..text = config.documentTitle,
      SpanElement()
        ..classes.add('ce-word-titlebar__mode')
        ..text = config.mode == CanvasEditorWidgetMode.viewer
            ? 'Somente leitura'
            : 'Editando',
    ]);

  // ---------------------------------------------------------------------
  // Abrir/salvar DOCX
  // ---------------------------------------------------------------------

  /// Opens the native file picker. The input remains attached to the widget,
  /// which keeps this gesture compatible with stricter browsers and modals.
  @override
  void openFilePicker() {
    fileInput.value = '';
    fileInput.click();
  }

  Future<void> _handleFileSelection(Event _) async {
    final List<File>? files = fileInput.files;
    if (files == null || files.isEmpty) return;
    final File file = files.first;
    try {
      await loadDocx(await _readFileBytes(file), fileName: file.name);
      config.onDocumentLoaded?.call(file.name);
    } catch (error) {
      config.onError?.call(error);
      rethrow;
    }
  }

  Future<Uint8List> _readFileBytes(File file) {
    final Completer<Uint8List> completer = Completer<Uint8List>();
    final FileReader reader = FileReader();
    reader.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer
            .completeError(reader.error ?? StateError('Falha ao ler DOCX.'));
      }
    });
    reader.onLoad.first.then((_) {
      final Object? result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
      } else if (result is Uint8List) {
        completer.complete(result);
      } else {
        completer.completeError(
            StateError('O navegador não retornou bytes do DOCX.'));
      }
    });
    reader.readAsArrayBuffer(file);
    return completer.future;
  }

  /// Replaces the current document with a DOCX without recreating the widget.
  ///
  /// Toda a configuração de página (geometria, numeração dinâmica, distâncias
  /// de cabeçalho/rodapé e caixas de texto flutuantes) é aplicada ANTES do
  /// `executeSetValue`, que faz o único render da abertura.
  Future<void> loadDocx(Uint8List bytes, {String? fileName}) async {
    await loading.show('Abrindo ${fileName ?? 'documento'}…');
    try {
      final DocxFile file = DocxReader.read(bytes);
      final DocxConversionResult converted =
          DocxToElementConverter.convert(file);

      final dynamic draw = editor.getDraw();
      draw.setPaperOptionsSilently(
        width: converted.pageWidthPx.toDouble(),
        height: converted.pageHeightPx.toDouble(),
        margins: converted.marginsPx,
      );

      // Campos PAGE/NUMPAGES do rodapé viram numeração dinâmica; sem campos,
      // desliga o pageNumber (evita número espúrio).
      final dynamic drawOptions = draw.getOptions();
      if (converted.pageNumberFormat != null) {
        drawOptions.pageNumber = IPageNumber(
          format: converted.pageNumberFormat,
          // jc ausente no Word = esquerda (painter usa center por default).
          rowFlex: converted.pageNumberRowFlex ?? RowFlex.left,
          size: converted.pageNumberSize?.toDouble(),
          font: converted.pageNumberFont,
          color: converted.pageNumberColor,
          // Número de página abaixo do banner do rodapé, na margem inferior.
          bottom: (converted.footerDistancePx - 18)
              .clamp(4, converted.footerDistancePx)
              .toDouble(),
        );
      } else {
        drawOptions.pageNumber = IPageNumber(disabled: true);
      }
      (drawOptions.header ??= header_model.IHeader()).top =
          converted.headerDistancePx;
      (drawOptions.footer ??= IFooter()).bottom = converted.footerDistancePx;

      // Caixas de texto flutuantes do cabeçalho (carimbos): aplicadas ao
      // frame do header antes do render do setValue.
      draw.getHeader().setTextBoxes(<header_model.IHeaderTextBox>[
        for (final tb in converted.headerTextBoxes)
          header_model.IHeaderTextBox(
            elements: tb.elements,
            alignRight: tb.alignRight,
            offsetYPx: tb.offsetYPx,
            widthPx: tb.widthPx,
            heightPx: tb.heightPx,
            borderColor: tb.borderColor,
            borderWidthPx: tb.borderWidthPx,
            fillColor: tb.fillColor,
          ),
      ]);

      draw.getRange().clearRange();
      command.executeSetValue(IEditorData(
        header: converted.header,
        main: converted.main,
        footer: converted.footer,
      ));

      _openedDocx = file;
      _openedDocxName = fileName;
      // Referência de "intocado" para o save: materializada só no 1º save.
      _openedConvertedMain = converted.main;
      _openedOriginalMain = null;

      if (fileName != null) {
        root.querySelector('.ce-word-titlebar__title')?.text = fileName;
      }
      _scheduleWordCount();
      if (catalogPanel.isVisible) {
        unawaited(catalogPanel.refresh());
      }
    } finally {
      loading.hide();
    }
  }

  /// Serializes the loaded DOCX while preserving unsupported original parts.
  Uint8List saveDocx() {
    DocxFile? file = _openedDocx;
    if (file == null) {
      file = DocxReader.createEmpty();
      final DocxConversionResult converted =
          DocxToElementConverter.convert(file);
      _openedDocx = file;
      _openedConvertedMain = converted.main;
    }
    // Materializa a referência de save a partir do snapshot pristino do
    // conversor (adiada da abertura para o 1º save).
    _openedOriginalMain ??= (editor.getDraw() as dynamic)
            .buildSaveReferenceFromConverted(_openedConvertedMain!)
        as List<IElement>;
    final List<IElement> currentMain = value.data.main;
    EditorToDocx.apply(file, currentMain, _openedOriginalMain!);
    final Uint8List bytes = DocxWriter.write(file);
    // Reancora o modelo no arquivo salvo para saves subsequentes.
    _openedDocx = DocxReader.read(bytes);
    _openedOriginalMain = currentMain;
    return bytes;
  }

  @override
  Future<void> downloadDocx([String? fileName]) async {
    final String name = fileName ?? _openedDocxName ?? 'documento.docx';
    await loading.show('Salvando $name…');
    try {
      final Blob blob = Blob(<Object>[
        saveDocx()
      ], 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      final String url = Url.createObjectUrlFromBlob(blob);
      AnchorElement(href: url)
        ..download = name
        ..click();
      Timer.run(() => Url.revokeObjectUrl(url));
    } catch (error) {
      config.onError?.call(error);
    } finally {
      loading.hide();
    }
  }

  /// Exporta a página visível como PNG (comando `getImage` do editor).
  @override
  Future<void> exportCurrentPageImage() async {
    await loading.show('Gerando imagem da página…');
    try {
      final List<String> images = await command.getImage();
      if (images.isEmpty) return;
      final int index = statusBar.currentPageIndex.clamp(0, images.length - 1);
      AnchorElement(href: images[index])
        ..download = 'pagina-${index + 1}.png'
        ..click();
    } catch (error) {
      config.onError?.call(error);
    } finally {
      loading.hide();
    }
  }

  /// Exporta o documento para um PDF **vetorial**: texto real selecionável e
  /// pesquisável (fontes standard-14 WinAnsi), tabelas/realces/sublinhados
  /// como vetores e imagens embutidas — usando o layout já computado pelo
  /// editor, sem rasterizar páginas. Se o export vetorial falhar, cai no
  /// codificador raster antigo como contingência.
  @override
  Future<void> downloadPdf([String? fileName]) async {
    final String requested = fileName ?? _openedDocxName ?? 'documento.pdf';
    final String name = requested.toLowerCase().endsWith('.pdf')
        ? requested
        : '${requested.replaceFirst(RegExp(r'\.[^.]+$'), '')}.pdf';
    await loading.show('Gerando $name…');
    try {
      Uint8List bytes;
      try {
        await _ensureFullPagination();
        bytes = exportPdfBytes();
      } catch (_) {
        bytes = await _exportRasterPdfFallback();
      }
      final String url = Url.createObjectUrlFromBlob(
        Blob(<Object>[bytes], 'application/pdf'),
      );
      AnchorElement(href: url)
        ..download = name
        ..click();
      Timer.run(() => Url.revokeObjectUrl(url));
    } catch (error) {
      config.onError?.call(error);
    } finally {
      loading.hide();
    }
  }

  /// Exporta o documento atual como bytes de PDF **vetorial** (texto
  /// selecionável/pesquisável), sem disparar download. Para documentos
  /// grandes abertos há pouco, chame após a paginação completa (o
  /// [downloadPdf] cuida disso automaticamente).
  Uint8List exportPdfBytes() =>
      VectorPdfExporter(editor.getDraw()).export(title: config.documentTitle);

  /// Força a paginação progressiva (estilo Google Docs) a descobrir todas as
  /// páginas antes do export — senão documentos grandes sairiam truncados.
  Future<void> _ensureFullPagination() async {
    final draw = editor.getDraw();
    if (!draw.isProgressiveLayoutPending()) return;
    for (int i = 0; i < 10000; i++) {
      draw.ensureProgressiveLayoutForPage(1 << 30);
      if (!draw.isProgressiveLayoutPending()) return;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    throw TimeoutException(
      'A paginação completa não terminou antes da exportação do PDF.',
    );
  }

  Future<Uint8List> _exportRasterPdfFallback() async {
    final List<String> dataUrls = await command.getImage(IGetImageOption(
      pixelRatio: 1,
      mode: EditorMode.print,
      mimeType: 'image/jpeg',
      quality: 0.92,
    ));
    final List<Uint8List> pages = <Uint8List>[
      for (final String dataUrl in dataUrls) _decodeDataUrl(dataUrl),
    ];
    return RasterPdfEncoder.encode(pages, title: config.documentTitle);
  }

  static Uint8List _decodeDataUrl(String dataUrl) {
    final int comma = dataUrl.indexOf(',');
    if (comma < 0 || !dataUrl.substring(0, comma).contains(';base64')) {
      throw const FormatException('Imagem de página inválida.');
    }
    return base64Decode(dataUrl.substring(comma + 1));
  }

  /// Exporta o documento atual no formato Delta do Quill
  /// (`{"ops": [...]}`), pronto para `jsonEncode`.
  Map<String, dynamic> toQuillDelta() =>
      QuillDeltaConverter.toDelta(value.data.main);

  /// Substitui o documento pelo conteúdo de um Delta do Quill.
  void loadQuillDelta(Map<String, dynamic> delta) {
    command.executeSetValue(
      IEditorData(main: QuillDeltaConverter.fromDelta(delta)),
    );
  }

  void setMode(CanvasEditorWidgetMode mode) {
    root.classes
        .toggle('ce-embed--viewer', mode == CanvasEditorWidgetMode.viewer);
    root.querySelector('.ce-word-titlebar__mode')?.text =
        mode == CanvasEditorWidgetMode.viewer ? 'Somente leitura' : 'Editando';
    command.executeMode(
      mode == CanvasEditorWidgetMode.viewer
          ? EditorMode.readonly
          : EditorMode.edit,
    );
    final bool viewer = mode == CanvasEditorWidgetMode.viewer;
    _viewerToolbar.setVisible(viewer);
    statusBar.setVisible(!viewer && config.showStatusBar);
    _ruler?.setVisible(!viewer && _rulersVisible);
    if (viewer) _floatingToolbar?.hide();
  }

  void _goToViewerPage(int delta) {
    final List<Element> pages = editor.getDraw().getPageList();
    if (pages.isEmpty) return;
    final int target =
        (statusBar.currentPageIndex + delta).clamp(0, pages.length - 1);
    scrollContainer.scrollTop = pages[target].offsetTop - 24;
    statusBar.setCurrentPage(target + 1);
  }

  @override
  void viewerPreviousPage() => _goToViewerPage(-1);

  @override
  void viewerNextPage() => _goToViewerPage(1);

  @override
  void viewerZoomOut() => command.executePageScaleMinus();

  @override
  void viewerZoomIn() => command.executePageScaleAdd();

  @override
  void viewerPrint() => command.executePrint();

  void destroy() {
    _wordCountDebounce?.cancel();
    _fileInputSubscription?.cancel();
    _scheduler.dispose();
    _ribbon?.dispose();
    _compactToolbar?.dispose();
    _viewerToolbar.dispose();
    _ruler?.dispose();
    catalogPanel.dispose();
    findPanel.dispose();
    commentsPanel.dispose();
    _floatingToolbar?.dispose();
    statusBar.dispose();
    loading.dispose();
    editor.destroy();
    root.remove();
  }

  static void _ensureStylesheet(String href, String marker) {
    if (document.head?.querySelector('link[data-ce-style="$marker"]') != null) {
      return;
    }
    document.head?.append(
      LinkElement()
        ..rel = 'stylesheet'
        ..href = href
        ..dataset['ceStyle'] = marker,
    );
  }
}
