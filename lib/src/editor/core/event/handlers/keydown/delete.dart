import 'dart:html';

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

bool _deleteHideElement(dynamic host) {
  final dynamic draw = host.getDraw();
  final dynamic rangeManager = draw.getRange();
  final IRange range = rangeManager.getRange() as IRange;
  final List<IElement> elementList = _elementListOf(draw);

  final int index = range.startIndex + 1;
  if (index < 0 || index >= elementList.length) {
    return false;
  }
  if (!_isHiddenElement(elementList[index])) {
    return false;
  }

  draw.flushDeferredHistory();
  if (draw.getHistoryManager().isStackEmpty() == true) {
    draw.submitHistory(range.endIndex);
  }

  var pointer = index;
  var changed = false;
  while (pointer < elementList.length) {
    final IElement element = elementList[pointer];
    int? newIndex;
    if (element.controlId != null) {
      newIndex = (draw.getControl().removeControl(pointer) as num?)?.toInt();
      changed = true;
    } else {
      draw.spliceElementList(elementList, pointer, 1);
      changed = true;
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
  return changed;
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
  final List<IElement> elementList = _elementListOf(draw);
  final dynamic control = draw.getControl();
  final dynamic activeControl = control?.ensureActiveControl();

  final bool hiddenMutation =
      rangeManager.getIsCollapsed() == true ? _deleteHideElement(host) : false;

  int? curIndex;
  LayoutInvalidation? mutationInvalidation;
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
      curIndex = isCollapsed ? index : startIndex;
      final int mutationStart = isCollapsed ? index + 1 : startIndex + 1;
      final int mutationDeleteCount = isCollapsed ? 1 : endIndex - startIndex;
      if (mutationStart < 0 ||
          mutationStart + mutationDeleteCount > elementList.length) {
        return;
      }
      mutationInvalidation = draw.applyTextMutation(
        elementList: elementList,
        start: mutationStart,
        deleteCount: mutationDeleteCount,
        replacement: const <IElement>[],
        curIndex: curIndex,
        mergeKey: 'delete',
        forceSnapshotHistory: hiddenMutation,
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
