import '../../dataset/constant/common.dart';
import '../../dataset/enum/common.dart';
import '../../dataset/enum/control.dart';
import '../../dataset/enum/editor.dart';
import '../../dataset/enum/element.dart';
import '../../dataset/enum/list.dart';
import '../../dataset/enum/row.dart';
import '../../dataset/enum/vertical_align.dart';
import '../../interface/common.dart';
import '../../interface/editor.dart';
import '../../interface/element.dart';
import '../../interface/position.dart';
import '../../interface/range.dart';
import '../../interface/row.dart';
import '../../interface/table/td.dart';
import '../../utils/element.dart' as element_utils;
import '../../utils/index.dart' show isRectIntersect;

class Position {
  Position(dynamic drawInstance)
      : draw = drawInstance,
        eventBus = drawInstance.getEventBus(),
        options = drawInstance.getOptions() as IEditorOption,
        positionList = <IElementPosition>[],
        floatPositionList = <IFloatPosition>[],
        cursorPosition = null,
        positionContext = IPositionContext(isTable: false);

  final dynamic draw;
  final dynamic eventBus;
  final IEditorOption options;

  IElementPosition? cursorPosition;
  IPositionContext positionContext;
  List<IElementPosition> positionList;
  List<IFloatPosition> floatPositionList;

  List<IFloatPosition> getFloatPositionList() {
    return floatPositionList;
  }

  List<IElementPosition> getTablePositionList(
      List<IElement> sourceElementList) {
    final int? index = positionContext.index;
    final int? trIndex = positionContext.trIndex;
    final int? tdIndex = positionContext.tdIndex;
    if (index == null || trIndex == null || tdIndex == null) {
      return <IElementPosition>[];
    }
    final IElement tableElement = sourceElementList[index];
    final List<ITr>? trList = tableElement.trList;
    if (trList == null || trIndex < 0 || trIndex >= trList.length) {
      return <IElementPosition>[];
    }
    final ITr tr = trList[trIndex];
    final List<ITd> tdList = tr.tdList;
    if (tdIndex < 0 || tdIndex >= tdList.length) {
      return <IElementPosition>[];
    }
    return tdList[tdIndex].positionList ?? <IElementPosition>[];
  }

  List<IElementPosition> getPositionList() {
    if (positionContext.isTable) {
      return getTablePositionList(draw.getOriginalElementList());
    }
    return getOriginalPositionList();
  }

  List<IElementPosition> getMainPositionList() {
    if (positionContext.isTable) {
      return getTablePositionList(draw.getOriginalMainElementList());
    }
    return positionList;
  }

  List<IElementPosition> getOriginalPositionList() {
    final dynamic zoneManager = draw.getZone();
    if (zoneManager.isHeaderActive() == true) {
      final dynamic header = draw.getHeader();
      return (header.getPositionList() as List<dynamic>)
          .whereType<IElementPosition>()
          .toList();
    }
    if (zoneManager.isFooterActive() == true) {
      final dynamic footer = draw.getFooter();
      return (footer.getPositionList() as List<dynamic>)
          .whereType<IElementPosition>()
          .toList();
    }
    return positionList;
  }

  List<IElementPosition> getOriginalMainPositionList() {
    return positionList;
  }

  List<IElementPosition>? getSelectionPositionList() {
    final IRange range = draw.getRange().getRange();
    if (range.startIndex == range.endIndex) {
      return null;
    }
    final List<IElementPosition> list = getPositionList();
    final int from = range.startIndex + 1;
    final int to = range.endIndex + 1;
    if (from < 0 || to > list.length) {
      return null;
    }
    return list.sublist(from, to);
  }

  void setPositionList(List<IElementPosition> payload) {
    positionList = payload;
  }

  void setFloatPositionList(List<IFloatPosition> payload) {
    floatPositionList = payload;
  }

