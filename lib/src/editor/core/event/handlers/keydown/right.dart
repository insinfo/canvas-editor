import 'dart:html';

import '../../../../dataset/enum/common.dart';
import '../../../../dataset/enum/control.dart';
import '../../../../dataset/enum/editor.dart';
import '../../../../dataset/enum/element.dart';
import '../../../../dataset/enum/observer.dart';
import '../../../../interface/draw.dart';
import '../../../../interface/element.dart';
import '../../../../interface/position.dart';
import '../../../../interface/range.dart';
import '../../../../interface/table/td.dart';
import '../../../../utils/element.dart';
import '../../../../utils/hotkey.dart';

void right(KeyboardEvent evt, dynamic host) {
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

  final int index = cursorPosition.index;
  final List<IElementPosition> positionList =
      (position.getPositionList() as List?)?.cast<IElementPosition>() ??
          <IElementPosition>[];
  final IPositionContext positionContext =
      position.getPositionContext() as IPositionContext;
  if (index > positionList.length - 1 && positionContext.isTable != true) {
    return;
  }

  final dynamic rangeManager = draw.getRange();
  final IRange range = rangeManager.getRange() as IRange;
  final int startIndex = range.startIndex;
  final int endIndex = range.endIndex;
  final bool isCollapsed = rangeManager.getIsCollapsed() == true;
  List<IElement> elementList =
      (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];

  final dynamic control = draw.getControl();
  final IElement? nextControlElement =
      index + 1 < elementList.length ? elementList[index + 1] : null;
  if (draw.getMode() == EditorMode.form &&
      control != null &&
      control.getActiveControl() != null &&
      nextControlElement != null &&
      (nextControlElement.controlComponent == ControlComponent.postfix ||
          nextControlElement.controlComponent == ControlComponent.postText)) {
    control.initNextControl(<String, dynamic>{
      'direction': MoveDirection.down,
    });
    return;
  }

  var moveCount = 1;
  if (isMod(evt)) {
    final RegExp? letterReg = draw.getLetterReg() as RegExp?;
    final int moveStartIndex =
        evt.shiftKey && !isCollapsed && startIndex == index
            ? endIndex
            : startIndex;
    if (letterReg != null &&
        moveStartIndex + 1 < elementList.length &&
        letterReg.hasMatch(elementList[moveStartIndex + 1].value)) {
      var i = moveStartIndex + 2;
      while (i < elementList.length) {
        final IElement element = elementList[i];
        if (!letterReg.hasMatch(element.value)) {
          break;
        }
        moveCount++;
        i++;
      }
    }
  }

  final int curIndex = endIndex + moveCount;
  var anchorStartIndex = curIndex;
  var anchorEndIndex = curIndex;

  if (evt.shiftKey) {
    if (startIndex != endIndex) {
      if (startIndex == index) {
        anchorStartIndex = startIndex;
        anchorEndIndex = curIndex;
      } else {
        anchorStartIndex = startIndex + moveCount;
        anchorEndIndex = endIndex;
      }
    } else {
      anchorStartIndex = startIndex;
    }
  }

  if (!evt.shiftKey && endIndex >= 0 && endIndex < elementList.length) {
    final IElement element = elementList[endIndex];
    final IElement? nextElement =
        endIndex + 1 < elementList.length ? elementList[endIndex + 1] : null;
    final dynamic tableTool = draw.getTableTool();
    if (nextElement != null && nextElement.type == ElementType.table) {
      final List<ITr>? trList = nextElement.trList;
      if (trList != null && trList.isNotEmpty) {
        final ITr nextTr = trList.first;
        if (nextTr.tdList.isNotEmpty) {
          final ITd nextTd = nextTr.tdList.first;
          position.setPositionContext(
            IPositionContext(
              isTable: true,
              index: endIndex + 1,
              trIndex: 0,
              tdIndex: 0,
              tdId: nextTd.id,
              trId: nextTr.id,
              tableId: nextElement.id,
            ),
          );
          anchorStartIndex = 0;
          anchorEndIndex = 0;
          tableTool?.render();
        }
      }
    } else if (element.tableId != null && nextElement == null) {
      final List<IElement> originalElementList =
          (draw.getOriginalElementList() as List?)?.cast<IElement>() ??
              <IElement>[];
      final int? tableIndex = positionContext.index;
      if (tableIndex != null &&
          tableIndex >= 0 &&
          tableIndex < originalElementList.length) {
        final List<ITr>? trList = originalElementList[tableIndex].trList;
        if (trList != null) {
          outer:
          for (var r = 0; r < trList.length; r++) {
            final ITr tr = trList[r];
            if (tr.id != element.trId) {
              continue;
            }
            final List<ITd> tdList = tr.tdList;
            for (var d = 0; d < tdList.length; d++) {
              final ITd td = tdList[d];
              if (td.id != element.tdId) {
                continue;
              }
              if (r == trList.length - 1 && d == tdList.length - 1) {
                position.setPositionContext(
                  IPositionContext(isTable: false),
                );
                anchorStartIndex = positionContext.index ?? 0;
                anchorEndIndex = anchorStartIndex;
                elementList =
                    (draw.getElementList() as List?)?.cast<IElement>() ??
                        <IElement>[];
                tableTool?.dispose();
              } else {
                var nextTrIndex = r;
                var nextTdIndex = d + 1;
                if (nextTdIndex > tdList.length - 1) {
                  nextTrIndex = r + 1;
                  nextTdIndex = 0;
                }
                if (nextTrIndex >= 0 &&
                    nextTrIndex < trList.length &&
                    nextTdIndex >= 0 &&
                    nextTdIndex < trList[nextTrIndex].tdList.length) {
                  final ITr nextTrItem = trList[nextTrIndex];
                  final ITd nextTdItem = nextTrItem.tdList[nextTdIndex];
                  position.setPositionContext(
                    IPositionContext(
                      isTable: true,
                      index: positionContext.index,
                      trIndex: nextTrIndex,
                      tdIndex: nextTdIndex,
                      tdId: nextTdItem.id,
                      trId: nextTrItem.id,
                      tableId: element.tableId,
                    ),
                  );
                  anchorStartIndex = 0;
                  anchorEndIndex = anchorStartIndex;
                  tableTool?.render();
                }
              }
              break outer;
            }
          }
        }
      }
    }
  }

  if (elementList.isEmpty) {
    return;
  }
  final int maxElementIndex = elementList.length - 1;
  if (anchorStartIndex > maxElementIndex || anchorEndIndex > maxElementIndex) {
    return;
  }

  final List<IElement> latestElementList =
      (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];
  anchorStartIndex = getNonHideElementIndex(
    latestElementList,
    anchorStartIndex,
    LocationPosition.after,
  );
  anchorEndIndex = getNonHideElementIndex(
    latestElementList,
    anchorEndIndex,
    LocationPosition.after,
  );

  rangeManager.setRange(anchorStartIndex, anchorEndIndex);
  final bool isAnchorCollapsed = anchorStartIndex == anchorEndIndex;
  draw.render(
    IDrawOption(
      curIndex: isAnchorCollapsed ? anchorStartIndex : null,
      isSetCursor: isAnchorCollapsed,
      isSubmitHistory: false,
      isCompute: false,
    ),
  );
  evt.preventDefault();
}
