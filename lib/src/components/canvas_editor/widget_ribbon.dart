import 'dart:async';
import 'package:canvas_text_editor/src/dom/dom.dart';

import '../../editor/index.dart';
import '../../editor/interface/draw.dart' show IDrawImagePayload;
import '../core/ui_component.dart';
import '../dialog/dialog.dart';
import 'widget_floating_toolbar.dart' show FloatingToolbarMode;

/// Ações da shell que os toolbars invocam. Implementado pelo
/// `CanvasEditorWidget`, mantendo os componentes desacoplados do widget.
abstract class CanvasEditorShellActions {
  Command get command;
  void openFilePicker();
  Future<void> downloadDocx([String? fileName]);
  Future<void> exportCurrentPageImage();
  Future<void> downloadPdf([String? fileName]);
  Future<void> printDocument();
  void openFind({bool focusReplace = false});
  void toggleCatalog();
  void toggleComments();
  void togglePageBreakMarkers();
  void toggleRulers();
  void setDocumentViewMode(CanvasDocumentViewMode mode);
}

enum CanvasDocumentViewMode { printLayout, webLayout, draft }

/// Ribbon estilo Word (abas Arquivo/Página Inicial/Inserir/Layout/Exibir).
///
/// Além de disparar comandos, o ribbon espelha o estado da seleção: o widget
/// chama [syncRangeStyle] (agendado por frame via [UiScheduler]) e os botões
/// de formatação, fonte, tamanho, alinhamento e estilo ficam ativos conforme
/// o texto sob o cursor.
class WidgetRibbon extends UiComponent {
  WidgetRibbon(this._actions, {required Element menuHost})
      : _menuHost = menuHost {
    root = _build();
  }

  static const double _pxPerCm = 96 / 2.54;

  final CanvasEditorShellActions _actions;

  /// Elemento que hospeda menus suspensos — o root do widget, para o menu
  /// não ser cortado pelo overflow horizontal dos painéis do ribbon.
  final Element _menuHost;

  @override
  late final HTMLDivElement root;

  Command get _command => _actions.command;

  final Map<String, HTMLButtonElement> _commandButtons = <String, HTMLButtonElement>{};
  final Map<String, HTMLButtonElement> _tabButtons = <String, HTMLButtonElement>{};
  final Map<TitleLevel?, HTMLButtonElement> _styleButtons =
      <TitleLevel?, HTMLButtonElement>{};
  late HTMLDivElement _shell;
  String _activeTabId = 'home';
  FloatingToolbarMode _contextMode = FloatingToolbarMode.hidden;
  late final HTMLSelectElement _fontSelect;
  late final HTMLSelectElement _sizeSelect;

  HTMLDivElement? _openMenu;
  Element? _openMenuOwner;

  // -----------------------------------------------------------------------
  // Sincronização com a seleção (rangeStyleChange)
  // -----------------------------------------------------------------------

  /// Último estilo de seleção recebido — alimenta "Atualizar estilo para
  /// Corresponder à Seleção" do menu de contexto da galeria.
  IRangeStyle? _lastRangeStyle;

  /// Espelha o estilo do texto sob o cursor nos controles do ribbon.
  /// Chamado pelo widget no flush do [UiScheduler] — uma vez por frame.
  void syncRangeStyle(IRangeStyle style) {
    _setDisabled('undo', !style.undo);
    _setDisabled('redo', !style.redo);

    // recoveryRangeStyle usa type=null durante transições de foco. Esse
    // payload não representa uma nova seleção e não deve apagar/repintar os
    // controles de formatação com os defaults antes do estado real chegar.
    if (style.type == null) {
      return;
    }
    _lastRangeStyle = style;

    _setActive('bold', style.bold);
    _setActive('italic', style.italic);
    _setActive('underline', style.underline);
    _setActive('strike', style.strikeout);
    _setActive('superscript', style.type == ElementType.superscript);
    _setActive('subscript', style.type == ElementType.subscript);
    _setActive('list', style.listType != null);

    _setActive(
        'align-left', style.rowFlex == null || style.rowFlex == RowFlex.left);
    _setActive('align-center', style.rowFlex == RowFlex.center);
    _setActive('align-right', style.rowFlex == RowFlex.right);
    _setActive('justify',
        style.rowFlex == RowFlex.alignment || style.rowFlex == RowFlex.justify);

    // O select SEMPRE acompanha o contexto (Word): valores fora da lista fixa
    // ganham uma opção dinâmica (marcada) em vez de manter o valor anterior.
    _selectValueEnsuring(_fontSelect, style.font);
    _selectValueEnsuring(_sizeSelect, '${style.size.round()}');

    _styleButtons.forEach((TitleLevel? level, HTMLButtonElement button) {
      button.classList.toggle('active', style.level == level);
    });
    _setActive(
      'styles-more',
      style.level == TitleLevel.third ||
          style.level == TitleLevel.fourth ||
          style.level == TitleLevel.fifth ||
          style.level == TitleLevel.sixth,
    );
  }

  void syncPageMode(PageMode mode) {
    _setActive('page-paging', mode == PageMode.paging);
    _setActive('page-continuity', mode == PageMode.continuity);
  }

  void _setActive(String commandName, bool active) {
    _commandButtons[commandName]?.classList.toggle('active', active);
  }

  void _setDisabled(String commandName, bool disabled) {
    _commandButtons[commandName]?.classList.toggle('disabled', disabled);
  }

  bool _optionExists(HTMLSelectElement select, String value) =>
      select.options.any((HTMLOptionElement option) => option.value == value);

  /// Seta o valor do select criando uma opção dinâmica quando o valor do
  /// contexto não está na lista fixa (fonte/tamanho fora do catálogo).
  void _selectValueEnsuring(HTMLSelectElement select, String value) {
    if (value.isEmpty || value == '0') return;
    if (!_optionExists(select, value)) {
      // Remove a opção dinâmica anterior (mantém a lista fixa enxuta).
      for (final HTMLOptionElement option in select.options.toList()) {
        if (option.data('dynamic') == '1') option.remove();
      }
      final HTMLOptionElement dynamicOption = (HTMLOptionElement()..text = value..value = value)..dataset['dynamic'] = '1';
      select.append(dynamicOption);
    }
    select.value = value;
  }

  // -----------------------------------------------------------------------
  // Construção
  // -----------------------------------------------------------------------

