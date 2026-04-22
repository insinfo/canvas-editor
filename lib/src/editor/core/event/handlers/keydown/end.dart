import 'dart:html';

import '../../../../interface/draw.dart';
import '../../../../interface/element.dart';
import '../../../../interface/range.dart';

void end(KeyboardEvent evt, dynamic host) {
  final dynamic draw = host.getDraw();
  if (draw.isReadonly() == true) {
    return;
  }

  final dynamic position = draw.getPosition();
  final IElementPosition? cursorPosition =
      position.getCursorPosition() as IElementPosition?;
  if (cursorPosition == null) {
    return;
  }

  final dynamic rangeManager = draw.getRange();
  final IRange range = rangeManager.getRange() as IRange;
  final int startIndex = range.startIndex;
  final int endIndex = range.endIndex;
  final List<IElementPosition> positionList =
      (position.getPositionList() as List?)?.cast<IElementPosition>() ??
          <IElementPosition>[];
  if (positionList.isEmpty) {
    return;
  }

  IElementPosition anchorPosition = cursorPosition;
  if (evt.shiftKey && startIndex != endIndex) {
    if (startIndex == cursorPosition.index) {
      if (endIndex >= 0 && endIndex < positionList.length) {
        anchorPosition = positionList[endIndex];
      }
    } else if (startIndex >= 0 && startIndex < positionList.length) {
      anchorPosition = positionList[startIndex];
    }
  }

  var rowNo = anchorPosition.rowNo;
  final int? hitLineStartIndex = draw.getCursor()?.getHitLineStartIndex() as int?;
  if (hitLineStartIndex != null) {
    rowNo++;
  }

  var lineEndIndex = anchorPosition.index;
  for (var i = anchorPosition.index + 1; i < positionList.length; i++) {
    if (positionList[i].rowNo != rowNo) {
      break;
    }
    lineEndIndex = i;
  }

  var anchorStart = lineEndIndex;
  var anchorEnd = lineEndIndex;

  if (evt.shiftKey) {
    if (startIndex != endIndex) {
      if (startIndex == cursorPosition.index) {
        anchorStart = startIndex;
        anchorEnd = lineEndIndex;
      } else {
        anchorStart = lineEndIndex;
        anchorEnd = endIndex;
      }
    } else {
      anchorStart = startIndex;
      anchorEnd = lineEndIndex;
    }
  }

  if (anchorStart > anchorEnd) {
    final int temp = anchorStart;
    anchorStart = anchorEnd;
    anchorEnd = temp;
  }

  rangeManager.setRange(anchorStart, anchorEnd);

  final bool isCollapsed = anchorStart == anchorEnd;
  draw.render(
    IDrawOption(
      curIndex: isCollapsed ? anchorStart : null,
      isSetCursor: isCollapsed,
      isSubmitHistory: false,
      isCompute: false,
    ),
  );

  evt.preventDefault();
}