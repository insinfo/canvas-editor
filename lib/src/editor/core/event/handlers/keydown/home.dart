import 'dart:html';

import '../../../../dataset/constant/common.dart';
import '../../../cursor/cursor.dart';
import '../../../../interface/draw.dart';
import '../../../../interface/element.dart';
import '../../../../interface/range.dart';

void home(KeyboardEvent evt, dynamic host) {
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

  final int rowNo = anchorPosition.rowNo;
  var lineStartIndex = anchorPosition.index;
  for (var i = anchorPosition.index - 1; i >= 0; i--) {
    if (positionList[i].rowNo != rowNo) {
      break;
    }
    lineStartIndex = i;
  }

  final bool isNonZero =
      lineStartIndex >= 0 && positionList[lineStartIndex].value != ZERO;
  if (isNonZero) {
    lineStartIndex--;
  }

  var anchorStart = lineStartIndex;
  var anchorEnd = lineStartIndex;

  if (evt.shiftKey) {
    if (startIndex != endIndex) {
      if (startIndex == cursorPosition.index) {
        anchorStart = startIndex;
        anchorEnd = lineStartIndex;
      } else {
        anchorStart = lineStartIndex;
        anchorEnd = endIndex;
      }
    } else {
      anchorStart = lineStartIndex;
      anchorEnd = startIndex;
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

  if (isNonZero) {
    draw.getCursor()?.drawCursor(
      IDrawCursorOption(hitLineStartIndex: lineStartIndex + 1),
    );
  }

  evt.preventDefault();
}