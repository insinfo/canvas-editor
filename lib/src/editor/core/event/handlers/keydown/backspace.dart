import 'dart:html';

import '../../../../dataset/constant/common.dart';
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

void _backspaceHideElement(dynamic host) {
  final dynamic draw = host.getDraw();
  final dynamic rangeManager = draw.getRange();
  final IRange range = rangeManager.getRange() as IRange;
  final List<IElement> elementList =
      (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];

  if (range.startIndex < 0 || range.startIndex >= elementList.length) {
    return;
  }
  if (!_isHiddenElement(elementList[range.startIndex])) {
    return;
  }

  var index = range.startIndex;
  while (index > 0) {
    final IElement element = elementList[index];
    int? newIndex;
    if (element.controlId != null) {
      newIndex = (draw.getControl().removeControl(index) as num?)?.toInt();
      if (newIndex != null) {
        index = newIndex;
      }
    } else {
      draw.spliceElementList(elementList, index, 1);
      newIndex = index - 1;
      index -= 1;
    }

    if (newIndex == null || newIndex < 0 || newIndex >= elementList.length) {
      break;
    }

    final IElement nextElement = elementList[newIndex];
    if (!_isHiddenElement(nextElement)) {
      if (newIndex != 0) {
        range
          ..startIndex = newIndex
          ..endIndex = newIndex;
        rangeManager.replaceRange(range);
        final dynamic position = draw.getPosition();
        final List<IElementPosition> positionList =
            (position.getPositionList() as List?)?.cast<IElementPosition>() ??
                <IElementPosition>[];
        if (newIndex >= 0 && newIndex < positionList.length) {
          position.setCursorPosition(positionList[newIndex]);
        }
      }
      break;
    }
  }
}

void backspace(KeyboardEvent evt, dynamic host) {
  final dynamic draw = host.getDraw();
  if (draw.isReadonly() == true) {
    return;
  }

  final dynamic rangeManager = draw.getRange();
  if (rangeManager.getIsCanInput() != true) {
    return;
  }

  if (rangeManager.getIsCollapsed() == true) {
    _backspaceHideElement(host);
  }

  final IRange range = rangeManager.getRange() as IRange;
  final dynamic control = draw.getControl();
  final int startIndex = range.startIndex;
  final int endIndex = range.endIndex;
  final bool isCrossRowCol = range.isCrossRowCol == true;
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
      control.getIsRangeCanCaptureEvent() == true) {
    curIndex = (control.keydown(evt) as num?)?.toInt();
    if (curIndex != null) {
      control.emitControlContentChange();
    }
  } else {
    final dynamic position = draw.getPosition();
    final IElementPosition? cursorPosition =
        position.getCursorPosition() as IElementPosition?;
    if (cursorPosition == null) {
      return;
    }
    final int index = cursorPosition.index;
    final bool isCollapsed = rangeManager.getIsCollapsed() == true;
    final List<IElement> elementList =
        (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];

    if (isCollapsed && index == 0 && elementList.isNotEmpty) {
      final IElement firstElement = elementList[index];
      if (firstElement.value == ZERO) {
        final dynamic listParticle = draw.getListParticle();
        listParticle?.unsetList();
        evt.preventDefault();
        return;
      }
    }

    if (isCollapsed && startIndex >= 0 && startIndex < elementList.length) {
      final IElement startElement = elementList[startIndex];
      if (startElement.rowFlex != null && startElement.value == ZERO) {
        final List<IElement>? rowFlexElementList =
            (rangeManager.getRangeRowElementList() as List?)?.cast<IElement>();
        if (rowFlexElementList != null) {
          final IElement? preElement =
              startIndex - 1 >= 0 ? elementList[startIndex - 1] : null;
          for (final IElement element in rowFlexElementList) {
            element.rowFlex = preElement?.rowFlex;
          }
        }
      }
    }

    if (!isCollapsed) {
      final int deleteCount = endIndex - startIndex;
      if (deleteCount > 0) {
        draw.spliceElementList(
          elementList,
          startIndex + 1,
          deleteCount,
        );
      }
    } else if (index >= 0 && index < elementList.length) {
      draw.spliceElementList(elementList, index, 1);
    }

    curIndex = isCollapsed ? index - 1 : startIndex;
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
