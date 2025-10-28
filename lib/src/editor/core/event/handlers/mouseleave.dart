void mouseleave(dynamic evt, dynamic host) {
  final dynamic draw = host.getDraw();
  final dynamic options = draw.getOptions();
  if (options == null || options.pageOuterSelectionDisable != true) {
    return;
  }

  final dynamic pageContainer = draw.getPageContainer();
  if (pageContainer == null) {
    return;
  }

  final dynamic rect = pageContainer.getBoundingClientRect();
  if (rect == null) {
    return;
  }

  final num evtX = (evt.x as num?) ?? 0;
  final num evtY = (evt.y as num?) ?? 0;
  final num rectX = (rect.x as num?) ?? 0;
  final num rectY = (rect.y as num?) ?? 0;
  final num rectWidth = (rect.width as num?) ?? 0;
  final num rectHeight = (rect.height as num?) ?? 0;

  final bool isInsideHorizontal = evtX >= rectX && evtX <= rectX + rectWidth;
  final bool isInsideVertical = evtY >= rectY && evtY <= rectY + rectHeight;
  if (isInsideHorizontal && isInsideVertical) {
    return;
  }

  host.setIsAllowSelection(false);
}
