import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/range.dart';
import '../../../utils/clipboard.dart';

Future<void> cut(dynamic host) async {
  final dynamic draw = host.getDraw();
  final dynamic rangeManager = draw.getRange();
  final IRange range = rangeManager.getRange() as IRange;
  final int startIndex = range.startIndex;
  final int endIndex = range.endIndex;
  if ((startIndex == -1) && (endIndex == -1)) {
    return;
  }
  if (draw.isReadonly() == true || rangeManager.getIsCanInput() != true) {
    return;
  }

  final List<IElement> elementList =
      (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];
  int start = startIndex;
  int end = endIndex;

  if (startIndex == endIndex && elementList.isNotEmpty) {
    final dynamic position = draw.getPosition();
    final List<IElementPosition> positionList =
        (position.getPositionList() as List?)?.cast<IElementPosition>() ??
            <IElementPosition>[];
    if (startIndex >= 0 && startIndex < positionList.length) {
      final IElementPosition startPosition = positionList[startIndex];
      final int curRowNo = startPosition.rowNo;
      final int curPageNo = startPosition.pageNo;
      final List<int> cutElementIndexList = <int>[];
      for (var p = 0; p < positionList.length; p++) {
        final IElementPosition pos = positionList[p];
        if (pos.pageNo > curPageNo) {
          break;
        }
        if (pos.pageNo == curPageNo && pos.rowNo == curRowNo) {
          cutElementIndexList.add(p);
        }
      }
      if (cutElementIndexList.isNotEmpty) {
        final int firstElementIndex = cutElementIndexList.first - 1;
        start = firstElementIndex < 0 ? 0 : firstElementIndex;
        end = cutElementIndexList.last;
      }
    }
  }

  final int sliceStart = (start + 1).clamp(0, elementList.length);
  final int sliceEnd = (end + 1).clamp(sliceStart, elementList.length);
  await writeElementList(
    elementList.sublist(sliceStart, sliceEnd),
    draw.getOptions() as IEditorOption,
  );

  final dynamic control = draw.getControl();
  int curIndex;
  if (control?.getActiveControl() != null &&
      control.getIsRangeWithinControl() == true) {
    final dynamic controlResult = control.cut();
    curIndex = (controlResult as num?)?.toInt() ?? start;
    control.emitControlContentChange();
  } else {
    final int deleteCount =
        (end - start).clamp(0, elementList.length - sliceStart);
    if (deleteCount > 0) {
      draw.spliceElementList(
        elementList,
        sliceStart,
        deleteCount,
      );
    }
    curIndex = start;
  }

  rangeManager.setRange(curIndex, curIndex);
  draw.render(IDrawOption(curIndex: curIndex));
}