  HTMLDivElement _build() {
    final HTMLDivElement shell = HTMLDivElement()..classList.add('ce-word-ribbon');
    _shell = shell;
    final HTMLDivElement tabs = HTMLDivElement()
      ..classList.add('ce-word-tabs')
      ..setAttribute('role', 'tablist');
    final HTMLDivElement panels = HTMLDivElement()..classList.add('ce-word-panels');

    void addTab(String id, String label, List<Element> groups,
        {bool contextual = false}) {
      final HTMLButtonElement tab = HTMLButtonElement()
        ..type = 'button'
        ..text = label
        ..dataset['ceTab'] = id
        ..classList.toggle('active', id == 'home')
        ..classList.toggle('ce-word-tab--contextual', contextual)
        ..onClick.listen((_) => _activateTab(shell, id));
      if (contextual) {
        tab.style.display = 'none';
      }
      _tabButtons[id] = tab;
      tabs.append(tab);
      final HTMLDivElement panel = HTMLDivElement()
        ..classList.add('ce-word-panel')
        ..classList.toggle('active', id == 'home')
        ..dataset['cePanel'] = id
        ..appendAll(groups);
      panels.append(panel);
    }

    addTab('file', 'Arquivo', <Element>[
      _group('Documento', <Element>[
        _button('open', 'ti-folder-open', 'Abrir DOCX', _actions.openFilePicker,
            labeled: true),
        _button('save', 'ti-device-floppy', 'Baixar DOCX',
            () => _actions.downloadDocx(),
            labeled: true),
        _button('print', 'ti-printer', 'Imprimir',
            () => unawaited(_actions.printDocument()),
            labeled: true),
      ]),
      _group('Exportar', <Element>[
        _button('export-image', 'ti-photo', 'Página → PNG',
            () => _actions.exportCurrentPageImage(),
            labeled: true),
        _button('export-pdf', 'ti-file-type-pdf', 'Documento → PDF',
            () => _actions.downloadPdf(),
            labeled: true),
      ]),
    ]);
    addTab('home', 'Página Inicial', <Element>[
      _group('Área de Transferência', <Element>[
        _button('undo', 'ti-arrow-back-up', 'Desfazer',
            () => _command.executeUndo()),
        _button('redo', 'ti-arrow-forward-up', 'Refazer',
            () => _command.executeRedo()),
        _button('format', 'ti-clear-formatting', 'Limpar',
            () => _command.executeFormat()),
      ]),
      _fontGroup(),
      _twoRowGroup('Parágrafo', <Element>[
        _button('align-left', 'ti-align-left', 'Esquerda',
            () => _command.executeRowFlex(RowFlex.left)),
        _button('align-center', 'ti-align-center', 'Centralizar',
            () => _command.executeRowFlex(RowFlex.center)),
        _button('align-right', 'ti-align-right', 'Direita',
            () => _command.executeRowFlex(RowFlex.right)),
        _button('justify', 'ti-align-justified', 'Justificar',
            () => _command.executeRowFlex(RowFlex.alignment)),
      ], <Element>[
        _button('list', 'ti-list', 'Lista',
            () => _command.executeList(ListType.unordered)),
        _smallDropdownCommand(
          'line-spacing',
          'ti-line-height',
          'Espaçamento de linhas e parágrafos',
          _buildParagraphSpacingMenu,
        ),
      ]),
      _styleGalleryGroup(),
      _group('Edição', <Element>[
        _button('find', 'ti-search', 'Localizar', () => _actions.openFind(),
            labeled: true),
        _button('replace', 'ti-replace', 'Substituir',
            () => _actions.openFind(focusReplace: true),
            labeled: true),
      ]),
    ]);
    addTab('insert', 'Inserir', <Element>[
      _group('Páginas', <Element>[
        _button('page-break', 'ti-page-break', 'Quebra de página',
            () => _command.executePageBreak(),
            labeled: true),
      ]),
      _group('Tabelas', <Element>[
        _dropdownButton(
            'table', 'ti-table', 'Tabela', _buildInsertTableMenu),
      ]),
      _group('Ilustrações', <Element>[
        _button('image', 'ti-photo', 'Imagens', _insertImageFromFile,
            labeled: true),
        _dropdownButton('shapes', 'ti-line', 'Formas', _buildShapesMenu),
      ]),
      _group('Cabeçalho e Rodapé', <Element>[
        _button('page-number', 'ti-number-123', 'Número de Página',
            _openPageNumberDialog,
            labeled: true),
      ]),
      _group('Referências', <Element>[
        _button(
            'toc', 'ti-list-tree', 'Sumário', () => _command.executeInsertToc(),
            labeled: true),
        _button('toc-update', 'ti-refresh', 'Atualizar Sumário',
            () => _command.executeInsertToc(),
            labeled: true),
      ]),
    ]);
    addTab('layout', 'Layout', <Element>[
      _group('Configurar Página', <Element>[
        _dropdownButton('margins', 'ti-layout-distribute-vertical', 'Margens',
            _buildMarginsMenu),
        _dropdownButton(
            'paper-size', 'ti-dimensions', 'Tamanho', _buildPaperSizeMenu),
        _button('portrait', 'ti-file-orientation', 'Retrato',
            () => _command.executePaperDirection(PaperDirection.vertical),
            labeled: true),
        _button('landscape', 'ti-file-orientation', 'Paisagem',
            () => _command.executePaperDirection(PaperDirection.horizontal),
            labeled: true),
      ]),
    ]);
    addTab('review', 'Revisão', <Element>[
      _group('Comentários', <Element>[
        _button(
            'comments', 'ti-message', 'Comentários', _actions.toggleComments,
            labeled: true),
      ]),
    ]);
    addTab('view', 'Exibir', <Element>[
      _group('Modos de Exibição', <Element>[
        _button(
            'page-paging',
            'ti-file',
            'Layout de Impressão',
            () => _actions
                .setDocumentViewMode(CanvasDocumentViewMode.printLayout),
            labeled: true),
        _button(
            'page-continuity',
            'ti-world',
            'Layout da Web',
            () =>
                _actions.setDocumentViewMode(CanvasDocumentViewMode.webLayout),
            labeled: true),
        _button('view-draft', 'ti-file-text', 'Rascunho',
            () => _actions.setDocumentViewMode(CanvasDocumentViewMode.draft),
            labeled: true),
      ]),
      _group('Mostrar', <Element>[
        _button('rulers', 'ti-ruler-2', 'Régua', _actions.toggleRulers,
            labeled: true),
        _button('catalog', 'ti-list-tree', 'Navegação', _actions.toggleCatalog,
            labeled: true),
        _button('page-break-markers', 'ti-separator-horizontal',
            'Marcas de quebra', _actions.togglePageBreakMarkers,
            labeled: true),
      ]),
      _group('Zoom', <Element>[
        _button('zoom-out', 'ti-zoom-out', 'Reduzir',
            () => _command.executePageScaleMinus(),
            labeled: true),
        _button('zoom-reset', 'ti-zoom-reset', '100%',
            () => _command.executePageScaleRecovery(),
            labeled: true),
        _button('zoom-in', 'ti-zoom-in', 'Ampliar',
            () => _command.executePageScaleAdd(),
            labeled: true),
      ]),
    ]);
    // Abas contextuais (estilo "Ferramentas de Tabela/Imagem" do Word):
    // aparecem quando a seleção entra numa tabela ou numa imagem, via
    // [syncSelectionContext].
    addTab(
        'table-tools',
        'Tabela',
        <Element>[
          _group('Linhas e Colunas', <Element>[
            _button('ctx-row-top', 'ti-row-insert-top', 'Inserir linha acima',
                () => _command.executeInsertTableTopRow()),
            _button(
                'ctx-row-bottom',
                'ti-row-insert-bottom',
                'Inserir linha abaixo',
                () => _command.executeInsertTableBottomRow()),
            _button(
                'ctx-col-left',
                'ti-column-insert-left',
                'Inserir coluna à esquerda',
                () => _command.executeInsertTableLeftCol()),
            _button(
                'ctx-col-right',
                'ti-column-insert-right',
                'Inserir coluna à direita',
                () => _command.executeInsertTableRightCol()),
            _button('ctx-row-remove', 'ti-row-remove', 'Excluir linha',
                () => _command.executeDeleteTableRow()),
            _button('ctx-col-remove', 'ti-column-remove', 'Excluir coluna',
                () => _command.executeDeleteTableCol()),
            _button('ctx-table-remove', 'ti-table-minus', 'Excluir tabela',
                () => _command.executeDeleteTable()),
          ]),
          _group('Mesclar', <Element>[
            _button('ctx-merge', 'ti-arrows-join-2', 'Mesclar células',
                () => _command.executeMergeTableCell()),
            _button('ctx-split', 'ti-arrows-split-2', 'Desfazer mesclagem',
                () => _command.executeCancelMergeTableCell()),
          ]),
          _group('Dados', <Element>[
            _button(
                'ctx-repeat-header',
                'ti-table-options',
                'Repetir linhas de cabeçalho',
                () => _command.executeToggleTableHeaderRow(),
                labeled: true),
          ]),
          _group('Estilos de Tabela', <Element>[_tableStyleGallery()]),
          _group('Bordas', <Element>[
            _button('ctx-border-all', 'ti-border-all', 'Todas as bordas',
                () => _command.executeTableBorderType(TableBorder.all)),
            _button('ctx-border-empty', 'ti-border-none', 'Sem bordas',
                () => _command.executeTableBorderType(TableBorder.empty)),
            _button('ctx-border-external', 'ti-border-outer', 'Bordas externas',
                () => _command.executeTableBorderType(TableBorder.external)),
            _button('ctx-border-internal', 'ti-border-inner', 'Bordas internas',
                () => _command.executeTableBorderType(TableBorder.internal)),
          ]),
          _group('Alinhamento', <Element>[
            _button('ctx-valign-top', 'ti-layout-align-top', 'Alinhar no topo',
                () => _command.executeTableTdVerticalAlign(VerticalAlign.top)),
            _button(
                'ctx-valign-middle',
                'ti-layout-align-middle',
                'Centralizar verticalmente',
                () =>
                    _command.executeTableTdVerticalAlign(VerticalAlign.middle)),
            _button(
                'ctx-valign-bottom',
                'ti-layout-align-bottom',
                'Alinhar na base',
                () =>
                    _command.executeTableTdVerticalAlign(VerticalAlign.bottom)),
          ]),
        ],
        contextual: true);
    addTab(
        'image-tools',
        'Imagem',
        <Element>[
          _group('Disposição do Texto', <Element>[
            _imageWrapButton('ctx-wrap-block', 'ti-float-none',
                'Embutida no texto', ImageDisplay.block),
            _imageWrapButton('ctx-wrap-inline', 'ti-layout-rows',
                'Acima e abaixo do texto', ImageDisplay.inline),
            _imageWrapButton('ctx-wrap-surround', 'ti-float-left',
                'Contornar pelo texto', ImageDisplay.surround),
            _imageWrapButton('ctx-wrap-front', 'ti-stack-front',
                'À frente do texto', ImageDisplay.floatTop),
            _imageWrapButton('ctx-wrap-behind', 'ti-stack-back',
                'Atrás do texto', ImageDisplay.floatBottom),
          ]),
          _group('Organizar', <Element>[
            _imageAlignButton(
                'ctx-img-align-left', 'ti-align-box-left-middle',
                'Alinhar à esquerda', 'left'),
            _imageAlignButton(
                'ctx-img-align-center', 'ti-align-box-center-middle',
                'Centralizar na página', 'center'),
            _imageAlignButton(
                'ctx-img-align-right', 'ti-align-box-right-middle',
                'Alinhar à direita', 'right'),
          ]),
          _group('Imagem', <Element>[
            _button('ctx-image-crop', 'ti-crop', 'Cortar',
                () => _command.executeOpenImagePreviewer(),
                labeled: true),
            _button('ctx-image-save', 'ti-download', 'Salvar imagem',
                () => _command.executeSaveAsImageElement(),
                labeled: true),
          ]),
        ],
        contextual: true);
    shell.appendAll(<Element>[tabs, panels]);
    return shell;
  }

