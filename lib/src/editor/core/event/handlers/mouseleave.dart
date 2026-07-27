import 'package:canvas_text_editor/src/dom/dom.dart' as html;

void mouseleave(dynamic evt, dynamic host) {
  final dynamic draw = host.getDraw();
  final dynamic options = draw.getOptions();
  if (options == null || options.pageOuterSelectionDisable != true) {
    return;
  }

  // Acesso tipado: pageContainer e evt são objetos JS — dispatch dinâmico
  // neles falha no dart2js.
  final Object? container = draw.getPageContainer();
  if (!html.jsIsElement(container) || !html.jsIsMouseEvent(evt)) {
    return;
  }
  final html.DOMRect rect =
      (container as html.Element).getBoundingClientRect();
  final html.MouseEvent mouse = evt as html.MouseEvent;

  final num evtX = mouse.clientX;
  final num evtY = mouse.clientY;
  final num rectX = rect.x;
  final num rectY = rect.y;
  final num rectWidth = rect.width;
  final num rectHeight = rect.height;

  final bool isInsideHorizontal = evtX >= rectX && evtX <= rectX + rectWidth;
  final bool isInsideVertical = evtY >= rectY && evtY <= rectY + rectHeight;
  if (isInsideHorizontal && isInsideVertical) {
    return;
  }

  host.setIsAllowSelection(false);
}
