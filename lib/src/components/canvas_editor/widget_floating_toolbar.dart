import 'dart:async';
import 'dart:html';

import '../../editor/index.dart';
import '../core/ui_component.dart';

/// Mini-toolbar contextual posicionada junto à seleção no canvas.
///
/// Ela usa o [RangeContext] e a posição calculada pelo core; não observa cada
/// tecla nem mede o DOM durante a digitação. A atualização é solicitada pelo
/// scheduler da shell após `rangeStyleChange`/`mouseup`.
class WidgetFloatingToolbar extends UiComponent {
  WidgetFloatingToolbar(this._command, this._draw, this._editorRoot) {
    root = DivElement()
      ..classes.add('ce-floating-toolbar')
      ..style.display = 'none'
      ..setAttribute('role', 'toolbar')
      ..setAttribute('aria-label', 'Formatação rápida');
    _buildCommands();
  }

  final Command _command;
  final dynamic _draw;
  final Element _editorRoot;

  @override
  late final DivElement root;

  final Map<String, ButtonElement> _buttons = <String, ButtonElement>{};
  bool _pointerInside = false;

  void _buildCommands() {
    root.children.addAll(<Element>[
      _button('bold', 'ti-bold', 'Negrito', _command.executeBold),
      _button('italic', 'ti-italic', 'Itálico', _command.executeItalic),
      _button(
          'underline', 'ti-underline', 'Sublinhado', _command.executeUnderline),
      _button(
          'strike', 'ti-strikethrough', 'Tachado', _command.executeStrikeout),
      _divider(),
      _button(
          'copy', 'ti-copy', 'Copiar', () => unawaited(_command.executeCopy())),
      _button('clear', 'ti-clear-formatting', 'Limpar formatação',
          _command.executeFormat),
    ]);
    listen(root.onMouseEnter, (_) => _pointerInside = true);
    listen(root.onMouseLeave, (_) => _pointerInside = false);
  }

  ButtonElement _button(
    String id,
    String icon,
    String label,
    void Function() action,
  ) {
    final ButtonElement button = ButtonElement()
      ..type = 'button'
      ..title = label
      ..setAttribute('aria-label', label)
      ..append(SpanElement()..classes.addAll(<String>['ti', icon]))
      ..onMouseDown.listen((MouseEvent event) => event.preventDefault())
      ..onClick.listen((_) {
        action();
        refresh();
      });
    _buttons[id] = button;
    return button;
  }

  Element _divider() => SpanElement()
    ..classes.add('ce-floating-toolbar__divider')
    ..setAttribute('aria-hidden', 'true');

  void syncStyle(IRangeStyle style) {
    _buttons['bold']?.classes.toggle('active', style.bold);
    _buttons['italic']?.classes.toggle('active', style.italic);
    _buttons['underline']?.classes.toggle('active', style.underline);
    _buttons['strike']?.classes.toggle('active', style.strikeout);
  }

  /// Mostra a toolbar somente para uma seleção textual não colapsada.
  void refresh() {
    final IRange range = _command.getRange();
    final bool isTable = range.tableId != null;
    final bool isCollapsed = range.startIndex == range.endIndex &&
        (!isTable ||
            (range.startTrIndex == range.endTrIndex &&
                range.startTdIndex == range.endTdIndex));
    if (isCollapsed || isTable) {
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

  void hide() => root.style.display = 'none';
}
