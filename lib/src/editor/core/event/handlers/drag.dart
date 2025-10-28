import 'dart:html' as html;

import '../../../dataset/enum/common.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/cursor.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/position.dart';
import '../../../interface/range.dart';
import '../../../utils/index.dart';
import '../../cursor/cursor.dart';

void dragover(dynamic evt, dynamic host) {
  final dynamic draw = host.getDraw();
  if (draw.isReadonly() == true) {
    return;
  }

  if (evt is html.Event) {
    evt.preventDefault();
  } else {
    try {
      evt?.preventDefault();
    } catch (_) {
      // ignore non-standard preventDefault access
    }
  }

  final html.Element? target = evt is html.Event
      ? evt.target as html.Element?
      : evt?.target as html.Element?;
  if (target == null) {
    return;
  }

  final html.Element? pageContainer = draw.getPageContainer() as html.Element?;
  if (pageContainer == null) {
    return;
  }

  final html.Element? editorRegion = findParent(
    target,
    (html.Element element) => identical(element, pageContainer),
    true,
  );
  if (editorRegion == null) {
    return;
  }

  final String? pageIndexValue = target.dataset['index'];
  if (pageIndexValue != null) {
    final int? pageIndex = int.tryParse(pageIndexValue);
    if (pageIndex != null) {
      draw.setPageNo(pageIndex);
    }
  }

  double offsetX;
  double offsetY;
  if (evt is html.MouseEvent) {
    offsetX = evt.offset.x.toDouble();
    offsetY = evt.offset.y.toDouble();
  } else {
    offsetX = (evt?.offsetX as num?)?.toDouble() ?? 0;
    offsetY = (evt?.offsetY as num?)?.toDouble() ?? 0;
  }

  final dynamic position = draw.getPosition();
  final ICurrentPosition? positionContext = position.adjustPositionContext(
    IGetPositionByXYPayload(x: offsetX, y: offsetY),
  ) as ICurrentPosition?;
  if (positionContext == null) {
    return;
  }

  final List<IElementPosition> positionList =
      (position.getPositionList() as List?)?.cast<IElementPosition>() ??
          <IElementPosition>[];
  final int index = positionContext.index;
  final bool isTable = positionContext.isTable == true;
  final int? tdValueIndex = positionContext.tdValueIndex;
  final int curIndex = isTable ? (tdValueIndex ?? -1) : index;
  if (curIndex < 0 || curIndex >= positionList.length) {
    return;
  }

  final dynamic rangeManager = draw.getRange();
  rangeManager.setRange(curIndex, curIndex);
  position.setCursorPosition(positionList[curIndex]);

  final IEditorOption editorOptions = draw.getOptions() as IEditorOption;
  final ICursorOption? cursorOption = editorOptions.cursor;
  final bool isDragFloatImageDisabled =
      cursorOption?.dragFloatImageDisabled == true;

  if (isDragFloatImageDisabled) {
    final IRange? cacheRange = host.cacheRange as IRange?;
    final List<IElement> cacheElementList =
        (host.cacheElementList as List?)?.cast<IElement>() ?? <IElement>[];
    final int dragIndex = cacheRange?.startIndex ?? -1;
    if (dragIndex >= 0 && dragIndex < cacheElementList.length) {
      final IElement dragElement = cacheElementList[dragIndex];
      if (dragElement.type == ElementType.image &&
          (dragElement.imgDisplay == ImageDisplay.floatTop ||
              dragElement.imgDisplay == ImageDisplay.floatBottom ||
              dragElement.imgDisplay == ImageDisplay.surround)) {
        return;
      }
    }
  }

  final dynamic cursor = draw.getCursor();
  cursor.drawCursor(
    IDrawCursorOption(
      width: cursorOption?.dragWidth,
      color: cursorOption?.dragColor,
      isBlink: false,
      isFocus: false,
    ),
  );
}

final Map<String, dynamic> drag = <String, dynamic>{
  'dragover': dragover,
};
