import 'dart:html';

import '../../editor/core/command/command.dart';
import '../../editor/core/draw/draw.dart';
import '../../editor/dataset/enum/editor.dart';
import '../../editor/interface/element.dart';
import '../core/ui_component.dart';

enum _RulerDrag {
  none,
  marginLeft,
  marginRight,
  indentLeft, // caixa: move recuo esquerdo + primeira linha juntos (Word)
  firstLine, // ▽ superior: só o delta da primeira linha
  hanging, // △ inferior: recuo das linhas de continuação (mantém a 1ª fixa)
  indentRight, // △ direito
}

/// Régua de página estilo Word/OnlyOffice.
///
/// A escala nasce na margem esquerda, usa quartos de centímetro e separa
/// visualmente o papel (cinza) da área editável (branca). Margens e recuos
/// são arrastáveis com o controle de 3 peças do Word (primeira linha,
/// deslocamento e caixa do recuo esquerdo) + recuo direito, com linha-guia
/// vertical pontilhada sobre o documento durante o arrasto.
class WidgetRuler extends UiComponent {
  WidgetRuler(this._command, this._draw) {
    root = DivElement()..classes.add('ce-rulers');
    _corner = DivElement()
      ..classes.add('ce-ruler-corner')
      ..title = 'Seletor de tabulação';
    _horizontal = DivElement()..classes.add('ce-ruler-horizontal');
    _vertical = DivElement()..classes.add('ce-ruler-vertical');
    root.children.addAll(<Element>[_corner, _horizontal, _vertical]);
    listen(_horizontal.onMouseDown, _startDrag);
    listen(document.onMouseMove, _handleDrag);
    listen(document.onMouseUp, _finishDrag);
    listen(window.onResize, (_) => refresh());
    window.requestAnimationFrame((_) => refresh());
  }

  final Command _command;
  final Draw _draw;

  @override
  late final DivElement root;
  late final DivElement _corner;
  late final DivElement _horizontal;
  late final DivElement _vertical;

  _RulerDrag _drag = _RulerDrag.none;
  double _pageWidth = 0;
  double _scale = 1;
  List<double> _margins = <double>[0, 0, 0, 0];
  double _indentLeft = 0;
  double _firstLine = 0;
  double _indentRight = 0;

  // Marcadores persistentes (reposicionados sem reconstruir a régua — o
  // sync com o cursor roda por tecla via rangeStyleChange coalescido).
  DivElement? _markerMarginLeft;
  DivElement? _markerMarginRight;
  DivElement? _markerFirstLine;
  DivElement? _markerHanging;
  DivElement? _markerLeftBox;
  DivElement? _markerRight;

  // Linha-guia vertical (Word/OnlyOffice) durante o arrasto.
  DivElement? _guide;

  void refresh() {
    _scale = (_draw.getOptions().scale ?? 1).toDouble();
    // getWidth/getHeight/getMargins já incluem scale.
    _pageWidth = _draw.getWidth();
    final double pageHeight = _draw.getHeight();
    _margins = List<double>.from(_draw.getMargins());
    final double pxPerCm = 96 / 2.54 * _scale;
    final int viewportHeight = root.parent?.clientHeight ?? 520;
    final double verticalHeight =
        (viewportHeight - 24).clamp(180, pageHeight).toDouble();

    _readParagraphIndents();
    _horizontal.style.width = '${_pageWidth}px';
    _vertical.style
      ..height = '${verticalHeight}px'
      ..left = 'calc(50% - ${_pageWidth / 2 + 24}px)';
    _corner.style.left = 'calc(50% - ${_pageWidth / 2 + 24}px)';
    _buildHorizontal(pxPerCm);
    _buildVertical(pxPerCm, verticalHeight);
  }

  /// Sincronização leve com o cursor: re-lê os recuos do parágrafo da
  /// seleção e reposiciona só os marcadores (sem reconstruir os ticks).
  void syncSelection() {
    if (_drag != _RulerDrag.none) return;
    if (_markerFirstLine == null) return;
    final double beforeLeft = _indentLeft;
    final double beforeFirst = _firstLine;
    final double beforeRight = _indentRight;
    _readParagraphIndents();
    if (beforeLeft == _indentLeft &&
        beforeFirst == _firstLine &&
        beforeRight == _indentRight) {
      return;
    }
    _positionMarkers();
  }

