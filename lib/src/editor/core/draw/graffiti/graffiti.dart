import 'dart:async';
import 'dart:html';

import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/graffiti.dart';
import '../draw.dart';

class Graffiti {
  Graffiti(this._draw, [List<IGraffitiData>? data])
      : _options = _draw.getOptions(),
        _pageContainer = _draw.getPageContainer(),
        _data = _cloneGraffitiData(data) {
    _register();
  }

  final Draw _draw;
  final IEditorOption _options;
  final DivElement _pageContainer;
  List<IGraffitiData> _data;
  bool _isDrawing = false;
  IGraffitiStroke? _startStroke;
  Point<double>? _startPoint;
  final List<StreamSubscription<Event>> _subscriptions =
      <StreamSubscription<Event>>[];

  void _register() {
    _subscriptions.add(
      _pageContainer.onMouseDown.listen((event) => _start(event)),
    );
    _subscriptions.add(
      _pageContainer.onMouseUp.listen((event) => _stop()),
    );
    _subscriptions.add(
      _pageContainer.onMouseLeave.listen((event) => _stop()),
    );
    _subscriptions.add(
      _pageContainer.onMouseMove.listen((event) => _drawing(event)),
    );
  }

  void dispose() {
    for (final StreamSubscription<Event> subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  List<IGraffitiData> getValue() => _cloneGraffitiData(_data);

  void setValue(List<IGraffitiData>? data) {
    _data = _cloneGraffitiData(data);
  }

  void compute() {
    final int pageSize = _draw.getPageRowList().length;
    for (int index = _data.length - 1; index >= 0; index--) {
      if (_data[index].pageNo > pageSize - 1) {
        _data.removeAt(index);
      }
    }
  }

  void clear() {
    _data = <IGraffitiData>[];
  }

  void render(CanvasRenderingContext2D ctx, int pageNo) {
    List<IGraffitiStroke>? strokes;
    for (final IGraffitiData item in _data) {
      if (item.pageNo == pageNo) {
        strokes = item.strokes;
        break;
      }
    }
    if (strokes == null || strokes.isEmpty) {
      return;
    }
    final String defaultLineColor =
        _options.graffiti?.defaultLineColor ?? '#000000';
    final num defaultLineWidth = _options.graffiti?.defaultLineWidth ?? 1;
    final double scale = (_options.scale ?? 1).toDouble();
    ctx.save();
    for (final IGraffitiStroke stroke in strokes) {
      if (stroke.points.length < 4) {
        continue;
      }
      ctx.beginPath();
      ctx.strokeStyle = stroke.lineColor ?? defaultLineColor;
      ctx.lineWidth = (stroke.lineWidth ?? defaultLineWidth).toDouble() * scale;
      ctx.moveTo(stroke.points[0] * scale, stroke.points[1] * scale);
      for (int pointIndex = 2; pointIndex < stroke.points.length; pointIndex += 2) {
        ctx.lineTo(
          stroke.points[pointIndex] * scale,
          stroke.points[pointIndex + 1] * scale,
        );
      }
      ctx.stroke();
    }
    ctx.restore();
  }

  void _start(MouseEvent event) {
    if (!_draw.isGraffitiMode()) {
      return;
    }
    final String? pageIndex = (event.target as Element?)?.dataset['index'];
    final int? parsedPageIndex =
        pageIndex != null ? int.tryParse(pageIndex) : null;
    if (parsedPageIndex != null) {
      _draw.setPageNo(parsedPageIndex);
    }
    final Point<double> offset = _resolveOffset(event);
    final double scale = (_options.scale ?? 1).toDouble();
    _isDrawing = true;
    _startPoint = offset;
    _startStroke = IGraffitiStroke(
      lineColor: _options.graffiti?.defaultLineColor,
      lineWidth: _options.graffiti?.defaultLineWidth,
      points: <double>[offset.x / scale, offset.y / scale],
    );
  }

  void _stop() {
    _isDrawing = false;
    _startStroke = null;
    _startPoint = null;
  }

  void _drawing(MouseEvent event) {
    if (!_isDrawing || !_draw.isGraffitiMode()) {
      return;
    }
    final Point<double> offset = _resolveOffset(event);
    final Point<double>? startPoint = _startPoint;
    const double minDistance = 2;
    if (_startStroke != null &&
        startPoint != null &&
        (offset.x - startPoint.x).abs() < minDistance &&
        (offset.y - startPoint.y).abs() < minDistance) {
      return;
    }

    final int pageNo = _draw.getPageNo();
    IGraffitiData? currentValue;
    for (final IGraffitiData item in _data) {
      if (item.pageNo == pageNo) {
        currentValue = item;
        break;
      }
    }
    if (_startStroke != null) {
      currentValue ??= IGraffitiData(pageNo: pageNo, strokes: <IGraffitiStroke>[]);
      if (!_data.contains(currentValue)) {
        _data.add(currentValue);
      }
      currentValue.strokes.add(_startStroke!);
      _startStroke = null;
    }
    if (currentValue == null || currentValue.strokes.isEmpty) {
      return;
    }

    final double scale = (_options.scale ?? 1).toDouble();
    final List<double> points = currentValue.strokes.last.points;
    points.addAll(<double>[offset.x / scale, offset.y / scale]);
    _draw.render(
      IDrawOption(
        isCompute: false,
        isSetCursor: false,
        isSubmitHistory: false,
      ),
    );
  }

  Point<double> _resolveOffset(MouseEvent event) {
    final Element? target = event.target as Element?;
    if (target != null) {
      final Rectangle<num> rect = target.getBoundingClientRect();
      return Point<double>(
        event.client.x.toDouble() - rect.left.toDouble(),
        event.client.y.toDouble() - rect.top.toDouble(),
      );
    }
    final Point<num> offset = event.offset;
    return Point<double>(offset.x.toDouble(), offset.y.toDouble());
  }
}

List<IGraffitiData> _cloneGraffitiData(List<IGraffitiData>? source) {
  if (source == null || source.isEmpty) {
    return <IGraffitiData>[];
  }
  return source
      .map(
        (IGraffitiData item) => IGraffitiData(
          pageNo: item.pageNo,
          strokes: item.strokes
              .map(
                (IGraffitiStroke stroke) => IGraffitiStroke(
                  lineColor: stroke.lineColor,
                  lineWidth: stroke.lineWidth,
                  points: List<double>.from(stroke.points),
                ),
              )
              .toList(growable: false),
        ),
      )
      .toList(growable: false);
}