  static const Map<TitleLevel, String> _titleLevelNames =
      <TitleLevel, String>{
    TitleLevel.first: 'Título 1',
    TitleLevel.second: 'Título 2',
    TitleLevel.third: 'Título 3',
    TitleLevel.fourth: 'Título 4',
    TitleLevel.fifth: 'Título 5',
    TitleLevel.sixth: 'Título 6',
  };

  static const List<String> _styleFontOptions = <String>[
    'Calibri Light',
    'Arial',
    'Times New Roman',
    'Calibri',
    'Cambria',
    'Georgia',
    'Verdana',
    'Tahoma',
    'Segoe UI',
  ];

  /// Diálogo "Modificar estilo" no formato do Word ("Criar Novo Estilo a
  /// Partir da Formatação"): propriedades, barra de formatação (fonte,
  /// tamanho, N/I e cor) e PREVIEW ao vivo entre parágrafos cinza. Confirmar
  /// reaplica o estilo em todos os títulos do nível (executeTitleStyle).
  void _openTitleStyleDialog({TitleLevel level = TitleLevel.first}) {
    final HTMLDivElement mask = HTMLDivElement()
      ..classList.add('dialog-mask')
      ..setAttribute('editor-component', 'component');
    final HTMLDivElement container = HTMLDivElement()
      ..classList.add('dialog-container')
      ..setAttribute('editor-component', 'component');
    final HTMLDivElement dialog = HTMLDivElement()
      ..classList.addAll(<String>['dialog', 'ce-style-dialog']);
    container.append(dialog);

    void close() {
      mask.remove();
      container.remove();
    }

    final HTMLDivElement titleBar = HTMLDivElement()
      ..classList.add('dialog-title')
      ..append(HTMLSpanElement()..text = 'Modificar estilo');
    final Element closeIcon = document.createElement('i');
    closeIcon.onClick.listen((_) => close());
    titleBar.append(closeIcon);
    dialog.append(titleBar);

    // ── Estado editável ──
    TitleLevel currentLevel = level;
    ITitleStyle draft =
        _command.getTitleStyle(level)?.clone() ?? ITitleStyle();

    // ── Propriedades (Nome) ──
    final HTMLSelectElement levelSelect = HTMLSelectElement();
    for (final MapEntry<TitleLevel, String> entry
        in _titleLevelNames.entries) {
      levelSelect.append(
          HTMLOptionElement()..text = entry.value..value = entry.key.value);
    }
    levelSelect.value = level.value;

    // ── Formatação ──
    final HTMLSelectElement fontSelect = HTMLSelectElement()
      ..classList.add('ce-style-dialog__font');
    for (final String font in _styleFontOptions) {
      fontSelect.append(HTMLOptionElement()..text = font..value = font);
    }
    final HTMLSelectElement sizeSelect = HTMLSelectElement();
    sizeSelect
        .append(HTMLOptionElement()..text = 'padrão do nível'..value = '');
    for (final int size in <int>[
      12, 14, 16, 18, 20, 22, 24, 26, 28, 32, 36, 42, 48
    ]) {
      sizeSelect.append(HTMLOptionElement()..text = '$size'..value = '$size');
    }
    final HTMLButtonElement boldButton = HTMLButtonElement()
      ..type = 'button'
      ..classList.add('ce-style-dialog__toggle')
      ..text = 'N'
      ..style.fontWeight = 'bold'
      ..title = 'Negrito';
    final HTMLButtonElement italicButton = HTMLButtonElement()
      ..type = 'button'
      ..classList.add('ce-style-dialog__toggle')
      ..text = 'I'
      ..style.fontStyle = 'italic'
      ..title = 'Itálico';
    final HTMLInputElement colorInput = (HTMLInputElement()..type = 'color')
      ..classList.add('ce-style-dialog__color')
      ..title = 'Cor da fonte';

    // ── Preview ao vivo (como o quadro do Word) ──
    final HTMLDivElement previewSample = HTMLDivElement()
      ..classList.add('ce-style-dialog__sample');
    const String ghost =
        'Parágrafo anterior Parágrafo anterior Parágrafo anterior '
        'Parágrafo anterior Parágrafo anterior Parágrafo anterior';
    const String ghostNext =
        'Parágrafo seguinte Parágrafo seguinte Parágrafo seguinte '
        'Parágrafo seguinte Parágrafo seguinte Parágrafo seguinte';
    final HTMLDivElement preview = HTMLDivElement()
      ..classList.add('ce-style-dialog__preview')
      ..appendAll(<Element>[
        HTMLDivElement()
          ..classList.add('ce-style-dialog__ghost')
          ..text = ghost,
        previewSample,
        HTMLDivElement()
          ..classList.add('ce-style-dialog__ghost')
          ..text = ghostNext,
        HTMLDivElement()
          ..classList.add('ce-style-dialog__ghost')
          ..text = ghostNext,
      ]);

    void syncControlsFromDraft() {
      fontSelect.value = draft.font ?? 'Calibri Light';
      sizeSelect.value = draft.size == null ? '' : '${draft.size}';
      colorInput.value = draft.color ?? '#2F5496';
      boldButton.classList.toggle('active', draft.bold ?? false);
      italicButton.classList.toggle('active', draft.italic ?? false);
    }

    void syncPreview() {
      previewSample
        ..text = _titleLevelNames[currentLevel] ?? 'Título'
        ..style.fontFamily = draft.font ?? 'Calibri Light'
        ..style.fontSize = '${draft.size ?? 20}px'
        ..style.color = draft.color ?? '#2F5496'
        ..style.fontWeight = (draft.bold ?? false) ? 'bold' : 'normal'
        ..style.fontStyle = (draft.italic ?? false) ? 'italic' : 'normal';
    }

    levelSelect.onChange.listen((_) {
      currentLevel = TitleLevel.values.firstWhere(
        (TitleLevel value) => value.value == levelSelect.value,
        orElse: () => TitleLevel.first,
      );
      draft = _command.getTitleStyle(currentLevel)?.clone() ?? ITitleStyle();
      syncControlsFromDraft();
      syncPreview();
    });
    fontSelect.onChange.listen((_) {
      draft.font = fontSelect.value;
      syncPreview();
    });
    sizeSelect.onChange.listen((_) {
      draft.size = int.tryParse(sizeSelect.value);
      syncPreview();
    });
    boldButton.onClick.listen((_) {
      draft.bold = !(draft.bold ?? false);
      boldButton.classList.toggle('active', draft.bold ?? false);
      syncPreview();
    });
    italicButton.onClick.listen((_) {
      draft.italic = !(draft.italic ?? false);
      italicButton.classList.toggle('active', draft.italic ?? false);
      syncPreview();
    });
    colorInput.onInput.listen((_) {
      draft.color = colorInput.value;
      syncPreview();
    });

    HTMLDivElement fieldRow(String label, List<Element> controls) =>
        HTMLDivElement()
          ..classList.add('ce-style-dialog__row')
          ..append(HTMLSpanElement()
            ..classList.add('ce-style-dialog__label')
            ..text = label)
          ..append(HTMLDivElement()
            ..classList.add('ce-style-dialog__controls')
            ..appendAll(controls));

    dialog.appendAll(<Element>[
      HTMLDivElement()
        ..classList.add('ce-style-dialog__section')
        ..text = 'Propriedades',
      fieldRow('Nome', <Element>[levelSelect]),
      HTMLDivElement()
        ..classList.add('ce-style-dialog__section')
        ..text = 'Formatação',
      fieldRow('', <Element>[
        fontSelect,
        sizeSelect,
        boldButton,
        italicButton,
        colorInput,
      ]),
      preview,
      HTMLDivElement()
        ..classList.add('ce-style-dialog__hint')
        ..text = 'Estilo: Mostrar na galeria de Estilos\n'
            'Reaplica em todos os títulos deste nível',
    ]);

    final HTMLDivElement menu = HTMLDivElement()..classList.add('dialog-menu');
    final HTMLButtonElement cancelButton = HTMLButtonElement()
      ..classList.add('dialog-menu__cancel')
      ..text = 'Cancelar'
      ..type = 'button';
    cancelButton.onClick.listen((_) => close());
    final HTMLButtonElement okButton = HTMLButtonElement()
      ..text = 'OK'
      ..type = 'submit';
    okButton.onClick.listen((_) {
      _command.executeTitleStyle(currentLevel, draft.clone());
      close();
    });
    menu.appendAll(<Element>[cancelButton, okButton]);
    dialog.append(menu);

    syncControlsFromDraft();
    syncPreview();
    document.body?.append(mask);
    document.body?.append(container);
  }

