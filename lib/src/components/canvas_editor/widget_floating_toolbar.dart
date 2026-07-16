import 'dart:async';
import 'dart:html';

import '../../editor/index.dart';
import '../core/ui_component.dart';

/// Modo contextual exibido pela mini-toolbar.
enum FloatingToolbarMode { hidden, text, table, image }

/// Resolve o contexto da seleção atual (texto/tabela/imagem) — usado pela
/// mini-toolbar e pelas abas contextuais do ribbon.
FloatingToolbarMode resolveSelectionContext(Command command) {
  final IRange range = command.getRange();
  final bool isTable = range.tableId != null;
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
    root = DivElement()
      ..classes.add('ce-floating-toolbar')
      ..style.display = 'none'
      ..setAttribute('role', 'toolbar')
      ..setAttribute('aria-label', 'Formatação rápida');
    _textGroup = _group('texto');
    _tableGroup = _group('tabela');
    _imageGroup = _group('imagem');
    root.children.addAll(<Element>[_textGroup, _tableGroup, _imageGroup]);
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
  late final DivElement root;

  late final DivElement _textGroup;
  late final DivElement _tableGroup;
  late final DivElement _imageGroup;

  final Map<String, ButtonElement> _buttons = <String, ButtonElement>{};
  bool _pointerInside = false;
  FloatingToolbarMode _mode = FloatingToolbarMode.hidden;

  FloatingToolbarMode get mode => _mode;

  DivElement _group(String name) => DivElement()
    ..classes.add('ce-floating-toolbar__group')
    ..dataset['group'] = name
    ..style.display = 'none';

  void _buildTextCommands() {
    _textGroup.children.addAll(<Element>[
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
    _tableGroup.children.addAll(<Element>[
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
    ]);
  }

  void _buildImageCommands() {
    _imageGroup.children.addAll(<Element>[
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
    final FileUploadInputElement input = FileUploadInputElement()
      ..accept = '.png, .jpg, .jpeg';
    input.onChange.first.then((_) {
      final File? file =
          input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) return;
      final FileReader reader = FileReader()..readAsDataUrl(file);
      reader.onLoad.first.then((_) {
        final dynamic value = reader.result;
        if (value is String && value.isNotEmpty) {
          _command.executeReplaceImageElement(value);
        }
      });
    });
    input.click();
  }

  ButtonElement _wrapButton(
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

  ButtonElement _button(
    String id,
    String icon,
    String label,
    void Function() action, {
    bool refreshAfterAction = true,
  }) {
    final ButtonElement button = ButtonElement()
      ..type = 'button'
      ..title = label
      ..setAttribute('aria-label', label)
      ..append(SpanElement()..classes.addAll(<String>['ti', icon]))
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

  Element _divider() => SpanElement()
    ..classes.add('ce-floating-toolbar__divider')
    ..setAttribute('aria-hidden', 'true');

  void syncStyle(IRangeStyle style) {
    if (style.type == null) {
      return;
    }
    _buttons['bold']?.classes.toggle('active', style.bold);
    _buttons['italic']?.classes.toggle('active', style.italic);
    _buttons['underline']?.classes.toggle('active', style.underline);
    _buttons['strike']?.classes.toggle('active', style.strikeout);
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
      _buttons[id]?.classes.toggle('active', display == value);
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
    final IElementPosition? position = _command.getCursorPosition();
    final CanvasElement? page =
        _draw.getPage(position?.pageNo ?? -1) as CanvasElement?;
    if (page == null) {
      hide();
      return;
    }
    _textGroup.style.display =
        _mode == FloatingToolbarMode.text ? 'contents' : 'none';
    _tableGroup.style.display =
        _mode == FloatingToolbarMode.table ? 'contents' : 'none';
    if (_mode == FloatingToolbarMode.table) {
      _buttons['repeatHeader']
          ?.classes
          .toggle('active', _command.getIsTableHeaderRowActive());
    }
    _imageGroup.style.display =
        _mode == FloatingToolbarMode.image ? 'contents' : 'none';
    if (_mode == FloatingToolbarMode.image) {
      final RangeContext? context = _command.getRangeContext();
      final IElement? element = context?.startElement;
      if (element != null) _syncImageDisplay(element);
    }
    final Rectangle<num> pageRect = page.getBoundingClientRect();
    final Rectangle<num> rootRect = _editorRoot.getBoundingClientRect();
    final double scale = (_draw.getOptions().scale as num?)?.toDouble() ?? 1;
    final double x = pageRect.left.toDouble() -
        rootRect.left.toDouble() +
        (position?.coordX ?? pageRect.width.toDouble() / 2) * scale;
    final double y = pageRect.top.toDouble() -
        rootRect.top.toDouble() +
        (position?.coordY ?? 80) * scale;
    root.style
      ..display = 'flex'
      ..left = '${x.round()}px'
      ..top = '${(y - 44).round()}px';
  }

  void hide() {
    _mode = FloatingToolbarMode.hidden;
    root.style.display = 'none';
  }
}
