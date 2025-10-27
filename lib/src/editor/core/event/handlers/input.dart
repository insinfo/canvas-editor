// TODO: Translate from C:\\MyTsProjects\\canvas-editor\\src\\editor\\core\\event\\handlers\\input.ts
import '../../../dataset/constant/common.dart';
import '../../../dataset/constant/element.dart' as element_constants;
import '../../../dataset/enum/element.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/range.dart';
import '../../../utils/element.dart';
import '../../../utils/index.dart';

void input(String data, dynamic host) {
  final dynamic draw = host.getDraw();
  if (draw.isReadonly() == true || draw.isDisabled() == true) {
    return;
  }
  final dynamic position = draw.getPosition();
  final dynamic cursorPosition = position.getCursorPosition();
  if (data.isEmpty || cursorPosition == null) {
    return;
  }
  final bool isComposing = host.isComposing == true;
  final Map<String, dynamic>? compositionInfo =
      host.compositionInfo as Map<String, dynamic>?;
  if (isComposing && compositionInfo?['value'] == data) {
    return;
  }
  final dynamic rangeManager = draw.getRange();
  if (rangeManager.getIsCanInput() != true) {
    return;
  }
  final IRangeElementStyle? defaultStyle =
      (rangeManager.getDefaultStyle() as IRangeElementStyle?) ??
          compositionInfo?['defaultStyle'] as IRangeElementStyle?;
  removeComposingInput(host);
  if (!isComposing) {
    draw.getCursor().clearAgentDomValue();
  }
  final String text = data.replaceAll('\n', ZERO);
  final IRange currentRange = rangeManager.getRange() as IRange;
  final int startIndex = currentRange.startIndex;
  final int endIndex = currentRange.endIndex;
  final List<IElement> elementList =
      (draw.getElementList() as List).cast<IElement>();
  final IElement? copyElement =
      rangeManager.getRangeAnchorStyle(elementList, endIndex) as IElement?;
  if (copyElement == null) {
    return;
  }
  final bool isDesignMode = draw.isDesignMode() == true;
  final List<IElement> inputData = splitText(text)
      .map((String value) => _createInputElement(
            value: value,
            copyElement: copyElement,
            defaultStyle: defaultStyle,
            elementList: elementList,
            endIndex: endIndex,
            isDesignMode: isDesignMode,
            isComposing: isComposing,
          ))
      .toList(growable: false);
  final dynamic control = draw.getControl();
  int curIndex = -1;
  if (control.getActiveControl() != null &&
      control.getIsRangeWithinControl() == true) {
    curIndex = control.setValue(inputData) as int? ?? -1;
    if (!isComposing) {
      control.emitControlContentChange();
    }
  } else {
    final int start = startIndex + 1;
    if (startIndex != endIndex) {
      draw.spliceElementList(
        elementList,
        start,
        endIndex - startIndex,
      );
    }
    formatElementContext(
      elementList,
      inputData,
      startIndex,
      options: FormatElementContextOption(
        editorOptions: draw.getOptions() as IEditorOption?,
      ),
    );
    draw.spliceElementList(elementList, start, 0, inputData);
    curIndex = startIndex + inputData.length;
  }
  if (curIndex >= 0) {
    rangeManager.setRange(curIndex, curIndex);
    draw.render(
      IDrawOption(
        curIndex: curIndex,
        isSubmitHistory: !isComposing,
      ),
    );
  }
  if (isComposing && curIndex >= 0) {
    host.compositionInfo = <String, dynamic>{
      'elementList': elementList,
      'value': text,
      'startIndex': curIndex - inputData.length,
      'endIndex': curIndex,
      'defaultStyle': defaultStyle,
    };
  }
}

void removeComposingInput(dynamic host) {
  final Map<String, dynamic>? info =
      host.compositionInfo as Map<String, dynamic>?;
  if (info == null) {
    return;
  }
  final List<IElement> elementList =
      (info['elementList'] as List?)?.cast<IElement>() ?? <IElement>[];
  final int startIndex = info['startIndex'] as int? ?? -1;
  final int endIndex = info['endIndex'] as int? ?? -1;
  if (startIndex >= 0 && endIndex >= startIndex) {
    final int removeCount = endIndex - startIndex;
    if (removeCount > 0 &&
        startIndex + 1 >= 0 &&
        startIndex + 1 + removeCount <= elementList.length) {
      elementList.removeRange(
        startIndex + 1,
        startIndex + 1 + removeCount,
      );
    }
    final dynamic rangeManager = host.getDraw().getRange();
    rangeManager.setRange(startIndex, startIndex);
  }
  host.compositionInfo = null;
}

IElement _createInputElement({
  required String value,
  required IElement copyElement,
  required IRangeElementStyle? defaultStyle,
  required List<IElement> elementList,
  required int endIndex,
  required bool isDesignMode,
  required bool isComposing,
}) {
  final IElement newElement = IElement(value: value);
  if (!isDesignMode &&
      (copyElement.title?.disabled == true ||
          copyElement.control?.disabled == true)) {
    return newElement;
  }
  final IElement? nextElement =
      endIndex + 1 < elementList.length ? elementList[endIndex + 1] : null;
  final ElementType? copyType = copyElement.type;
  final bool shouldCopyElementData = copyType == null ||
      copyType == ElementType.text ||
      (copyType == ElementType.hyperlink &&
          nextElement?.type == ElementType.hyperlink) ||
      (copyType == ElementType.date && nextElement?.type == ElementType.date) ||
      (copyType == ElementType.subscript &&
          nextElement?.type == ElementType.subscript) ||
      (copyType == ElementType.superscript &&
          nextElement?.type == ElementType.superscript);
  if (shouldCopyElementData) {
    assignElementAttributes(
      copyElement,
      newElement,
      element_constants.editorElementCopyAttr,
    );
  }
  if (defaultStyle != null || copyType == ElementType.tab) {
    assignElementAttributes(
      copyElement,
      newElement,
      element_constants.editorElementStyleAttr,
    );
    _applyRangeDefaultStyle(newElement, defaultStyle);
  }
  if (isComposing) {
    newElement.underline = true;
  }
  return newElement;
}

void _applyRangeDefaultStyle(
  IElement element,
  IRangeElementStyle? style,
) {
  if (style == null) {
    return;
  }
  if (style.bold != null) {
    element.bold = style.bold;
  }
  if (style.color != null) {
    element.color = style.color;
  }
  if (style.highlight != null) {
    element.highlight = style.highlight;
  }
  if (style.font != null) {
    element.font = style.font;
  }
  if (style.size != null) {
    element.size = style.size;
  }
  if (style.italic != null) {
    element.italic = style.italic;
  }
  if (style.underline != null) {
    element.underline = style.underline;
  }
  if (style.strikeout != null) {
    element.strikeout = style.strikeout;
  }
}