  /// "Atualizar Título N para Corresponder à Seleção" (menu de contexto da
  /// galeria, como o Word): copia fonte/tamanho/N/I/cor da seleção atual
  /// para o estilo do nível e reaplica nos títulos existentes.
  void _updateTitleStyleFromSelection(TitleLevel level) {
    final IRangeStyle? style = _lastRangeStyle;
    if (style == null) return;
    _command.executeTitleStyle(
      level,
      ITitleStyle(
        font: style.font,
        size: style.size.round(),
        color: style.color,
        bold: style.bold,
        italic: style.italic,
      ),
    );
  }

  /// Menu de contexto (botão direito) dos cartões da galeria de estilos —
  /// como no Word: "Atualizar ... para Corresponder à Seleção" e
  /// "Modificar…".
  void _openStyleContextMenu(HTMLButtonElement card, TitleLevel? level) {
    final HTMLDivElement menu = HTMLDivElement();
    if (level != null) {
      menu.append(_menuItem(
        'Atualizar ${_titleLevelNames[level]} para Corresponder à Seleção',
        'Copia a formatação da seleção para o estilo',
        () => _updateTitleStyleFromSelection(level),
      ));
      menu.append(_menuItem(
        'Modificar…',
        'Alterar a aparência deste nível de título',
        () => _openTitleStyleDialog(level: level),
      ));
    } else {
      menu.append(_menuItem(
        'Limpar formatação da seleção',
        'Volta a seleção ao estilo Normal',
        _command.executeFormat,
      ));
    }
    _openMenuFor(card, menu);
  }

  /// "Número de Página" (Word): escolhe formato, alinhamento e a partir de
  /// qual número contar; insere no rodapé como conteúdo editável.
  void _openPageNumberDialog() {
    Dialog(DialogOptions(
      title: 'Número de página',
      data: <DialogData>[
        DialogData(
          type: 'select',
          name: 'format',
          label: 'Formato',
          value: 'Página {pageNo} | {pageCount}',
          options: <DialogOptionItem>[
            DialogOptionItem(
                label: 'Página X | Y', value: 'Página {pageNo} | {pageCount}'),
            DialogOptionItem(
                label: 'Página X de Y', value: 'Página {pageNo} de {pageCount}'),
            DialogOptionItem(label: 'X de Y', value: '{pageNo} de {pageCount}'),
            DialogOptionItem(label: 'X', value: '{pageNo}'),
            DialogOptionItem(label: '- X -', value: '- {pageNo} -'),
            DialogOptionItem(label: 'Página X', value: 'Página {pageNo}'),
          ],
        ),
        DialogData(
          type: 'select',
          name: 'align',
          label: 'Alinhamento',
          value: 'center',
          options: <DialogOptionItem>[
            DialogOptionItem(label: 'Esquerda', value: 'left'),
            DialogOptionItem(label: 'Centro', value: 'center'),
            DialogOptionItem(label: 'Direita', value: 'right'),
          ],
        ),
        DialogData(
          type: 'text',
          name: 'startAt',
          label: 'Iniciar em',
          value: '1',
          placeholder: '1',
        ),
      ],
      onConfirm: (List<DialogConfirm> payload) {
        String format = 'Página {pageNo} | {pageCount}';
        RowFlex align = RowFlex.center;
        int startAt = 1;
        for (final DialogConfirm field in payload) {
          switch (field.name) {
            case 'format':
              if (field.value.isNotEmpty) format = field.value;
            case 'align':
              align = switch (field.value) {
                'left' => RowFlex.left,
                'right' => RowFlex.right,
                _ => RowFlex.center,
              };
            case 'startAt':
              startAt = int.tryParse(field.value.trim()) ?? 1;
          }
        }
        _command.executeInsertPageNumber(
          format: format,
          align: align,
          startAt: startAt,
        );
      },
    ));
  }

