import 'dart:async';
import 'package:canvas_text_editor/src/dom/dom.dart';

import '../../editor/index.dart';
import '../core/ui_component.dart';

/// Modo contextual exibido pela mini-toolbar.
enum FloatingToolbarMode { hidden, text, table, image }

/// Resolve o contexto da seleção atual (texto/tabela/imagem) — usado pela
/// mini-toolbar e pelas abas contextuais do ribbon.
FloatingToolbarMode resolveSelectionContext(Command command) {
  final IRange range = command.getRange();
  // `range.tableId` só é preenchido em seleção que ATRAVESSA células; com o
  // caret dentro de uma célula ele fica null — por isso o contexto de tabela
  // (aba do ribbon + mini-toolbar) não aparecia ao simplesmente clicar numa
  // célula. O sinal correto é o mesmo do TableTool: o contexto de posição.
  final bool isTable =
      range.tableId != null || command.getCursorTableElement() != null;
  final bool isCollapsed = range.startIndex == range.endIndex &&
      (!isTable ||
          (range.startTrIndex == range.endTrIndex &&
              range.startTdIndex == range.endTdIndex));
  // Dentro de tabela o caret normalmente está colapsado em uma única
  // célula. Ainda assim os comandos estruturais da tabela devem aparecer.
  if (isTable) {
    return FloatingToolbarMode.table;
  }
  if (isCollapsed) {
    // getRangeContext também materializa coordenadas lazy; mantenha essa
    // consulta fora do caminho quente das seleções textuais não colapsadas.
    final RangeContext? context = command.getRangeContext();
    if (context?.startElement.type == ElementType.image) {
      return FloatingToolbarMode.image;
    }
    return FloatingToolbarMode.hidden;
  }
  return FloatingToolbarMode.text;
}

/// Mini-toolbar contextual posicionada junto à seleção no canvas.
///
/// Ela usa o [RangeContext] e a posição calculada pelo core; não observa cada
/// tecla nem mede o DOM durante a digitação. A atualização é solicitada pelo
/// scheduler da shell após `rangeStyleChange`/`mouseup`. O conjunto de
/// comandos muda conforme o contexto: seleção de texto, seleção dentro de
/// tabela ou imagem selecionada (estilo Word).
class WidgetFloatingToolbar extends UiComponent {
  WidgetFloatingToolbar(this._command, this._draw, this._editorRoot) {
    root = HTMLDivElement()
      ..classList.add('ce-floating-toolbar')
      ..style.display = 'none'
      ..setAttribute('role', 'toolbar')
      ..setAttribute('aria-label', 'Formatação rápida');
    _textGroup = _group('texto');
    _tableGroup = _group('tabela');
    _imageGroup = _group('imagem');
    root.appendAll(<Element>[_textGroup, _tableGroup, _imageGroup]);
    _buildTextCommands();
    _buildTableCommands();
    _buildImageCommands();
    listen(root.onMouseEnter, (_) => _pointerInside = true);
    listen(root.onMouseLeave, (_) => _pointerInside = false);
  }

  final Command _command;
  final dynamic _draw;
  final Element _editorRoot;

  @override
  late final HTMLDivElement root;

  late final HTMLDivElement _textGroup;
  late final HTMLDivElement _tableGroup;
  late final HTMLDivElement _imageGroup;

  final Map<String, HTMLButtonElement> _buttons = <String, HTMLButtonElement>{};
  bool _pointerInside = false;
  FloatingToolbarMode _mode = FloatingToolbarMode.hidden;

  FloatingToolbarMode get mode => _mode;

  HTMLDivElement _group(String name) => HTMLDivElement()
    ..classList.add('ce-floating-toolbar__group')
    ..dataset['group'] = name
    ..style.display = 'none';

  void _buildTextCommands() {
    _textGroup.appendAll(<Element>[
      _button('bold', 'ti-bold', 'Negrito', _command.executeBold,
          refreshAfterAction: false),
      _button('italic', 'ti-italic', 'Itálico', _command.executeItalic,
          refreshAfterAction: false),
      _button(
          'underline', 'ti-underline', 'Sublinhado', _command.executeUnderline,
          refreshAfterAction: false),
      _button(
          'strike', 'ti-strikethrough', 'Tachado', _command.executeStrikeout,
          refreshAfterAction: false),
      _divider(),
      _button(
          'copy', 'ti-copy', 'Copiar', () => unawaited(_command.executeCopy()),
          refreshAfterAction: false),
      _button('clear', 'ti-clear-formatting', 'Limpar formatação',
          _command.executeFormat,
          refreshAfterAction: false),
    ]);
  }

