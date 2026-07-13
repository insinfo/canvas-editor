import 'dart:html';

import '../../../dataset/constant/editor.dart';
import '../../../interface/draw.dart';
import '../../../interface/element.dart';
import '../../../interface/header.dart';
import '../frame/header.dart';
import '../draw.dart';

/// Ferramenta interativa das caixas de texto do cabeçalho (carimbo, §1.4 do
/// plano de expansão): seleção com 8 alças (mover/redimensionar), edição do
/// texto num painel flutuante e alinhamento esquerda/direita — no espírito
/// das "Opções de Layout" do Word. As edições são visuais (render/PDF); a
/// sincronização do header editado no DOCX continua pendente (F3 follow-up).
class TextBoxTool {
  TextBoxTool(this._draw) {
    _container = _draw.getContainer();
  }

  final Draw _draw;
  late final DivElement _container;

  DivElement? _overlay;
  DivElement? _editPanel;
  int _selectedIndex = -1;

  // Estado de arrasto (mover ou redimensionar por alça).
  String? _dragKind; // 'move' | 'nw'|'n'|'ne'|'e'|'se'|'s'|'sw'|'w'
  double _startClientX = 0;
  double _startClientY = 0;
  double _startLeft = 0;
  double _startTop = 0;
  double _startWidth = 0;
  double _startHeight = 0;

  Header get _header => _draw.getHeader();

  double get _scale => (_draw.getOptions().scale ?? 1).toDouble();

  double _pagePreY() {
    final int pageNo = _draw.getPageNo();
    return pageNo * (_draw.getHeight() + _draw.getPageGap());
  }

  /// Hit-test no mousedown do canvas (coordenadas da página). Retorna true
  /// quando consumiu o clique (selecionou uma caixa ou manteve a seleção).
  bool handleMousedown(double x, double y) {
    final dynamic zone = _draw.getZone();
    if (zone?.isHeaderActive() != true) {
      clear();
      return false;
    }
    for (final HeaderTextBoxRect rect in _header.getTextBoxRects()) {
      if (x >= rect.left &&
          x <= rect.left + rect.width &&
          y >= rect.top &&
          y <= rect.top + rect.height) {
        _select(rect);
        return true;
      }
    }
    clear();
    return false;
  }

  void _select(HeaderTextBoxRect rect) {
    // Limpa QUALQUER seleção anterior (resizer de imagem, popup, caret e o
    // range da shell) — evita duas mini-UIs contextuais simultâneas.
    try {
      _draw.clearSideEffect(); // inclui este tool (overlay antigo)
      final dynamic rangeManager = _draw.getRange();
      rangeManager?.clearRange?.call();
      // Notifica a shell (rangeStyleChange) p/ a mini-toolbar flutuante sumir.
      rangeManager?.setRangeStyle?.call();
    } catch (_) {}
    _selectedIndex = rect.index;
    _renderOverlay(rect);
  }

