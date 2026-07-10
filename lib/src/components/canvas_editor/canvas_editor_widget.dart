import 'dart:async';
import 'dart:html';
import 'dart:typed_data';

import 'package:canvas_text_editor/ce_docx.dart';

import '../../editor/index.dart';
import '../../word/docx_to_element.dart';
import '../../word/element_to_docx.dart';

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
    this.locale = 'ptBR',
    this.documentTitle = 'Documento — Canvas Editor',
    this.onDocumentLoaded,
    this.onError,
    this.data,
    this.editorOptions,
  });

  final CanvasEditorWidgetMode mode;
  final CanvasEditorAppearance appearance;
  final String height;
  final bool showToolbar;
  final String locale;
  final String documentTitle;
  final void Function(String fileName)? onDocumentLoaded;
  final void Function(Object error)? onError;
  final IEditorData? data;
  final IEditorOption? editorOptions;
}

/// Embeddable facade for Dart Web and AngularDart applications.
///
/// The widget owns only [host], never relies on body scrolling and does not
/// query toolbar elements outside its own root.
class CanvasEditorWidget {
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
  late final DivElement scrollContainer;
  late final DivElement editorSurface;
  late final Editor editor;
  late final FileUploadInputElement fileInput;
  StreamSubscription<Event>? _fileInputSubscription;
  DocxFile? _openedDocx;
  List<IElement>? _openedOriginalMain;

  Command get command => editor.command;
  IEditorResult get value => editor.getDraw().getValue();

  void _mount() {
    _ensureStylesheet(stylesheet, 'canvas-editor-embed');
    _ensureStylesheet(iconStylesheet, 'canvas-editor-tabler-icons');
    final int id = _nextId++;
    final String scrollId = 'ce-embed-scroll-$id';

    root = DivElement()..classes.add('ce-embed');
    if (config.mode == CanvasEditorWidgetMode.viewer) {
      root.classes.add('ce-embed--viewer');
    }
    if (config.appearance == CanvasEditorAppearance.word) {
      root.classes.add('ce-embed--word');
      root.append(_buildWordTitlebar());
    }
    if (config.showToolbar) {
      root.append(
        config.appearance == CanvasEditorAppearance.word
            ? _buildWordRibbon()
            : _buildCompactToolbar(),
      );
    }
    fileInput = FileUploadInputElement()
      ..accept =
          '.docx,application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      ..classes.add('ce-embed__file-input')
      ..setAttribute('aria-hidden', 'true');
    _fileInputSubscription = fileInput.onChange.listen(_handleFileSelection);
    root.append(fileInput);
    scrollContainer = DivElement()
      ..id = scrollId
      ..classes.add('ce-embed__scroll')
      ..style.height = config.height;
    editorSurface = DivElement()..classes.add('ce-embed__surface');
    scrollContainer.append(editorSurface);
    root.append(scrollContainer);
    _host.children
      ..clear()
      ..add(root);

    final IEditorOption options = config.editorOptions ?? IEditorOption();
    options
      ..mode = config.mode == CanvasEditorWidgetMode.viewer
          ? EditorMode.readonly
          : EditorMode.edit
      ..locale = config.locale
      ..scrollContainerSelector = '#$scrollId';
    final IEditorData initialData =
        config.data ?? IEditorData(main: <IElement>[IElement(value: '')]);
    editor = Editor(editorSurface, initialData, options);
  }

  DivElement _buildCompactToolbar() {
    final DivElement toolbar = DivElement()
      ..classes.add('ce-embed__toolbar')
      ..setAttribute('role', 'toolbar')
      ..setAttribute('aria-label', 'Formatação do documento');
    toolbar.children.addAll(<Element>[
      _button('open', 'ti-folder-open', 'Abrir DOCX', openFilePicker),
      _button(
          'undo', 'ti-arrow-back-up', 'Desfazer', () => command.executeUndo()),
      _button('redo', 'ti-arrow-forward-up', 'Refazer',
          () => command.executeRedo()),
      _button('bold', 'ti-bold', 'Negrito', () => command.executeBold()),
      _button('italic', 'ti-italic', 'Itálico', () => command.executeItalic()),
      _button('underline', 'ti-underline', 'Sublinhado',
          () => command.executeUnderline()),
      _button('align-left', 'ti-align-left', 'Alinhar à esquerda',
          () => command.executeRowFlex(RowFlex.left)),
      _button('align-center', 'ti-align-center', 'Centralizar',
          () => command.executeRowFlex(RowFlex.center)),
      _button('align-right', 'ti-align-right', 'Alinhar à direita',
          () => command.executeRowFlex(RowFlex.right)),
      _button('print', 'ti-printer', 'Imprimir', () => command.executePrint()),
    ]);
    return toolbar;
  }

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