  void _buildTableCommands() {
    _tableGroup.appendAll(<Element>[
      _button('rowTop', 'ti-row-insert-top', 'Inserir linha acima',
          _command.executeInsertTableTopRow),
      _button('rowBottom', 'ti-row-insert-bottom', 'Inserir linha abaixo',
          _command.executeInsertTableBottomRow),
      _button('colLeft', 'ti-column-insert-left', 'Inserir coluna à esquerda',
          _command.executeInsertTableLeftCol),
      _button('colRight', 'ti-column-insert-right', 'Inserir coluna à direita',
          _command.executeInsertTableRightCol),
      _divider(),
      _button('rowRemove', 'ti-row-remove', 'Excluir linha',
          _command.executeDeleteTableRow),
      _button('colRemove', 'ti-column-remove', 'Excluir coluna',
          _command.executeDeleteTableCol),
      _button('tableRemove', 'ti-table-minus', 'Excluir tabela',
          _command.executeDeleteTable),
      _divider(),
      _button('mergeCells', 'ti-arrows-join-2', 'Mesclar células',
          _command.executeMergeTableCell),
      _button('splitCells', 'ti-arrows-split-2', 'Desfazer mesclagem',
          _command.executeCancelMergeTableCell),
      _divider(),
      _button('repeatHeader', 'ti-table-options', 'Repetir linhas de cabeçalho',
          _command.executeToggleTableHeaderRow),
      _divider(),
      _button('valignTop', 'ti-layout-align-top', 'Alinhar no topo',
          () => _command.executeTableTdVerticalAlign(VerticalAlign.top)),
      _button('valignMiddle', 'ti-layout-align-middle', 'Alinhar no meio',
          () => _command.executeTableTdVerticalAlign(VerticalAlign.middle)),
      _button('valignBottom', 'ti-layout-align-bottom', 'Alinhar embaixo',
          () => _command.executeTableTdVerticalAlign(VerticalAlign.bottom)),
      _divider(),
      _button('borderAll', 'ti-border-all', 'Todas as bordas',
          () => _command.executeTableBorderType(TableBorder.all)),
      _button('borderOuter', 'ti-border-outer', 'Bordas externas',
          () => _command.executeTableBorderType(TableBorder.external)),
      _button('borderInner', 'ti-border-inner', 'Bordas internas',
          () => _command.executeTableBorderType(TableBorder.internal)),
      _button('borderNone', 'ti-border-none', 'Sem bordas',
          () => _command.executeTableBorderType(TableBorder.empty)),
      _button('borderDash', 'ti-border-style-2', 'Borda tracejada',
          () => _command.executeTableBorderType(TableBorder.dash)),
      _colorPicker('borderColor', 'ti-brush', 'Cor da borda',
          (String value) => _command.executeTableBorderColor(value)),
      _divider(),
      _colorPicker('cellFill', 'ti-paint', 'Cor de fundo da célula',
          (String value) => _command.executeTableTdBackgroundColor(value)),
      _button('slashForward', 'ti-slash', 'Diagonal ↗',
          () => _command.executeTableTdSlashType(TdSlash.forward)),
      _button('slashBack', 'ti-backslash', 'Diagonal ↘',
          () => _command.executeTableTdSlashType(TdSlash.back)),
    ]);
  }

  /// Botão com input de cor embutido (borda/preenchimento de célula).
  Element _colorPicker(
    String id,
    String icon,
    String label,
    void Function(String) onPick,
  ) {
    final HTMLInputElement input = (HTMLInputElement()..type = 'color')
      ..classList.add('ce-floating-toolbar__color-input');
    input.onInput.listen((_) {
      final String value = input.value;
      if (value.isNotEmpty) onPick(value);
    });
    final HTMLButtonElement button = HTMLButtonElement()
      ..type = 'button'
      ..title = label
      ..setAttribute('aria-label', label)
      ..append(HTMLSpanElement()..classList.addAll(<String>['ti', icon]))
      ..onMouseDown.listen((MouseEvent event) => event.preventDefault())
      ..onClick.listen((_) => input.click());
    _buttons[id] = button;
    return HTMLSpanElement()
      ..classList.add('ce-floating-toolbar__color')
      ..append(button)
      ..append(input);
  }