  void _renderOverlay(HeaderTextBoxRect rect) {
    _overlay?.remove();
    final double preY = _pagePreY();
    final DivElement overlay = DivElement()
      ..classes.add('$editorPrefix-textbox-tool')
      ..style.left = '${rect.left}px'
      ..style.top = '${rect.top + preY}px'
      ..style.width = '${rect.width}px'
      ..style.height = '${rect.height}px';
    overlay.onMouseDown.listen((MouseEvent event) {
      event
        ..preventDefault()
        ..stopPropagation();
      _beginDrag('move', event, rect);
    });
    overlay.onDoubleClick.listen((Event event) {
      event
        ..preventDefault()
        ..stopPropagation();
      _openEditPanel(rect);
    });
    for (final String kind in const <String>[
      'nw', 'n', 'ne', 'e', 'se', 's', 'sw', 'w' //
    ]) {
      final DivElement handle = DivElement()
        ..classes.addAll(<String>['$editorPrefix-textbox-tool__handle', kind]);
      handle.onMouseDown.listen((MouseEvent event) {
        event
          ..preventDefault()
          ..stopPropagation();
        _beginDrag(kind, event, rect);
      });
      overlay.append(handle);
    }
    // Mini-toolbar de alinhamento/edição (estilo "Opções de Layout").
    final DivElement bar = DivElement()
      ..classes.add('$editorPrefix-textbox-tool__bar');
    ButtonElement barButton(String icon, String title, void Function() act) {
      final ButtonElement button = ButtonElement()
        ..type = 'button'
        ..title = title
        ..append(SpanElement()..classes.addAll(<String>['ti', icon]));
      button.onMouseDown.listen((MouseEvent e) => e.preventDefault());
      button.onClick.listen((_) => act());
      return button;
    }

    bar
      ..append(barButton('ti-layout-align-left', 'Alinhar à esquerda', () {
        _mutateBox((IHeaderTextBox tb) {
          tb
            ..offsetXPx = null
            ..alignRight = false;
        });
      }))
      ..append(barButton('ti-layout-align-right', 'Alinhar à direita', () {
        _mutateBox((IHeaderTextBox tb) {
          tb
            ..offsetXPx = null
            ..alignRight = true;
        });
      }))
      ..append(barButton('ti-pencil', 'Editar texto', () {
        _openEditPanel(rect);
      }));
    // Cor de fundo da caixa (input nativo) + limpar fundo.
    final InputElement fillInput = InputElement(type: 'color')
      ..classes.add('$editorPrefix-textbox-tool__fill')
      ..title = 'Cor de fundo';
    final List<IHeaderTextBox> boxesNow = _header.getTextBoxes();
    if (_selectedIndex >= 0 && _selectedIndex < boxesNow.length) {
      final String? fill = boxesNow[_selectedIndex].fillColor;
      if (fill != null && fill.startsWith('#') && fill.length == 7) {
        fillInput.value = fill;
      }
    }
    fillInput.onMouseDown.listen((MouseEvent e) => e.stopPropagation());
    fillInput.onChange.listen((_) {
      final String? value = fillInput.value;
      if (value == null || value.isEmpty) return;
      _mutateBox((IHeaderTextBox tb) => tb.fillColor = value);
    });
    bar.append(fillInput);
    bar.append(barButton('ti-droplet-off', 'Sem cor de fundo', () {
      _mutateBox((IHeaderTextBox tb) => tb.fillColor = null);
    }));
    overlay.append(bar);
    _container.append(overlay);
    _overlay = overlay;
  }

  void _beginDrag(String kind, MouseEvent event, HeaderTextBoxRect rect) {
    _dragKind = kind;
    _startClientX = event.client.x.toDouble();
    _startClientY = event.client.y.toDouble();
    _startLeft = rect.left;
    _startTop = rect.top;
    _startWidth = rect.width;
    _startHeight = rect.height;
    late final dynamic moveSub;
    late final dynamic upSub;
    moveSub = document.onMouseMove.listen(_onDragMove);
    upSub = document.onMouseUp.listen((MouseEvent up) {
      moveSub.cancel();
      upSub.cancel();
      _endDrag(up);
    });
  }

  void _onDragMove(MouseEvent event) {
    final DivElement? overlay = _overlay;
    final String? kind = _dragKind;
    if (overlay == null || kind == null) return;
    final double dx = event.client.x - _startClientX;
    final double dy = event.client.y - _startClientY;
    double left = _startLeft;
    double top = _startTop;
    double width = _startWidth;
    double height = _startHeight;
    if (kind == 'move') {
      left += dx;
      top += dy;
    } else {
      if (kind.contains('w')) {
        left += dx;
        width -= dx;
      }
      if (kind.contains('e')) width += dx;
      if (kind.contains('n')) {
        top += dy;
        height -= dy;
      }
      if (kind.contains('s')) height += dy;
      if (width < 24) width = 24;
      if (height < 16) height = 16;
    }
    overlay.style
      ..left = '${left}px'
      ..top = '${top + _pagePreY()}px'
      ..width = '${width}px'
      ..height = '${height}px';
  }

