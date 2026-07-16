import 'dart:html' as html;

import '../../../dataset/constant/common.dart';
import '../../../dataset/constant/element.dart' as element_constants;
import '../../../dataset/enum/element.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/range.dart';
import '../../../utils/element.dart';
import '../../../utils/index.dart';
import '../canvas_event.dart' show CanvasEvent, CompositionInfo;
import '../../draw/draw.dart' show Draw;
import '../../layout/layout_invalidation.dart';
import '../../layout/layout_request.dart';
import '../../range/range_manager.dart';

void input(String data, CanvasEvent host) {
  if (data.isEmpty) {
    return;
  }
  // Instrumentação da tecla (Draw.debugRenderTiming): pré-render × render.
  final bool timing = Draw.debugRenderTiming;
  final double inputT0 = timing ? html.window.performance.now().toDouble() : 0;
  final Draw draw = host.getDraw() as Draw;
  if (draw.isReadonly() == true || draw.isDisabled() == true) {
    return;
  }
  final dynamic position = draw.getPosition();
  final dynamic cursorPosition = position.getCursorPosition();
  if (cursorPosition == null) {
    return;
  }
  final bool isComposing = host.isComposing;
  final CompositionInfo? compositionInfo = host.compositionInfo;
  if (isComposing && compositionInfo?.value == data) {
    return;
  }
  final RangeManager rangeManager = draw.getRange() as RangeManager;
  if (rangeManager.getIsCanInput() != true) {
    return;
  }
  final IRangeElementStyle? defaultStyle =
      rangeManager.getDefaultStyle() ?? compositionInfo?.defaultStyle;
  final IRange preCompositionRange = rangeManager.getRange();
  final List<IElement> elementList = draw.getElementList();
  final int originalStartIndex =
      compositionInfo?.originalStartIndex ?? preCompositionRange.startIndex;
  final List<IElement> originalRemovedElements;
  if (compositionInfo != null) {
    originalRemovedElements = compositionInfo.originalRemovedElements;
  } else {
    final int selectionStart = preCompositionRange.startIndex + 1;
    final int selectionCount =
        preCompositionRange.endIndex - preCompositionRange.startIndex;
    originalRemovedElements = selectionCount > 0 &&
            selectionStart >= 0 &&
            selectionStart + selectionCount <= elementList.length
        ? cloneElementList(
            elementList.sublist(
              selectionStart,
              selectionStart + selectionCount,
            ),
          )
        : <IElement>[];
  }
  removeComposingInput(host);
  if (!isComposing && compositionInfo != null) {
    final List<IElement> restoredSelection =
        cloneElementList(originalRemovedElements);
    if (restoredSelection.isNotEmpty) {
      draw.spliceElementList(
        elementList,
        originalStartIndex + 1,
        0,
        restoredSelection,
      );
    }
    rangeManager.setRange(
      originalStartIndex,
      originalStartIndex + restoredSelection.length,
    );
  }
  if (!isComposing) {
    final dynamic cursor = draw.getCursor();
    cursor?.clearAgentDomValue();
  }
  final String text = data.replaceAll('\n', ZERO);
  final IRange currentRange = rangeManager.getRange();
  final int startIndex = currentRange.startIndex;
  final int endIndex = currentRange.endIndex;
  final IElement? copyElement =
      rangeManager.getRangeAnchorStyle(elementList, endIndex);
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
  final dynamic activeControl = control?.ensureActiveControl();
  int curIndex = -1;
  LayoutInvalidation? mutationInvalidation;
  if (control != null &&
      activeControl != null &&
      control.getIsRangeWithinControl() == true) {
    final dynamic result = control.setValue(inputData);
    if (result is int) {
      curIndex = result;
    } else if (result is num) {
      curIndex = result.toInt();
    }
    if (!isComposing) {
      control.emitControlContentChange();
    }
  } else {
    final int start = startIndex + 1;
    formatElementContext(
      elementList,
      inputData,
      startIndex,
      options: FormatElementContextOption(
        editorOptions: draw.getOptions() as IEditorOption?,
      ),
    );
    curIndex = startIndex + inputData.length;
    mutationInvalidation = draw.applyTextMutation(
      elementList: elementList,
      start: start,
      deleteCount: endIndex - startIndex,
      replacement: inputData,
      curIndex: curIndex,
      // Enter e caracteres consecutivos formam a mesma rajada inseridora. Isso
      // mantém Enter+digitação repetidos em um único splice/restorer compacto.
      mergeKey: 'text-insert',
      recordHistory: !isComposing,
    );
  }
  if (curIndex >= 0) {
    final double preRenderT =
        timing ? html.window.performance.now().toDouble() : 0;
    rangeManager.setRange(curIndex, curIndex);
    if (mutationInvalidation != null) {
      draw.renderUpdate(
        LayoutRequest(
          invalidation: mutationInvalidation,
          curIndex: curIndex,
          notifyContentChange: !isComposing,
        ),
      );
    } else {
      // Conteudo de control ainda usa o fallback legado ate que Table/Control
      // changes sejam migrados para transactions tipadas.
      draw.render(
        IDrawOption(
          curIndex: curIndex,
          isSubmitHistory: !isComposing,
          isSubmitHistoryDeferred: true,
          fastLayoutIndex: curIndex,
        ),
      );
    }
    if (timing) {
      final double end = html.window.performance.now().toDouble();
      html.window.console.log('[input] pre='
          '${(preRenderT - inputT0).toStringAsFixed(0)}ms '
          'render=${(end - preRenderT).toStringAsFixed(0)}ms '
          'total=${(end - inputT0).toStringAsFixed(0)}ms');
    }
  }
  if (isComposing && curIndex >= 0) {
    host.compositionInfo = CompositionInfo(
      elementList: elementList,
      startIndex: curIndex - inputData.length,
      endIndex: curIndex,
      value: text,
      defaultStyle: defaultStyle,
      originalStartIndex: originalStartIndex,
      originalRemovedElements: originalRemovedElements,
    );
  }
}

void removeComposingInput(
  CanvasEvent host, {
  bool restoreOriginalSelection = false,
}) {
  final CompositionInfo? info = host.compositionInfo;
  if (info == null) {
    return;
  }
  final List<IElement> elementList = info.elementList;
  final int startIndex = info.startIndex;
  final int endIndex = info.endIndex;
  if (startIndex >= 0 && endIndex >= startIndex) {
    final int removeCount = endIndex - startIndex;
    if (removeCount > 0 && startIndex + 1 + removeCount <= elementList.length) {
      (host.getDraw() as Draw).spliceElementList(
        elementList,
        startIndex + 1,
        removeCount,
      );
    }
    final RangeManager rangeManager = host.getDraw().getRange() as RangeManager;
    if (restoreOriginalSelection) {
      final List<IElement> restored =
          cloneElementList(info.originalRemovedElements);
      if (restored.isNotEmpty) {
        (host.getDraw() as Draw).spliceElementList(
          elementList,
          info.originalStartIndex + 1,
          0,
          restored,
        );
      }
      rangeManager.setRange(
        info.originalStartIndex,
        info.originalStartIndex + restored.length,
      );
    } else {
      rangeManager.setRange(startIndex, startIndex);
    }
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
