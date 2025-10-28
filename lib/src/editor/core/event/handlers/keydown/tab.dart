import 'dart:html';

import '../../../../dataset/constant/element.dart' as element_constants;
import '../../../../dataset/enum/element.dart';
import '../../../../dataset/enum/observer.dart';
import '../../../../interface/editor.dart';
import '../../../../interface/element.dart';
import '../../../../interface/range.dart';
import '../../../../utils/element.dart' as element_utils;

void tab(KeyboardEvent evt, dynamic host) {
  final dynamic draw = host.getDraw();
  if (draw.isReadonly() == true) {
    return;
  }

  evt.preventDefault();

  final dynamic control = draw.getControl();
  final dynamic activeControl = control?.getActiveControl();
  if (activeControl != null && control.getIsRangeWithinControl() == true) {
    control.initNextControl(<String, dynamic>{
      'direction': evt.shiftKey ? MoveDirection.up : MoveDirection.down,
    });
    return;
  }

  final dynamic rangeManager = draw.getRange();
  final IRange range = rangeManager.getRange() as IRange;
  final int startIndex = range.startIndex;
  final int endIndex = range.endIndex;

  final List<IElement> elementList =
      (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];

  final IElement tabElement = IElement(
    type: ElementType.tab,
    value: '',
  );

  final IElement? anchorElement =
      rangeManager.getRangeAnchorStyle(elementList, endIndex) as IElement?;
  if (anchorElement != null) {
    element_utils.assignElementAttributes(
      anchorElement,
      tabElement,
      element_constants.editorElementStyleAttr,
    );
  }

  element_utils.formatElementContext(
    elementList,
    <IElement>[tabElement],
    startIndex,
    options: element_utils.FormatElementContextOption(
      editorOptions: draw.getOptions() as IEditorOption?,
    ),
  );

  draw.insertElementList(<IElement>[tabElement]);
}