  /// Galeria de estilos de tabela (Word): miniaturas clicáveis que aplicam
  /// bordas + preenchimentos do estilo na tabela sob o cursor.
  HTMLDivElement _tableStyleGallery() {
    final HTMLDivElement gallery = HTMLDivElement()
      ..classList.add('ce-table-style-gallery');
    for (final ITableStyle style in defaultTableStyleGallery) {
      final HTMLDivElement preview = HTMLDivElement()
        ..classList.add('ce-table-style')
        ..title = style.label
        ..setAttribute('role', 'button')
        ..setAttribute('aria-label', 'Estilo de tabela: ${style.label}');
      final String borderColor = style.borderType == TableBorder.empty
          ? 'transparent'
          : (style.borderColor ?? '#000000');
      // Miniatura 3×3: faixa de cabeçalho + linhas (com faixa alternada).
      for (int row = 0; row < 3; row++) {
        final HTMLDivElement line = HTMLDivElement()
          ..classList.add('ce-table-style__row');
        final String? fill = row == 0
            ? style.headerFill
            : (row == 2 ? style.bandFill : style.cellFill);
        line.style
          ..background = fill ?? 'transparent'
          ..borderBottom = style.borderType == TableBorder.empty
              ? 'none'
              : '1px solid $borderColor';
        if (row == 0 && style.headerBold) {
          line.classList.add('ce-table-style__row--header');
        }
        for (int col = 0; col < 3; col++) {
          line.append(HTMLDivElement()
            ..classList.add('ce-table-style__cell')
            ..style.borderRight = style.borderType == TableBorder.all ||
                    style.borderType == TableBorder.external
                ? '1px solid $borderColor'
                : 'none');
        }
        preview.append(line);
      }
      preview.style.border = style.borderType == TableBorder.empty ||
              style.borderType == TableBorder.internal
          ? '1px solid #d7dce3'
          : '1px solid $borderColor';
      preview.onMouseDown.listen((MouseEvent event) => event.preventDefault());
      preview.onClick.listen((_) => _command.executeTableStyle(style));
      gallery.append(preview);
    }
    return gallery;
  }

  HTMLButtonElement _imageAlignButton(
      String id, String icon, String label, String align) {
    return _button(id, icon, label, () {
      final RangeContext? context = _command.getRangeContext();
      final IElement? element = context?.startElement;
      if (element == null || element.type != ElementType.image) return;
      _command.executeImageAlign(element, align);
    });
  }

  HTMLButtonElement _imageWrapButton(
      String id, String icon, String label, ImageDisplay display) {
    return _button(id, icon, label, () {
      final RangeContext? context = _command.getRangeContext();
      final IElement? element = context?.startElement;
      if (element == null || element.type != ElementType.image) return;
      _command.executeChangeImageDisplay(element, display);
    });
  }

  /// Mostra/oculta as abas contextuais conforme a seleção (tabela/imagem),
  /// como as "Ferramentas de Tabela" do Word. Se a aba ativa some, volta
  /// para Página Inicial.
  void syncSelectionContext(FloatingToolbarMode mode) {
    if (mode == _contextMode) return;
    final FloatingToolbarMode previous = _contextMode;
    _contextMode = mode;
    final bool showTable = mode == FloatingToolbarMode.table;
    final bool showImage = mode == FloatingToolbarMode.image;
    _tabButtons['table-tools']?.style.display = showTable ? '' : 'none';
    _tabButtons['image-tools']?.style.display = showImage ? '' : 'none';
    if ((_activeTabId == 'table-tools' && !showTable) ||
        (_activeTabId == 'image-tools' && !showImage)) {
      _activateTab(_shell, 'home');
    }
    // Word ATIVA a aba contextual ao selecionar o objeto ("Formato de Imagem"
    // / "Layout de Tabela" abrem sozinhas). Só na TRANSIÇÃO para o contexto —
    // depois o usuário fica livre para trocar de aba.
    if (showImage && previous != FloatingToolbarMode.image) {
      _activateTab(_shell, 'image-tools');
    } else if (showTable && previous != FloatingToolbarMode.table) {
      _activateTab(_shell, 'table-tools');
    }
  }

  HTMLDivElement _fontGroup() {
    _fontSelect = HTMLSelectElement()
      ..title = 'Fonte'
      ..classList.add('ce-word-select');
    for (final String font in <String>[
      'Arial',
      'Calibri',
      'Cambria',
      'Times New Roman'
    ]) {
      _fontSelect.append((HTMLOptionElement()..text = font..value = font));
    }
    _fontSelect.onChange
        .listen((_) => _command.executeFont(_fontSelect.value));
    _sizeSelect = HTMLSelectElement()
      ..title = 'Tamanho'
      ..classList.add('ce-word-select');
    for (final int size in <int>[8, 10, 12, 14, 16, 18, 24, 32, 48]) {
      _sizeSelect.append((HTMLOptionElement()..text = '$size'..value = '$size'));
    }
    _sizeSelect.value = '16';
    _sizeSelect.onChange
        .listen((_) => _command.executeSize(int.parse(_sizeSelect.value)));
    return _twoRowGroup('Fonte', <Element>[
      _fontSelect,
      _sizeSelect,
    ], <Element>[
      _button('bold', 'ti-bold', 'Negrito', () => _command.executeBold()),
      _button('italic', 'ti-italic', 'Itálico', () => _command.executeItalic()),
      _button('underline', 'ti-underline', 'Sublinhado',
          () => _command.executeUnderline()),
      _button('strike', 'ti-strikethrough', 'Tachado',
          () => _command.executeStrikeout()),
      _button('superscript', 'ti-superscript', 'Sobrescrito',
          () => _command.executeSuperscript()),
      _button('subscript', 'ti-subscript', 'Subscrito',
          () => _command.executeSubscript()),
      _colorDropdownCommand(
        'text-color',
        'ti-color-picker',
        'Cor do texto',
        isHighlight: false,
      ),
      _colorDropdownCommand(
        'text-highlight',
        'ti-highlight',
        'Cor de fundo do texto',
        isHighlight: true,
      ),
    ]);
  }

  HTMLButtonElement _colorDropdownCommand(
    String commandName,
    String iconClass,
    String label, {
    required bool isHighlight,
  }) {
    late HTMLButtonElement button;
    button = _button(commandName, iconClass, label, () {
      if (_openMenuOwner == button) {
        _closeMenu();
      } else {
        _openMenuFor(button, _buildColorPalette(isHighlight: isHighlight));
      }
    })
      ..classList.add('ce-word-command--dropdown')
      ..append(
          HTMLSpanElement()..classList.addAll(<String>['ti', 'ti-chevron-down']));
    return button;
  }

  HTMLButtonElement _smallDropdownCommand(
    String commandName,
    String iconClass,
    String label,
    HTMLDivElement Function() buildMenu,
  ) {
    late HTMLButtonElement button;
    button = _button(commandName, iconClass, label, () {
      if (_openMenuOwner == button) {
        _closeMenu();
      } else {
        _openMenuFor(button, buildMenu());
      }
    })
      ..classList.add('ce-word-command--dropdown')
      ..append(
          HTMLSpanElement()..classList.addAll(<String>['ti', 'ti-chevron-down']));
    return button;
  }