  IComputePageRowPositionResult computePageRowPosition(
      IComputePageRowPositionPayload payload) {
    final List<IElementPosition> targetPositionList = payload.positionList;
    final List<IRow> rowList = payload.rowList;
    final int pageNo = payload.pageNo;
    final double innerWidth = payload.innerWidth;
    final double startX = payload.startX;
    final double startY = payload.startY;
    final int startRowIndex = payload.startRowIndex;
    final int startIndex = payload.startIndex;
    final double scale = _getScale();
    final List<double> tdPadding = _getTdPadding();

    double x = startX;
    double y = startY;
    var index = startIndex;

    for (var i = 0; i < rowList.length; i++) {
      final IRow curRow = rowList[i];

      if (curRow.isSurround != true) {
        final double curRowWidth = curRow.width + (curRow.offsetX ?? 0);
        if (curRow.rowFlex == RowFlex.center) {
          x += (innerWidth - curRowWidth) / 2;
        } else if (curRow.rowFlex == RowFlex.right) {
          x += innerWidth - curRowWidth;
        }
      }

      x += curRow.offsetX ?? 0;
      y += curRow.offsetY ?? 0;

      final double tablePreX = x;
      final double tablePreY = y;

      final List<IRowElement> elementList = curRow.elementList;
      for (var j = 0; j < elementList.length; j++) {
        final IRowElement element = elementList[j];
        final IElementMetrics metrics = element.metrics;
        final bool isImageLike = (element.imgDisplay != null &&
                element.imgDisplay != ImageDisplay.inline &&
                element.type == ElementType.image) ||
            element.type == ElementType.latex;
        final double offsetY = element.hide != true && isImageLike
            ? curRow.ascent - metrics.height
            : curRow.ascent;

        if (element.left != null) {
          x += element.left!;
        }
        if (element.translateX != null) {
          x += element.translateX! * scale;
        }

        final IElementPosition positionItem = IElementPosition(
          pageNo: pageNo,
          index: index,
          value: element.value,
          rowIndex: startRowIndex + i,
          rowNo: i,
          metrics: metrics,
          left: element.left ?? 0,
          ascent: offsetY,
          lineHeight: curRow.height,
          isFirstLetter: j == 0,
          isLastLetter: j == elementList.length - 1,
          coordinate: <String, List<double>>{
            'leftTop': <double>[x, y],
            'leftBottom': <double>[x, y + curRow.height],
            'rightTop': <double>[x + metrics.width, y],
            'rightBottom': <double>[x + metrics.width, y + curRow.height],
          },
        );

        if (element.imgDisplay == ImageDisplay.surround ||
            element.imgDisplay == ImageDisplay.floatTop ||
            element.imgDisplay == ImageDisplay.floatBottom) {
          if (targetPositionList.isNotEmpty) {
            final IElementPosition prePosition =
                targetPositionList[targetPositionList.length - 1];
            positionItem.metrics = prePosition.metrics;
            positionItem.coordinate = Map<String, List<double>>.from(
              prePosition.coordinate.map(
                (String key, List<double> value) =>
                    MapEntry<String, List<double>>(
                        key, List<double>.from(value)),
              ),
            );
          }
          element.imgFloatPosition ??= <String, num>{
            'x': x,
            'y': y,
            'pageNo': pageNo,
          };
          floatPositionList.add(
            IFloatPosition(
              pageNo: pageNo,
              element: element,
              position: positionItem,
              isTable: payload.isTable,
              index: payload.index,
              tdIndex: payload.tdIndex,
              trIndex: payload.trIndex,
              tdValueIndex: index,
              zone: payload.zone,
            ),
          );
        }

        targetPositionList.add(positionItem);
        index += 1;
        x += metrics.width;

        if (element.type == ElementType.table && element.hide != true) {
          final List<ITr>? trList = element.trList;
          if (trList != null) {
            final double tdPaddingWidth = (tdPadding[1] + tdPadding[3]);
            final double tdPaddingHeight = (tdPadding[0] + tdPadding[2]);
            for (var t = 0; t < trList.length; t++) {
              final ITr tr = trList[t];
              for (var d = 0; d < tr.tdList.length; d++) {
                final ITd td = tr.tdList[d];
                td.positionList = <IElementPosition>[];
                final List<IRow> tdRowList = td.rowList ?? <IRow>[];
                final double tdStartX = ((td.x ?? 0) + tdPadding[3]) * scale +
                    tablePreX +
                    (element.translateX ?? 0) * scale;
                final double tdStartY =
                    ((td.y ?? 0) + tdPadding[0]) * scale + tablePreY;
                final double tdInnerWidth =
                    ((td.width ?? 0) - tdPaddingWidth) * scale;
                final IComputePageRowPositionResult drawRowResult =
                    computePageRowPosition(
                  IComputePageRowPositionPayload(
                    positionList: td.positionList!,
                    rowList: tdRowList,
                    pageNo: pageNo,
                    startRowIndex: 0,
                    startIndex: 0,
                    startX: tdStartX,
                    startY: tdStartY,
                    innerWidth: tdInnerWidth,
                    isTable: true,
                    index: index - 1,
                    tdIndex: d,
                    trIndex: t,
                    zone: payload.zone,
                  ),
                );

                if (td.verticalAlign == VerticalAlign.middle ||
                    td.verticalAlign == VerticalAlign.bottom) {
                  final double rowsHeight = tdRowList.fold<double>(
                    0,
                    (double previousValue, IRow current) =>
                        previousValue + current.height,
                  );
                  final double blankHeight =
                      ((td.height ?? 0) - tdPaddingHeight) * scale - rowsHeight;
                  final double offsetHeight =
                      td.verticalAlign == VerticalAlign.middle
                          ? blankHeight / 2
                          : blankHeight;
                  if (offsetHeight.floor() > 0) {
                    for (final IElementPosition tdPosition
                        in td.positionList!) {
                      final List<double>? leftTop =
                          tdPosition.coordinate['leftTop'];
                      final List<double>? leftBottom =
                          tdPosition.coordinate['leftBottom'];
                      final List<double>? rightBottom =
                          tdPosition.coordinate['rightBottom'];
                      final List<double>? rightTop =
                          tdPosition.coordinate['rightTop'];
                      if (leftTop != null && leftTop.length >= 2) {
                        leftTop[1] += offsetHeight;
                      }
                      if (leftBottom != null && leftBottom.length >= 2) {
                        leftBottom[1] += offsetHeight;
                      }
                      if (rightBottom != null && rightBottom.length >= 2) {
                        rightBottom[1] += offsetHeight;
                      }
                      if (rightTop != null && rightTop.length >= 2) {
                        rightTop[1] += offsetHeight;
                      }
                    }
                  }
                }
                x = drawRowResult.x;
                y = drawRowResult.y;
              }
            }
          }
          x = tablePreX;
          y = tablePreY;
        }
      }

      x = startX;
      y += curRow.height;
    }

    return IComputePageRowPositionResult(x: x, y: y, index: index);
  }

