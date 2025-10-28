import 'dart:html';

import '../../../../dataset/enum/element.dart';
import '../../../../dataset/enum/key_map.dart';
import '../../../../dataset/enum/observer.dart';
import '../../../../interface/draw.dart';
import '../../../../interface/editor.dart';
import '../../../../interface/element.dart';
import '../../../../interface/position.dart';
import '../../../../interface/range.dart';
import '../../../../interface/table/td.dart';
import '../../../cursor/cursor.dart';

int _getNextPositionIndex({
  required List<IElementPosition> positionList,
  required int index,
  required int rowNo,
  required bool isUp,
  required double cursorX,
}) {
  var nextIndex = -1;
  final List<IElementPosition> probablePosition = <IElementPosition>[];
  if (isUp) {
    var p = index - 1;
    while (p >= 0) {
      final IElementPosition position = positionList[p];
      p--;
      if (position.rowNo == rowNo) {
        continue;
      }
      if (probablePosition.isNotEmpty &&
          probablePosition.first.rowNo != position.rowNo) {
        break;
      }
      probablePosition.insert(0, position);
    }
  } else {
    var p = index + 1;
    while (p < positionList.length) {
      final IElementPosition position = positionList[p];
      p++;
      if (position.rowNo == rowNo) {
        continue;
      }
      if (probablePosition.isNotEmpty &&
          probablePosition.first.rowNo != position.rowNo) {
        break;
      }
      probablePosition.add(position);
    }
  }

  for (var p = 0; p < probablePosition.length; p++) {
    final IElementPosition nextPosition = probablePosition[p];
    final List<double>? leftTop = nextPosition.coordinate['leftTop'];
    final List<double>? rightTop = nextPosition.coordinate['rightTop'];
    final double? nextLeftX =
        leftTop != null && leftTop.isNotEmpty ? leftTop[0] : null;
    final double? nextRightX =
        rightTop != null && rightTop.isNotEmpty ? rightTop[0] : null;
    if (p == probablePosition.length - 1) {
      nextIndex = nextPosition.index;
    }
    if (nextLeftX == null || nextRightX == null) {
      continue;
    }
    if (cursorX < nextLeftX || cursorX > nextRightX) {
      continue;
    }
    nextIndex = nextPosition.index;
    break;
  }

  return nextIndex;
}

