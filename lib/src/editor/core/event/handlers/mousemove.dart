import 'dart:html' as html;

import '../../../dataset/enum/common.dart';
import '../../../dataset/enum/control.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/draw.dart';
import '../../../interface/element.dart';
import '../../../interface/position.dart';
import '../../../interface/range.dart';

void mousemove(dynamic evt, dynamic host) {
  final dynamic draw = host.getDraw();
  final double offsetX = (evt?.offsetX as num?)?.toDouble() ?? 0;
  final double offsetY = (evt?.offsetY as num?)?.toDouble() ?? 0;

  if (host.isAllowDrag == true) {
    final IRange? cacheRange = host.cacheRange as IRange?;
    final List<IElementPosition> cachePositionList =
        (host.cachePositionList as List?)?.cast<IElementPosition>() ??
            <IElementPosition>[];
    if (cacheRange != null && cachePositionList.isNotEmpty) {
      final int loopStart = cacheRange.startIndex + 1;
      final int loopEnd = cacheRange.endIndex;
      for (int p = loopStart; p <= loopEnd; p++) {
        if (p < 0 || p >= cachePositionList.length) {
          continue;
        }
        final IElementPosition position = cachePositionList[p];
        final List<double> leftTop =
            position.coordinate['leftTop'] ?? <double>[0, 0];
        final List<double> rightBottom =
            position.coordinate['rightBottom'] ?? <double>[0, 0];
        final double left = leftTop.isNotEmpty ? leftTop[0] : 0;
        final double top = leftTop.length > 1 ? leftTop[1] : 0;
        final double right = rightBottom.isNotEmpty ? rightBottom[0] : left;
        final double bottom = rightBottom.length > 1 ? rightBottom[1] : top;
        final bool withinHorizontal = offsetX >= left && offsetX <= right;
        final bool withinVertical = offsetY >= top && offsetY <= bottom;
        if (withinHorizontal && withinVertical) {
          return;
        }
      }

      final List<IElement> cacheElementList =
          (host.cacheElementList as List?)?.cast<IElement>() ?? <IElement>[];
      final int cacheStartIndex = cacheRange.startIndex;
      if (cacheStartIndex != 0 &&
          cacheStartIndex >= 0 &&
          cacheStartIndex < cacheElementList.length) {
        final IElement dragElement = cacheElementList[cacheStartIndex];
        final ImageDisplay? display = dragElement.imgDisplay;
        if (dragElement.type == ElementType.image &&
            (display == ImageDisplay.surround ||
                display == ImageDisplay.floatTop ||
                display == ImageDisplay.floatBottom)) {
          draw.getPreviewer()?.clearResizer();
          draw.getImageParticle()?.dragFloatImage(
                (evt?.movementX as num?)?.toDouble() ?? 0,
                (evt?.movementY as num?)?.toDouble() ?? 0,
              );
        }
      }
    }
    try {
      host.dragover(evt);
    } catch (_) {}
    host.isAllowDrop = true;
    return;
  }

  if (host.isAllowSelection != true || host.mouseDownStartPosition == null) {
    return;
  }

  final html.Element? target = evt?.target as html.Element?;
  final String? pageIndex = target?.dataset['index'];
  if (pageIndex != null) {
    final int? parsed = int.tryParse(pageIndex);
    if (parsed != null) {
      draw.setPageNo(parsed);
    }
  }

  final dynamic position = draw.getPosition();
  final ICurrentPosition positionResult = position.getPositionByXY(
    IGetPositionByXYPayload(x: offsetX, y: offsetY),
  ) as ICurrentPosition;
  if (positionResult.index == -1) {
    return;
  }

  final ICurrentPosition startPosition =
      host.mouseDownStartPosition as ICurrentPosition;
  final bool isTable = positionResult.isTable == true;
  final bool startIsTable = startPosition.isTable == true;
  final int endIndex = isTable
      ? (positionResult.tdValueIndex ?? positionResult.index)
      : positionResult.index;
  final dynamic rangeManager = draw.getRange();

  if (isTable &&
      startIsTable &&
      (positionResult.tdIndex != startPosition.tdIndex ||
          positionResult.trIndex != startPosition.trIndex)) {
    rangeManager.setRange(
      endIndex,
      endIndex,
      positionResult.tableId,
      startPosition.tdIndex,
      positionResult.tdIndex,
      startPosition.trIndex,
      positionResult.trIndex,
    );
    position.setPositionContext(
      IPositionContext(
        isTable: isTable,
        index: positionResult.index,
        trIndex: positionResult.trIndex,
        tdIndex: positionResult.tdIndex,
        tdId: positionResult.tdId,
        trId: positionResult.trId,
        tableId: positionResult.tableId,
      ),
    );
  } else {
    int end = endIndex != -1 ? endIndex : 0;
    final String? startTableId = startPosition.tableId;
    if ((startIsTable || isTable) && startTableId != positionResult.tableId) {
      return;
    }
    int start = startPosition.index;
    if (start > end) {
      final int temp = start;
      start = end;
      end = temp;
    }
    if (start == end) {
      return;
    }

    final List<IElement> elementList =
        (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];
    if (elementList.isEmpty) {
      return;
    }
    if (start + 1 >= 0 &&
        start + 1 < elementList.length &&
        end >= 0 &&
        end < elementList.length) {
      final IElement startElement = elementList[start + 1];
      final IElement endElement = elementList[end];
      if (startElement.controlComponent == ControlComponent.placeholder &&
          endElement.controlComponent == ControlComponent.placeholder &&
          startElement.controlId == endElement.controlId) {
        return;
      }
    }

    rangeManager.setRange(start, end);
  }

  draw.render(
    IDrawOption(
      isSubmitHistory: false,
      isSetCursor: false,
      isCompute: false,
    ),
  );
}
