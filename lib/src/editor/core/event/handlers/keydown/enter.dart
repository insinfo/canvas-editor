import 'dart:html';

import '../../../../dataset/constant/common.dart';
import '../../../../dataset/enum/control.dart';
import '../../../../interface/draw.dart';
import '../../../../interface/editor.dart';
import '../../../../interface/element.dart';
import '../../../../interface/range.dart';
import '../../../../utils/element.dart' as element_utils;
import '../../../draw/draw.dart' show Draw;
import '../../../draw/particle/list_particle.dart';
import '../../../range/range_manager.dart';
import '../../canvas_event.dart' show CanvasEvent;

void enter(KeyboardEvent evt, CanvasEvent host) {
  final Draw draw = host.getDraw() as Draw;
  if (draw.isReadonly() == true) {
    return;
  }

  final RangeManager rangeManager = draw.getRange() as RangeManager;
  if (rangeManager.getIsCanInput() != true) {
    return;
  }

  final IRange range = rangeManager.getRange();
  final int startIndex = range.startIndex;
  final int endIndex = range.endIndex;
  final bool isCollapsed = rangeManager.getIsCollapsed() == true;
  final List<IElement> elementList =
      (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];

  if (startIndex < 0 || startIndex >= elementList.length) {
    return;
  }
  if (endIndex < 0 || endIndex >= elementList.length) {
    return;
  }

  final IElement startElement = elementList[startIndex];
  final IElement endElement = elementList[endIndex];

  if (isCollapsed &&
      endElement.listId != null &&
      endElement.value == ZERO &&
      (endIndex + 1 >= elementList.length ||
          elementList[endIndex + 1].listId != endElement.listId)) {
    final ListParticle? listParticle = draw.getListParticle() as ListParticle?;
    listParticle?.unsetList();
    return;
  }

  final IElement enterText = IElement(value: ZERO);
  if (evt.shiftKey == true && startElement.listId != null) {
    enterText.listWrap = true;
  }

  element_utils.formatElementContext(
    elementList,
    <IElement>[enterText],
    startIndex,
    options: element_utils.FormatElementContextOption(
      isBreakWhenWrap: true,
      editorOptions: draw.getOptions() as IEditorOption?,
    ),
  );

  if (evt.shiftKey == true &&
      endElement.areaId != null &&
      (endIndex + 1 >= elementList.length ||
          elementList[endIndex + 1].areaId != endElement.areaId)) {
    enterText
      ..areaId = null
      ..area = null;
  }

  final bool isTitleBoundary = endElement.titleId != null &&
      (endIndex + 1 >= elementList.length ||
          elementList[endIndex + 1].titleId != endElement.titleId);
  if (!isTitleBoundary) {
  final IElement? copyElement =
    rangeManager.getRangeAnchorStyle(elementList, endIndex);
    if (copyElement != null) {
      enterText
        ..rowFlex = copyElement.rowFlex
        ..rowMargin = copyElement.rowMargin;
      if (copyElement.controlComponent != ControlComponent.postfix) {
        enterText
          ..bold = copyElement.bold
          ..color = copyElement.color
          ..highlight = copyElement.highlight
          ..font = copyElement.font
          ..size = copyElement.size
          ..italic = copyElement.italic
          ..underline = copyElement.underline
          ..strikeout = copyElement.strikeout
          ..textDecoration = copyElement.textDecoration;
      }
    }
  }

  final dynamic control = draw.getControl();
  final dynamic activeControl = control?.getActiveControl();
  int? curIndex;

  if (activeControl != null && control.getIsRangeWithinControl() == true) {
    curIndex = (control.setValue(<IElement>[enterText]) as num?)?.toInt();
    control.emitControlContentChange();
  } else {
    final dynamic position = draw.getPosition();
    final IElementPosition? cursorPosition =
        position.getCursorPosition() as IElementPosition?;
    if (cursorPosition == null) {
      return;
    }
    final int index = cursorPosition.index;
    if (isCollapsed) {
      draw.spliceElementList(elementList, index + 1, 0, <IElement>[enterText]);
    } else {
      draw.spliceElementList(
        elementList,
        startIndex + 1,
        endIndex - startIndex,
        <IElement>[enterText],
      );
    }
    curIndex = index + 1;
  }

  if (curIndex != null && curIndex >= 0) {
    rangeManager.setRange(curIndex, curIndex);
    draw.render(IDrawOption(curIndex: curIndex));
  }

  evt.preventDefault();
}