  void computePositionList() {
    positionList = <IElementPosition>[];
    floatPositionList = <IFloatPosition>[];
    final double innerWidth = draw.getInnerWidth();
    final List<List<IRow>> pageRowList =
        (draw.getPageRowList() as List<dynamic>).map<List<IRow>>(
      (dynamic entry) {
        if (entry is List<IRow>) {
          return entry;
        }
        if (entry is List) {
          return entry.whereType<IRow>().toList();
        }
        return <IRow>[];
      },
    ).toList();
    final List<double> margins = _getMargins();
    final dynamic header = draw.getHeader();
    final double extraHeight = (header.getExtraHeight() as num).toDouble();
    final double startX = margins[3];
    final double startY = margins[0] + extraHeight;
    var startRowIndex = 0;
    for (var i = 0; i < pageRowList.length; i++) {
      final List<IRow> rowList = pageRowList[i];
      final int startIndex = rowList.isNotEmpty ? rowList[0].startIndex : 0;
      computePageRowPosition(
        IComputePageRowPositionPayload(
          positionList: positionList,
          rowList: rowList,
          pageNo: i,
          startRowIndex: startRowIndex,
          startIndex: startIndex,
          startX: startX,
          startY: startY,
          innerWidth: innerWidth,
        ),
      );
      startRowIndex += rowList.length;
    }
  }

  List<IElementPosition> computeRowPosition(
      IComputeRowPositionPayload payload) {
    final IRow rowClone = _cloneRow(payload.row);
    final List<IElementPosition> tempPositionList = <IElementPosition>[];
    computePageRowPosition(
      IComputePageRowPositionPayload(
        positionList: tempPositionList,
        rowList: <IRow>[rowClone],
        pageNo: 0,
        startRowIndex: 0,
        startIndex: 0,
        startX: 0,
        startY: 0,
        innerWidth: payload.innerWidth,
      ),
    );
    return tempPositionList;
  }

  void setCursorPosition(IElementPosition? position) {
    cursorPosition = position;
  }

  IElementPosition? getCursorPosition() {
    return cursorPosition;
  }

  IPositionContext getPositionContext() {
    return positionContext;
  }

  void setPositionContext(IPositionContext payload) {
    try {
      eventBus.emit('positionContextChange', <String, dynamic>{
        'value': payload,
        'oldValue': positionContext,
      });
    } catch (_) {}
    positionContext = payload;
  }