  void _buildImageCommands() {
    _imageGroup.appendAll(<Element>[
      _alignButton('imgAlignLeft', 'ti-align-box-left-middle',
          'Alinhar à esquerda', 'left'),
      _alignButton('imgAlignCenter', 'ti-align-box-center-middle',
          'Centralizar na página', 'center'),
      _alignButton('imgAlignRight', 'ti-align-box-right-middle',
          'Alinhar à direita', 'right'),
      _divider(),
      _button('imageChange', 'ti-photo-edit', 'Alterar imagem', _changeImage),
      _button('imageSave', 'ti-download', 'Salvar imagem',
          _command.executeSaveAsImageElement),
      _divider(),
      _wrapButton('wrapBlock', 'ti-float-none', 'Embutida no texto',
          ImageDisplay.block),
      _wrapButton('wrapInline', 'ti-layout-rows', 'Acima e abaixo do texto',
          ImageDisplay.inline),
      _wrapButton('wrapSurround', 'ti-float-left', 'Contornar pelo texto',
          ImageDisplay.surround),
      _wrapButton('wrapFront', 'ti-stack-front', 'À frente do texto',
          ImageDisplay.floatTop),
      _wrapButton('wrapBehind', 'ti-stack-back', 'Atrás do texto',
          ImageDisplay.floatBottom),
    ]);
  }