  HTMLDivElement _buildParagraphSpacingMenu() {
    final HTMLDivElement menu = HTMLDivElement();
    for (final double value in <double>[1, 1.08, 1.15, 1.5, 2, 2.5, 3]) {
      menu.append(_menuItem(
        value.toStringAsFixed(value % 1 == 0 ? 1 : 2),
        'Espaçamento entre linhas',
        () => _command.executeParagraphSpacing('auto', value),
      ));
    }
    menu.append(HTMLDivElement()..classList.add('ce-word-menu__divider'));

    final HTMLInputElement before = (HTMLInputElement()..type = 'number')
      ..min = '0'
      ..step = '1'
      ..value = '0'
      ..title = 'Espaçamento antes (pt)';
    final HTMLInputElement after = (HTMLInputElement()..type = 'number')
      ..min = '0'
      ..step = '1'
      ..value = '8'
      ..title = 'Espaçamento depois (pt)';
    final HTMLButtonElement apply = HTMLButtonElement()
      ..type = 'button'
      ..classList.add('ce-word-menu__apply')
      ..text = 'Aplicar espaçamento'
      ..onClick.listen((_) {
        const double ptToPx = 96 / 72;
        _command.executeParagraphSpacing(
          'auto',
          1.08,
          before: (double.tryParse(before.value) ?? 0) * ptToPx,
          after: (double.tryParse(after.value) ?? 0) * ptToPx,
        );
        _closeMenu();
      });
    menu.append(HTMLDivElement()
      ..classList.add('ce-word-menu__form')
      ..appendAll(<Element>[
        HTMLSpanElement()
          ..classList.add('ce-word-menu__form-title')
          ..text = 'Espaçamento de parágrafo (pt)',
        HTMLDivElement()
          ..classList.add('ce-word-menu__fields')
          ..appendAll(<Element>[
            _numberField('Antes', before),
            _numberField('Depois', after),
          ]),
        apply,
      ]));
    return menu;
  }

  HTMLDivElement _numberField(String label, HTMLInputElement input) =>
      HTMLDivElement()
        ..classList.add('ce-word-menu__field')
        ..appendAll(<Element>[HTMLSpanElement()..text = label, input]);

  HTMLDivElement _buildColorPalette({required bool isHighlight}) {
    const List<String> colors = <String>[
      '#000000',
      '#404040',
      '#7f7f7f',
      '#bfbfbf',
      '#ffffff',
      '#c00000',
      '#ff0000',
      '#ffc000',
      '#ffff00',
      '#92d050',
      '#00b050',
      '#00b0f0',
      '#0070c0',
      '#002060',
      '#7030a0',
      '#f4cccc',
      '#fce5cd',
      '#fff2cc',
      '#d9ead3',
      '#d0e0e3',
      '#c9daf8',
      '#cfe2f3',
      '#d9d2e9',
      '#ead1dc',
      '#6aa84f',
    ];
    final HTMLDivElement grid = HTMLDivElement()..classList.add('ce-color-palette__grid');
    for (final String color in colors) {
      grid.append(HTMLButtonElement()
        ..type = 'button'
        ..classList.add('ce-color-palette__swatch')
        ..dataset['color'] = color
        ..title = color
        ..style.backgroundColor = color
        ..onClick.listen((_) {
          if (isHighlight) {
            _command.executeHighlight(color);
          } else {
            _command.executeColor(color);
          }
          _closeMenu();
        }));
    }

    final HTMLInputElement custom = (HTMLInputElement()..type = 'color')
      ..classList.add('ce-color-palette__custom')
      ..title = 'Cor personalizada';
    custom.onChange.listen((_) {
      final String color = custom.value;
      if (isHighlight) {
        _command.executeHighlight(color);
      } else {
        _command.executeColor(color);
      }
      _closeMenu();
    });

    final HTMLButtonElement clear = HTMLButtonElement()
      ..type = 'button'
      ..classList.add('ce-color-palette__clear')
      ..text = isHighlight ? 'Sem realce' : 'Cor automática'
      ..onClick.listen((_) {
        if (isHighlight) {
          _command.executeHighlight(null);
        } else {
          _command.executeColor(null);
        }
        _closeMenu();
      });

    return HTMLDivElement()
      ..classList.add('ce-color-palette')
      ..setAttribute('role', 'dialog')
      ..setAttribute(
          'aria-label', isHighlight ? 'Cor de fundo do texto' : 'Cor do texto')
      ..appendAll(<Element>[
        HTMLSpanElement()
          ..classList.add('ce-color-palette__title')
          ..text = isHighlight ? 'Realce' : 'Cor da fonte',
        grid,
        HTMLDivElement()
          ..classList.add('ce-color-palette__footer')
          ..appendAll(<Element>[custom, clear]),
      ]);
  }

  HTMLDivElement _group(String label, List<Element> children) => HTMLDivElement()
    ..classList.add('ce-word-group')
    ..appendAll(<Element>[
      HTMLDivElement()
        ..classList.add('ce-word-group__commands')
        ..appendAll(children),
      HTMLSpanElement()
        ..classList.add('ce-word-group__label')
        ..text = label,
    ]);

  HTMLDivElement _twoRowGroup(
    String label,
    List<Element> firstRow,
    List<Element> secondRow,
  ) {
    final HTMLDivElement group = _group(label, <Element>[
      HTMLDivElement()
        ..classList.add('ce-word-command-rows')
        ..appendAll(<Element>[
          HTMLDivElement()
            ..classList.add('ce-word-command-row')
            ..appendAll(firstRow),
          HTMLDivElement()
            ..classList.add('ce-word-command-row')
            ..appendAll(secondRow),
        ]),
    ]);
    group.classList.add('ce-word-group--two-row');
    return group;
  }

  HTMLDivElement _styleGalleryGroup() {
    final HTMLButtonElement more = _button(
      'styles-more',
      'ti-chevron-down',
      'Mais estilos',
      () {},
    );
    more.onClick.listen((_) {
      if (_openMenuOwner == more) {
        _closeMenu();
        return;
      }
      final HTMLDivElement menu = HTMLDivElement();
      for (final (String label, TitleLevel level) in <(String, TitleLevel)>[
        ('Título 3', TitleLevel.third),
        ('Título 4', TitleLevel.fourth),
        ('Título 5', TitleLevel.fifth),
        ('Título 6', TitleLevel.sixth),
      ]) {
        menu.append(_menuItem(label, 'Estilo de título do Word', () {
          _command.executeTitle(level);
        }));
      }
      // "Modificar Estilo" do Word: customiza fonte/tamanho/cor/negrito de um
      // nível e reaplica nos títulos que já usam aquele nível.
      menu.append(_menuItem('Modificar estilo…',
          'Alterar a aparência de um nível de título', _openTitleStyleDialog));
      _openMenuFor(more, menu);
    });
    final HTMLDivElement group = _group('Estilos', <Element>[
      HTMLDivElement()
        ..classList.add('ce-word-style-gallery')
        ..appendAll(<Element>[
          _styleCommand('Normal', null),
          _styleCommand('Título 1', TitleLevel.first),
          _styleCommand('Título 2', TitleLevel.second),
          more,
        ]),
    ]);
    group.classList.add('ce-word-group--styles');
    return group;
  }

  HTMLButtonElement _styleCommand(String label, TitleLevel? level) {
    late final HTMLButtonElement button;
    button = HTMLButtonElement()
      ..type = 'button'
      ..classList.add('ce-word-style')
      ..dataset['styleLevel'] = level?.value ?? 'normal'
      ..text = label
      ..onMouseDown.listen((event) => event.preventDefault())
      ..onClick.listen((_) => _command.executeTitle(level))
      // Word: botão direito no cartão da galeria abre "Atualizar para
      // Corresponder à Seleção" / "Modificar…".
      ..onContextMenu.listen((MouseEvent event) {
        event.preventDefault();
        _openStyleContextMenu(button, level);
      });
    _styleButtons[level] = button;
    return button;
  }

  void _activateTab(HTMLDivElement shell, String id) {
    _activeTabId = id;
    for (final Element tab in shell.querySelectorAll('[data-ce-tab]').toElements()) {
      tab.classList.toggle('active', tab.data('ceTab') == id);
    }
    for (final Element panel in shell.querySelectorAll('[data-ce-panel]').toElements()) {
      panel.classList.toggle('active', panel.data('cePanel') == id);
    }
  }