  ICurrentPosition getPositionByXY(IGetPositionByXYPayload payload) {
    final double x = payload.x;
    final double y = payload.y;
    final bool isTable = payload.isTable == true;
    final List<IElement> elementList = _resolveElementList(payload.elementList);
    final List<IElementPosition> currentPositionList =
        payload.positionList ?? getOriginalPositionList();
    final dynamic zoneManager = draw.getZone();
    final int curPageNo = payload.pageNo ?? draw.getPageNo();
    final bool isMainActive = zoneManager.isMainActive() == true;
    final int positionNo = isMainActive ? curPageNo : 0;
    final List<double> margins = _getMargins();

    if (!isTable) {
      final ICurrentPosition? floatTopPosition = getFloatPositionByXY(
        IGetFloatPositionByXYPayload(
          imgDisplays: <ImageDisplay>[
            ImageDisplay.floatTop,
            ImageDisplay.surround
          ],
          x: x,
          y: y,
          pageNo: payload.pageNo,
          isTable: payload.isTable,
          td: payload.td,
          tablePosition: payload.tablePosition,
          elementList: payload.elementList,
          positionList: payload.positionList,
        ),
      );
      if (floatTopPosition != null) {
        return floatTopPosition;
      }
    }

    for (var j = 0; j < currentPositionList.length; j++) {
      final IElementPosition positionItem = currentPositionList[j];
      final int index = positionItem.index;
      final int pageNo = positionItem.pageNo;
      final double left = positionItem.left;
      final bool isFirstLetter = positionItem.isFirstLetter;
      final List<double> leftTop =
          positionItem.coordinate['leftTop'] ?? <double>[0, 0];
      final List<double> rightTop =
          positionItem.coordinate['rightTop'] ?? <double>[0, 0];
      final List<double> leftBottom =
          positionItem.coordinate['leftBottom'] ?? <double>[0, 0];
      if (positionNo != pageNo) {
        continue;
      }
      if (pageNo > positionNo) {
        break;
      }
      if (leftTop.length < 2 || rightTop.length < 2 || leftBottom.length < 2) {
        continue;
      }
      if (leftTop[0] - left <= x &&
          rightTop[0] >= x &&
          leftTop[1] <= y &&
          leftBottom[1] >= y) {
        var curPositionIndex = j;
        final IElement element = elementList[j];
        if (element.type == ElementType.table) {
          final List<ITr>? trList = element.trList;
          if (trList != null) {
            for (var t = 0; t < trList.length; t++) {
              final ITr tr = trList[t];
              for (var d = 0; d < tr.tdList.length; d++) {
                final ITd td = tr.tdList[d];
                final ICurrentPosition tablePosition = getPositionByXY(
                  IGetPositionByXYPayload(
                    x: x,
                    y: y,
                    pageNo: curPageNo,
                    isTable: true,
                    td: td,
                    tablePosition: positionItem,
                    elementList: td.value,
                    positionList: td.positionList,
                  ),
                );
                if (tablePosition.index != -1) {
                  final int tdValueIndex = tablePosition.index;
                  final IElement tdValueElement = td.value[tdValueIndex];
                  return ICurrentPosition(
                    index: index,
                    isCheckbox: tablePosition.isCheckbox == true ||
                        tdValueElement.type == ElementType.checkbox ||
                        tdValueElement.controlComponent ==
                            ControlComponent.checkbox,
                    isRadio: tdValueElement.type == ElementType.radio ||
                        tdValueElement.controlComponent ==
                            ControlComponent.radio,
                    isControl: tdValueElement.controlId != null,
                    isImage: tablePosition.isImage,
                    isDirectHit: tablePosition.isDirectHit,
                    isTable: true,
                    tdIndex: d,
                    trIndex: t,
                    tdValueIndex: tdValueIndex,
                    tdId: td.id,
                    trId: tr.id,
                    tableId: element.id,
                    hitLineStartIndex: tablePosition.hitLineStartIndex,
                  );
                }
              }
            }
          }
        }
        if (element.type == ElementType.image ||
            element.type == ElementType.latex) {
          return ICurrentPosition(
            index: curPositionIndex,
            isDirectHit: true,
            isImage: true,
          );
        }
        if (element.type == ElementType.checkbox ||
            element.controlComponent == ControlComponent.checkbox) {
          return ICurrentPosition(
            index: curPositionIndex,
            isDirectHit: true,
            isCheckbox: true,
          );
        }
        if (element.type == ElementType.tab &&
            element.listStyle == ListStyle.checkbox) {
          var indexPointer = curPositionIndex - 1;
          while (indexPointer > 0) {
            final IElement checkElement = elementList[indexPointer];
            if (checkElement.value == ZERO &&
                checkElement.listStyle == ListStyle.checkbox) {
              break;
            }
            indexPointer -= 1;
          }
          return ICurrentPosition(
            index: indexPointer,
            isDirectHit: true,
            isCheckbox: true,
          );
        }
        if (element.type == ElementType.radio ||
            element.controlComponent == ControlComponent.radio) {
          return ICurrentPosition(
            index: curPositionIndex,
            isDirectHit: true,
            isRadio: true,
          );
        }

        int? hitLineStartIndex;
        if (elementList[index].value != ZERO) {
          final double valueWidth = rightTop[0] - leftTop[0];
          if (x < leftTop[0] + valueWidth / 2) {
            curPositionIndex = j - 1;
            if (isFirstLetter) {
              hitLineStartIndex = j;
            }
          }
        }
        return ICurrentPosition(
          index: curPositionIndex,
          isDirectHit: true,
          isControl: element.controlId != null,
          hitLineStartIndex: hitLineStartIndex,
        );
      }
    }

    if (!isTable) {
      final ICurrentPosition? floatBottomPosition = getFloatPositionByXY(
        IGetFloatPositionByXYPayload(
          imgDisplays: <ImageDisplay>[ImageDisplay.floatBottom],
          x: x,
          y: y,
          pageNo: payload.pageNo,
          isTable: payload.isTable,
          td: payload.td,
          tablePosition: payload.tablePosition,
          elementList: payload.elementList,
          positionList: payload.positionList,
        ),
      );
      if (floatBottomPosition != null) {
        return floatBottomPosition;
      }
    }

    var curPositionIndex = -1;
    int? hitLineStartIndex;
    var isLastArea = false;

    if (isTable) {
      final double scale = _getScale();
      final ITd? td = payload.td;
      final IElementPosition? tablePosition = payload.tablePosition;
      if (td != null && tablePosition != null) {
        final List<double> leftTop =
            tablePosition.coordinate['leftTop'] ?? <double>[0, 0];
        final double tdX =
            (td.x ?? 0) * scale + (leftTop.isNotEmpty ? leftTop[0] : 0);
        final double tdY =
            (td.y ?? 0) * scale + (leftTop.length > 1 ? leftTop[1] : 0);
        final double tdWidth = (td.width ?? 0) * scale;
        final double tdHeight = (td.height ?? 0) * scale;
        final bool insideTd =
            tdX < x && x < tdX + tdWidth && tdY < y && y < tdY + tdHeight;
        if (!insideTd) {
          return ICurrentPosition(index: curPositionIndex);
        }
      }
    }

    final List<IElementPosition> lastLetterList = currentPositionList
        .where((IElementPosition position) =>
            position.isLastLetter && position.pageNo == positionNo)
        .toList();
    for (var j = 0; j < lastLetterList.length; j++) {
      final IElementPosition lastLetter = lastLetterList[j];
      final int index = lastLetter.index;
      final int rowNo = lastLetter.rowNo;
      final List<double> rowLeftTop =
          lastLetter.coordinate['leftTop'] ?? <double>[0, 0];
      final List<double> rowLeftBottom =
          lastLetter.coordinate['leftBottom'] ?? <double>[0, 0];
      if (rowLeftTop.length < 2 || rowLeftBottom.length < 2) {
        continue;
      }
      if (y > rowLeftTop[1] && y <= rowLeftBottom[1]) {
        final int headIndex = currentPositionList.indexWhere(
          (IElementPosition position) =>
              position.pageNo == positionNo && position.rowNo == rowNo,
        );
        if (headIndex >= 0) {
          final IElement headElement = elementList[headIndex];
          final IElementPosition headPosition = currentPositionList[headIndex];
          final List<double> headLeftTop =
              headPosition.coordinate['leftTop'] ?? <double>[0, 0];
          final double headStartX = headElement.listStyle == ListStyle.checkbox
              ? margins[3]
              : (headLeftTop.isNotEmpty ? headLeftTop[0] : 0);
          if (x < headStartX) {
            if (headPosition.value == ZERO) {
              curPositionIndex = headIndex;
            } else {
              curPositionIndex = headIndex - 1;
              hitLineStartIndex = headIndex;
            }
          } else {
            if (headElement.listStyle == ListStyle.checkbox &&
                headLeftTop.isNotEmpty &&
                x < headLeftTop[0]) {
              return ICurrentPosition(
                index: headIndex,
                isDirectHit: true,
                isCheckbox: true,
              );
            }
            curPositionIndex = index;
          }
        } else {
          curPositionIndex = index;
        }
        isLastArea = true;
        break;
      }
    }

    if (!isLastArea) {
      final dynamic header = draw.getHeader();
      final double headerHeight = (header.getHeight() as num).toDouble();
      final double headerTop = (header.getHeaderTop() as num).toDouble();
      final double headerBottomY = headerTop + headerHeight;
      final dynamic footer = draw.getFooter();
      final double pageHeight = (draw.getHeight() as num).toDouble();
      final double footerBottom = (footer.getFooterBottom() as num).toDouble();
      final double footerHeight = (footer.getHeight() as num).toDouble();
      final double footerTopY = pageHeight - (footerBottom + footerHeight);
      if (isMainActive) {
        if (y < headerBottomY) {
          return ICurrentPosition(index: -1, zone: EditorZone.header);
        }
        if (y > footerTopY) {
          return ICurrentPosition(index: -1, zone: EditorZone.footer);
        }
      } else {
        if (y <= footerTopY && y >= headerBottomY) {
          return ICurrentPosition(index: -1, zone: EditorZone.main);
        }
      }

      if (y <= margins[0]) {
        for (var p = 0; p < currentPositionList.length; p++) {
          final IElementPosition position = currentPositionList[p];
          if (position.pageNo != positionNo || position.rowNo != 0) {
            continue;
          }
          final List<double> leftTop =
              position.coordinate['leftTop'] ?? <double>[0, 0];
          final List<double> rightTop =
              position.coordinate['rightTop'] ?? <double>[0, 0];
          final bool isLastElement = p + 1 >= currentPositionList.length ||
              currentPositionList[p + 1].rowNo != 0;
          if (x <= margins[3] ||
              (leftTop.isNotEmpty &&
                  rightTop.isNotEmpty &&
                  x >= leftTop[0] &&
                  x <= rightTop[0]) ||
              isLastElement) {
            return ICurrentPosition(index: position.index);
          }
        }
      } else {
        final IElementPosition? lastLetter = lastLetterList.isNotEmpty
            ? lastLetterList[lastLetterList.length - 1]
            : null;
        if (lastLetter != null) {
          final int lastRowNo = lastLetter.rowNo;
          for (var p = 0; p < currentPositionList.length; p++) {
            final IElementPosition position = currentPositionList[p];
            if (position.pageNo != positionNo || position.rowNo != lastRowNo) {
              continue;
            }
            final List<double> leftTop =
                position.coordinate['leftTop'] ?? <double>[0, 0];
            final List<double> rightTop =
                position.coordinate['rightTop'] ?? <double>[0, 0];
            final bool isLastElement = p + 1 >= currentPositionList.length ||
                currentPositionList[p + 1].rowNo != lastRowNo;
            if (x <= margins[3] ||
                (leftTop.isNotEmpty &&
                    rightTop.isNotEmpty &&
                    x >= leftTop[0] &&
                    x <= rightTop[0]) ||
                isLastElement) {
              return ICurrentPosition(index: position.index);
            }
          }
        }
      }
      return ICurrentPosition(
        index: lastLetterList.isNotEmpty
            ? lastLetterList[lastLetterList.length - 1].index
            : currentPositionList.length - 1,
      );
    }

    final bool hasControl =
        curPositionIndex >= 0 && curPositionIndex < elementList.length
            ? elementList[curPositionIndex].controlId != null
            : false;
    return ICurrentPosition(
      index: curPositionIndex,
      hitLineStartIndex: hitLineStartIndex,
      isControl: hasControl,
    );
  }