  DivElement _buildWordRibbon() {
    final DivElement shell = DivElement()..classes.add('ce-word-ribbon');
    final DivElement tabs = DivElement()
      ..classes.add('ce-word-tabs')
      ..setAttribute('role', 'tablist');
    final DivElement panels = DivElement()..classes.add('ce-word-panels');

    void addTab(String id, String label, List<Element> groups) {
      final ButtonElement tab = ButtonElement()
        ..type = 'button'
        ..text = label
        ..dataset['ceTab'] = id
        ..classes.toggle('active', id == 'home')
        ..onClick.listen((_) => _activateWordTab(shell, id));
      tabs.append(tab);
      final DivElement panel = DivElement()
        ..classes.add('ce-word-panel')
        ..classes.toggle('active', id == 'home')
        ..dataset['cePanel'] = id
        ..children.addAll(groups);
      panels.append(panel);
    }

    addTab('file', 'Arquivo', <Element>[
      _ribbonGroup('Documento', <Element>[
        _button('open', 'ti-folder-open', 'Abrir DOCX', openFilePicker,
            labeled: true),
        _button('save', 'ti-device-floppy', 'Salvar DOCX', downloadDocx,
            labeled: true),
        _button('print', 'ti-printer', 'Imprimir', () => command.executePrint(),
            labeled: true),
      ]),
    ]);
    addTab('home', 'Página Inicial', <Element>[
      _ribbonGroup('Área de Transferência', <Element>[
        _button('undo', 'ti-arrow-back-up', 'Desfazer',
            () => command.executeUndo()),
        _button('redo', 'ti-arrow-forward-up', 'Refazer',
            () => command.executeRedo()),
        _button('format', 'ti-clear-formatting', 'Limpar',
            () => command.executeFormat()),
      ]),
      _fontGroup(),
      _ribbonGroup('Parágrafo', <Element>[
        _button('align-left', 'ti-align-left', 'Esquerda',
            () => command.executeRowFlex(RowFlex.left)),
        _button('align-center', 'ti-align-center', 'Centralizar',
            () => command.executeRowFlex(RowFlex.center)),
        _button('align-right', 'ti-align-right', 'Direita',
            () => command.executeRowFlex(RowFlex.right)),
        _button('justify', 'ti-align-justified', 'Justificar',
            () => command.executeRowFlex(RowFlex.alignment)),
        _button('list', 'ti-list', 'Lista',
            () => command.executeList(ListType.unordered)),
      ]),
      _ribbonGroup('Estilos', <Element>[
        _textCommand('Normal', () => command.executeTitle(null)),
        _textCommand('Título 1', () => command.executeTitle(TitleLevel.first)),
        _textCommand('Título 2', () => command.executeTitle(TitleLevel.second)),
      ]),
    ]);
    addTab('insert', 'Inserir', <Element>[
      _ribbonGroup('Páginas', <Element>[
        _button('page-break', 'ti-page-break', 'Quebra de página',
            () => command.executePageBreak(),
            labeled: true),
      ]),
      _ribbonGroup('Tabelas', <Element>[
        _button('table', 'ti-table', 'Tabela 3 × 3',
            () => command.executeInsertTable(3, 3),
            labeled: true),
      ]),
      _ribbonGroup('Texto e símbolos', <Element>[
        _button('separator', 'ti-separator-horizontal', 'Separador',
            () => command.executeSeparator(<num>[1, 1]),
            labeled: true),
      ]),
    ]);
    addTab('layout', 'Layout', <Element>[
      _ribbonGroup('Configurar Página', <Element>[
        _button('margin-normal', 'ti-layout', 'Margens normais',
            () => command.executeSetPaperMargin(<double>[96, 96, 96, 96]),
            labeled: true),
        _button('portrait', 'ti-file-orientation', 'Retrato',
            () => command.executePaperDirection(PaperDirection.vertical),
            labeled: true),
        _button('landscape', 'ti-file-orientation', 'Paisagem',
            () => command.executePaperDirection(PaperDirection.horizontal),
            labeled: true),
        _button('a4', 'ti-dimensions', 'Tamanho A4',
            () => command.executePaperSize(794, 1123),
            labeled: true),
      ]),
    ]);
    addTab('view', 'Exibir', <Element>[
      _ribbonGroup('Zoom', <Element>[
        _button('zoom-out', 'ti-zoom-out', 'Reduzir',
            () => command.executePageScaleMinus(),
            labeled: true),
        _button('zoom-reset', 'ti-zoom-reset', '100%',
            () => command.executePageScaleRecovery(),
            labeled: true),
        _button('zoom-in', 'ti-zoom-in', 'Ampliar',
            () => command.executePageScaleAdd(),
            labeled: true),
      ]),
    ]);
    shell.children.addAll(<Element>[tabs, panels]);
    return shell;
  }

