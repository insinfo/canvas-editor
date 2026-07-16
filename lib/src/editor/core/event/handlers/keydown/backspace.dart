import 'dart:html';

import '../../../../dataset/constant/common.dart';
import '../../../../interface/draw.dart';
import '../../../../interface/element.dart';
import '../../../../interface/range.dart';
import '../../../layout/layout_invalidation.dart';
import '../../../layout/layout_request.dart';

bool _isHiddenElement(IElement? element) {
  if (element == null) {
    return false;
  }
  return element.hide == true ||
      element.control?.hide == true ||
      element.area?.hide == true;
}

List<IElement> _elementListOf(dynamic draw) {
  final dynamic value = draw.getElementList();
  return value is List<IElement>
      ? value
      : (value as List?)?.whereType<IElement>().toList() ?? <IElement>[];
}

bool _backspaceHideElement(dynamic host) {
  final dynamic draw = host.getDraw();
  final dynamic rangeManager = draw.getRange();
  final IRange range = rangeManager.getRange() as IRange;
  final List<IElement> elementList = _elementListOf(draw);

  if (range.startIndex < 0 || range.startIndex >= elementList.length) {
    return false;
  }
  if (!_isHiddenElement(elementList[range.startIndex])) {
    return false;
  }

  draw.flushDeferredHistory();
  if (draw.getHistoryManager().isStackEmpty() == true) {
    draw.submitHistory(range.endIndex);
  }

  var index = range.startIndex;
  var changed = false;
  while (index > 0) {
    final IElement element = elementList[index];
    int? newIndex;
    if (element.controlId != null) {
      newIndex = (draw.getControl().removeControl(index) as num?)?.toInt();
      changed = true;
      if (newIndex != null) {
        index = newIndex;
      }
    } else {
      draw.spliceElementList(elementList, index, 1);
      changed = true;
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
  return changed;
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

  final bool hiddenMutation = rangeManager.getIsCollapsed() == true
      ? _backspaceHideElement(host)
      : false;

  final IRange range = rangeManager.getRange() as IRange;
  final dynamic control = draw.getControl();
  final dynamic activeControl = control?.ensureActiveControl();
  final int startIndex = range.startIndex;
  final int endIndex = range.endIndex;
  final bool isCrossRowCol = range.isCrossRowCol == true;
  int? curIndex;
  LayoutInvalidation? mutationInvalidation;
  var rowFlexMutation = false;

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
      activeControl != null &&
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
    final List<IElement> elementList = _elementListOf(draw);

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
          draw.flushDeferredHistory();
          if (draw.getHistoryManager().isStackEmpty() == true) {
            draw.submitHistory(range.endIndex);
          }
          final IElement? preElement =
              startIndex - 1 >= 0 ? elementList[startIndex - 1] : null;
          for (final IElement element in rowFlexElementList) {
            element.rowFlex = preElement?.rowFlex;
          }
          rowFlexMutation = true;
        }
      }
    }

    curIndex = isCollapsed ? index - 1 : startIndex;
    final int mutationStart = isCollapsed ? index : startIndex + 1;
    final int mutationDeleteCount = isCollapsed ? 1 : endIndex - startIndex;
    if (mutationDeleteCount > 0 &&
        mutationStart >= 0 &&
        mutationStart + mutationDeleteCount <= elementList.length) {
      mutationInvalidation = draw.applyTextMutation(
        elementList: elementList,
        start: mutationStart,
        deleteCount: mutationDeleteCount,
        replacement: const <IElement>[],
        curIndex: curIndex,
        mergeKey: 'backspace',
        forceSnapshotHistory: hiddenMutation || rowFlexMutation,
      ) as LayoutInvalidation?;
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
    if (mutationInvalidation != null) {
      draw.renderUpdate(
        LayoutRequest(
          invalidation: mutationInvalidation,
          curIndex: curIndex,
          notifyContentChange: true,
        ),
      );
    } else {
      draw.render(IDrawOption(
        curIndex: curIndex,
        isSubmitHistoryDeferred: true,
        fastLayoutIndex: curIndex,
      ));
    }
  }
}