  ICurrentPosition? getFloatPositionByXY(IGetFloatPositionByXYPayload payload) {
    final double x = payload.x;
    final double y = payload.y;
    final int currentPageNo = payload.pageNo ?? draw.getPageNo();
    final EditorZone? currentZone = draw.getZone().getZone() as EditorZone?;
    final double scale = _getScale();

    for (final IFloatPosition floatPosition in floatPositionList) {
      final IElement element = floatPosition.element;
      final bool isTable = floatPosition.isTable == true;
      if (currentPageNo != floatPosition.pageNo) {
        continue;
      }
      if (element.type != ElementType.image) {
        continue;
      }
      final ImageDisplay? imgDisplay = element.imgDisplay;
      if (imgDisplay == null || !payload.imgDisplays.contains(imgDisplay)) {
        continue;
      }
      final EditorZone? floatZone = floatPosition.zone;
      if (floatZone != null &&
          currentZone != null &&
          floatZone != currentZone) {
        continue;
      }
      final Map<String, num>? imgFloatPosition =
          element.imgFloatPosition?.cast<String, num>();
      if (imgFloatPosition == null) {
        continue;
      }
      final double floatX = (imgFloatPosition['x'] ?? 0) * scale;
      final double floatY = (imgFloatPosition['y'] ?? 0) * scale;
      final double elementWidth = (element.width ?? 0) * scale;
      final double elementHeight = (element.height ?? 0) * scale;
      final bool isHit = x >= floatX &&
          x <= floatX + elementWidth &&
          y >= floatY &&
          y <= floatY + elementHeight;
      if (!isHit) {
        continue;
      }
      if (isTable) {
        return ICurrentPosition(
          index: floatPosition.index ?? -1,
          isDirectHit: true,
          isImage: true,
          isTable: true,
          trIndex: floatPosition.trIndex,
          tdIndex: floatPosition.tdIndex,
          tdValueIndex: floatPosition.tdValueIndex,
          tdId: element.tdId,
          trId: element.trId,
          tableId: element.tableId,
        );
      }
      return ICurrentPosition(
        index: floatPosition.position.index,
        isDirectHit: true,
        isImage: true,
      );
    }
    return null;
  }