  void _endDrag(MouseEvent event) {
    final String? kind = _dragKind;
    _dragKind = null;
    if (kind == null) return;
    final double dx = event.client.x - _startClientX;
    final double dy = event.client.y - _startClientY;
    if (dx == 0 && dy == 0) return;
    final double scale = _scale;
    final List<double> margins = List<double>.from(_draw.getMargins());
    final double headerTop = _header.getHeaderTop();
    _mutateBox((IHeaderTextBox tb) {
      double left = _startLeft;
      double top = _startTop;
      double width = _startWidth;
      double height = _startHeight;
      if (kind == 'move') {
        left += dx;
        top += dy;
      } else {
        if (kind.contains('w')) {
          left += dx;
          width -= dx;
        }
        if (kind.contains('e')) width += dx;
        if (kind.contains('n')) {
          top += dy;
          height -= dy;
        }
        if (kind.contains('s')) height += dy;
        if (width < 24) width = 24;
        if (height < 16) height = 16;
      }
      tb
        ..offsetXPx = (left - margins[3]) / scale
        ..offsetYPx = ((top - headerTop) / scale).clamp(0, double.infinity)
        ..widthPx = width / scale
        ..heightPx = height / scale;
    });
  }

  /// Aplica a mutação, repinta e reposiciona a seleção. O desenho da caixa
  /// recomputa as próprias rows no render — isCompute:false basta.
  void _mutateBox(void Function(IHeaderTextBox tb) mutate) {
    final List<IHeaderTextBox> boxes = _header.getTextBoxes();
    if (_selectedIndex < 0 || _selectedIndex >= boxes.length) return;
    mutate(boxes[_selectedIndex]);
    _draw.render(IDrawOption(
      isCompute: false,
      isSubmitHistory: false,
      isSetCursor: false,
    ));
    final List<HeaderTextBoxRect> rects = _header.getTextBoxRects();
    if (_selectedIndex < rects.length) {
      _renderOverlay(rects[_selectedIndex]);
    }
  }

  void _openEditPanel(HeaderTextBoxRect rect) {
    _editPanel?.remove();
    final List<IHeaderTextBox> boxes = _header.getTextBoxes();
    if (_selectedIndex < 0 || _selectedIndex >= boxes.length) return;
    final IHeaderTextBox tb = boxes[_selectedIndex];
    final String currentText = tb.elements.map((IElement e) => e.value).join();
    final DivElement panel = DivElement()
      ..classes.add('$editorPrefix-textbox-tool__editor')
      ..style.left = '${rect.left}px'
      ..style.top = '${rect.top + _pagePreY() + rect.height + 6}px';
    final TextAreaElement area = TextAreaElement()
      ..value = currentText
      ..rows = 5;
    final ButtonElement ok = ButtonElement()
      ..type = 'button'
      ..text = 'Aplicar';
    final ButtonElement cancel = ButtonElement()
      ..type = 'button'
      ..text = 'Cancelar';
    ok.onClick.listen((_) {
      final String text = area.value ?? '';
      // Reusa o estilo do primeiro elemento de texto do carimbo.
      final IElement styleSource = tb.elements.firstWhere(
        (IElement e) => e.value.trim().isNotEmpty,
        orElse: () =>
            tb.elements.isNotEmpty ? tb.elements.first : IElement(value: ''),
      );
      tb.elements = <IElement>[
        for (final String line in text.split('\n')) ...<IElement>[
          if (line.isNotEmpty)
            IElement(
              value: line,
              font: styleSource.font,
              size: styleSource.size,
              bold: styleSource.bold,
              color: styleSource.color,
            ),
          IElement(value: '\n'),
        ]
      ];
      if (tb.elements.isNotEmpty && tb.elements.last.value == '\n') {
        tb.elements.removeLast();
      }
      _editPanel?.remove();
      _editPanel = null;
      _mutateBox((_) {});
    });
    cancel.onClick.listen((_) {
      _editPanel?.remove();
      _editPanel = null;
    });
    panel
      ..append(area)
      ..append(DivElement()
        ..classes.add('$editorPrefix-textbox-tool__editor-actions')
        ..append(ok)
        ..append(cancel));
    _container.append(panel);
    _editPanel = panel;
    area.focus();
  }

  void clear() {
    _selectedIndex = -1;
    _dragKind = null;
    _overlay?.remove();
    _overlay = null;
    _editPanel?.remove();
    _editPanel = null;
  }
}