  HTMLButtonElement _button(
    String commandName,
    String iconClass,
    String label,
    void Function() action, {
    bool labeled = false,
  }) {
    final HTMLButtonElement button = HTMLButtonElement()
      ..type = 'button'
      ..title = label
      ..dataset['ceCommand'] = commandName
      ..classList.toggle('ce-word-command--labeled', labeled)
      ..setAttribute('aria-label', label)
      ..append(HTMLSpanElement()..classList.addAll(<String>['ti', iconClass]));
    if (labeled) {
      button.append(HTMLSpanElement()
        ..classList.add('ce-word-command__label')
        ..text = label);
    }
    button.onMouseDown.listen((MouseEvent event) {
      // Keeps the canvas selection active while a format command is clicked.
      event.preventDefault();
    });
    button.onClick.listen((_) => action());
    _commandButtons[commandName] = button;
    return button;
  }

  // -----------------------------------------------------------------------
  // Menus suspensos
  // -----------------------------------------------------------------------

  HTMLButtonElement _dropdownButton(
    String commandName,
    String iconClass,
    String label,
    HTMLDivElement Function() buildMenu,
  ) {
    late HTMLButtonElement button;
    button = _button(commandName, iconClass, label, () {
      if (_openMenuOwner == button) {
        _closeMenu();
        return;
      }
      _openMenuFor(button, buildMenu());
    }, labeled: true);
    button.append(
        HTMLSpanElement()..classList.addAll(<String>['ti', 'ti-chevron-down']));
    return button;
  }

  StreamSubscription<MouseEvent>? _outsideClickSubscription;

  void _openMenuFor(Element owner, HTMLDivElement menu) {
    _closeMenu();
    final DOMRect ownerRect = owner.getBoundingClientRect();
    final DOMRect hostRect = _menuHost.getBoundingClientRect();
    menu
      ..classList.add('ce-word-menu')
      ..style.left = '${ownerRect.left - hostRect.left}px'
      ..style.top = '${ownerRect.bottom - hostRect.top + 2}px';
    _menuHost.append(menu);
    _openMenu = menu;
    _openMenuOwner = owner;
    _outsideClickSubscription = document.onClick.listen((MouseEvent event) {
      final Node? target = event.target as Node?;
      if (target != null && (menu.contains(target) || owner.contains(target))) {
        return;
      }
      _closeMenu();
    });
  }

  void _closeMenu() {
    _outsideClickSubscription?.cancel();
    _outsideClickSubscription = null;
    _openMenu?.remove();
    _openMenu = null;
    _openMenuOwner = null;
  }

  HTMLDivElement _menuItem(String title, String detail, void Function() action) {
    return HTMLDivElement()
      ..classList.add('ce-word-menu__item')
      ..appendAll(<Element>[
        HTMLSpanElement()
          ..classList.add('ce-word-menu__item-title')
          ..text = title,
        HTMLSpanElement()
          ..classList.add('ce-word-menu__item-detail')
          ..text = detail,
      ])
      ..onClick.listen((_) {
        action();
        _closeMenu();
      });
  }