  ICurrentPosition? adjustPositionContext(IGetPositionByXYPayload payload) {
    final ICurrentPosition positionResult = getPositionByXY(payload);
    if (positionResult.index == -1) {
      return null;
    }
    if (positionResult.isControl == true &&
        draw.getMode() != EditorMode.readonly) {
      final dynamic control = draw.getControl();
      final Map<String, dynamic> moveResult =
          control.moveCursor(<String, dynamic>{
        'index': positionResult.index,
        'isTable': positionResult.isTable,
        'trIndex': positionResult.trIndex,
        'tdIndex': positionResult.tdIndex,
        'tdValueIndex': positionResult.tdValueIndex,
      }) as Map<String, dynamic>;
      final int? newIndex = moveResult['newIndex'] as int?;
      if (positionResult.isTable == true) {
        positionResult.tdValueIndex = newIndex;
      } else {
        if (newIndex != null) {
          positionResult.index = newIndex;
        }
      }
    }

    setPositionContext(
      IPositionContext(
        isTable: positionResult.isTable ?? false,
        isCheckbox: positionResult.isCheckbox ?? false,
        isRadio: positionResult.isRadio ?? false,
        isControl: positionResult.isControl ?? false,
        isImage: positionResult.isImage ?? false,
        isDirectHit: positionResult.isDirectHit ?? false,
        index: positionResult.index,
        trIndex: positionResult.trIndex,
        tdIndex: positionResult.tdIndex,
        tdId: positionResult.tdId,
        trId: positionResult.trId,
        tableId: positionResult.tableId,
      ),
    );

    return positionResult;
  }

