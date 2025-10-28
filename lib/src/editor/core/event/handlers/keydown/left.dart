import 'dart:html';

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

void left(KeyboardEvent evt, dynamic host) {
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

  final IPositionContext positionContext =
      position.getPositionContext() as IPositionContext;
  final int index = cursorPosition.index;
  if (index <= 0 && positionContext.isTable != true) {
    return;
  }

  final dynamic rangeManager = draw.getRange();
  final IRange range = rangeManager.getRange() as IRange;
  final int startIndex = range.startIndex;
  final int endIndex = range.endIndex;
  final bool isCollapsed = rangeManager.getIsCollapsed() == true;
  final List<IElement> elementList =
      (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];

  final dynamic control = draw.getControl();
  final bool hasCurrentElement = index >= 0 && index < elementList.length;
  if (draw.getMode() == EditorMode.form &&
      control != null &&
      control.getActiveControl() != null &&
      hasCurrentElement &&
      (elementList[index].controlComponent == ControlComponent.prefix ||
          elementList[index].controlComponent == ControlComponent.preText)) {
    control.initNextControl(<String, dynamic>{
      'direction': MoveDirection.up,
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
        moveStartIndex >= 0 &&
        moveStartIndex < elementList.length &&
        letterReg.hasMatch(elementList[moveStartIndex].value)) {
      var i = moveStartIndex - 1;
      while (i > 0) {
        final IElement element = elementList[i];
        if (!letterReg.hasMatch(element.value)) {
          break;
        }
        moveCount++;
        i--;
      }
    }
  }

  final int curIndex = startIndex - moveCount;
  var anchorStartIndex = curIndex;
  var anchorEndIndex = curIndex;

  if (evt.shiftKey) {
    if (startIndex != endIndex) {
      if (startIndex == index) {
        anchorStartIndex = startIndex;
        anchorEndIndex = endIndex - moveCount;
      } else {
        anchorStartIndex = curIndex;
        anchorEndIndex = endIndex;
      }
    } else {
      anchorEndIndex = endIndex;
    }
  }

  if (!evt.shiftKey && startIndex >= 0 && startIndex < elementList.length) {
    final IElement element = elementList[startIndex];
    final dynamic tableTool = draw.getTableTool();
    if (element.type == ElementType.table) {
      final List<ITr>? trList = element.trList;
      if (trList != null && trList.isNotEmpty) {
        final int lastTrIndex = trList.length - 1;
        final ITr lastTr = trList[lastTrIndex];
        if (lastTr.tdList.isNotEmpty) {
          final int lastTdIndex = lastTr.tdList.length - 1;
          final ITd lastTd = lastTr.tdList[lastTdIndex];
          position.setPositionContext(
            IPositionContext(
              isTable: true,
              index: startIndex,
              trIndex: lastTrIndex,
              tdIndex: lastTdIndex,
              tdId: lastTd.id,
              trId: lastTr.id,
              tableId: element.id,
            ),
          );
          anchorStartIndex =
              lastTd.value.isEmpty ? -1 : lastTd.value.length - 1;
          anchorEndIndex = anchorStartIndex;
          tableTool?.render();
        }
      }
    } else if (element.tableId != null && startIndex == 0) {
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
            for (var d = 0; d < tr.tdList.length; d++) {
              final ITd td = tr.tdList[d];
              if (td.id != element.tdId) {
                continue;
              }
              if (r == 0 && d == 0) {
                position.setPositionContext(
                  IPositionContext(isTable: false),
                );
                anchorStartIndex = (positionContext.index ?? 0) - 1;
                anchorEndIndex = anchorStartIndex;
                tableTool?.dispose();
              } else {
                var preTrIndex = r;
                var preTdIndex = d - 1;
                if (preTdIndex < 0) {
                  preTrIndex = r - 1;
                  if (preTrIndex >= 0 && preTrIndex < trList.length) {
                    preTdIndex = trList[preTrIndex].tdList.length - 1;
                  }
                }
                if (preTrIndex >= 0 &&
                    preTrIndex < trList.length &&
                    preTdIndex >= 0 &&
                    preTdIndex < trList[preTrIndex].tdList.length) {
                  final ITr preTr = trList[preTrIndex];
                  final ITd preTd = preTr.tdList[preTdIndex];
                  position.setPositionContext(
                    IPositionContext(
                      isTable: true,
                      index: positionContext.index,
                      trIndex: preTrIndex,
                      tdIndex: preTdIndex,
                      tdId: preTd.id,
                      trId: preTr.id,
                      tableId: element.tableId,
                    ),
                  );
                  anchorStartIndex =
                      preTd.value.isEmpty ? -1 : preTd.value.length - 1;
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

  if (anchorStartIndex < 0 || anchorEndIndex < 0) {
    return;
  }

  final List<IElement> latestElementList =
      (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];
  if (latestElementList.isEmpty) {
    return;
  }
  if (anchorStartIndex >= latestElementList.length) {
    anchorStartIndex = latestElementList.length - 1;
  }
  if (anchorEndIndex >= latestElementList.length) {
    anchorEndIndex = latestElementList.length - 1;
  }
  anchorStartIndex =
      getNonHideElementIndex(latestElementList, anchorStartIndex);
  anchorEndIndex = getNonHideElementIndex(latestElementList, anchorEndIndex);

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
