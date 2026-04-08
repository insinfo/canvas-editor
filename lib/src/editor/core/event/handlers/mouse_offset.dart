import 'dart:html' as html;
import 'dart:math';

Point<double> getMouseOffset(dynamic evt) {
  if (evt is html.MouseEvent) {
    final Point<num> offset = evt.offset;
    return Point<double>(offset.x.toDouble(), offset.y.toDouble());
  }

  final html.MouseEvent? mouseEvent = evt is html.MouseEvent ? evt : null;
  final html.Element? element = _resolveTargetElement(evt);
  if (mouseEvent != null && element != null) {
    final Rectangle<num> rect = element.getBoundingClientRect();
    return Point<double>(
      mouseEvent.client.x.toDouble() - rect.left.toDouble(),
      mouseEvent.client.y.toDouble() - rect.top.toDouble(),
    );
  }

  return const Point<double>(0, 0);
}

html.Element? _resolveTargetElement(dynamic evt) {
  if (evt is! html.Event) {
    return null;
  }
  final dynamic target = evt.target;
  if (target is html.Element) {
    return target;
  }
  final dynamic currentTarget = evt.currentTarget;
  if (currentTarget is html.Element) {
    return currentTarget;
  }
  return null;
}