  Map<String, double> setSurroundPosition(ISetSurroundPositionPayload payload) {
    final double scale = _getScale();
    final int pageNo = payload.pageNo;
    final IRow row = payload.row;
    final IRowElement rowElement = payload.rowElement;
    final IElementFillRect rowElementRect = payload.rowElementRect;
    final List<IElement> surroundElementList = payload.surroundElementList;
    final double availableWidth = payload.availableWidth;

    double x = rowElementRect.x;
    double rowIncreaseWidth = 0;

    if (surroundElementList.isNotEmpty &&
        !element_utils.getIsBlockElement(rowElement) &&
        rowElement.control?.minWidth == null) {
      for (final IElement surroundElement in surroundElementList) {
        final Map<String, num>? floatPosition =
            surroundElement.imgFloatPosition?.cast<String, num>();
        if (floatPosition == null) {
          continue;
        }
        if ((floatPosition['pageNo'] ?? -1).toInt() != pageNo) {
          continue;
        }
        final IElementFillRect surroundRect = IElementFillRect(
          x: (floatPosition['x'] ?? 0) * scale,
          y: (floatPosition['y'] ?? 0) * scale,
          width: (surroundElement.width ?? 0) * scale,
          height: (surroundElement.height ?? 0) * scale,
        );
        if (isRectIntersect(rowElementRect, surroundRect)) {
          row.isSurround = true;
          final double translateX =
              surroundRect.width + surroundRect.x - rowElementRect.x;
          rowElement.left = translateX;
          row.width += translateX;
          rowIncreaseWidth += translateX;
          x = surroundRect.x + surroundRect.width;
          if (row.width + rowElement.metrics.width > availableWidth) {
            rowElement.left = 0;
            row.width -= rowIncreaseWidth;
            break;
          }
        }
      }
    }

    return <String, double>{
      'x': x,
      'rowIncreaseWidth': rowIncreaseWidth,
    };
  }

  double _getScale() {
    return options.scale?.toDouble() ?? 1;
  }

  List<double> _getTdPadding() {
    final IPadding? padding = options.table?.tdPadding;
    return <double>[
      (padding?.top ?? 0).toDouble(),
      (padding?.right ?? 0).toDouble(),
      (padding?.bottom ?? 0).toDouble(),
      (padding?.left ?? 0).toDouble(),
    ];
  }