  DivElement _fontGroup() {
    final SelectElement fonts = SelectElement()
      ..title = 'Fonte'
      ..classes.add('ce-word-select');
    for (final String font in <String>[
      'Arial',
      'Calibri',
      'Cambria',
      'Times New Roman'
    ]) {
      fonts.append(OptionElement(data: font, value: font));
    }
    fonts.onChange.listen((_) => command.executeFont(fonts.value ?? 'Arial'));
    final SelectElement sizes = SelectElement()
      ..title = 'Tamanho'
      ..classes.add('ce-word-select');
    for (final int size in <int>[8, 10, 12, 14, 16, 18, 24, 32, 48]) {
      sizes.append(OptionElement(data: '$size', value: '$size'));
    }
    sizes.value = '16';
    sizes.onChange.listen((_) => command.executeSize(int.parse(sizes.value!)));
    return _ribbonGroup('Fonte', <Element>[
      fonts,
      sizes,
      _button('bold', 'ti-bold', 'Negrito', () => command.executeBold()),
      _button('italic', 'ti-italic', 'Itálico', () => command.executeItalic()),
      _button('underline', 'ti-underline', 'Sublinhado',
          () => command.executeUnderline()),
      _button('strike', 'ti-strikethrough', 'Tachado',
          () => command.executeStrikeout()),
      _button('superscript', 'ti-superscript', 'Sobrescrito',
          () => command.executeSuperscript()),
      _button('subscript', 'ti-subscript', 'Subscrito',
          () => command.executeSubscript()),
    ]);
  }

  DivElement _ribbonGroup(String label, List<Element> children) => DivElement()
    ..classes.add('ce-word-group')
    ..children.addAll(<Element>[
      DivElement()
        ..classes.add('ce-word-group__commands')
        ..children.addAll(children),
      SpanElement()
        ..classes.add('ce-word-group__label')
        ..text = label,
    ]);

  ButtonElement _textCommand(String label, void Function() action) =>
      ButtonElement()
        ..type = 'button'
        ..classes.add('ce-word-style')
        ..text = label
        ..onMouseDown.listen((event) => event.preventDefault())
        ..onClick.listen((_) => action());

  void _activateWordTab(DivElement shell, String id) {
    for (final Element tab in shell.querySelectorAll('[data-ce-tab]')) {
      tab.classes.toggle('active', tab.dataset['ceTab'] == id);
    }
    for (final Element panel in shell.querySelectorAll('[data-ce-panel]')) {
      panel.classes.toggle('active', panel.dataset['cePanel'] == id);
    }
  }

  ButtonElement _button(
    String commandName,
    String iconClass,
    String label,
    void Function() action, {
    bool labeled = false,
  }) {
    final ButtonElement button = ButtonElement()
      ..type = 'button'
      ..title = label
      ..dataset['ceCommand'] = commandName
      ..classes.toggle('ce-word-command--labeled', labeled)
      ..setAttribute('aria-label', label)
      ..append(SpanElement()..classes.addAll(<String>['ti', iconClass]));
    if (labeled) {
      button.append(SpanElement()..text = label);
    }
    button.onMouseDown.listen((MouseEvent event) {
      // Keeps the canvas selection active while a format command is clicked.
      event.preventDefault();
    });
    button.onClick.listen((_) => action());
    return button;
  }

  /// Opens the native file picker. The input remains attached to the widget,
  /// which keeps this gesture compatible with stricter browsers and modals.
  void openFilePicker() {
    fileInput.value = '';
    fileInput.click();
  }

  Future<void> _handleFileSelection(Event _) async {
    final List<File>? files = fileInput.files;
    if (files == null || files.isEmpty) return;
    final File file = files.first;
    try {
      loadDocx(await _readFileBytes(file));
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
  void loadDocx(Uint8List bytes) {
    final DocxFile file = DocxReader.read(bytes);
    final DocxConversionResult converted = DocxToElementConverter.convert(file);
    _openedDocx = file;
    _openedOriginalMain = List<IElement>.from(converted.main);
    command
      ..executePaperSize(converted.pageWidthPx, converted.pageHeightPx)
      ..executeSetPaperMargin(converted.marginsPx)
      ..executeSetValue(
        IEditorData(
          header: converted.header,
          main: converted.main,
          footer: converted.footer,
        ),
        ISetValueOption(isSetCursor: false),
      );
  }

  /// Serializes the loaded DOCX while preserving unsupported original parts.
  Uint8List saveDocx() {
    final DocxFile? file = _openedDocx;
    final List<IElement>? original = _openedOriginalMain;
    if (file == null || original == null) {
      throw StateError('Abra um DOCX antes de salvá-lo.');
    }
    EditorToDocx.apply(file, value.data.main, original);
    return DocxWriter.write(file);
  }

  void downloadDocx([String fileName = 'documento.docx']) {
    try {
      final Blob blob = Blob(<Object>[
        saveDocx()
      ], 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      final String url = Url.createObjectUrlFromBlob(blob);
      AnchorElement(href: url)
        ..download = fileName
        ..click();
      Timer.run(() => Url.revokeObjectUrl(url));
    } catch (error) {
      config.onError?.call(error);
    }
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
  }

  void destroy() {
    _fileInputSubscription?.cancel();
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
