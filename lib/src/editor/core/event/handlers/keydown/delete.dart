import 'dart:html';

import '../../../../interface/draw.dart';
import '../../../../interface/element.dart';
import '../../../../interface/range.dart';

bool _isHiddenElement(IElement? element) {
  if (element == null) {
    return false;
  }
  return element.hide == true ||
      element.control?.hide == true ||
      element.area?.hide == true;
}

void _deleteHideElement(dynamic host) {
  final dynamic draw = host.getDraw();
  final dynamic rangeManager = draw.getRange();
  final IRange range = rangeManager.getRange() as IRange;
  final List<IElement> elementList =
      (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];

  final int index = range.startIndex + 1;
  if (index < 0 || index >= elementList.length) {
    return;
  }
  if (!_isHiddenElement(elementList[index])) {
    return;
  }

  var pointer = index;
  while (pointer < elementList.length) {
    final IElement element = elementList[pointer];
    int? newIndex;
    if (element.controlId != null) {
      newIndex = (draw.getControl().removeControl(pointer) as num?)?.toInt();
    } else {
      draw.spliceElementList(elementList, pointer, 1);
      newIndex = pointer;
    }

    if (newIndex == null || newIndex < 0 || newIndex >= elementList.length) {
      break;
    }

    final IElement nextElement = elementList[newIndex];
    if (!_isHiddenElement(nextElement)) {
      break;
    }
    pointer = newIndex;
  }
}

void del(KeyboardEvent evt, dynamic host) {
  final dynamic draw = host.getDraw();
  if (draw.isReadonly() == true) {
    return;
  }

  final dynamic rangeManager = draw.getRange();
  if (rangeManager.getIsCanInput() != true) {
    return;
  }

  final IRange range = rangeManager.getRange() as IRange;
  final int startIndex = range.startIndex;
  final int endIndex = range.endIndex;
  final bool isCrossRowCol = range.isCrossRowCol == true;
  final List<IElement> elementList =
      (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];
  final dynamic control = draw.getControl();

  if (rangeManager.getIsCollapsed() == true) {
    _deleteHideElement(host);
  }

  int? curIndex;
  if (isCrossRowCol) {
    final dynamic rowCol = draw.getTableParticle().getRangeRowCol();
    if (rowCol == null) {
      return;
    }
    var isDeleted = false;
    for (final dynamic row in rowCol as List<dynamic>) {
      if (row is! List) {
        continue;
      }
      for (final dynamic col in row) {
        final dynamic colValueRaw = col is Map ? col['value'] : col?.value;
        final List<IElement>? colValue =
            (colValueRaw as List?)?.cast<IElement>();
        if (colValue != null && colValue.length > 1) {
          draw.spliceElementList(colValue, 1, colValue.length - 1);
          isDeleted = true;
        }
      }
    }
    curIndex = isDeleted ? 0 : null;
  } else if (control != null &&
      control.getActiveControl() != null &&
      control.getIsRangeWithinControl() == true) {
    curIndex = (control.keydown(evt) as num?)?.toInt();
    if (curIndex != null) {
      control.emitControlContentChange();
    }
  } else if (endIndex + 1 < elementList.length &&
      elementList[endIndex + 1].controlId != null) {
    curIndex = (control?.removeControl(endIndex + 1) as num?)?.toInt();
  } else {
    final dynamic position = draw.getPosition();
    final IElementPosition? cursorPosition =
        position.getCursorPosition() as IElementPosition?;
    if (cursorPosition == null) {
      return;
    }
    final int index = cursorPosition.index;
    final dynamic positionContext = position.getPositionContext();
    if (positionContext?.isDirectHit == true &&
        positionContext?.isImage == true) {
      draw.spliceElementList(elementList, index, 1);
      curIndex = index - 1;
    } else {
      final bool isCollapsed = rangeManager.getIsCollapsed() == true;
      if (!isCollapsed) {
        draw.spliceElementList(
          elementList,
          startIndex + 1,
          endIndex - startIndex,
        );
      } else {
        if (index + 1 >= elementList.length) {
          return;
        }
        draw.spliceElementList(elementList, index + 1, 1);
      }
      curIndex = isCollapsed ? index : startIndex;
    }
  }

  final dynamic globalEvent = draw.getGlobalEvent();
  globalEvent?.setCanvasEventAbility();

  if (curIndex == null) {
    rangeManager.setRange(startIndex, startIndex);
    draw.render(
      IDrawOption(
        curIndex: startIndex,
        isSubmitHistory: false,
      ),
    );
  } else {
    rangeManager.setRange(curIndex, curIndex);
    draw.render(IDrawOption(curIndex: curIndex));
  }
}