  List<double> _getMargins() {
    final dynamic marginsRaw = draw.getMargins();
    if (marginsRaw is List) {
      final List<double> margins =
          marginsRaw.map((dynamic value) => (value as num).toDouble()).toList();
      if (margins.length < 4) {
        margins.addAll(List<double>.filled(4 - margins.length, 0));
      } else if (margins.length > 4) {
        return margins.sublist(0, 4);
      }
      return margins;
    }
    return <double>[0, 0, 0, 0];
  }

  List<IElement> _resolveElementList(List<IElement>? explicitList) {
    if (explicitList != null) {
      return explicitList;
    }
    final dynamic value = draw.getOriginalElementList();
    if (value is List<IElement>) {
      return value;
    }
    if (value is Iterable) {
      return value.whereType<IElement>().toList();
    }
    return <IElement>[];
  }

  IRow _cloneRow(IRow row) {
    return IRow(
      width: row.width,
      height: row.height,
      ascent: row.ascent,
      rowFlex: row.rowFlex,
      startIndex: row.startIndex,
      isPageBreak: row.isPageBreak,
      isList: row.isList,
      listIndex: row.listIndex,
      offsetX: row.offsetX,
      offsetY: row.offsetY,
      elementList:
          row.elementList.map(_cloneRowElement).toList(growable: false),
      isWidthNotEnough: row.isWidthNotEnough,
      rowIndex: row.rowIndex,
      isSurround: row.isSurround,
    );
  }

  IRowElement _cloneRowElement(IRowElement element) {
    final List<IElement> cloneList =
        element_utils.cloneElementList(<IElement>[element]);
    final IElement clone = cloneList.first;
    final IElementMetrics metrics = IElementMetrics(
      width: element.metrics.width,
      height: element.metrics.height,
      boundingBoxAscent: element.metrics.boundingBoxAscent,
      boundingBoxDescent: element.metrics.boundingBoxDescent,
    );

    return IRowElement(
      metrics: metrics,
      style: element.style,
      left: element.left,
      id: clone.id,
      type: clone.type,
      value: clone.value,
      extension: clone.extension,
      externalId: clone.externalId,
      font: clone.font,
      size: clone.size,
      width: clone.width,
      height: clone.height,
      bold: clone.bold,
      color: clone.color,
      highlight: clone.highlight,
      italic: clone.italic,
      underline: clone.underline,
      strikeout: clone.strikeout,
      rowFlex: clone.rowFlex,
      rowMargin: clone.rowMargin,
      letterSpacing: clone.letterSpacing,
      textDecoration: clone.textDecoration,
      hide: clone.hide,
      groupIds:
          clone.groupIds == null ? null : List<String>.from(clone.groupIds!),
      colgroup: clone.colgroup,
      trList: clone.trList,
      borderType: clone.borderType,
      borderColor: clone.borderColor,
      borderWidth: clone.borderWidth,
      borderExternalWidth: clone.borderExternalWidth,
      translateX: clone.translateX,
      tableToolDisabled: clone.tableToolDisabled,
      tdId: clone.tdId,
      trId: clone.trId,
      tableId: clone.tableId,
      conceptId: clone.conceptId,
      pagingId: clone.pagingId,
      pagingIndex: clone.pagingIndex,
      valueList: clone.valueList == null
          ? null
          : element_utils.cloneElementList(clone.valueList!),
      url: clone.url,
      hyperlinkId: clone.hyperlinkId,
      actualSize: clone.actualSize,
      dashArray:
          clone.dashArray == null ? null : List<double>.from(clone.dashArray!),
      control: clone.control,
      controlId: clone.controlId,
      controlComponent: clone.controlComponent,
      checkbox: clone.checkbox,
      radio: clone.radio,
      laTexSVG: clone.laTexSVG,
      dateFormat: clone.dateFormat,
      dateId: clone.dateId,
      imgDisplay: clone.imgDisplay,
      imgFloatPosition: clone.imgFloatPosition == null
          ? null
          : Map<String, num>.from(clone.imgFloatPosition!),
      imgToolDisabled: clone.imgToolDisabled,
      block: clone.block,
      level: clone.level,
      titleId: clone.titleId,
      title: clone.title,
      listType: clone.listType,
      listStyle: clone.listStyle,
      listId: clone.listId,
      listWrap: clone.listWrap,
      areaId: clone.areaId,
      areaIndex: clone.areaIndex,
      area: clone.area,
    );
  }
}