void updown(KeyboardEvent evt, dynamic host) {
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
  List<IElementPosition> positionList =
      (position.getPositionList() as List?)?.cast<IElementPosition>() ??
          <IElementPosition>[];

  final bool isUp = evt.key == KeyMap.up.value;
  var anchorStartIndex = -1;
  var anchorEndIndex = -1;

  final IPositionContext positionContext =
      position.getPositionContext() as IPositionContext;
  final int rowCount = (draw.getRowCount() as num?)?.toInt() ?? 0;
  if (!evt.shiftKey &&
      positionContext.isTable == true &&
      ((isUp && cursorPosition.rowIndex == 0) ||
          (!isUp && rowCount > 0 && cursorPosition.rowIndex == rowCount - 1))) {
    final int? tableIndex = positionContext.index;
    final int? trIndex = positionContext.trIndex;
    final int? tdIndex = positionContext.tdIndex;
    final String? tableId = positionContext.tableId;

    if (tableIndex == null || trIndex == null || tdIndex == null) {
      return;
    }

    if (isUp) {
      if (trIndex == 0) {
        position.setPositionContext(IPositionContext(isTable: false));
        anchorStartIndex = tableIndex - 1;
        anchorEndIndex = anchorStartIndex;
        draw.getTableTool()?.dispose();
      } else {
        int preTrIndex = -1;
        int preTdIndex = -1;
        final List<IElement> originalElementList =
            (draw.getOriginalElementList() as List?)?.cast<IElement>() ??
                <IElement>[];
        if (tableIndex < 0 || tableIndex >= originalElementList.length) {
          return;
        }
        final IElement tableElement = originalElementList[tableIndex];
        final List<ITr>? trList = tableElement.trList;
        if (trList == null || trList.isEmpty) {
          return;
        }
        final List<ITd> currentTdList = trList[trIndex].tdList;
        final int? curTdColIndex = currentTdList[tdIndex].colIndex;
        if (curTdColIndex == null) {
          return;
        }
        outer:
        for (var r = trIndex - 1; r >= 0; r--) {
          final ITr tr = trList[r];
          final List<ITd> tdList = tr.tdList;
          for (var d = 0; d < tdList.length; d++) {
            final ITd td = tdList[d];
            final int? tdColIndex = td.colIndex;
            if (tdColIndex == null) {
              continue;
            }
            final int tdColEnd = tdColIndex + td.colspan - 1;
            if (tdColIndex == curTdColIndex ||
                (tdColEnd >= curTdColIndex && tdColIndex <= curTdColIndex)) {
              preTrIndex = r;
              preTdIndex = d;
              break outer;
            }
          }
        }
        if (preTrIndex < 0 || preTdIndex < 0) {
          return;
        }
        final ITr preTr = trList[preTrIndex];
        final ITd preTd = preTr.tdList[preTdIndex];
        position.setPositionContext(
          IPositionContext(
            isTable: true,
            index: tableIndex,
            trIndex: preTrIndex,
            tdIndex: preTdIndex,
            tdId: preTd.id,
            trId: preTr.id,
            tableId: tableId,
          ),
        );
        anchorStartIndex = preTd.value.isEmpty ? -1 : preTd.value.length - 1;
        anchorEndIndex = anchorStartIndex;
        draw.getTableTool()?.render();
      }
    } else {
      final List<IElement> originalElementList =
          (draw.getOriginalElementList() as List?)?.cast<IElement>() ??
              <IElement>[];
      if (tableIndex < 0 || tableIndex >= originalElementList.length) {
        return;
      }
      final IElement tableElement = originalElementList[tableIndex];
      final List<ITr>? trList = tableElement.trList;
      if (trList == null || trList.isEmpty) {
        return;
      }
      if (trIndex == trList.length - 1) {
        position.setPositionContext(IPositionContext(isTable: false));
        anchorStartIndex = tableIndex;
        anchorEndIndex = anchorStartIndex;
        draw.getTableTool()?.dispose();
      } else {
        int nextTrIndex = -1;
        int nextTdIndex = -1;
        final List<ITd> currentTdList = trList[trIndex].tdList;
        final int? curTdColIndex = currentTdList[tdIndex].colIndex;
        if (curTdColIndex == null) {
          return;
        }
        outer:
        for (var r = trIndex + 1; r < trList.length; r++) {
          final ITr tr = trList[r];
          final List<ITd> tdList = tr.tdList;
          for (var d = 0; d < tdList.length; d++) {
            final ITd td = tdList[d];
            final int? tdColIndex = td.colIndex;
            if (tdColIndex == null) {
              continue;
            }
            final int tdColEnd = tdColIndex + td.colspan - 1;
            if (tdColIndex == curTdColIndex ||
                (tdColEnd >= curTdColIndex && tdColIndex <= curTdColIndex)) {
              nextTrIndex = r;
              nextTdIndex = d;
              break outer;
            }
          }
        }
        if (nextTrIndex < 0 || nextTdIndex < 0) {
          return;
        }
        final ITr nextTr = trList[nextTrIndex];
        final ITd nextTd = nextTr.tdList[nextTdIndex];
        position.setPositionContext(
          IPositionContext(
            isTable: true,
            index: tableIndex,
            trIndex: nextTrIndex,
            tdIndex: nextTdIndex,
            tdId: nextTd.id,
            trId: nextTr.id,
            tableId: tableId,
          ),
        );
        anchorStartIndex = nextTd.value.isEmpty ? -1 : nextTd.value.length - 1;
        anchorEndIndex = anchorStartIndex;
        draw.getTableTool()?.render();
      }
    }
  } else {
    IElementPosition anchorPosition = cursorPosition;
    if (evt.shiftKey) {
      if (cursorPosition.index == startIndex &&
          endIndex >= 0 &&
          endIndex < positionList.length) {
        anchorPosition = positionList[endIndex];
      } else if (startIndex >= 0 && startIndex < positionList.length) {
        anchorPosition = positionList[startIndex];
      }
    }
    final int anchorIndex = anchorPosition.index;
    final int anchorRowNo = anchorPosition.rowNo;
    final int anchorRowIndex = anchorPosition.rowIndex;
    final List<double> rightTop =
        anchorPosition.coordinate['rightTop'] ?? <double>[0, 0];
    final double curRightX = rightTop.isNotEmpty ? rightTop[0] : 0;
    if ((isUp && anchorRowIndex == 0) ||
        (!isUp && rowCount > 0 && anchorRowIndex == rowCount - 1)) {
      return;
    }

    final int nextIndex = _getNextPositionIndex(
      positionList: positionList,
      index: anchorIndex,
      rowNo: anchorRowNo,
      isUp: isUp,
      cursorX: curRightX,
    );
    if (nextIndex < 0) {
      return;
    }

    anchorStartIndex = nextIndex;
    anchorEndIndex = nextIndex;
    if (evt.shiftKey) {
      if (startIndex != endIndex) {
        if (startIndex == cursorPosition.index) {
          anchorStartIndex = startIndex;
        } else {
          anchorEndIndex = endIndex;
        }
      } else {
        if (isUp) {
          anchorEndIndex = endIndex;
        } else {
          anchorStartIndex = startIndex;
        }
      }
    }

    final List<IElement> elementList =
        (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];
    if (nextIndex >= 0 && nextIndex < elementList.length) {
      final IElement nextElement = elementList[nextIndex];
      if (nextElement.type == ElementType.table) {
        final IEditorOption options = draw.getOptions() as IEditorOption;
        final double scale = options.scale ?? 1;
        final List<double> margins =
            (draw.getMargins() as List?)?.cast<double>() ??
                <double>[0, 0, 0, 0];
        final List<ITr>? trList = nextElement.trList;
        if (trList != null && trList.isNotEmpty) {
          int trIndex = -1;
          int tdIndex = -1;
          int tdPositionIndex = -1;

          if (isUp) {
            outer:
            for (var r = trList.length - 1; r >= 0; r--) {
              final ITr tr = trList[r];
              final List<ITd> tdList = tr.tdList;
              for (var d = 0; d < tdList.length; d++) {
                final ITd td = tdList[d];
                final double tdX =
                    (td.x ?? 0) * scale + (margins.length > 3 ? margins[3] : 0);
                final double tdWidth = (td.width ?? 0) * scale;
                if (curRightX >= tdX && curRightX <= tdX + tdWidth) {
                  final List<IElementPosition>? tdPositionList =
                      td.positionList?.cast<IElementPosition>();
                  if (tdPositionList == null || tdPositionList.isEmpty) {
                    continue;
                  }
                  final IElementPosition lastPosition =
                      tdPositionList[tdPositionList.length - 1];
                  final int candidateIndex = _getNextPositionIndex(
                    positionList: tdPositionList,
                    index: lastPosition.index + 1,
                    rowNo: lastPosition.rowNo - 1,
                    isUp: true,
                    cursorX: curRightX,
                  );
                  final int nextPositionIndex =
                      candidateIndex >= 0 ? candidateIndex : lastPosition.index;
                  trIndex = r;
                  tdIndex = d;
                  tdPositionIndex = nextPositionIndex;
                  break outer;
                }
              }
            }
          } else {
            outer:
            for (var r = 0; r < trList.length; r++) {
              final ITr tr = trList[r];
              final List<ITd> tdList = tr.tdList;
              for (var d = 0; d < tdList.length; d++) {
                final ITd td = tdList[d];
                final double tdX =
                    (td.x ?? 0) * scale + (margins.length > 3 ? margins[3] : 0);
                final double tdWidth = (td.width ?? 0) * scale;
                if (curRightX >= tdX && curRightX <= tdX + tdWidth) {
                  final List<IElementPosition>? tdPositionList =
                      td.positionList?.cast<IElementPosition>();
                  if (tdPositionList == null || tdPositionList.isEmpty) {
                    continue;
                  }
                  final int candidateIndex = _getNextPositionIndex(
                    positionList: tdPositionList,
                    index: -1,
                    rowNo: -1,
                    isUp: false,
                    cursorX: curRightX,
                  );
                  final int nextPositionIndex =
                      candidateIndex >= 0 ? candidateIndex : 0;
                  trIndex = r;
                  tdIndex = d;
                  tdPositionIndex = nextPositionIndex;
                  break outer;
                }
              }
            }
          }

          if (trIndex >= 0 && tdIndex >= 0 && tdPositionIndex >= 0) {
            final ITr targetTr = trList[trIndex];
            final ITd targetTd = targetTr.tdList[tdIndex];
            position.setPositionContext(
              IPositionContext(
                isTable: true,
                index: nextIndex,
                trIndex: trIndex,
                tdIndex: tdIndex,
                tdId: targetTd.id,
                trId: targetTr.id,
                tableId: nextElement.id,
              ),
            );
            anchorStartIndex = tdPositionIndex;
            anchorEndIndex = anchorStartIndex;
            positionList = (position.getPositionList() as List?)
                    ?.cast<IElementPosition>() ??
                <IElementPosition>[];
            draw.getTableTool()?.render();
          }
        }
      }
    }
  }

  if (anchorStartIndex < 0 || anchorEndIndex < 0) {
    return;
  }
  if (anchorStartIndex > anchorEndIndex) {
    final int temp = anchorStartIndex;
    anchorStartIndex = anchorEndIndex;
    anchorEndIndex = temp;
  }

  rangeManager.setRange(anchorStartIndex, anchorEndIndex);
  final bool isCollapsed = anchorStartIndex == anchorEndIndex;
  draw.render(
    IDrawOption(
      curIndex: isCollapsed ? anchorStartIndex : null,
      isSetCursor: isCollapsed,
      isSubmitHistory: false,
      isCompute: false,
    ),
  );

  final int cursorIndex = isUp ? anchorStartIndex : anchorEndIndex;
  if (cursorIndex >= 0 && cursorIndex < positionList.length) {
    final dynamic cursor = draw.getCursor();
    cursor?.moveCursorToVisible(
      IMoveCursorToVisibleOption(
        direction: isUp ? MoveDirection.up : MoveDirection.down,
        cursorPosition: positionList[cursorIndex],
      ),
    );
  }
}