  void _changeImage() {
    final HTMLInputElement input = (HTMLInputElement()..type = 'file')
      ..accept = '.png, .jpg, .jpeg';
    input.onChange.first.then((_) {
      final File? file =
          input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) return;
      final FileReader reader = FileReader()..readAsDataURL(file);
      reader.onLoad.first.then((_) {
        final dynamic value = reader.result;
        if (value is String && value.isNotEmpty) {
          _command.executeReplaceImageElement(value);
        }
      });
    });
    input.click();
  }

  HTMLButtonElement _alignButton(
    String id,
    String icon,
    String label,
    String align,
  ) =>
      _button(id, icon, label, () {
        final RangeContext? context = _command.getRangeContext();
        final IElement? element = context?.startElement;
        if (element == null || element.type != ElementType.image) return;
        _command.executeImageAlign(element, align);
      });

  HTMLButtonElement _wrapButton(
    String id,
    String icon,
    String label,
    ImageDisplay display,
  ) =>
      _button(id, icon, label, () {
        final RangeContext? context = _command.getRangeContext();
        final IElement? element = context?.startElement;
        if (element == null || element.type != ElementType.image) return;
        _command.executeChangeImageDisplay(element, display);
      });

  HTMLButtonElement _button(
    String id,
    String icon,
    String label,
    void Function() action, {
    bool refreshAfterAction = true,
  }) {
    final HTMLButtonElement button = HTMLButtonElement()
      ..type = 'button'
      ..title = label
      ..setAttribute('aria-label', label)
      ..append(HTMLSpanElement()..classList.addAll(<String>['ti', icon]))
      ..onMouseDown.listen((MouseEvent event) => event.preventDefault())
      ..onClick.listen((_) {
        action();
        if (refreshAfterAction) {
          refresh();
        }
      });
    _buttons[id] = button;
    return button;
  }

  Element _divider() => HTMLSpanElement()
    ..classList.add('ce-floating-toolbar__divider')
    ..setAttribute('aria-hidden', 'true');

  void syncStyle(IRangeStyle style) {
    if (style.type == null) {
      return;
    }
    _buttons['bold']?.classList.toggle('active', style.bold);
    _buttons['italic']?.classList.toggle('active', style.italic);
    _buttons['underline']?.classList.toggle('active', style.underline);
    _buttons['strike']?.classList.toggle('active', style.strikeout);
  }

  void _syncImageDisplay(IElement element) {
    final ImageDisplay display = element.imgDisplay ?? ImageDisplay.block;
    const Map<String, ImageDisplay> wrapIds = <String, ImageDisplay>{
      'wrapBlock': ImageDisplay.block,
      'wrapInline': ImageDisplay.inline,
      'wrapSurround': ImageDisplay.surround,
      'wrapFront': ImageDisplay.floatTop,
      'wrapBehind': ImageDisplay.floatBottom,
    };
    wrapIds.forEach((String id, ImageDisplay value) {
      _buttons[id]?.classList.toggle('active', display == value);
    });
  }

  /// Decide o modo contextual a partir do range atual.
  FloatingToolbarMode _resolveMode() => resolveSelectionContext(_command);

  /// Mostra a toolbar conforme o contexto: texto, tabela ou imagem.
  void refresh() {
    _mode = _resolveMode();
    if (_mode == FloatingToolbarMode.hidden) {
      if (!_pointerInside) hide();
      return;
    }
    final IRange range = _command.getRange();
    // Seleção que atravessa células (linha/coluna/tabela inteira pelas alças
    // ✥/barras) — o balão vai para CIMA da tabela, fora dela.
    final bool crossCell = _mode == FloatingToolbarMode.table &&
        (range.isCrossRowCol == true ||
            range.startTdIndex != range.endTdIndex ||
            range.startTrIndex != range.endTrIndex);
    // Word: caret apenas digitando numa célula NÃO mostra balão flutuante
    // (fica só a aba contextual "Tabela" no ribbon) — senão ele cobre as
    // células e atrapalha a digitação.
    if (_mode == FloatingToolbarMode.table &&
        !crossCell &&
        range.startIndex == range.endIndex) {
      if (!_pointerInside) hide();
      return;
    }
    final IElementPosition? position = _command.getCursorPosition();
    final HTMLCanvasElement? page =
        _draw.getPage(position?.pageNo ?? -1) as HTMLCanvasElement?;
    if (page == null) {
      hide();
      return;
    }
    // Word: dentro de tabela a mini-toolbar traz formatação de TEXTO **e** os
    // controles de tabela (fonte/negrito + Inserir/Excluir no mesmo balão).
    _textGroup.style.display = _mode == FloatingToolbarMode.text ||
            _mode == FloatingToolbarMode.table
        ? 'contents'
        : 'none';
    _tableGroup.style.display =
        _mode == FloatingToolbarMode.table ? 'contents' : 'none';
    if (_mode == FloatingToolbarMode.table) {
      _buttons['repeatHeader']
          ?.classList
          .toggle('active', _command.getIsTableHeaderRowActive());
    }
    _imageGroup.style.display =
        _mode == FloatingToolbarMode.image ? 'contents' : 'none';
    if (_mode == FloatingToolbarMode.image) {
      final RangeContext? context = _command.getRangeContext();
      final IElement? element = context?.startElement;
      if (element != null) _syncImageDisplay(element);
    }
    final DOMRect rootRect = _editorRoot.getBoundingClientRect();
    final double scale = (_draw.getOptions().scale as num?)?.toDouble() ?? 1;

    // Seleção de linha/coluna/tabela: balão ACIMA da borda superior da
    // tabela (como o Word ao clicar na alça ✥), nunca sobre as células.
    if (crossCell) {
      final Map<String, double>? tableRect = _command.getCursorTableRect();
      final HTMLCanvasElement? tablePage = tableRect == null
          ? null
          : _draw.getPage(tableRect['pageNo']!.toInt()) as HTMLCanvasElement?;
      if (tableRect != null && tablePage != null) {
        final DOMRect tablePageRect = tablePage.getBoundingClientRect();
        final double x = tablePageRect.left.toDouble() -
            rootRect.left.toDouble() +
            tableRect['x']! * scale;
        final double y = tablePageRect.top.toDouble() -
            rootRect.top.toDouble() +
            tableRect['y']! * scale;
        root.style
          ..display = 'flex'
          ..left = '${x.round()}px'
          ..top = '${(y - 10).round()}px'
          ..transform = 'translateY(-100%)';
        return;
      }
    }

    final DOMRect pageRect = page.getBoundingClientRect();
    final double x = pageRect.left.toDouble() -
        rootRect.left.toDouble() +
        (position?.coordX ?? pageRect.width.toDouble() / 2) * scale;
    final double y = pageRect.top.toDouble() -
        rootRect.top.toDouble() +
        (position?.coordY ?? 80) * scale;
    root.style
      ..display = 'flex'
      ..left = '${x.round()}px'
      ..top = '${(y - 44).round()}px'
      ..transform = '';
  }

  void hide() {
    _mode = FloatingToolbarMode.hidden;
    root.style.display = 'none';
  }
}
