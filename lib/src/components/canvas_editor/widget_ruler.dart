import 'dart:html';

import '../../editor/core/command/command.dart';
import '../../editor/core/draw/draw.dart';
import '../../editor/dataset/enum/editor.dart';
import '../../editor/interface/element.dart';
import '../core/ui_component.dart';

enum _RulerDrag { none, marginLeft, marginRight, indentLeft, firstLine }

/// Régua de página inspirada no Word/DocumentServer.
///
/// A escala nasce na margem esquerda, usa quartos de centímetro e separa
/// visualmente o papel (cinza) da área editável (branca). Margens e recuos
/// podem ser arrastados sem criar elementos dentro do stage do documento.
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

  void _readParagraphIndents() {
    _indentLeft = 0;
    _firstLine = 0;
    try {
      final dynamic raw = _draw.getRange().getRangeParagraphElementList();
      if (raw is List) {
        for (final dynamic item in raw) {
          if (item is! IElement) continue;
          if (item.paraIndentLeft != null || item.paraIndentFirstLine != null) {
            _indentLeft = (item.paraIndentLeft ?? 0) * _scale;
            _firstLine = (item.paraIndentFirstLine ?? 0) * _scale;
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
    _horizontal.children.addAll(<Element>[
      _marker('ce-ruler__margin-handle ce-ruler__margin-handle--left', left,
          'Margem esquerda', _RulerDrag.marginLeft),
      _marker('ce-ruler__margin-handle ce-ruler__margin-handle--right',
          _pageWidth - right, 'Margem direita', _RulerDrag.marginRight),
      _marker(
          'ce-ruler__indent ce-ruler__indent--first',
          left + _indentLeft + _firstLine,
          'Recuo da primeira linha',
          _RulerDrag.firstLine),
      _marker('ce-ruler__indent ce-ruler__indent--left', left + _indentLeft,
          'Recuo esquerdo', _RulerDrag.indentLeft),
      _marker('ce-ruler__indent ce-ruler__indent--right', _pageWidth - right,
          'Recuo direito', _RulerDrag.none),
    ]);
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

  DivElement _marker(
      String classes, double position, String title, _RulerDrag drag) {
    final DivElement marker = DivElement()
      ..classes.addAll(classes.split(' '))
      ..style.left = '${position.clamp(0, _pageWidth)}px'
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
        _indentLeft =
            (x - _margins[3]).clamp(0, _pageWidth - _margins[1]).toDouble();
      case _RulerDrag.firstLine:
        _firstLine = (x - _margins[3] - _indentLeft)
            .clamp(-_indentLeft, _pageWidth - _margins[1])
            .toDouble();
      case _RulerDrag.none:
        return;
    }
    _buildHorizontal(96 / 2.54 * _scale);
  }

  void _finishDrag(MouseEvent _) {
    if (_drag == _RulerDrag.none) return;
    final _RulerDrag completed = _drag;
    _drag = _RulerDrag.none;
    root.classes.remove('is-dragging');
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
          _indentLeft / _scale, _firstLine / _scale);
    }
    window.requestAnimationFrame((_) => refresh());
  }

  void setVisible(bool visible) {
    root.style.display = visible ? '' : 'none';
    if (visible) window.requestAnimationFrame((_) => refresh());
  }
}