  void _readParagraphIndents() {
    _indentLeft = 0;
    _firstLine = 0;
    _indentRight = 0;
    try {
      final dynamic raw = _draw.getRange().getRangeParagraphElementList();
      if (raw is List) {
        for (final dynamic item in raw) {
          if (item is! IElement) continue;
          if (item.paraIndentLeft != null ||
              item.paraIndentFirstLine != null ||
              item.paraIndentRight != null) {
            _indentLeft = (item.paraIndentLeft ?? 0) * _scale;
            _firstLine = (item.paraIndentFirstLine ?? 0) * _scale;
            _indentRight = (item.paraIndentRight ?? 0) * _scale;
            break;
          }
        }
      }
    } catch (_) {
      // A seleção pode estar sendo recomposta durante um render.
    }
  }

  void _buildHorizontal(double pxPerCm) {
    _horizontal.children.clear();
    final double left = _margins[3];
    final double right = _margins[1];
    final double contentWidth =
        (_pageWidth - left - right).clamp(1, _pageWidth);
    _horizontal.children.addAll(<Element>[
      DivElement()
        ..classes.add('ce-ruler__paper')
        ..style.left = '${left}px'
        ..style.width = '${contentWidth}px',
      _marginShade(start: true, size: left),
      _marginShade(start: false, size: right),
    ]);
    _appendTicks(_horizontal,
        extent: _pageWidth, pxPerCm: pxPerCm, zero: left, horizontal: true);
    _markerMarginLeft = _marker(
        'ce-ruler__margin-handle ce-ruler__margin-handle--left',
        'Margem esquerda',
        _RulerDrag.marginLeft);
    _markerMarginRight = _marker(
        'ce-ruler__margin-handle ce-ruler__margin-handle--right',
        'Margem direita',
        _RulerDrag.marginRight);
    _markerFirstLine = _marker('ce-ruler__indent ce-ruler__indent--first',
        'Recuo da primeira linha', _RulerDrag.firstLine);
    _markerHanging = _marker('ce-ruler__indent ce-ruler__indent--hanging',
        'Recuo deslocado', _RulerDrag.hanging);
    _markerLeftBox = _marker('ce-ruler__indent ce-ruler__indent--leftbox',
        'Recuo à esquerda', _RulerDrag.indentLeft);
    _markerRight = _marker('ce-ruler__indent ce-ruler__indent--right',
        'Recuo à direita', _RulerDrag.indentRight);
    _horizontal.children.addAll(<Element>[
      _markerMarginLeft!,
      _markerMarginRight!,
      _markerFirstLine!,
      _markerHanging!,
      _markerLeftBox!,
      _markerRight!,
    ]);
    _positionMarkers();
  }

  void _positionMarkers() {
    final double left = _margins[3];
    final double right = _margins[1];
    void setX(DivElement? marker, double x) {
      marker?.style.left = '${x.clamp(0, _pageWidth)}px';
    }

    setX(_markerMarginLeft, left);
    setX(_markerMarginRight, _pageWidth - right);
    setX(_markerFirstLine, left + _indentLeft + _firstLine);
    setX(_markerHanging, left + _indentLeft);
    setX(_markerLeftBox, left + _indentLeft);
    setX(_markerRight, _pageWidth - right - _indentRight);
  }

  void _buildVertical(double pxPerCm, double extent) {
    _vertical.children.clear();
    final double top = _margins[0];
    final double bottom = _margins[2];
    _vertical.append(DivElement()
      ..classes.add('ce-ruler__paper')
      ..style.top = '${top.clamp(0, extent)}px'
      ..style.height =
          '${(extent - top - bottom).clamp(0, extent).toDouble()}px');
    _appendTicks(_vertical,
        extent: extent, pxPerCm: pxPerCm, zero: top, horizontal: false);
  }

  DivElement _marginShade({required bool start, required double size}) {
    final DivElement shade = DivElement()..classes.add('ce-ruler__margin');
    shade.style
      ..width = '${size}px'
      ..setProperty(start ? 'left' : 'right', '0');
    return shade;
  }

  void _appendTicks(Element ruler,
      {required double extent,
      required double pxPerCm,
      required double zero,
      required bool horizontal}) {
    final double quarter = pxPerCm / 4;
    void appendTick(double position, int distance) {
      final int part = distance % 4;
      final SpanElement tick = SpanElement()
        ..classes.addAll(<String>[
          'ce-ruler__tick',
          horizontal ? 'horizontal' : 'vertical',
          part == 0
              ? 'major'
              : part == 2
                  ? 'half'
                  : 'quarter',
        ])
        ..style.setProperty(horizontal ? 'left' : 'top', '${position}px');
      if (part == 0) {
        final int number = distance ~/ 4;
        if (number > 0) {
          tick.append(SpanElement()
            ..classes.add('ce-ruler__number')
            ..text = '$number');
        }
      }
      ruler.append(tick);
    }

    appendTick(zero.clamp(0, extent).toDouble(), 0);
    for (int distance = 1;; distance++) {
      final double position = zero + distance * quarter;
      if (position > extent) break;
      appendTick(position, distance);
    }
    for (int distance = 1;; distance++) {
      final double position = zero - distance * quarter;
      if (position < 0) break;
      appendTick(position, distance);
    }
  }