  /// Menu "Tabela" da aba Inserir no formato do Word: grade 10×8 com hover
  /// que pré-visualiza N×M ("Tabela 4x3") e insere ao clicar, mais o item
  /// "Inserir Tabela…" com linhas/colunas digitadas.
  HTMLDivElement _buildInsertTableMenu() {
    const int gridCols = 10;
    const int gridRows = 8;
    final HTMLDivElement caption = HTMLDivElement()
      ..classList.add('ce-table-grid__caption')
      ..text = 'Inserir Tabela';
    final HTMLDivElement grid = HTMLDivElement()
      ..classList.add('ce-table-grid');
    final List<HTMLDivElement> cells = <HTMLDivElement>[];
    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        final HTMLDivElement cell = HTMLDivElement()
          ..classList.add('ce-table-grid__cell')
          ..dataset['row'] = '$r'
          ..dataset['col'] = '$c';
        cell.onMouseEnter.listen((_) {
          for (final HTMLDivElement other in cells) {
            final int or = int.parse(other.data('row')!);
            final int oc = int.parse(other.data('col')!);
            other.classList.toggle('hover', or <= r && oc <= c);
          }
          caption.text = 'Tabela ${c + 1}x${r + 1}';
        });
        cell.onClick.listen((_) {
          _command.executeInsertTable(r + 1, c + 1);
          _closeMenu();
        });
        cells.add(cell);
        grid.append(cell);
      }
    }
    grid.onMouseLeave.listen((_) {
      for (final HTMLDivElement other in cells) {
        other.classList.remove('hover');
      }
      caption.text = 'Inserir Tabela';
    });
    final HTMLDivElement menu = HTMLDivElement()
      ..classList.add('ce-table-grid__menu')
      ..appendAll(<Element>[
        caption,
        grid,
        HTMLDivElement()..classList.add('ce-word-menu__divider'),
        _menuItem('Inserir Tabela…', 'Escolher número de linhas e colunas',
            _openInsertTableDialog),
      ]);
    return menu;
  }

  void _openInsertTableDialog() {
    Dialog(DialogOptions(
      title: 'Inserir tabela',
      data: <DialogData>[
        DialogData(
            type: 'number', name: 'cols', label: 'Número de colunas',
            value: '3'),
        DialogData(
            type: 'number', name: 'rows', label: 'Número de linhas',
            value: '3'),
      ],
      onConfirm: (List<DialogConfirm> payload) {
        int rows = 3;
        int cols = 3;
        for (final DialogConfirm field in payload) {
          if (field.name == 'rows') {
            rows = int.tryParse(field.value.trim()) ?? 3;
          } else if (field.name == 'cols') {
            cols = int.tryParse(field.value.trim()) ?? 3;
          }
        }
        if (rows > 0 && cols > 0) {
          _command.executeInsertTable(rows.clamp(1, 200), cols.clamp(1, 63));
        }
      },
    ));
  }

  /// "Imagens" da aba Inserir (Word): abre o seletor de arquivo e insere a
  /// imagem no cursor com o tamanho natural.
  void _insertImageFromFile() {
    final HTMLInputElement input = (HTMLInputElement()..type = 'file')
      ..accept = '.png, .jpg, .jpeg, .gif, .webp';
    input.onChange.first.then((_) {
      final File? file =
          input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) return;
      final FileReader reader = FileReader()..readAsDataURL(file);
      reader.onLoad.first.then((_) {
        final String? value = readerResultAsString(reader);
        if (value == null || value.isEmpty) return;
        final HTMLImageElement image = HTMLImageElement()..src = value;
        image.onLoad.first.then((_) {
          final num width =
              image.naturalWidth != 0 ? image.naturalWidth : image.width;
          final num height =
              image.naturalHeight != 0 ? image.naturalHeight : image.height;
          _command.executeImage(IDrawImagePayload(
            value: value,
            width: width.toDouble(),
            height: height.toDouble(),
          ));
        });
      });
    });
    input.click();
  }

  /// "Formas" da aba Inserir: linhas horizontais (o motor suporta o
  /// separador com padrões de traço).
  HTMLDivElement _buildShapesMenu() {
    HTMLDivElement shape(String name, List<num> dash) {
      final HTMLDivElement item = _menuItem(
          name, '', () => _command.executeSeparator(dash));
      item.append(HTMLDivElement()
        ..classList.add('ce-shape-preview')
        ..style.borderTopStyle = dash.isEmpty ? 'solid' : 'dashed');
      return item;
    }

    return HTMLDivElement()
      ..appendAll(<Element>[
        HTMLDivElement()
          ..classList.add('ce-table-grid__caption')
          ..text = 'Linhas',
        shape('Linha contínua', <num>[]),
        shape('Linha tracejada', <num>[3, 1]),
        shape('Linha pontilhada', <num>[1, 1]),
        shape('Traço longo', <num>[6, 2]),
        shape('Traço e ponto', <num>[6, 2, 2, 2]),
      ]);
  }

  HTMLDivElement _buildMarginsMenu() {
    // Presets do Word (cm): [superior, direita, inferior, esquerda].
    HTMLDivElement preset(String name, String detail, List<double> cm) =>
        _menuItem(name, detail, () {
          _command.executeSetPaperMargin(<double>[
            for (final double value in cm) value * _pxPerCm,
          ]);
        });

    final HTMLDivElement menu = HTMLDivElement()
      ..appendAll(<Element>[
        preset('Normal', 'Sup/Inf 2,5 cm · Esq/Dir 3 cm',
            <double>[2.5, 3, 2.5, 3]),
        preset('Estreita', 'Todas 1,27 cm', <double>[1.27, 1.27, 1.27, 1.27]),
        preset('Moderada', 'Sup/Inf 2,54 cm · Esq/Dir 1,91 cm',
            <double>[2.54, 1.91, 2.54, 1.91]),
        preset('Larga', 'Sup/Inf 2,54 cm · Esq/Dir 5,08 cm',
            <double>[2.54, 5.08, 2.54, 5.08]),
        HTMLDivElement()..classList.add('ce-word-menu__divider'),
      ]);
    menu.append(_buildCustomMarginsForm());
    return menu;
  }

  HTMLDivElement _buildCustomMarginsForm() {
    final List<double> current = _currentMarginsPx();
    HTMLInputElement marginInput(String label, double px) {
      return (HTMLInputElement()..type = 'number')
        ..classList.add('ce-word-menu__number')
        ..title = label
        ..min = '0'
        ..step = '0.1'
        ..value = (px / _pxPerCm).toStringAsFixed(2);
    }

    final HTMLInputElement top = marginInput('Superior', current[0]);
    final HTMLInputElement right = marginInput('Direita', current[1]);
    final HTMLInputElement bottom = marginInput('Inferior', current[2]);
    final HTMLInputElement left = marginInput('Esquerda', current[3]);

    HTMLDivElement field(String label, HTMLInputElement input) => HTMLDivElement()
      ..classList.add('ce-word-menu__field')
      ..appendAll(<Element>[
        HTMLSpanElement()..text = label,
        input,
      ]);

    final HTMLButtonElement apply = HTMLButtonElement()
      ..type = 'button'
      ..classList.add('ce-word-menu__apply')
      ..text = 'Aplicar'
      ..onClick.listen((_) {
        double parse(HTMLInputElement input, double fallbackPx) {
          final double? cm = double.tryParse(input.value);
          return cm == null ? fallbackPx : cm * _pxPerCm;
        }

        _command.executeSetPaperMargin(<double>[
          parse(top, current[0]),
          parse(right, current[1]),
          parse(bottom, current[2]),
          parse(left, current[3]),
        ]);
        _closeMenu();
      });

    return HTMLDivElement()
      ..classList.add('ce-word-menu__form')
      ..appendAll(<Element>[
        HTMLSpanElement()
          ..classList.add('ce-word-menu__form-title')
          ..text = 'Margens personalizadas (cm)',
        HTMLDivElement()
          ..classList.add('ce-word-menu__fields')
          ..appendAll(<Element>[
            field('Sup.', top),
            field('Dir.', right),
            field('Inf.', bottom),
            field('Esq.', left),
          ]),
        apply,
      ]);
  }

  List<double> _currentMarginsPx() {
    try {
      final dynamic margins = _command.getPaperMargin();
      if (margins is List && margins.length == 4) {
        return <double>[for (final dynamic m in margins) (m as num).toDouble()];
      }
    } catch (_) {
      // Sem margens legíveis: usa o padrão A4 do editor.
    }
    return <double>[96, 96, 96, 96];
  }

  HTMLDivElement _buildPaperSizeMenu() {
    HTMLDivElement size(String name, String detail, double width, double height) =>
        _menuItem(name, detail, () => _command.executePaperSize(width, height));

    return HTMLDivElement()
      ..appendAll(<Element>[
        size('A4', '21 × 29,7 cm', 794, 1123),
        size('Carta', '21,6 × 27,9 cm', 816, 1056),
        size('Ofício', '21,6 × 35,6 cm', 816, 1344),
        size('A5', '14,8 × 21 cm', 559, 794),
      ]);
  }

  @override
  void onDispose() {
    _closeMenu();
  }
}

/// Toolbar compacta para o modo embutido ([CanvasEditorAppearance.compact]).
class WidgetCompactToolbar extends UiComponent {
  WidgetCompactToolbar(this._actions) {
    root = _build();
  }

  final CanvasEditorShellActions _actions;

  @override
  late final HTMLDivElement root;

  final Map<String, HTMLButtonElement> _commandButtons = <String, HTMLButtonElement>{};

  Command get _command => _actions.command;

  void syncRangeStyle(IRangeStyle style) {
    _commandButtons['undo']?.classList.toggle('disabled', !style.undo);
    _commandButtons['redo']?.classList.toggle('disabled', !style.redo);
    if (style.type == null) {
      return;
    }
    _commandButtons['bold']?.classList.toggle('active', style.bold);
    _commandButtons['italic']?.classList.toggle('active', style.italic);
    _commandButtons['underline']?.classList.toggle('active', style.underline);
  }

  HTMLDivElement _build() {
    final HTMLDivElement toolbar = HTMLDivElement()
      ..classList.add('ce-embed__toolbar')
      ..setAttribute('role', 'toolbar')
      ..setAttribute('aria-label', 'Formatação do documento');
    toolbar.appendAll(<Element>[
      _button('open', 'ti-folder-open', 'Abrir DOCX', _actions.openFilePicker),
      _button('save', 'ti-device-floppy', 'Baixar DOCX',
          () => _actions.downloadDocx()),
      _button(
          'undo', 'ti-arrow-back-up', 'Desfazer', () => _command.executeUndo()),
      _button('redo', 'ti-arrow-forward-up', 'Refazer',
          () => _command.executeRedo()),
      _button('bold', 'ti-bold', 'Negrito', () => _command.executeBold()),
      _button('italic', 'ti-italic', 'Itálico', () => _command.executeItalic()),
      _button('underline', 'ti-underline', 'Sublinhado',
          () => _command.executeUnderline()),
      _button('align-left', 'ti-align-left', 'Alinhar à esquerda',
          () => _command.executeRowFlex(RowFlex.left)),
      _button('align-center', 'ti-align-center', 'Centralizar',
          () => _command.executeRowFlex(RowFlex.center)),
      _button('align-right', 'ti-align-right', 'Alinhar à direita',
          () => _command.executeRowFlex(RowFlex.right)),
      _button('search', 'ti-search', 'Localizar (Ctrl+F)',
          () => _actions.openFind()),
      _button('print', 'ti-printer', 'Imprimir',
          () => unawaited(_actions.printDocument())),
    ]);
    return toolbar;
  }

  HTMLButtonElement _button(
    String commandName,
    String iconClass,
    String label,
    void Function() action,
  ) {
    final HTMLButtonElement button = HTMLButtonElement()
      ..type = 'button'
      ..title = label
      ..dataset['ceCommand'] = commandName
      ..setAttribute('aria-label', label)
      ..append(HTMLSpanElement()..classList.addAll(<String>['ti', iconClass]));
    button.onMouseDown.listen((MouseEvent event) => event.preventDefault());
    button.onClick.listen((_) => action());
    _commandButtons[commandName] = button;
    return button;
  }
}
