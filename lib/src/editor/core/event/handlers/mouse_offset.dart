import 'dart:math';

import 'package:canvas_text_editor/src/dom/dom.dart' as html;

Point<double> getMouseOffset(dynamic evt) {
  if (html.jsIsMouseEvent(evt)) {
    final Point<num> offset = (evt as html.MouseEvent).offset;
    return Point<double>(offset.x.toDouble(), offset.y.toDouble());
  }

  final html.Element? element = _resolveTargetElement(evt);
  if (element != null && html.jsIsMouseEvent(evt)) {
    final html.MouseEvent mouseEvent = evt as html.MouseEvent;
    final html.DOMRect rect = element.getBoundingClientRect();
    return Point<double>(
      mouseEvent.clientX.toDouble() - rect.left.toDouble(),
      mouseEvent.clientY.toDouble() - rect.top.toDouble(),
    );
  }

  return const Point<double>(0, 0);
}

html.Element? _resolveTargetElement(dynamic evt) {
  if (!html.jsIsEvent(evt)) {
    return null;
  }
  final html.Event event = evt as html.Event;
  final html.Element? target = html.asElement(event.target);
  if (target != null) {
    return target;
  }
  return html.asElement(event.currentTarget);
}