  DivElement _marker(String classes, String title, _RulerDrag drag) {
    final DivElement marker = DivElement()
      ..classes.addAll(classes.split(' '))
      ..title = title;
    if (drag != _RulerDrag.none) {
      marker.dataset['drag'] = drag.name;
    }
    return marker;
  }

  void _startDrag(MouseEvent event) {
    final EventTarget? target = event.target;
    if (target is! Element) return;
    final Element? marker = target.closest('[data-drag]');
    final String? name = marker?.dataset['drag'];
    if (name == null) return;
    _drag = _RulerDrag.values.firstWhere(
      (_RulerDrag value) => value.name == name,
      orElse: () => _RulerDrag.none,
    );
    if (_drag == _RulerDrag.none) return;
    event
      ..preventDefault()
      ..stopPropagation();
    root.classes.add('is-dragging');
    _showGuide(event.client.x.toDouble());
  }

  void _showGuide(double clientX) {
    final Rectangle<num> bounds = _horizontal.getBoundingClientRect();
    final double top = bounds.bottom.toDouble();
    final DivElement guide =
        _guide ??= DivElement()..classes.add('ce-ruler-guide');
    guide.style
      ..top = '${top}px'
      ..height = '${(window.innerHeight ?? 800) - top}px'
      ..left = '${clientX}px';
    if (guide.parent == null) {
      document.body?.append(guide);
    }
  }

  void _hideGuide() {
    _guide?.remove();
    _guide = null;
  }

  void _handleDrag(MouseEvent event) {
    if (_drag == _RulerDrag.none) return;
    final Rectangle<num> bounds = _horizontal.getBoundingClientRect();
    final double x =
        (event.client.x - bounds.left).clamp(0, _pageWidth).toDouble();
    final double minContent = 48 * _scale;
    switch (_drag) {
      case _RulerDrag.marginLeft:
        _margins[3] =
            x.clamp(0, _pageWidth - _margins[1] - minContent).toDouble();
      case _RulerDrag.marginRight:
        _margins[1] = (_pageWidth - x)
            .clamp(0, _pageWidth - _margins[3] - minContent)
            .toDouble();
      case _RulerDrag.indentLeft:
        // Caixa: move recuo esquerdo mantendo o delta da 1ª linha.
        _indentLeft =
            (x - _margins[3]).clamp(0, _pageWidth - _margins[1]).toDouble();
      case _RulerDrag.hanging:
        // △: muda o recuo das linhas de continuação mantendo a 1ª linha
        // fixa no lugar (o delta compensa), como no Word.
        final double firstLineAbs = _indentLeft + _firstLine;
        _indentLeft =
            (x - _margins[3]).clamp(0, _pageWidth - _margins[1]).toDouble();
        _firstLine = firstLineAbs - _indentLeft;
      case _RulerDrag.firstLine:
        _firstLine = (x - _margins[3] - _indentLeft)
            .clamp(-_indentLeft, _pageWidth - _margins[1])
            .toDouble();
      case _RulerDrag.indentRight:
        _indentRight = (_pageWidth - _margins[1] - x)
            .clamp(0, _pageWidth - _margins[1] - _margins[3] - minContent)
            .toDouble();
      case _RulerDrag.none:
        return;
    }
    _showGuide(event.client.x.toDouble());
    _positionMarkers();
  }

  void _finishDrag(MouseEvent _) {
    if (_drag == _RulerDrag.none) return;
    final _RulerDrag completed = _drag;
    _drag = _RulerDrag.none;
    root.classes.remove('is-dragging');
    _hideGuide();
    if (completed == _RulerDrag.marginLeft ||
        completed == _RulerDrag.marginRight) {
      final List<double> visual =
          _margins.map((double value) => value / _scale).toList();
      final PaperDirection? direction = _draw.getOptions().paperDirection;
      _command.executeSetPaperMargin(direction == PaperDirection.horizontal
          ? <double>[visual[3], visual[0], visual[1], visual[2]]
          : visual);
    } else {
      _command.executeParagraphIndent(
          _indentLeft / _scale, _firstLine / _scale, _indentRight / _scale);
    }
    window.requestAnimationFrame((_) => refresh());
  }

  void setVisible(bool visible) {
    root.style.display = visible ? '' : 'none';
    if (visible) window.requestAnimationFrame((_) => refresh());
  }

  @override
  void dispose() {
    _hideGuide();
    super.dispose();
  }
}
