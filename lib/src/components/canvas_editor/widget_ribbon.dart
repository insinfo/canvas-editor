import 'dart:async';
import 'dart:html';

import '../../editor/index.dart';
import '../core/ui_component.dart';
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
  late final DivElement root;

  Command get _command => _actions.command;

  final Map<String, ButtonElement> _commandButtons = <String, ButtonElement>{};
  final Map<String, ButtonElement> _tabButtons = <String, ButtonElement>{};
  final Map<TitleLevel?, ButtonElement> _styleButtons =
      <TitleLevel?, ButtonElement>{};
  late DivElement _shell;
  String _activeTabId = 'home';
  FloatingToolbarMode _contextMode = FloatingToolbarMode.hidden;
  late final SelectElement _fontSelect;
  late final SelectElement _sizeSelect;

  DivElement? _openMenu;
  Element? _openMenuOwner;

  // -----------------------------------------------------------------------
  // Sincronização com a seleção (rangeStyleChange)
  // -----------------------------------------------------------------------

  /// Espelha o estilo do texto sob o cursor nos controles do ribbon.
  /// Chamado pelo widget no flush do [UiScheduler] — uma vez por frame.
  void syncRangeStyle(IRangeStyle style) {
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

    _setDisabled('undo', !style.undo);
    _setDisabled('redo', !style.redo);

    // O select SEMPRE acompanha o contexto (Word): valores fora da lista fixa
    // ganham uma opção dinâmica (marcada) em vez de manter o valor anterior.
    _selectValueEnsuring(_fontSelect, style.font);
    _selectValueEnsuring(_sizeSelect, '${style.size.round()}');

    // `recoveryRangeStyle` emite type=null durante transições de foco. Não
    // deixe esse payload transitório alternar Título/Normal na ribbon.
    if (style.type != null) {
      _styleButtons.forEach((TitleLevel? level, ButtonElement button) {
        button.classes.toggle('active', style.level == level);
      });
      _setActive(
        'styles-more',
        style.level == TitleLevel.third ||
            style.level == TitleLevel.fourth ||
            style.level == TitleLevel.fifth ||
            style.level == TitleLevel.sixth,
      );
    }
  }

  void syncPageMode(PageMode mode) {
    _setActive('page-paging', mode == PageMode.paging);
    _setActive('page-continuity', mode == PageMode.continuity);
  }

  void _setActive(String commandName, bool active) {
    _commandButtons[commandName]?.classes.toggle('active', active);
  }

  void _setDisabled(String commandName, bool disabled) {
    _commandButtons[commandName]?.classes.toggle('disabled', disabled);
  }

  bool _optionExists(SelectElement select, String value) =>
      select.options.any((OptionElement option) => option.value == value);

  /// Seta o valor do select criando uma opção dinâmica quando o valor do
  /// contexto não está na lista fixa (fonte/tamanho fora do catálogo).
  void _selectValueEnsuring(SelectElement select, String value) {
    if (value.isEmpty || value == '0') return;
    if (!_optionExists(select, value)) {
      // Remove a opção dinâmica anterior (mantém a lista fixa enxuta).
      for (final OptionElement option in select.options.toList()) {
        if (option.dataset['dynamic'] == '1') option.remove();
      }
      final OptionElement dynamicOption = OptionElement(
        data: value,
        value: value,
      )..dataset['dynamic'] = '1';
      select.append(dynamicOption);
    }
    select.value = value;
  }

  // -----------------------------------------------------------------------
  // Construção
  // -----------------------------------------------------------------------

  DivElement _build() {
    final DivElement shell = DivElement()..classes.add('ce-word-ribbon');
    _shell = shell;
    final DivElement tabs = DivElement()
      ..classes.add('ce-word-tabs')
      ..setAttribute('role', 'tablist');
    final DivElement panels = DivElement()..classes.add('ce-word-panels');

    void addTab(String id, String label, List<Element> groups,
        {bool contextual = false}) {
      final ButtonElement tab = ButtonElement()
        ..type = 'button'
        ..text = label
        ..dataset['ceTab'] = id
        ..classes.toggle('active', id == 'home')
        ..classes.toggle('ce-word-tab--contextual', contextual)
        ..onClick.listen((_) => _activateTab(shell, id));
      if (contextual) {
        tab.style.display = 'none';
      }
      _tabButtons[id] = tab;
      tabs.append(tab);
      final DivElement panel = DivElement()
        ..classes.add('ce-word-panel')
        ..classes.toggle('active', id == 'home')
        ..dataset['cePanel'] = id
        ..children.addAll(groups);
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
        _button('table', 'ti-table', 'Tabela 3 × 3',
            () => _command.executeInsertTable(3, 3),
            labeled: true),
      ]),
      _group('Texto e símbolos', <Element>[
        _button('separator', 'ti-separator-horizontal', 'Separador',
            () => _command.executeSeparator(<num>[1, 1]),
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
          _group('Imagem', <Element>[
            _button('ctx-image-save', 'ti-download', 'Salvar imagem',
                () => _command.executeSaveAsImageElement(),
                labeled: true),
          ]),
        ],
        contextual: true);
    shell.children.addAll(<Element>[tabs, panels]);
    return shell;
  }

  ButtonElement _imageWrapButton(
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
    _contextMode = mode;
    final bool showTable = mode == FloatingToolbarMode.table;
    final bool showImage = mode == FloatingToolbarMode.image;
    _tabButtons['table-tools']?.style.display = showTable ? '' : 'none';
    _tabButtons['image-tools']?.style.display = showImage ? '' : 'none';
    if ((_activeTabId == 'table-tools' && !showTable) ||
        (_activeTabId == 'image-tools' && !showImage)) {
      _activateTab(_shell, 'home');
    }
  }

  DivElement _fontGroup() {
    _fontSelect = SelectElement()
      ..title = 'Fonte'
      ..classes.add('ce-word-select');
    for (final String font in <String>[
      'Arial',
      'Calibri',
      'Cambria',
      'Times New Roman'
    ]) {
      _fontSelect.append(OptionElement(data: font, value: font));
    }
    _fontSelect.onChange
        .listen((_) => _command.executeFont(_fontSelect.value ?? 'Arial'));
    _sizeSelect = SelectElement()
      ..title = 'Tamanho'
      ..classes.add('ce-word-select');
    for (final int size in <int>[8, 10, 12, 14, 16, 18, 24, 32, 48]) {
      _sizeSelect.append(OptionElement(data: '$size', value: '$size'));
    }
    _sizeSelect.value = '16';
    _sizeSelect.onChange
        .listen((_) => _command.executeSize(int.parse(_sizeSelect.value!)));
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

  ButtonElement _colorDropdownCommand(
    String commandName,
    String iconClass,
    String label, {
    required bool isHighlight,
  }) {
    late ButtonElement button;
    button = _button(commandName, iconClass, label, () {
      if (_openMenuOwner == button) {
        _closeMenu();
      } else {
        _openMenuFor(button, _buildColorPalette(isHighlight: isHighlight));
      }
    })
      ..classes.add('ce-word-command--dropdown')
      ..append(
          SpanElement()..classes.addAll(<String>['ti', 'ti-chevron-down']));
    return button;
  }

  ButtonElement _smallDropdownCommand(
    String commandName,
    String iconClass,
    String label,
    DivElement Function() buildMenu,
  ) {
    late ButtonElement button;
    button = _button(commandName, iconClass, label, () {
      if (_openMenuOwner == button) {
        _closeMenu();
      } else {
        _openMenuFor(button, buildMenu());
      }
    })
      ..classes.add('ce-word-command--dropdown')
      ..append(
          SpanElement()..classes.addAll(<String>['ti', 'ti-chevron-down']));
    return button;
  }

  DivElement _buildParagraphSpacingMenu() {
    final DivElement menu = DivElement();
    for (final double value in <double>[1, 1.08, 1.15, 1.5, 2, 2.5, 3]) {
      menu.append(_menuItem(
        value.toStringAsFixed(value % 1 == 0 ? 1 : 2),
        'Espaçamento entre linhas',
        () => _command.executeParagraphSpacing('auto', value),
      ));
    }
    menu.append(DivElement()..classes.add('ce-word-menu__divider'));

    final NumberInputElement before = NumberInputElement()
      ..min = '0'
      ..step = '1'
      ..value = '0'
      ..title = 'Espaçamento antes (pt)';
    final NumberInputElement after = NumberInputElement()
      ..min = '0'
      ..step = '1'
      ..value = '8'
      ..title = 'Espaçamento depois (pt)';
    final ButtonElement apply = ButtonElement()
      ..type = 'button'
      ..classes.add('ce-word-menu__apply')
      ..text = 'Aplicar espaçamento'
      ..onClick.listen((_) {
        const double ptToPx = 96 / 72;
        _command.executeParagraphSpacing(
          'auto',
          1.08,
          before: (double.tryParse(before.value ?? '') ?? 0) * ptToPx,
          after: (double.tryParse(after.value ?? '') ?? 0) * ptToPx,
        );
        _closeMenu();
      });
    menu.append(DivElement()
      ..classes.add('ce-word-menu__form')
      ..children.addAll(<Element>[
        SpanElement()
          ..classes.add('ce-word-menu__form-title')
          ..text = 'Espaçamento de parágrafo (pt)',
        DivElement()
          ..classes.add('ce-word-menu__fields')
          ..children.addAll(<Element>[
            _numberField('Antes', before),
            _numberField('Depois', after),
          ]),
        apply,
      ]));
    return menu;
  }

  DivElement _numberField(String label, NumberInputElement input) =>
      DivElement()
        ..classes.add('ce-word-menu__field')
        ..children.addAll(<Element>[SpanElement()..text = label, input]);

  DivElement _buildColorPalette({required bool isHighlight}) {
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
    final DivElement grid = DivElement()..classes.add('ce-color-palette__grid');
    for (final String color in colors) {
      grid.append(ButtonElement()
        ..type = 'button'
        ..classes.add('ce-color-palette__swatch')
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

    final InputElement custom = InputElement(type: 'color')
      ..classes.add('ce-color-palette__custom')
      ..title = 'Cor personalizada';
    custom.onChange.listen((_) {
      final String? color = custom.value;
      if (color == null) return;
      if (isHighlight) {
        _command.executeHighlight(color);
      } else {
        _command.executeColor(color);
      }
      _closeMenu();
    });

    final ButtonElement clear = ButtonElement()
      ..type = 'button'
      ..classes.add('ce-color-palette__clear')
      ..text = isHighlight ? 'Sem realce' : 'Cor automática'
      ..onClick.listen((_) {
        if (isHighlight) {
          _command.executeHighlight(null);
        } else {
          _command.executeColor(null);
        }
        _closeMenu();
      });

    return DivElement()
      ..classes.add('ce-color-palette')
      ..setAttribute('role', 'dialog')
      ..setAttribute(
          'aria-label', isHighlight ? 'Cor de fundo do texto' : 'Cor do texto')
      ..children.addAll(<Element>[
        SpanElement()
          ..classes.add('ce-color-palette__title')
          ..text = isHighlight ? 'Realce' : 'Cor da fonte',
        grid,
        DivElement()
          ..classes.add('ce-color-palette__footer')
          ..children.addAll(<Element>[custom, clear]),
      ]);
  }

  DivElement _group(String label, List<Element> children) => DivElement()
    ..classes.add('ce-word-group')
    ..children.addAll(<Element>[
      DivElement()
        ..classes.add('ce-word-group__commands')
        ..children.addAll(children),
      SpanElement()
        ..classes.add('ce-word-group__label')
        ..text = label,
    ]);

  DivElement _twoRowGroup(
    String label,
    List<Element> firstRow,
    List<Element> secondRow,
  ) {
    final DivElement group = _group(label, <Element>[
      DivElement()
        ..classes.add('ce-word-command-rows')
        ..children.addAll(<Element>[
          DivElement()
            ..classes.add('ce-word-command-row')
            ..children.addAll(firstRow),
          DivElement()
            ..classes.add('ce-word-command-row')
            ..children.addAll(secondRow),
        ]),
    ]);
    group.classes.add('ce-word-group--two-row');
    return group;
  }

  DivElement _styleGalleryGroup() {
    final ButtonElement more = _button(
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
      final DivElement menu = DivElement();
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
      _openMenuFor(more, menu);
    });
    final DivElement group = _group('Estilos', <Element>[
      DivElement()
        ..classes.add('ce-word-style-gallery')
        ..children.addAll(<Element>[
          _styleCommand('Normal', null),
          _styleCommand('Título 1', TitleLevel.first),
          _styleCommand('Título 2', TitleLevel.second),
          more,
        ]),
    ]);
    group.classes.add('ce-word-group--styles');
    return group;
  }

  ButtonElement _styleCommand(String label, TitleLevel? level) {
    final ButtonElement button = ButtonElement()
      ..type = 'button'
      ..classes.add('ce-word-style')
      ..dataset['styleLevel'] = level?.value ?? 'normal'
      ..text = label
      ..onMouseDown.listen((event) => event.preventDefault())
      ..onClick.listen((_) => _command.executeTitle(level));
    _styleButtons[level] = button;
    return button;
  }

  void _activateTab(DivElement shell, String id) {
    _activeTabId = id;
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
      button.append(SpanElement()
        ..classes.add('ce-word-command__label')
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

  ButtonElement _dropdownButton(
    String commandName,
    String iconClass,
    String label,
    DivElement Function() buildMenu,
  ) {
    late ButtonElement button;
    button = _button(commandName, iconClass, label, () {
      if (_openMenuOwner == button) {
        _closeMenu();
        return;
      }
      _openMenuFor(button, buildMenu());
    }, labeled: true);
    button.append(
        SpanElement()..classes.addAll(<String>['ti', 'ti-chevron-down']));
    return button;
  }

  StreamSubscription<MouseEvent>? _outsideClickSubscription;

  void _openMenuFor(Element owner, DivElement menu) {
    _closeMenu();
    final Rectangle<num> ownerRect = owner.getBoundingClientRect();
    final Rectangle<num> hostRect = _menuHost.getBoundingClientRect();
    menu
      ..classes.add('ce-word-menu')
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

  DivElement _menuItem(String title, String detail, void Function() action) {
    return DivElement()
      ..classes.add('ce-word-menu__item')
      ..children.addAll(<Element>[
        SpanElement()
          ..classes.add('ce-word-menu__item-title')
          ..text = title,
        SpanElement()
          ..classes.add('ce-word-menu__item-detail')
          ..text = detail,
      ])
      ..onClick.listen((_) {
        action();
        _closeMenu();
      });
  }

  DivElement _buildMarginsMenu() {
    // Presets do Word (cm): [superior, direita, inferior, esquerda].
    DivElement preset(String name, String detail, List<double> cm) =>
        _menuItem(name, detail, () {
          _command.executeSetPaperMargin(<double>[
            for (final double value in cm) value * _pxPerCm,
          ]);
        });

    final DivElement menu = DivElement()
      ..children.addAll(<Element>[
        preset('Normal', 'Sup/Inf 2,5 cm · Esq/Dir 3 cm',
            <double>[2.5, 3, 2.5, 3]),
        preset('Estreita', 'Todas 1,27 cm', <double>[1.27, 1.27, 1.27, 1.27]),
        preset('Moderada', 'Sup/Inf 2,54 cm · Esq/Dir 1,91 cm',
            <double>[2.54, 1.91, 2.54, 1.91]),
        preset('Larga', 'Sup/Inf 2,54 cm · Esq/Dir 5,08 cm',
            <double>[2.54, 5.08, 2.54, 5.08]),
        DivElement()..classes.add('ce-word-menu__divider'),
      ]);
    menu.append(_buildCustomMarginsForm());
    return menu;
  }

  DivElement _buildCustomMarginsForm() {
    final List<double> current = _currentMarginsPx();
    NumberInputElement marginInput(String label, double px) {
      return NumberInputElement()
        ..classes.add('ce-word-menu__number')
        ..title = label
        ..min = '0'
        ..step = '0.1'
        ..value = (px / _pxPerCm).toStringAsFixed(2);
    }

    final NumberInputElement top = marginInput('Superior', current[0]);
    final NumberInputElement right = marginInput('Direita', current[1]);
    final NumberInputElement bottom = marginInput('Inferior', current[2]);
    final NumberInputElement left = marginInput('Esquerda', current[3]);

    DivElement field(String label, NumberInputElement input) => DivElement()
      ..classes.add('ce-word-menu__field')
      ..children.addAll(<Element>[
        SpanElement()..text = label,
        input,
      ]);

    final ButtonElement apply = ButtonElement()
      ..type = 'button'
      ..classes.add('ce-word-menu__apply')
      ..text = 'Aplicar'
      ..onClick.listen((_) {
        double parse(NumberInputElement input, double fallbackPx) {
          final double? cm = double.tryParse(input.value ?? '');
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

    return DivElement()
      ..classes.add('ce-word-menu__form')
      ..children.addAll(<Element>[
        SpanElement()
          ..classes.add('ce-word-menu__form-title')
          ..text = 'Margens personalizadas (cm)',
        DivElement()
          ..classes.add('ce-word-menu__fields')
          ..children.addAll(<Element>[
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

  DivElement _buildPaperSizeMenu() {
    DivElement size(String name, String detail, double width, double height) =>
        _menuItem(name, detail, () => _command.executePaperSize(width, height));

    return DivElement()
      ..children.addAll(<Element>[
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
  late final DivElement root;

  final Map<String, ButtonElement> _commandButtons = <String, ButtonElement>{};

  Command get _command => _actions.command;

  void syncRangeStyle(IRangeStyle style) {
    _commandButtons['bold']?.classes.toggle('active', style.bold);
    _commandButtons['italic']?.classes.toggle('active', style.italic);
    _commandButtons['underline']?.classes.toggle('active', style.underline);
    _commandButtons['undo']?.classes.toggle('disabled', !style.undo);
    _commandButtons['redo']?.classes.toggle('disabled', !style.redo);
  }

  DivElement _build() {
    final DivElement toolbar = DivElement()
      ..classes.add('ce-embed__toolbar')
      ..setAttribute('role', 'toolbar')
      ..setAttribute('aria-label', 'Formatação do documento');
    toolbar.children.addAll(<Element>[
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

  ButtonElement _button(
    String commandName,
    String iconClass,
    String label,
    void Function() action,
  ) {
    final ButtonElement button = ButtonElement()
      ..type = 'button'
      ..title = label
      ..dataset['ceCommand'] = commandName
      ..setAttribute('aria-label', label)
      ..append(SpanElement()..classes.addAll(<String>['ti', iconClass]));
    button.onMouseDown.listen((MouseEvent event) => event.preventDefault());
    button.onClick.listen((_) => action());
    _commandButtons[commandName] = button;
    return button;
  }
}
