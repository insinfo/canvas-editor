// ignore_for_file: avoid_dynamic_calls

import 'dart:html';

import '../../dataset/constant/common.dart';
import '../../dataset/constant/element.dart';
import '../../dataset/constant/title.dart';
import '../../dataset/constant/watermark.dart';
import '../../dataset/enum/common.dart';
import '../../dataset/enum/control.dart';
import '../../dataset/enum/editor.dart';
import '../../dataset/enum/element.dart';
import '../../dataset/enum/list.dart';
import '../../dataset/enum/observer.dart';
import '../../dataset/enum/row.dart';
import '../../dataset/enum/table/table.dart';
import '../../dataset/enum/title.dart';
import '../../dataset/enum/vertical_align.dart';
import '../../dataset/enum/watermark.dart';
import '../../interface/badge.dart';
import '../../interface/catalog.dart';
import '../../interface/command.dart';
import '../../interface/draw.dart';
import '../../interface/editor.dart';
import '../../interface/element.dart';
import '../../interface/event.dart';
import '../../interface/margin.dart';
import '../../interface/position.dart';
import '../../interface/range.dart';
import '../../interface/search.dart';
import '../../interface/watermark.dart';
import '../../utils/element.dart' as element_utils;
import '../../utils/index.dart';
import '../../utils/print.dart';
import '../event/handlers/paste.dart';

/// Partial translation of the original TypeScript `CommandAdapt` class.
///
/// At this stage many downstream components (`Draw`, `RangeManager`, etc.) are
/// still under active migration, so we keep the member types dynamic and focus
/// on replicating the command wiring and rich-text behaviours that the Dart
/// layer already depends on. Remaining methods from the TypeScript source will
/// be ported incrementally.
class CommandAdapt {
  CommandAdapt(dynamic drawInstance)
      : draw = drawInstance,
        range = drawInstance.getRange(),
        position = drawInstance.getPosition(),
        historyManager = drawInstance.getHistoryManager(),
        canvasEvent = drawInstance.getCanvasEvent(),
        options = drawInstance.getOptions(),
        control = drawInstance.getControl(),
        workerManager = drawInstance.getWorkerManager(),
        searchManager = drawInstance.getSearch(),
        i18n = drawInstance.getI18n(),
        zone = drawInstance.getZone(),
        tableOperate = drawInstance.getTableOperate();

  final dynamic draw;
  final dynamic range;
  final dynamic position;
  final dynamic historyManager;
  final dynamic canvasEvent;
  final dynamic options;
  final dynamic control;
  final dynamic workerManager;
  final dynamic searchManager;
  final dynamic i18n;
  final dynamic zone;
  final dynamic tableOperate;

  // ---------------------------------------------------------------------------
  // Global commands

  void mode(EditorMode payload) {
    draw.setMode(payload);
  }

  Future<void> cut() async {
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    await canvasEvent.cut();
  }

  Future<void> copy([ICopyOption? payload]) async {
    await canvasEvent.copy(payload);
  }

  void paste([IPasteOption? payload]) {
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    pasteByApi(canvasEvent, payload);
  }

  void selectAll() {
    canvasEvent.selectAll();
  }

  void backspace() {
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    final List<IElement> elementList = _castElementList(draw.getElementList());
    final IRange currentRange = range.getRange();
    final int startIndex = currentRange.startIndex;
    final int endIndex = currentRange.endIndex;
    final bool isCollapsed = startIndex == endIndex;

    if (isCollapsed &&
        startIndex == 0 &&
        elementList.isNotEmpty &&
        elementList[startIndex].value == ZERO) {
      return;
    }

    if (!isCollapsed) {
      draw.spliceElementList(
        elementList,
        startIndex + 1,
        endIndex - startIndex,
      );
    } else {
      draw.spliceElementList(elementList, startIndex, 1);
    }
    final int curIndex = isCollapsed ? startIndex - 1 : startIndex;
    range.setRange(curIndex, curIndex);
    draw.render(IDrawOption(curIndex: curIndex));
  }

  void setRange(
    int startIndex,
    int endIndex, [
    String? tableId,
    int? startTdIndex,
    int? endTdIndex,
    int? startTrIndex,
    int? endTrIndex,
  ]) {
    if (startIndex < 0 || endIndex < 0 || endIndex < startIndex) {
      return;
    }
    range.setRange(
      startIndex,
      endIndex,
      tableId,
      startTdIndex,
      endTdIndex,
      startTrIndex,
      endTrIndex,
    );
    final bool isCollapsed = startIndex == endIndex;
    draw.render(
      IDrawOption(
        curIndex: isCollapsed ? startIndex : null,
        isCompute: false,
        isSubmitHistory: false,
        isSetCursor: isCollapsed,
      ),
    );
  }

  void replaceRange(IRange payload) {
    setRange(
      payload.startIndex,
      payload.endIndex,
      payload.tableId,
      payload.startTdIndex,
      payload.endTdIndex,
      payload.startTrIndex,
      payload.endTrIndex,
    );
  }

  void setPositionContext(IRange payload) {
    final String? tableId = payload.tableId;
    final int? startTrIndex = payload.startTrIndex;
    final int? startTdIndex = payload.startTdIndex;
    final List<IElement> elementList =
        _castElementList(draw.getOriginalElementList());

    if (tableId != null) {
      final int tableElementIndex =
          elementList.indexWhere((IElement el) => el.id == tableId);
      if (tableElementIndex == -1) {
        return;
      }
      final IElement tableElement = elementList[tableElementIndex];
      final List<ITr>? trList = tableElement.trList;
      if (trList == null || startTrIndex == null || startTdIndex == null) {
        return;
      }
      if (startTrIndex < 0 || startTrIndex >= trList.length) {
        return;
      }
      final ITr tr = trList[startTrIndex];
      if (startTdIndex < 0 || startTdIndex >= tr.tdList.length) {
        return;
      }
      final dynamic td = tr.tdList[startTdIndex];
      position.setPositionContext(
        IPositionContext(
          isTable: true,
          index: tableElementIndex,
          trIndex: startTrIndex,
          tdIndex: startTdIndex,
          tdId: td.id,
          trId: tr.id,
          tableId: tableId,
        ),
      );
    } else {
      position.setPositionContext(
        IPositionContext(isTable: false),
      );
    }
  }

  void forceUpdate([IForceUpdateOption? option]) {
    final bool isSubmitHistory = option?.isSubmitHistory ?? false;
    range.clearRange();
    draw.render(
      IDrawOption(
        isSubmitHistory: isSubmitHistory,
        isSetCursor: false,
      ),
    );
  }

  void blur() {
    range.clearRange();
    draw.getCursor().recoveryCursor();
  }

  void undo() {
    if (_isReadonly()) {
      return;
    }
    historyManager.undo();
  }

  void redo() {
    if (_isReadonly()) {
      return;
    }
    historyManager.redo();
  }

  // ---------------------------------------------------------------------------
  // Painter and formatting

  void painter(IPainterOption options) {
    final dynamic painterStyleContext = draw.getPainterStyle();
    if (!options.isDblclick && painterStyleContext != null) {
      canvasEvent.clearPainterStyle();
      return;
    }
    final List<IElement> selection = _castElementList(range.getSelection());
    if (selection.isEmpty) {
      return;
    }
    final IElementStyle painterStyle = IElementStyle();
    for (final IElement element in selection) {
      for (final String attr in editorElementStyleAttr) {
        if (_getStyleValue(painterStyle, attr) == null) {
          _setStyleValue(painterStyle, attr, _getElementAttr(element, attr));
        }
      }
    }
    draw.setPainterStyle(painterStyle, options);
  }

  void applyPainterStyle() {
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    canvasEvent.applyPainterStyle();
  }

  void format([IRichtextOption? options]) {
    final bool isIgnoreDisabledRule = options?.isIgnoreDisabledRule ?? false;
    final bool isDisabled =
        !isIgnoreDisabledRule && (_isReadonly() || _isDisabled());
    if (isDisabled) {
      return;
    }

    final List<IElement> selection =
        _castElementList(range.getSelectionElementList());
    final List<IElement> changeElementList = <IElement>[];
    final IDrawOption renderOption = IDrawOption();

    if (selection.isNotEmpty) {
      changeElementList.addAll(selection);
      renderOption.isSetCursor = false;
    } else {
      final IRange currentRange = range.getRange();
      final int endIndex = currentRange.endIndex;
      final List<IElement> elementList =
          _castElementList(draw.getElementList());
      if (endIndex >= 0 && endIndex < elementList.length) {
        final IElement enterElement = elementList[endIndex];
        if (enterElement.value == ZERO) {
          changeElementList.add(enterElement);
          renderOption.curIndex = endIndex;
        }
      }
    }

    if (changeElementList.isEmpty) {
      return;
    }

    for (final IElement element in changeElementList) {
      for (final String attr in editorElementStyleAttr) {
        _clearElementAttr(element, attr);
      }
    }
    draw.render(renderOption);
  }

  void font(String payload, [IRichtextOption? options]) {
    final bool isIgnoreDisabledRule = options?.isIgnoreDisabledRule ?? false;
    final bool isDisabled =
        !isIgnoreDisabledRule && (_isReadonly() || _isDisabled());
    if (isDisabled) {
      return;
    }

    final List<IElement> selection =
        _castElementList(range.getSelectionElementList());
    if (selection.isNotEmpty) {
      for (final IElement element in selection) {
        element.font = payload;
      }
      draw.render(IDrawOption(isSetCursor: false));
      return;
    }

    final IRange currentRange = range.getRange();
    final int endIndex = currentRange.endIndex;
    final List<IElement> elementList = _castElementList(draw.getElementList());
    if (endIndex < 0 || endIndex >= elementList.length) {
      return;
    }
    final IElement enterElement = elementList[endIndex];
    range.setDefaultStyle(IElementStyle(font: payload));
    bool isSubmitHistory = true;
    if (enterElement.value == ZERO) {
      enterElement.font = payload;
    } else {
      isSubmitHistory = false;
    }
    draw.render(
      IDrawOption(
        isSubmitHistory: isSubmitHistory,
        curIndex: endIndex,
        isCompute: false,
      ),
    );
  }

  void size(int payload, [IRichtextOption? options]) {
    final bool isIgnoreDisabledRule = options?.isIgnoreDisabledRule ?? false;
    final bool isDisabled =
        !isIgnoreDisabledRule && (_isReadonly() || _isDisabled());
    if (isDisabled) {
      return;
    }

    final int minSize = this.options.minSize ?? payload;
    final int maxSize = this.options.maxSize ?? payload;
    final int defaultSize = this.options.defaultSize ?? payload;

    if (payload < minSize || payload > maxSize) {
      return;
    }

    final List<IElement> selection =
        _castElementList(range.getTextLikeSelectionElementList());
    final List<IElement> changeElementList = <IElement>[];
    final IDrawOption renderOption = IDrawOption();

    if (selection.isNotEmpty) {
      changeElementList.addAll(selection);
      renderOption.isSetCursor = false;
    } else {
      final IRange currentRange = range.getRange();
      final int endIndex = currentRange.endIndex;
      final List<IElement> elementList =
          _castElementList(draw.getElementList());
      if (endIndex >= 0 && endIndex < elementList.length) {
        final IElement enterElement = elementList[endIndex];
        range.setDefaultStyle(IElementStyle(size: payload));
        if (enterElement.value == ZERO) {
          changeElementList.add(enterElement);
          renderOption.curIndex = endIndex;
        } else {
          draw.render(
            IDrawOption(
              curIndex: endIndex,
              isCompute: false,
              isSubmitHistory: false,
            ),
          );
        }
      }
    }

    if (changeElementList.isEmpty) {
      return;
    }

    bool isExistUpdate = false;
    for (final IElement element in changeElementList) {
      final int? currentSize = element.size;
      if ((currentSize == null && payload == defaultSize) ||
          (currentSize != null && currentSize == payload)) {
        continue;
      }
      element.size = payload;
      isExistUpdate = true;
    }

    if (isExistUpdate) {
      draw.render(renderOption);
    }
  }

  void sizeAdd([IRichtextOption? options]) {
    final bool isIgnoreDisabledRule = options?.isIgnoreDisabledRule ?? false;
    final bool isDisabled =
        !isIgnoreDisabledRule && (_isReadonly() || _isDisabled());
    if (isDisabled) {
      return;
    }

    final int defaultSize = this.options.defaultSize ?? 0;
    final int maxSize = this.options.maxSize ?? defaultSize;
    final List<IElement> selection =
        _castElementList(range.getTextLikeSelectionElementList());
    final List<IElement> changeElementList = <IElement>[];
    final IDrawOption renderOption = IDrawOption();

    if (selection.isNotEmpty) {
      changeElementList.addAll(selection);
      renderOption.isSetCursor = false;
    } else {
      final IRange currentRange = range.getRange();
      final int endIndex = currentRange.endIndex;
      final List<IElement> elementList =
          _castElementList(draw.getElementList());
      if (endIndex >= 0 && endIndex < elementList.length) {
        final IElement enterElement = elementList[endIndex];
        final IElementStyle? defaultStyle = range.getDefaultStyle();
        final int anchorSize =
            defaultStyle?.size ?? enterElement.size ?? defaultSize;
        final int nextSize =
            (anchorSize + 2) > maxSize ? maxSize : anchorSize + 2;
        range.setDefaultStyle(IElementStyle(size: nextSize));
        if (enterElement.value == ZERO) {
          changeElementList.add(enterElement);
          renderOption.curIndex = endIndex;
        } else {
          draw.render(
            IDrawOption(
              curIndex: endIndex,
              isCompute: false,
              isSubmitHistory: false,
            ),
          );
        }
      }
    }

    if (changeElementList.isEmpty) {
      return;
    }

    bool isExistUpdate = false;
    for (final IElement element in changeElementList) {
      element.size ??= defaultSize;
      if (element.size! >= maxSize) {
        continue;
      }
      element.size =
          (element.size! + 2) > maxSize ? maxSize : element.size! + 2;
      isExistUpdate = true;
    }

    if (isExistUpdate) {
      draw.render(renderOption);
    }
  }

  void sizeMinus([IRichtextOption? options]) {
    final bool isIgnoreDisabledRule = options?.isIgnoreDisabledRule ?? false;
    final bool isDisabled =
        !isIgnoreDisabledRule && (_isReadonly() || _isDisabled());
    if (isDisabled) {
      return;
    }

    final int defaultSize = this.options.defaultSize ?? 0;
    final int minSize = this.options.minSize ?? defaultSize;
    final List<IElement> selection =
        _castElementList(range.getTextLikeSelectionElementList());
    final List<IElement> changeElementList = <IElement>[];
    final IDrawOption renderOption = IDrawOption();

    if (selection.isNotEmpty) {
      changeElementList.addAll(selection);
      renderOption.isSetCursor = false;
    } else {
      final IRange currentRange = range.getRange();
      final int endIndex = currentRange.endIndex;
      final List<IElement> elementList =
          _castElementList(draw.getElementList());
      if (endIndex >= 0 && endIndex < elementList.length) {
        final IElement enterElement = elementList[endIndex];
        final IElementStyle? defaultStyle = range.getDefaultStyle();
        final int anchorSize =
            defaultStyle?.size ?? enterElement.size ?? defaultSize;
        final int nextSize =
            (anchorSize - 2) < minSize ? minSize : anchorSize - 2;
        range.setDefaultStyle(IElementStyle(size: nextSize));
        if (enterElement.value == ZERO) {
          changeElementList.add(enterElement);
          renderOption.curIndex = endIndex;
        } else {
          draw.render(
            IDrawOption(
              curIndex: endIndex,
              isCompute: false,
              isSubmitHistory: false,
            ),
          );
        }
      }
    }

    if (changeElementList.isEmpty) {
      return;
    }

    bool isExistUpdate = false;
    for (final IElement element in changeElementList) {
      element.size ??= defaultSize;
      if (element.size! <= minSize) {
        continue;
      }
      element.size =
          (element.size! - 2) < minSize ? minSize : element.size! - 2;
      isExistUpdate = true;
    }

    if (isExistUpdate) {
      draw.render(renderOption);
    }
  }

  void bold([IRichtextOption? options]) {
    final bool isIgnoreDisabledRule = options?.isIgnoreDisabledRule ?? false;
    final bool isDisabled =
        !isIgnoreDisabledRule && (_isReadonly() || _isDisabled());
    if (isDisabled) {
      return;
    }

    final List<IElement> selection =
        _castElementList(range.getSelectionElementList());
    if (selection.isNotEmpty) {
      final bool toggleValue = selection.any((IElement s) => s.bold != true);
      for (final IElement element in selection) {
        element.bold = toggleValue;
      }
      draw.render(IDrawOption(isSetCursor: false));
      return;
    }

    final IRange currentRange = range.getRange();
    final int endIndex = currentRange.endIndex;
    final List<IElement> elementList = _castElementList(draw.getElementList());
    if (endIndex < 0 || endIndex >= elementList.length) {
      return;
    }
    final IElement enterElement = elementList[endIndex];
    final bool nextBold = enterElement.bold != true
        ? true
        : !(range.getDefaultStyle()?.bold ?? false);
    range.setDefaultStyle(IElementStyle(bold: nextBold));
    bool isSubmitHistory = true;
    if (enterElement.value == ZERO) {
      enterElement.bold = enterElement.bold != true;
    } else {
      isSubmitHistory = false;
    }
    draw.render(
      IDrawOption(
        isSubmitHistory: isSubmitHistory,
        curIndex: endIndex,
        isCompute: false,
      ),
    );
  }

  void italic([IRichtextOption? options]) {
    final bool isIgnoreDisabledRule = options?.isIgnoreDisabledRule ?? false;
    final bool isDisabled =
        !isIgnoreDisabledRule && (_isReadonly() || _isDisabled());
    if (isDisabled) {
      return;
    }

    final List<IElement> selection =
        _castElementList(range.getSelectionElementList());
    if (selection.isNotEmpty) {
      final bool toggleValue = selection.any((IElement s) => s.italic != true);
      for (final IElement element in selection) {
        element.italic = toggleValue;
      }
      draw.render(IDrawOption(isSetCursor: false));
      return;
    }

    final IRange currentRange = range.getRange();
    final int endIndex = currentRange.endIndex;
    final List<IElement> elementList = _castElementList(draw.getElementList());
    if (endIndex < 0 || endIndex >= elementList.length) {
      return;
    }
    final IElement enterElement = elementList[endIndex];
    final bool nextItalic = enterElement.italic != true
        ? true
        : !(range.getDefaultStyle()?.italic ?? false);
    range.setDefaultStyle(IElementStyle(italic: nextItalic));
    bool isSubmitHistory = true;
    if (enterElement.value == ZERO) {
      enterElement.italic = enterElement.italic != true;
    } else {
      isSubmitHistory = false;
    }
    draw.render(
      IDrawOption(
        isSubmitHistory: isSubmitHistory,
        curIndex: endIndex,
        isCompute: false,
      ),
    );
  }

  void underline([
    ITextDecoration? textDecoration,
    IRichtextOption? options,
  ]) {
    final bool isIgnoreDisabledRule = options?.isIgnoreDisabledRule ?? false;
    final bool isDisabled =
        !isIgnoreDisabledRule && (_isReadonly() || _isDisabled());
    if (isDisabled) {
      return;
    }

    final List<IElement> selection =
        _castElementList(range.getSelectionElementList());
    if (selection.isNotEmpty) {
      final bool isSetUnderline = selection.any((IElement s) {
        final bool hasUnderline = s.underline == true;
        final ITextDecoration? sDecoration = s.textDecoration;
        if (!hasUnderline) {
          return true;
        }
        if (textDecoration == null && sDecoration != null) {
          return true;
        }
        if (textDecoration != null && sDecoration == null) {
          return true;
        }
        if (textDecoration != null &&
            sDecoration != null &&
            !isObjectEqual(
              _textDecorationToMap(sDecoration),
              _textDecorationToMap(textDecoration),
            )) {
          return true;
        }
        return false;
      });

      for (final IElement element in selection) {
        element.underline = isSetUnderline;
        if (isSetUnderline && textDecoration != null) {
          element.textDecoration = ITextDecoration(style: textDecoration.style);
        } else {
          element.textDecoration = null;
        }
      }
      draw.render(
        IDrawOption(
          isSetCursor: false,
          isCompute: false,
        ),
      );
      return;
    }

    final IRange currentRange = range.getRange();
    final int endIndex = currentRange.endIndex;
    final List<IElement> elementList = _castElementList(draw.getElementList());
    if (endIndex < 0 || endIndex >= elementList.length) {
      return;
    }
    final IElement enterElement = elementList[endIndex];
    range.setDefaultStyle(
      IElementStyle(underline: enterElement.underline != true),
    );
    bool isSubmitHistory = true;
    if (enterElement.value == ZERO) {
      enterElement.underline = enterElement.underline != true;
    } else {
      isSubmitHistory = false;
    }
    draw.render(
      IDrawOption(
        isSubmitHistory: isSubmitHistory,
        curIndex: endIndex,
        isCompute: false,
      ),
    );
  }

  void strikeout([IRichtextOption? options]) {
    final bool isIgnoreDisabledRule = options?.isIgnoreDisabledRule ?? false;
    final bool isDisabled =
        !isIgnoreDisabledRule && (_isReadonly() || _isDisabled());
    if (isDisabled) {
      return;
    }

    final List<IElement> selection =
        _castElementList(range.getSelectionElementList());
    if (selection.isNotEmpty) {
      final bool toggleValue =
          selection.any((IElement s) => s.strikeout != true);
      for (final IElement element in selection) {
        element.strikeout = toggleValue;
      }
      draw.render(
        IDrawOption(
          isSetCursor: false,
          isCompute: false,
        ),
      );
      return;
    }

    final IRange currentRange = range.getRange();
    final int endIndex = currentRange.endIndex;
    final List<IElement> elementList = _castElementList(draw.getElementList());
    if (endIndex < 0 || endIndex >= elementList.length) {
      return;
    }
    final IElement enterElement = elementList[endIndex];
    range.setDefaultStyle(
      IElementStyle(strikeout: enterElement.strikeout != true),
    );
    bool isSubmitHistory = true;
    if (enterElement.value == ZERO) {
      enterElement.strikeout = enterElement.strikeout != true;
    } else {
      isSubmitHistory = false;
    }
    draw.render(
      IDrawOption(
        isSubmitHistory: isSubmitHistory,
        curIndex: endIndex,
        isCompute: false,
      ),
    );
  }

  void superscript([IRichtextOption? options]) {
    final bool isIgnoreDisabledRule = options?.isIgnoreDisabledRule ?? false;
    final bool isDisabled =
        !isIgnoreDisabledRule && (_isReadonly() || _isDisabled());
    if (isDisabled) {
      return;
    }

    final List<IElement> selection =
        _castElementList(range.getSelectionElementList());
    if (selection.isEmpty) {
      return;
    }

    final int superscriptIndex = selection.indexWhere(
      (IElement s) => s.type == ElementType.superscript,
    );

    for (final IElement element in selection) {
      if (superscriptIndex >= 0) {
        if (element.type == ElementType.superscript) {
          element.type = ElementType.text;
          element.actualSize = null;
        }
      } else {
        if (element.type == null ||
            element.type == ElementType.text ||
            element.type == ElementType.subscript) {
          element.type = ElementType.superscript;
        }
      }
    }
    draw.render(IDrawOption(isSetCursor: false));
  }

  void subscript([IRichtextOption? options]) {
    final bool isIgnoreDisabledRule = options?.isIgnoreDisabledRule ?? false;
    final bool isDisabled =
        !isIgnoreDisabledRule && (_isReadonly() || _isDisabled());
    if (isDisabled) {
      return;
    }

    final List<IElement> selection =
        _castElementList(range.getSelectionElementList());
    if (selection.isEmpty) {
      return;
    }

    final int subscriptIndex = selection.indexWhere(
      (IElement s) => s.type == ElementType.subscript,
    );

    for (final IElement element in selection) {
      if (subscriptIndex >= 0) {
        if (element.type == ElementType.subscript) {
          element.type = ElementType.text;
          element.actualSize = null;
        }
      } else {
        if (element.type == null ||
            element.type == ElementType.text ||
            element.type == ElementType.superscript) {
          element.type = ElementType.subscript;
        }
      }
    }
    draw.render(IDrawOption(isSetCursor: false));
  }

  void color(String? payload, [IRichtextOption? options]) {
    final bool isIgnoreDisabledRule = options?.isIgnoreDisabledRule ?? false;
    final bool isDisabled =
        !isIgnoreDisabledRule && (_isReadonly() || _isDisabled());
    if (isDisabled) {
      return;
    }

    final List<IElement> selection =
        _castElementList(range.getSelectionElementList());
    if (selection.isNotEmpty) {
      for (final IElement element in selection) {
        if (payload != null) {
          element.color = payload;
        } else {
          element.color = null;
        }
      }
      draw.render(
        IDrawOption(
          isSetCursor: false,
          isCompute: false,
        ),
      );
      return;
    }

    final IRange currentRange = range.getRange();
    final int endIndex = currentRange.endIndex;
    final List<IElement> elementList = _castElementList(draw.getElementList());
    if (endIndex < 0 || endIndex >= elementList.length) {
      return;
    }
    final IElement enterElement = elementList[endIndex];
    range.setDefaultStyle(IElementStyle(color: payload));
    bool isSubmitHistory = true;
    if (enterElement.value == ZERO) {
      if (payload != null) {
        enterElement.color = payload;
      } else {
        enterElement.color = null;
      }
    } else {
      isSubmitHistory = false;
    }
    draw.render(
      IDrawOption(
        isSubmitHistory: isSubmitHistory,
        curIndex: endIndex,
        isCompute: false,
      ),
    );
  }

  void highlight(String? payload, [IRichtextOption? options]) {
    final bool isIgnoreDisabledRule = options?.isIgnoreDisabledRule ?? false;
    final bool isDisabled =
        !isIgnoreDisabledRule && (_isReadonly() || _isDisabled());
    if (isDisabled) {
      return;
    }

    final List<IElement> selection =
        _castElementList(range.getSelectionElementList());
    if (selection.isNotEmpty) {
      for (final IElement element in selection) {
        if (payload != null) {
          element.highlight = payload;
        } else {
          element.highlight = null;
        }
      }
      draw.render(
        IDrawOption(
          isSetCursor: false,
          isCompute: false,
        ),
      );
      return;
    }

    final IRange currentRange = range.getRange();
    final int endIndex = currentRange.endIndex;
    final List<IElement> elementList = _castElementList(draw.getElementList());
    if (endIndex < 0 || endIndex >= elementList.length) {
      return;
    }
    final IElement enterElement = elementList[endIndex];
    range.setDefaultStyle(IElementStyle(highlight: payload));
    bool isSubmitHistory = true;
    if (enterElement.value == ZERO) {
      if (payload != null) {
        enterElement.highlight = payload;
      } else {
        enterElement.highlight = null;
      }
    } else {
      isSubmitHistory = false;
    }
    draw.render(
      IDrawOption(
        isSubmitHistory: isSubmitHistory,
        curIndex: endIndex,
        isCompute: false,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Structural commands

  void title(TitleLevel? payload) {
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    final IRange currentRange = range.getRange();
    final int startIndex = currentRange.startIndex;
    final int endIndex = currentRange.endIndex;
    if (startIndex < 0 && endIndex < 0) {
      return;
    }

    final List<IElement> elementList = _castElementList(draw.getElementList());
    List<IElement> changeElementList;
    if (startIndex == endIndex) {
      changeElementList =
          _castElementList(range.getRangeParagraphElementList());
    } else {
      changeElementList = _safeSublist(
        elementList,
        startIndex + 1,
        endIndex + 1,
      );
    }

    if (changeElementList.isEmpty) {
      return;
    }

    final String titleId = getUUID();
    final dynamic optionSnapshot = draw.getOptions();
    final dynamic editorOptions = _editorOption();
    final dynamic titleOption = optionSnapshot?.title ?? editorOptions?.title;

    for (final IElement element in changeElementList) {
      if (element.type == null && element.value == ZERO) {
        continue;
      }
      if (payload != null) {
        element.level = payload;
        element.titleId = titleId;
        if (element_utils.isTextLikeElement(element)) {
          final int? titleSize = _resolveTitleSize(titleOption, payload);
          if (titleSize != null) {
            element.size = titleSize;
          }
          element.bold = true;
        }
      } else if (element.titleId != null) {
        element.titleId = null;
        element.title = null;
        element.level = null;
        element.size = null;
        element.bold = null;
      }
    }

    final bool isSetCursor = startIndex == endIndex;
    final int curIndex = isSetCursor ? endIndex : startIndex;
    draw.render(IDrawOption(curIndex: curIndex, isSetCursor: isSetCursor));
  }

  void list(ListType? listType, [ListStyle? listStyle]) {
    if (_isReadonly()) {
      return;
    }
    final dynamic listParticle = draw.getListParticle();
    listParticle?.setList(listType, listStyle);
  }

  void rowFlex(RowFlex payload) {
    if (_isReadonly()) {
      return;
    }
    final IRange currentRange = range.getRange();
    final int startIndex = currentRange.startIndex;
    final int endIndex = currentRange.endIndex;
    if (startIndex < 0 && endIndex < 0) {
      return;
    }
    final List<IElement> rowElementList =
        _castElementList(range.getRangeRowElementList());
    if (rowElementList.isEmpty) {
      return;
    }
    for (final IElement element in rowElementList) {
      element.rowFlex = payload;
    }
    final bool isSetCursor = startIndex == endIndex;
    final int curIndex = isSetCursor ? endIndex : startIndex;
    draw.render(IDrawOption(curIndex: curIndex, isSetCursor: isSetCursor));
  }

  void rowMargin(double payload) {
    if (_isReadonly()) {
      return;
    }
    final IRange currentRange = range.getRange();
    final int startIndex = currentRange.startIndex;
    final int endIndex = currentRange.endIndex;
    if (startIndex < 0 && endIndex < 0) {
      return;
    }
    final List<IElement> rowElementList =
        _castElementList(range.getRangeRowElementList());
    if (rowElementList.isEmpty) {
      return;
    }
    for (final IElement element in rowElementList) {
      element.rowMargin = payload;
    }
    final bool isSetCursor = startIndex == endIndex;
    final int curIndex = isSetCursor ? endIndex : startIndex;
    draw.render(IDrawOption(curIndex: curIndex, isSetCursor: isSetCursor));
  }

  void insertTable(int row, int col) {
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    final dynamic activeControl = control.getActiveControl();
    if (activeControl != null) {
      return;
    }
    tableOperate.insertTable(row, col);
  }

  void insertTableTopRow() {
    if (_isReadonly()) {
      return;
    }
    tableOperate.insertTableTopRow();
  }

  void insertTableBottomRow() {
    if (_isReadonly()) {
      return;
    }
    tableOperate.insertTableBottomRow();
  }

  void insertTableLeftCol() {
    if (_isReadonly()) {
      return;
    }
    tableOperate.insertTableLeftCol();
  }

  void insertTableRightCol() {
    if (_isReadonly()) {
      return;
    }
    tableOperate.insertTableRightCol();
  }

  void deleteTableRow() {
    if (_isReadonly()) {
      return;
    }
    tableOperate.deleteTableRow();
  }

  void deleteTableCol() {
    if (_isReadonly()) {
      return;
    }
    tableOperate.deleteTableCol();
  }

  void deleteTable() {
    if (_isReadonly()) {
      return;
    }
    tableOperate.deleteTable();
  }

  void mergeTableCell() {
    if (_isReadonly()) {
      return;
    }
    tableOperate.mergeTableCell();
  }

  void cancelMergeTableCell() {
    if (_isReadonly()) {
      return;
    }
    tableOperate.cancelMergeTableCell();
  }

  void splitVerticalTableCell() {
    if (_isReadonly()) {
      return;
    }
    tableOperate.splitVerticalTableCell();
  }

  void splitHorizontalTableCell() {
    if (_isReadonly()) {
      return;
    }
    tableOperate.splitHorizontalTableCell();
  }

  void tableTdVerticalAlign(VerticalAlign payload) {
    if (_isReadonly()) {
      return;
    }
    tableOperate.tableTdVerticalAlign(payload);
  }

  void tableBorderType(TableBorder payload) {
    if (_isReadonly()) {
      return;
    }
    tableOperate.tableBorderType(payload);
  }

  void tableBorderColor(String payload) {
    if (_isReadonly()) {
      return;
    }
    tableOperate.tableBorderColor(payload);
  }

  void tableTdBorderType(TdBorder payload) {
    if (_isReadonly()) {
      return;
    }
    tableOperate.tableTdBorderType(payload);
  }

  void tableTdSlashType(TdSlash payload) {
    if (_isReadonly()) {
      return;
    }
    tableOperate.tableTdSlashType(payload);
  }

  void tableTdBackgroundColor(String payload) {
    if (_isReadonly()) {
      return;
    }
    tableOperate.tableTdBackgroundColor(payload);
  }

  void tableSelectAll() {
    tableOperate.tableSelectAll();
  }

  void hyperlink(IElement payload) {
    final List<IElement>? valueList = payload.valueList;
    final String? url = payload.url;
    final String? hyperlinkId = payload.hyperlinkId;
    if (url == null || valueList == null || valueList.isEmpty) {
      return;
    }
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    final dynamic activeControl = control.getActiveControl();
    if (activeControl != null) {
      return;
    }
    final IRange currentRange = range.getRange();
    final int startIndex = currentRange.startIndex;
    final int endIndex = currentRange.endIndex;
    if (startIndex < 0 && endIndex < 0) {
      return;
    }
    insertElementList(
      <IElement>[
        IElement(
          value: '',
          type: ElementType.hyperlink,
          valueList: valueList,
          url: url,
          hyperlinkId: hyperlinkId ?? getUUID(),
        ),
      ],
    );
  }

  List<int>? getHyperlinkRange() {
    int leftIndex = -1;
    int rightIndex = -1;
    final IRange currentRange = range.getRange();
    final int startIndex = currentRange.startIndex;
    final int endIndex = currentRange.endIndex;
    if (startIndex < 0 && endIndex < 0) {
      return null;
    }
    final List<IElement> elementList = _castElementList(draw.getElementList());
    if (startIndex < 0 || startIndex >= elementList.length) {
      return null;
    }
    final IElement startElement = elementList[startIndex];
    if (startElement.type != ElementType.hyperlink) {
      return null;
    }

    int preIndex = startIndex;
    while (preIndex > 0) {
      final IElement previous = elementList[preIndex];
      if (previous.hyperlinkId != startElement.hyperlinkId) {
        leftIndex = preIndex + 1;
        break;
      }
      preIndex -= 1;
    }
    if (preIndex == 0 && leftIndex == -1) {
      leftIndex = 0;
    }

    int nextIndex = startIndex + 1;
    while (nextIndex < elementList.length) {
      final IElement nextElement = elementList[nextIndex];
      if (nextElement.hyperlinkId != startElement.hyperlinkId) {
        rightIndex = nextIndex - 1;
        break;
      }
      nextIndex += 1;
    }
    if (nextIndex == elementList.length && rightIndex == -1) {
      rightIndex = nextIndex - 1;
    }

    if (leftIndex < 0 || rightIndex < 0) {
      return null;
    }
    return <int>[leftIndex, rightIndex];
  }

  void deleteHyperlink() {
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    final List<int>? hyperRange = getHyperlinkRange();
    if (hyperRange == null) {
      return;
    }
    final List<IElement> elementList = _castElementList(draw.getElementList());
    final int leftIndex = hyperRange[0];
    final int rightIndex = hyperRange[1];
    draw.spliceElementList(
      elementList,
      leftIndex,
      rightIndex - leftIndex + 1,
    );
    draw.getHyperlinkParticle()?.clearHyperlinkPopup();
    final int newIndex = leftIndex - 1;
    range.setRange(newIndex, newIndex);
    draw.render(IDrawOption(curIndex: newIndex));
  }

  void cancelHyperlink() {
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    final List<int>? hyperRange = getHyperlinkRange();
    if (hyperRange == null) {
      return;
    }
    final List<IElement> elementList = _castElementList(draw.getElementList());
    final int leftIndex = hyperRange[0];
    final int rightIndex = hyperRange[1];
    for (int i = leftIndex; i <= rightIndex; i += 1) {
      final IElement element = elementList[i];
      element.type = null;
      element.url = null;
      element.hyperlinkId = null;
      element.underline = null;
    }
    draw.getHyperlinkParticle()?.clearHyperlinkPopup();
    final int endIndex = range.getRange().endIndex;
    draw.render(
      IDrawOption(
        curIndex: endIndex,
        isCompute: false,
      ),
    );
  }

  void editHyperlink(String payload) {
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    final List<int>? hyperRange = getHyperlinkRange();
    if (hyperRange == null) {
      return;
    }
    final List<IElement> elementList = _castElementList(draw.getElementList());
    final int leftIndex = hyperRange[0];
    final int rightIndex = hyperRange[1];
    for (int i = leftIndex; i <= rightIndex; i += 1) {
      elementList[i].url = payload;
    }
    draw.getHyperlinkParticle()?.clearHyperlinkPopup();
    final int endIndex = range.getRange().endIndex;
    draw.render(
      IDrawOption(
        curIndex: endIndex,
        isCompute: false,
      ),
    );
  }

  void separator(List<num> payload) {
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    final dynamic activeControl = control.getActiveControl();
    if (activeControl != null) {
      return;
    }
    final IRange currentRange = range.getRange();
    final int startIndex = currentRange.startIndex;
    final int endIndex = currentRange.endIndex;
    if (startIndex < 0 && endIndex < 0) {
      return;
    }
    final List<IElement> elementList = _castElementList(draw.getElementList());
    int curIndex = -1;
    final IElement? endElement =
        endIndex + 1 < elementList.length ? elementList[endIndex + 1] : null;
    final List<double> dashArray =
        payload.map((num value) => value.toDouble()).toList();
    if (endElement != null && endElement.type == ElementType.separator) {
      final List<double>? existing = endElement.dashArray;
      if (existing != null &&
          existing.length == dashArray.length &&
          <double>[...existing].join(',') == dashArray.join(',')) {
        return;
      }
      curIndex = endIndex;
      endElement.dashArray = dashArray;
    } else {
      final IElement newElement = IElement(
        value: WRAP,
        type: ElementType.separator,
        dashArray: dashArray,
      );
      element_utils.formatElementContext(
        elementList,
        <IElement>[newElement],
        startIndex,
        options: element_utils.FormatElementContextOption(
          editorOptions: _editorOption(),
        ),
      );
      if (startIndex != 0 && elementList[startIndex].value == ZERO) {
        draw.spliceElementList(
          elementList,
          startIndex,
          1,
          <IElement>[newElement],
        );
        curIndex = startIndex - 1;
      } else {
        draw.spliceElementList(
          elementList,
          startIndex + 1,
          0,
          <IElement>[newElement],
        );
        curIndex = startIndex;
      }
    }
    range.setRange(curIndex, curIndex);
    draw.render(IDrawOption(curIndex: curIndex));
  }

  void pageBreak() {
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    final dynamic activeControl = control.getActiveControl();
    if (activeControl != null) {
      return;
    }
    insertElementList(
      <IElement>[
        IElement(
          value: WRAP,
          type: ElementType.pageBreak,
        ),
      ],
    );
  }

  void addWatermark(IWatermark payload) {
    if (_isReadonly()) {
      return;
    }
    final dynamic currentOptions = draw.getOptions();
    final dynamic watermarkOption = currentOptions?.watermark;
    if (watermarkOption == null) {
      return;
    }
    watermarkOption.data = payload.data;
    watermarkOption.type = payload.type ?? WatermarkType.text;
    if (payload.width != null) {
      watermarkOption.width = payload.width;
    }
    if (payload.height != null) {
      watermarkOption.height = payload.height;
    }
    watermarkOption.color = payload.color ?? defaultWatermarkOption.color;
    watermarkOption.opacity = payload.opacity ?? defaultWatermarkOption.opacity;
    watermarkOption.size = payload.size ?? defaultWatermarkOption.size;
    watermarkOption.font = payload.font ?? defaultWatermarkOption.font;
    watermarkOption.repeat = payload.repeat == true;
    if (payload.numberType != null) {
      watermarkOption.numberType = payload.numberType;
    }
    watermarkOption.gap = payload.gap ?? defaultWatermarkOption.gap;
    draw.render(
      IDrawOption(
        isSetCursor: false,
        isSubmitHistory: false,
        isCompute: false,
      ),
    );
  }

  void deleteWatermark() {
    if (_isReadonly()) {
      return;
    }
    final dynamic currentOptions = draw.getOptions();
    final dynamic watermarkOption = currentOptions?.watermark;
    if (watermarkOption == null) {
      return;
    }
    if (watermarkOption.data != null) {
      currentOptions.watermark = defaultWatermarkOption;
      draw.render(
        IDrawOption(
          isSetCursor: false,
          isSubmitHistory: false,
          isCompute: false,
        ),
      );
    }
  }

  void insertElementList(
    List<IElement> payload, [
    IInsertElementListOption? insertOptions,
  ]) {
    if (payload.isEmpty) {
      return;
    }
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    final bool isReplace = insertOptions?.isReplace ?? true;
    if (!isReplace) {
      range.shrinkRange();
    }
    final List<IElement> cloneElementList =
        element_utils.cloneElementList(payload);
    final IRange currentRange = range.getRange();
    final int startIndex = currentRange.startIndex;
    final List<IElement> elementList = _castElementList(draw.getElementList());
    element_utils.formatElementContext(
      elementList,
      cloneElementList,
      startIndex,
      options: element_utils.FormatElementContextOption(
        isBreakWhenWrap: true,
        editorOptions: _editorOption(),
      ),
    );
    draw.insertElementList(cloneElementList, insertOptions);
  }

  void appendElementList(
    List<IElement> elementList, [
    IAppendElementListOption? appendOptions,
  ]) {
    if (elementList.isEmpty) {
      return;
    }
    if (_isReadonly()) {
      return;
    }
    draw.appendElementList(
      element_utils.cloneElementList(elementList),
      appendOptions,
    );
  }

  String? image(IDrawImagePayload payload) {
    if (_isReadonly() || _isDisabled()) {
      return null;
    }
    final IRange currentRange = range.getRange();
    final int startIndex = currentRange.startIndex;
    final int endIndex = currentRange.endIndex;
    if (startIndex < 0 && endIndex < 0) {
      return null;
    }
    final String imageId = payload.id ?? getUUID();
    insertElementList(
      <IElement>[
        IElement(
          value: payload.value,
          id: imageId,
          type: ElementType.image,
          width: payload.width,
          height: payload.height,
          imgDisplay: payload.imgDisplay,
          imgFloatPosition: payload.imgFloatPosition,
          hyperlinkId: payload.hyperlinkId,
          url: payload.url,
          extension: payload.extension,
        ),
      ],
    );
    return imageId;
  }

  void search(String? payload) {
    searchManager.setSearchKeyword(payload);
    draw.render(
      IDrawOption(
        isSetCursor: false,
        isSubmitHistory: false,
      ),
    );
  }

  void searchNavigatePre() {
    final dynamic index = searchManager.searchNavigatePre();
    if (index == null) {
      return;
    }
    draw.render(
      IDrawOption(
        isSetCursor: false,
        isSubmitHistory: false,
        isCompute: false,
        isLazy: false,
      ),
    );
  }

  void searchNavigateNext() {
    final dynamic index = searchManager.searchNavigateNext();
    if (index == null) {
      return;
    }
    draw.render(
      IDrawOption(
        isSetCursor: false,
        isSubmitHistory: false,
        isCompute: false,
        isLazy: false,
      ),
    );
  }

  dynamic getSearchNavigateInfo() {
    return searchManager.getSearchNavigateInfo();
  }

  void replace(String payload, [IReplaceOption? option]) {
    draw.getSearch().replace(payload, option);
  }

  Future<void> print() async {
    final dynamic editorOptions = options;
    final num? scale = editorOptions?.scale;
    final dynamic pixelRatio = editorOptions?.printPixelRatio;
    final dynamic paperDirection = editorOptions?.paperDirection;
    final dynamic width = editorOptions?.width;
    final dynamic height = editorOptions?.height;
    if (scale != null && scale != 1) {
      draw.setPageScale(1);
    }
    final List<String> base64List = await draw.getDataURL(
      IGetImageOption(
        pixelRatio: pixelRatio,
        mode: EditorMode.print,
      ),
    );
    printImageBase64(
      base64List,
      width: width,
      height: height,
      direction: paperDirection,
    );
    if (scale != null && scale != 1) {
      draw.setPageScale(scale);
    }
  }

  void replaceImageElement(String payload) {
    final int startIndex = range.getRange().startIndex;
    final List<IElement> elementList = _castElementList(draw.getElementList());
    if (startIndex < 0 || startIndex >= elementList.length) {
      return;
    }
    final IElement element = elementList[startIndex];
    if (element.type != ElementType.image) {
      return;
    }
    element.value = payload;
    draw.render(IDrawOption(isSetCursor: false));
  }

  void saveAsImageElement() {
    final int startIndex = range.getRange().startIndex;
    final List<IElement> elementList = _castElementList(draw.getElementList());
    if (startIndex < 0 || startIndex >= elementList.length) {
      return;
    }
    final IElement element = elementList[startIndex];
    if (element.type != ElementType.image) {
      return;
    }
    downloadFile(element.value, '${element.id ?? getUUID()}.png');
  }

  void changeImageDisplay(IElement element, ImageDisplay display) {
    if (element.imgDisplay == display) {
      return;
    }
    element.imgDisplay = display;
    final IRange currentRange = range.getRange();
    final int startIndex = currentRange.startIndex;
    final int endIndex = currentRange.endIndex;
    if (display == ImageDisplay.surround ||
        display == ImageDisplay.floatTop ||
        display == ImageDisplay.floatBottom) {
      final List<dynamic> positionList = position.getPositionList();
      final dynamic currentPosition =
          startIndex >= 0 && startIndex < positionList.length
              ? positionList[startIndex]
              : null;
      if (currentPosition != null) {
        final dynamic pageNo = currentPosition.pageNo;
        final dynamic coordinate = currentPosition.coordinate;
        final List<dynamic>? leftTop =
            coordinate != null ? (coordinate.leftTop as List<dynamic>?) : null;
        if (leftTop != null) {
          element.imgFloatPosition = <String, num>{
            'pageNo': _asNum(pageNo),
            'x': _asNum(leftTop[0]),
            'y': _asNum(leftTop[1]),
          };
        }
      }
    } else {
      element.imgFloatPosition = null;
    }
    draw.getPreviewer()?.clearResizer();
    draw.render(
      IDrawOption(
        isSetCursor: true,
        curIndex: endIndex,
      ),
    );
  }

  Future<List<String>> getImage([IGetImageOption? payload]) {
    return draw.getDataURL(payload);
  }

  IEditorOption getOptions() {
    final dynamic editorOptions = options;
    if (editorOptions is IEditorOption) {
      return editorOptions;
    }
    return editorOptions as IEditorOption;
  }

  IEditorResult getValue([IGetValueOption? option]) {
    final dynamic result = draw.getValue(option);
    return result as IEditorResult;
  }

  Future<IEditorResult> getValueAsync([IGetValueOption? option]) async {
    final dynamic result = await draw.getWorkerManager().getValue(option);
    return result as IEditorResult;
  }

  IGetAreaValueResult<IElement>? getAreaValue([IGetAreaValueOption? option]) {
    final dynamic result = draw.getArea().getAreaValue(option);
    return result as IGetAreaValueResult<IElement>?;
  }

  IEditorHTML getHTML() {
    final dynamic headerElementList = draw.getHeaderElementList();
    final dynamic mainElementList = draw.getOriginalMainElementList();
    final dynamic footerElementList = draw.getFooterElementList();
    final IEditorOption? editorOptions =
        options is IEditorOption ? options as IEditorOption : null;
    return IEditorHTML(
      header: element_utils
              .createDomFromElementList(
                headerElementList,
                options: editorOptions,
              )
              .innerHtml ??
          '',
      main: element_utils
              .createDomFromElementList(
                mainElementList,
                options: editorOptions,
              )
              .innerHtml ??
          '',
      footer: element_utils
              .createDomFromElementList(
                footerElementList,
                options: editorOptions,
              )
              .innerHtml ??
          '',
    );
  }

  IEditorText getText() {
    final dynamic headerElementList = draw.getHeaderElementList();
    final dynamic mainElementList = draw.getOriginalMainElementList();
    final dynamic footerElementList = draw.getFooterElementList();
    return IEditorHTML(
      header: element_utils.getTextFromElementList(headerElementList),
      main: element_utils.getTextFromElementList(mainElementList),
      footer: element_utils.getTextFromElementList(footerElementList),
    );
  }

  Future<int> getWordCount() {
    return workerManager.getWordCount();
  }

  IElementPosition? getCursorPosition() {
    final dynamic cursorPosition = position.getCursorPosition();
    return cursorPosition as IElementPosition?;
  }

  IRange getRange() {
    return deepClone(range.getRange()) as IRange;
  }

  String getRangeText() {
    return range.toString();
  }

  // ---------------------------------------------------------------------------
  // Range context and queries

  RangeContext? getRangeContext() {
    final IRange currentRange = range.getRange();
    final int startIndex = currentRange.startIndex;
    final int endIndex = currentRange.endIndex;
    if (startIndex < 0 && endIndex < 0) {
      return null;
    }

    final bool isCollapsed = startIndex == endIndex;
    final String selectionText = range.toString();
    final List<IElement> selection = _castElementList(
      range.getSelectionElementList(),
    );
    final List<IElement> selectionElementList =
        element_utils.zipElementList(selection);

    final List<IElement> elementList = _castElementList(draw.getElementList());
    if (elementList.isEmpty) {
      return null;
    }

    final int startElementIndex = _clampIndex(
      isCollapsed ? startIndex : startIndex + 1,
      elementList.length,
    );
    final int endElementIndex = _clampIndex(endIndex, elementList.length);

    final IElement startSource = elementList[startElementIndex];
    final IElement endSource = elementList[endElementIndex];
    final IElement startElement = element_utils.pickElementAttr(
      startSource,
      extraPickAttrs: <String>['id', 'controlComponent'],
    );
    final IElement endElement = element_utils.pickElementAttr(
      endSource,
      extraPickAttrs: <String>['id', 'controlComponent'],
    );

    final List<dynamic> rowList = draw.getRowList() as List<dynamic>;
    final List<dynamic> positionList =
        position.getPositionList() as List<dynamic>;
    final dynamic startPosition = positionList[startElementIndex];
    final dynamic endPosition = positionList[endElementIndex];
    final int startPageNo = _asInt(startPosition?.pageNo);
    final int endPageNo = _asInt(endPosition?.pageNo);
    final int startRowNo = _asInt(startPosition?.rowIndex);
    final int endRowNo = _asInt(endPosition?.rowIndex);

    int startColNo = 0;
    int endColNo = 0;
    final dynamic cursor = draw.getCursor();
    final dynamic hitLineStartIndex = cursor?.getHitLineStartIndex();
    if (hitLineStartIndex == null || hitLineStartIndex == 0) {
      final dynamic startRow = startRowNo >= 0 && startRowNo < rowList.length
          ? rowList[startRowNo]
          : null;
      final dynamic endRow =
          endRowNo >= 0 && endRowNo < rowList.length ? rowList[endRowNo] : null;
      if (startRow != null && startPosition != null) {
        final List<dynamic> startRowElements =
            (startRow.elementList as List<dynamic>? ?? <dynamic>[]);
        final bool startsWithBreak =
            startRowElements.isNotEmpty && startRowElements.first.value == ZERO;
        startColNo = _asInt(startPosition.index) -
            _asInt(startRow.startIndex) +
            (startsWithBreak ? 0 : 1);
      }
      if (isCollapsed) {
        endColNo = startColNo;
      } else if (endRow != null && endPosition != null) {
        final List<dynamic> endRowElements =
            (endRow.elementList as List<dynamic>? ?? <dynamic>[]);
        final bool endsWithBreak =
            endRowElements.isNotEmpty && endRowElements.first.value == ZERO;
        endColNo = _asInt(endPosition.index) -
            _asInt(endRow.startIndex) +
            (endsWithBreak ? 0 : 1);
      }
    }

    final double height = _asNum(draw.getOriginalHeight()).toDouble();
    final double pageGap = _asNum(draw.getOriginalPageGap()).toDouble();
    final List<dynamic>? selectionPositions =
        position.getSelectionPositionList() as List<dynamic>?;
    final List<RangeRect> rangeRects = <RangeRect>[];
    if (selectionPositions != null && selectionPositions.isNotEmpty) {
      int? currentRowNo;
      double currentX = 0;
      RangeRect? currentRect;
      for (var i = 0; i < selectionPositions.length; i++) {
        final dynamic pos = selectionPositions[i];
        final int rowNo = _asInt(pos?.rowNo);
        final int pageNo = _asInt(pos?.pageNo);
        final List<dynamic> leftTop =
            (pos?.coordinate?.leftTop as List<dynamic>? ?? <dynamic>[0, 0]);
        final List<dynamic> rightTop =
            (pos?.coordinate?.rightTop as List<dynamic>? ?? <dynamic>[0, 0]);
        final double lineHeight = _asNum(pos?.lineHeight).toDouble();
        final double x =
            _asNum(leftTop.isNotEmpty ? leftTop.first : 0).toDouble();
        final double y =
            _asNum(leftTop.length > 1 ? leftTop[1] : 0).toDouble() +
                pageNo * (height + pageGap);
        final double width =
            _asNum(rightTop.isNotEmpty ? rightTop.first : 0).toDouble() -
                _asNum(leftTop.isNotEmpty ? leftTop.first : 0).toDouble();

        if (currentRowNo == null || currentRowNo != rowNo) {
          if (currentRect != null) {
            rangeRects.add(currentRect);
          }
          currentRect = RangeRect(
            x: x,
            y: y,
            width: width,
            height: lineHeight,
          );
          currentRowNo = rowNo;
          currentX = _asNum(leftTop.isNotEmpty ? leftTop.first : 0).toDouble();
        } else if (currentRect != null) {
          currentRect.width =
              _asNum(rightTop.isNotEmpty ? rightTop.first : 0).toDouble() -
                  currentX;
        }
        if (i == selectionPositions.length - 1 && currentRect != null) {
          rangeRects.add(currentRect);
        }
      }
    } else {
      final dynamic caretPosition = positionList[endElementIndex];
      if (caretPosition != null) {
        final List<dynamic> rightTop =
            (caretPosition.coordinate?.rightTop as List<dynamic>? ??
                <dynamic>[0, 0]);
        final double lineHeight = _asNum(caretPosition.lineHeight).toDouble();
        final int pageNo = _asInt(caretPosition.pageNo);
        rangeRects.add(
          RangeRect(
            x: _asNum(rightTop.isNotEmpty ? rightTop.first : 0).toDouble(),
            y: _asNum(rightTop.length > 1 ? rightTop[1] : 0).toDouble() +
                pageNo * (height + pageGap),
            width: 0,
            height: lineHeight,
          ),
        );
      }
    }

    final dynamic zoneManager = draw.getZone();
    final EditorZone zoneValue = zoneManager?.getZone() is EditorZone
        ? zoneManager.getZone() as EditorZone
        : EditorZone.main;

    final dynamic positionContext = position.getPositionContext();
    final bool isTable = positionContext?.isTable == true;
    final int? trIndex = positionContext?.trIndex as int?;
    final int? tdIndex = positionContext?.tdIndex as int?;
    IElement? tableElement;
    if (isTable) {
      final int? rawIndex = positionContext?.index as int?;
      if (rawIndex != null) {
        final List<IElement> originalElementList =
            _castElementList(draw.getOriginalElementList());
        final int tableIndex =
            _clampIndex(rawIndex, originalElementList.length);
        if (tableIndex >= 0 && tableIndex < originalElementList.length) {
          final IElement tableSource = originalElementList[tableIndex];
          tableElement =
              element_utils.zipElementList(<IElement>[tableSource]).first;
        }
      }
    }

    String? titleId;
    int? titleStartPageNo;
    int searchIndex = startElementIndex - 1;
    while (searchIndex > 0) {
      final IElement current = elementList[searchIndex];
      final IElement previous = elementList[searchIndex - 1];
      if (current.titleId != null && current.titleId != previous.titleId) {
        titleId = current.titleId;
        if (searchIndex >= 0 && searchIndex < positionList.length) {
          final dynamic pos = positionList[searchIndex];
          titleStartPageNo = _asInt(pos?.pageNo);
        }
        break;
      }
      searchIndex -= 1;
    }

    return RangeContext(
      isCollapsed: isCollapsed,
      startElement: startElement,
      endElement: endElement,
      startPageNo: startPageNo,
      endPageNo: endPageNo,
      startRowNo: startRowNo,
      endRowNo: endRowNo,
      startColNo: startColNo,
      endColNo: endColNo,
      rangeRects: rangeRects,
      zone: zoneValue,
      isTable: isTable,
      trIndex: trIndex,
      tdIndex: tdIndex,
      tableElement: tableElement,
      selectionText: selectionText,
      selectionElementList: selectionElementList,
      titleId: titleId,
      titleStartPageNo: titleStartPageNo,
    );
  }

  List<IElement>? getRangeRow() {
    final List<IElement> rowElementList =
        _castElementList(range.getRangeRowElementList());
    if (rowElementList.isEmpty) {
      return null;
    }
    return element_utils.zipElementList(rowElementList);
  }

  List<IElement>? getRangeParagraph() {
    final List<IElement> paragraphElementList =
        _castElementList(range.getRangeParagraphElementList());
    if (paragraphElementList.isEmpty) {
      return null;
    }
    return element_utils.zipElementList(paragraphElementList);
  }

  List<IRange> getKeywordRangeList(String payload) {
    return range.getKeywordRangeList(payload);
  }

  List<ISearchResultContext>? getKeywordContext(String payload) {
    final List<IRange> rangeList = getKeywordRangeList(payload);
    if (rangeList.isEmpty) {
      return null;
    }
    final List<ISearchResultContext> contextList = <ISearchResultContext>[];
    final List<dynamic> positionList =
        position.getOriginalMainPositionList() as List<dynamic>;
    final List<IElement> elementList =
        _castElementList(draw.getOriginalMainElementList());
    for (final IRange keywordRange in rangeList) {
      final int start = keywordRange.startIndex;
      final int end = keywordRange.endIndex;
      List<dynamic> keywordPositionList = positionList;
      if (keywordRange.tableId != null) {
        IElement? tableElement;
        for (final IElement el in elementList) {
          if (el.id == keywordRange.tableId) {
            tableElement = el;
            break;
          }
        }
        final List<dynamic>? trList = tableElement?.trList;
        final int? trIndex = keywordRange.startTrIndex;
        final int? tdIndex = keywordRange.startTdIndex;
        dynamic td;
        if (trList != null && trIndex != null && tdIndex != null) {
          if (trIndex >= 0 && trIndex < trList.length) {
            final dynamic tr = trList[trIndex];
            final List<dynamic>? tdList = tr?.tdList as List<dynamic>?;
            if (tdList != null && tdIndex >= 0 && tdIndex < tdList.length) {
              td = tdList[tdIndex];
            }
          }
        }
        final List<dynamic>? tablePositionList =
            td?.positionList as List<dynamic>?;
        if (tablePositionList != null && tablePositionList.isNotEmpty) {
          keywordPositionList = tablePositionList;
        } else {
          keywordPositionList = <dynamic>[];
        }
      }
      if (start >= keywordPositionList.length ||
          end >= keywordPositionList.length) {
        continue;
      }
      final IElementPosition startPosition =
          keywordPositionList[start] as IElementPosition;
      final IElementPosition endPosition =
          keywordPositionList[end] as IElementPosition;
      contextList.add(
        ISearchResultContext(
          range: keywordRange,
          startPosition: startPosition,
          endPosition: endPosition,
        ),
      );
    }
    return contextList;
  }

  // ---------------------------------------------------------------------------
  // Page configuration

  void pageMode(PageMode payload) {
    draw.setPageMode(payload);
  }

  void pageScale(num scale) {
    final dynamic currentScale = options?.scale;
    if (currentScale is num && currentScale == scale) {
      return;
    }
    draw.setPageScale(scale);
  }

  void pageScaleRecovery() {
    final dynamic currentScale = options?.scale;
    if (currentScale is num && currentScale != 1) {
      draw.setPageScale(1);
    }
  }

  void pageScaleMinus() {
    final dynamic currentScale = options?.scale;
    if (currentScale is num) {
      final int nextScale = (currentScale * 10).round() - 1;
      if (nextScale >= 5) {
        draw.setPageScale(nextScale / 10);
      }
    }
  }

  void pageScaleAdd() {
    final dynamic currentScale = options?.scale;
    if (currentScale is num) {
      final int nextScale = (currentScale * 10).round() + 1;
      if (nextScale <= 30) {
        draw.setPageScale(nextScale / 10);
      }
    }
  }

  void paperSize(num width, num height) {
    draw.setPaperSize(width, height);
  }

  void paperDirection(PaperDirection payload) {
    draw.setPaperDirection(payload);
  }

  List<double> getPaperMargin() {
    final dynamic margins = options?.margins;
    if (margins is List<double>) {
      return margins;
    }
    if (margins is List) {
      return margins
          .whereType<num>()
          .map((num value) => value.toDouble())
          .toList();
    }
    return <double>[];
  }

  dynamic setPaperMargin(IMargin payload) {
    return draw.setPaperMargin(payload);
  }

  void setMainBadge(IBadge? payload) {
    draw.getBadge().setMainBadge(payload);
    draw.render(
      IDrawOption(
        isCompute: false,
        isSubmitHistory: false,
      ),
    );
  }

  void setAreaBadge(List<IAreaBadge> payload) {
    draw.getBadge().setAreaBadgeMap(payload);
    draw.render(
      IDrawOption(
        isCompute: false,
        isSubmitHistory: false,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Element lookups

  void updateElementById(IUpdateElementByIdOption payload) {
    final String? id = payload.id;
    final String? conceptId = payload.conceptId;
    if ((id == null || id.isEmpty) &&
        (conceptId == null || conceptId.isEmpty)) {
      return;
    }
    final List<Map<String, dynamic>> updateInfoList = <Map<String, dynamic>>[];

    void collect(List<IElement> elementList) {
      for (var i = 0; i < elementList.length; i++) {
        final IElement element = elementList[i];
        if (element.type == ElementType.table) {
          final List<dynamic>? trList = element.trList;
          if (trList != null) {
            for (final dynamic tr in trList) {
              final List<dynamic>? tdList = tr?.tdList as List<dynamic>?;
              if (tdList == null) {
                continue;
              }
              for (final dynamic td in tdList) {
                final List<IElement>? valueList = td?.value as List<IElement>?;
                if (valueList != null) {
                  collect(valueList);
                }
              }
            }
          }
        }
        final bool matchId = id != null && element.id == id;
        final bool matchConcept =
            conceptId != null && element.conceptId == conceptId;
        if (matchId || matchConcept) {
          updateInfoList.add(<String, dynamic>{
            'list': elementList,
            'index': i,
          });
        }
      }
    }

    final List<List<IElement>> data = <List<IElement>>[
      _castElementList(draw.getOriginalMainElementList()),
      _castElementList(draw.getHeaderElementList()),
      _castElementList(draw.getFooterElementList()),
    ];
    for (final List<IElement> elementList in data) {
      collect(elementList);
    }
    if (updateInfoList.isEmpty) {
      return;
    }

    final IElement properties = payload.properties;
    final IEditorOption? editorOption = _editorOption();
    for (final Map<String, dynamic> info in updateInfoList) {
      final List<IElement> elementList = info['list'] as List<IElement>;
      final int index = info['index'] as int;
      final IElement oldElement = elementList[index];
      final List<IElement> cloneList = element_utils.zipElementList(
        <IElement>[oldElement],
        options: const element_utils.ZipElementListOption(
          extraPickAttrs: <String>['id'],
        ),
      );
      final IElement newElement = cloneList.first;
      _applyElementOverrides(newElement, properties);
      _cloneElementContextProperties(oldElement, newElement, areaContextAttr);
      if (editorOption != null) {
        element_utils.formatElementList(
          cloneList,
          element_utils.FormatElementListOption(
            editorOptions: editorOption,
            isHandleFirstElement: false,
          ),
        );
      }
      elementList[index] = newElement;
    }
    draw.render(IDrawOption(isSetCursor: false));
  }

  void deleteElementById(IDeleteElementByIdOption payload) {
    final String? id = payload.id;
    final String? conceptId = payload.conceptId;
    if ((id == null || id.isEmpty) &&
        (conceptId == null || conceptId.isEmpty)) {
      return;
    }
    bool isExistDelete = false;

    void remove(List<IElement> elementList) {
      var i = 0;
      while (i < elementList.length) {
        final IElement element = elementList[i];
        if (element.type == ElementType.table) {
          final List<dynamic>? trList = element.trList;
          if (trList != null) {
            for (final dynamic tr in trList) {
              final List<dynamic>? tdList = tr?.tdList as List<dynamic>?;
              if (tdList == null) {
                continue;
              }
              for (final dynamic td in tdList) {
                final List<IElement>? valueList = td?.value as List<IElement>?;
                if (valueList != null) {
                  remove(valueList);
                }
              }
            }
          }
        }
        final bool matchId = id != null && element.id == id;
        final bool matchConcept =
            conceptId != null && element.conceptId == conceptId;
        if (matchId || matchConcept) {
          elementList.removeAt(i);
          isExistDelete = true;
          continue;
        }
        i += 1;
      }
    }

    final List<List<IElement>> data = <List<IElement>>[
      _castElementList(draw.getOriginalMainElementList()),
      _castElementList(draw.getHeaderElementList()),
      _castElementList(draw.getFooterElementList()),
    ];
    for (final List<IElement> elementList in data) {
      remove(elementList);
    }
    if (isExistDelete) {
      draw.render(IDrawOption(isSetCursor: false));
    }
  }

  List<IElement> getElementById(IGetElementByIdOption payload) {
    final String? id = payload.id;
    final String? conceptId = payload.conceptId;
    if ((id == null || id.isEmpty) &&
        (conceptId == null || conceptId.isEmpty)) {
      return <IElement>[];
    }
    final List<IElement> result = <IElement>[];

    void collect(List<IElement> elementList) {
      for (final IElement element in elementList) {
        if (element.type == ElementType.table) {
          final List<dynamic>? trList = element.trList;
          if (trList != null) {
            for (final dynamic tr in trList) {
              final List<dynamic>? tdList = tr?.tdList as List<dynamic>?;
              if (tdList == null) {
                continue;
              }
              for (final dynamic td in tdList) {
                final List<IElement>? valueList = td?.value as List<IElement>?;
                if (valueList != null) {
                  collect(valueList);
                }
              }
            }
          }
        }
        if (id != null && element.id != id) {
          continue;
        }
        if (conceptId != null && element.conceptId != conceptId) {
          continue;
        }
        result.add(element);
      }
    }

    final List<List<IElement>> data = <List<IElement>>[
      _castElementList(draw.getHeaderElementList()),
      _castElementList(draw.getOriginalMainElementList()),
      _castElementList(draw.getFooterElementList()),
    ];
    for (final List<IElement> elementList in data) {
      collect(elementList);
    }
    if (result.isEmpty) {
      return <IElement>[];
    }
    return element_utils.zipElementList(
      result,
      options: const element_utils.ZipElementListOption(
        extraPickAttrs: <String>['id'],
      ),
    );
  }

  void setValue(dynamic payload, [ISetValueOption? options]) {
    draw.setValue(payload, options);
  }

  void removeControl([IRemoveControlOption? payload]) {
    if (payload?.id != null || payload?.conceptId != null) {
      final String? id = payload?.id;
      final String? conceptId = payload?.conceptId;
      bool isExistRemove = false;
      void remove(List<IElement> elementList) {
        var i = elementList.length - 1;
        while (i >= 0) {
          final IElement element = elementList[i];
          if (element.type == ElementType.table) {
            final List<dynamic>? trList = element.trList;
            if (trList != null) {
              for (final dynamic tr in trList) {
                final List<dynamic>? tdList = tr?.tdList as List<dynamic>?;
                if (tdList == null) {
                  continue;
                }
                for (final dynamic td in tdList) {
                  final List<IElement>? valueList =
                      td?.value as List<IElement>?;
                  if (valueList != null) {
                    remove(valueList);
                  }
                }
              }
            }
          }
          i -= 1;
          final bool hasControl = element.control != null;
          final bool matchId = id != null && element.controlId == id;
          final bool matchConcept =
              conceptId != null && element.control?.conceptId == conceptId;
          if (!hasControl || (!matchId && !matchConcept)) {
            continue;
          }
          isExistRemove = true;
          final int removeIndex = i + 1;
          if (removeIndex >= 0 && removeIndex < elementList.length) {
            elementList.removeAt(removeIndex);
          }
        }
      }

      final List<List<IElement>> data = <List<IElement>>[
        _castElementList(draw.getHeaderElementList()),
        _castElementList(draw.getOriginalMainElementList()),
        _castElementList(draw.getFooterElementList()),
      ];
      for (final List<IElement> elementList in data) {
        remove(elementList);
      }
      if (isExistRemove) {
        draw.render(IDrawOption(isSetCursor: false));
      }
      return;
    }

    final IRange currentRange = range.getRange();
    final int startIndex = currentRange.startIndex;
    final int endIndex = currentRange.endIndex;
    if (startIndex != endIndex) {
      return;
    }
    final List<IElement> elementList = _castElementList(draw.getElementList());
    if (startIndex < 0 || startIndex >= elementList.length) {
      return;
    }
    final IElement element = elementList[startIndex];
    if (element.controlId == null) {
      return;
    }
    final dynamic controlManager = draw.getControl();
    final dynamic newIndex = controlManager.removeControl(startIndex);
    if (newIndex == null || newIndex is! int) {
      return;
    }
    range.setRange(newIndex, newIndex);
    draw.render(IDrawOption(curIndex: newIndex));
  }

  String translate(String path) {
    return i18n.t(path) as String;
  }

  void setLocale(String payload) {
    i18n.setLocale(payload);
  }

  String getLocale() {
    final dynamic locale = i18n.getLocale();
    return locale is String ? locale : '';
  }

  Future<ICatalog?> getCatalog() {
    return workerManager.getCatalog();
  }

  void locationCatalog(String titleId) {
    final List<IElement> elementList =
        _castElementList(draw.getOriginalElementList());

    Map<String, dynamic>? getPosition(
      List<IElement> list,
      String id,
    ) {
      for (var e = 0; e < list.length; e++) {
        final IElement element = list[e];
        if (element.type == ElementType.table) {
          final List<dynamic>? trList = element.trList;
          if (trList != null) {
            for (var r = 0; r < trList.length; r++) {
              final dynamic tr = trList[r];
              final List<dynamic>? tdList = tr?.tdList as List<dynamic>?;
              if (tdList == null) {
                continue;
              }
              for (var d = 0; d < tdList.length; d++) {
                final dynamic td = tdList[d];
                final List<IElement>? valueList = td?.value as List<IElement>?;
                if (valueList == null) {
                  continue;
                }
                final Map<String, dynamic>? range = getPosition(valueList, id);
                if (range != null) {
                  range['isTable'] = true;
                  range['index'] = e;
                  range['trIndex'] = r;
                  range['tdIndex'] = d;
                  range['tdId'] = td?.id;
                  range['trId'] = tr?.id;
                  range['tableId'] = element.id;
                  return range;
                }
              }
            }
          }
        }
        if (element.titleId == id) {
          var newIndex = e;
          while (newIndex + 1 < list.length) {
            final IElement nextElement = list[newIndex + 1];
            if (nextElement.titleId != id) {
              break;
            }
            newIndex += 1;
          }
          return <String, dynamic>{
            'isTable': false,
            'startIndex': newIndex,
            'endIndex': newIndex,
          };
        }
      }
      return null;
    }

    final Map<String, dynamic>? context = getPosition(elementList, titleId);
    if (context == null) {
      return;
    }
    final bool isTable = context['isTable'] == true;
    final int endIndex = context['endIndex'] as int;
    final IPositionContext positionContext = IPositionContext(
      isTable: isTable,
      index: context['index'] as int?,
      trIndex: context['trIndex'] as int?,
      tdIndex: context['tdIndex'] as int?,
      tdId: context['tdId'] as String?,
      trId: context['trId'] as String?,
      tableId: context['tableId'] as String?,
    );
    position.setPositionContext(positionContext);
    range.setRange(
      endIndex,
      endIndex,
      context['tableId'] as String?,
      context['startTdIndex'] as int?,
      context['endTdIndex'] as int?,
      context['startTrIndex'] as int?,
      context['endTrIndex'] as int?,
    );
    draw.render(
      IDrawOption(
        curIndex: endIndex,
        isCompute: false,
        isSubmitHistory: false,
      ),
    );
  }

  void wordTool() {
    final List<IElement> elementList =
        _castElementList(draw.getMainElementList());
    bool isApply = false;
    for (var i = 0; i < elementList.length; i++) {
      final IElement element = elementList[i];
      if (element.value == ZERO) {
        while (i + 1 < elementList.length) {
          final IElement nextElement = elementList[i + 1];
          if (nextElement.value != ZERO && nextElement.value != NBSP) {
            break;
          }
          elementList.removeAt(i + 1);
          isApply = true;
        }
      }
    }
    if (!isApply) {
      final bool isCollapsed = range.getIsCollapsed() == true;
      draw.getCursor().drawCursor(isShow: isCollapsed);
    } else {
      draw.render(IDrawOption(isSetCursor: false));
    }
  }

  void setHTML(dynamic payload) {
    if (payload == null) {
      return;
    }
    final dynamic header = payload.header;
    final dynamic main = payload.main;
    final dynamic footer = payload.footer;
    final double innerWidth = _asNum(draw.getOriginalInnerWidth()).toDouble();

    List<IElement>? buildElementList(String? html) {
      if (html == null) {
        return null;
      }
      return element_utils.getElementListByHTML(
        html,
        element_utils.GetElementListByHtmlOption(
          innerWidth: innerWidth,
        ),
      );
    }

    final Map<String, dynamic> data = <String, dynamic>{};
    if (header != null) {
      data['header'] = buildElementList(header as String?);
    }
    if (main != null) {
      data['main'] = buildElementList(main as String?) ?? <IElement>[];
    }
    if (footer != null) {
      data['footer'] = buildElementList(footer as String?);
    }
    if (data.isNotEmpty) {
      setValue(data);
    }
  }

  String? setGroup() {
    if (_isReadonly()) {
      return null;
    }
    final dynamic group = draw.getGroup();
    final dynamic result = group.setGroup();
    return result is String ? result : null;
  }

  void deleteGroup(String groupId) {
    if (_isReadonly()) {
      return;
    }
    draw.getGroup().deleteGroup(groupId);
  }

  Future<List<String>> getGroupIds() {
    return draw.getWorkerManager().getGroupIds();
  }

  void locationGroup(String groupId) {
    final List<IElement> elementList =
        _castElementList(draw.getOriginalMainElementList());
    final dynamic context =
        draw.getGroup().getContextByGroupId(elementList, groupId);
    if (context == null) {
      return;
    }
    final IPositionContext positionContext = IPositionContext(
      isTable: context.isTable == true,
      index: context.index as int?,
      trIndex: context.trIndex as int?,
      tdIndex: context.tdIndex as int?,
      tdId: context.tdId as String?,
      trId: context.trId as String?,
      tableId: context.tableId as String?,
    );
    position.setPositionContext(positionContext);
    final int endIndex = context.endIndex as int;
    range.setRange(endIndex, endIndex);
    draw.render(
      IDrawOption(
        curIndex: endIndex,
        isCompute: false,
        isSubmitHistory: false,
      ),
    );
  }

  void setZone(EditorZone editorZone) {
    draw.getZone().setZone(editorZone);
  }

  IGetControlValueResult? getControlValue(IGetControlValueOption payload) {
    return draw.getControl().getValueById(payload);
  }

  void setControlValue(ISetControlValueOption payload) {
    draw.getControl().setValueListById(<ISetControlValueOption>[payload]);
  }

  void setControlValueList(List<ISetControlValueOption> payload) {
    if (payload.isEmpty) {
      return;
    }
    draw.getControl().setValueListById(payload);
  }

  void setControlExtension(ISetControlExtensionOption payload) {
    draw
        .getControl()
        .setExtensionListById(<ISetControlExtensionOption>[payload]);
  }

  void setControlExtensionList(List<ISetControlExtensionOption> payload) {
    if (payload.isEmpty) {
      return;
    }
    draw.getControl().setExtensionListById(payload);
  }

  void setControlProperties(ISetControlProperties payload) {
    draw.getControl().setPropertiesListById(<ISetControlProperties>[payload]);
  }

  void setControlPropertiesList(List<ISetControlProperties> payload) {
    if (payload.isEmpty) {
      return;
    }
    draw.getControl().setPropertiesListById(payload);
  }

  void setControlHighlight(ISetControlHighlightOption payload) {
    draw.getControl().setHighlightList(payload);
    draw.render(IDrawOption(isSubmitHistory: false));
  }

  void updateOptions(IUpdateOption payload) {
    _applyEditorOptionUpdate(payload);
    forceUpdate();
  }

  List<IElement> getControlList() {
    return draw.getControl().getList();
  }

  void locationControl(String controlId, [ILocationControlOption? options]) {
    ILocationPosition? locate(List<IElement> elementList, EditorZone zone) {
      var i = 0;
      while (i < elementList.length) {
        final IElement element = elementList[i];
        i += 1;
        if (element.type == ElementType.table) {
          final List<dynamic>? trList = element.trList;
          if (trList != null) {
            for (var r = 0; r < trList.length; r++) {
              final dynamic tr = trList[r];
              final List<dynamic>? tdList = tr?.tdList as List<dynamic>?;
              if (tdList == null) {
                continue;
              }
              for (var d = 0; d < tdList.length; d++) {
                final dynamic td = tdList[d];
                final List<IElement>? valueList = td?.value as List<IElement>?;
                if (valueList == null) {
                  continue;
                }
                final ILocationPosition? child = locate(valueList, zone);
                if (child != null) {
                  final IPositionContext context = child.positionContext;
                  context.isTable = true;
                  context.index = i - 1;
                  context.trIndex = r;
                  context.tdIndex = d;
                  context.tdId = element.tdId;
                  context.trId = element.trId;
                  context.tableId = element.tableId;
                  return child;
                }
              }
            }
          }
        }
        if (element.controlId != controlId) {
          continue;
        }
        var curIndex = i - 1;
        final LocationPosition positionType =
            options?.position ?? LocationPosition.before;
        if (positionType == LocationPosition.outerAfter) {
          final IElement? nextElement = curIndex + 1 < elementList.length
              ? elementList[curIndex + 1]
              : null;
          if (!(element.controlComponent == ControlComponent.postfix &&
              nextElement?.controlComponent != ControlComponent.postText)) {
            continue;
          }
        } else if (positionType == LocationPosition.outerBefore) {
          curIndex = curIndex - 1;
        } else if (positionType == LocationPosition.after) {
          curIndex = curIndex - 1;
          if (element.controlComponent != ControlComponent.placeholder &&
              element.controlComponent != ControlComponent.postfix &&
              element.controlComponent != ControlComponent.postText) {
            continue;
          }
        } else {
          final IElement? nextElement = curIndex + 1 < elementList.length
              ? elementList[curIndex + 1]
              : null;
          final bool isPrefix =
              element.controlComponent == ControlComponent.prefix ||
                  element.controlComponent == ControlComponent.preText;
          final bool nextIsPrefix =
              nextElement?.controlComponent == ControlComponent.prefix ||
                  nextElement?.controlComponent == ControlComponent.preText;
          if (!isPrefix || nextIsPrefix) {
            continue;
          }
        }
        if (curIndex < 0) {
          curIndex = 0;
        }
        return ILocationPosition(
          zone: zone,
          range: IRange(startIndex: curIndex, endIndex: curIndex),
          positionContext: IPositionContext(isTable: false),
        );
      }
      return null;
    }

    final List<Map<String, dynamic>> data = <Map<String, dynamic>>[
      <String, dynamic>{
        'zone': EditorZone.header,
        'elements': _castElementList(draw.getHeaderElementList()),
      },
      <String, dynamic>{
        'zone': EditorZone.main,
        'elements': _castElementList(draw.getOriginalMainElementList()),
      },
      <String, dynamic>{
        'zone': EditorZone.footer,
        'elements': _castElementList(draw.getFooterElementList()),
      },
    ];

    for (final Map<String, dynamic> entry in data) {
      final ILocationPosition? locationContext = locate(
        entry['elements'] as List<IElement>,
        entry['zone'] as EditorZone,
      );
      if (locationContext != null) {
        setZone(locationContext.zone);
        position.setPositionContext(locationContext.positionContext);
        range.replaceRange(locationContext.range);
        draw.render(
          IDrawOption(
            curIndex: locationContext.range.startIndex,
            isCompute: false,
            isSubmitHistory: false,
          ),
        );
        break;
      }
    }
  }

  void insertControl(IElement payload) {
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    final List<IElement> elementList = _castElementList(draw.getElementList());
    final int startIndex = range.getRange().startIndex;
    final IElement? copyElement =
        element_utils.getAnchorElement(elementList, startIndex);
    if (copyElement == null) {
      return;
    }
    final List<IElement> cloneList =
        element_utils.cloneElementList(<IElement>[payload]);
    final IElement cloneElement = cloneList.first;
    final List<String> cloneAttr = <String>[
      ...tableContextAttr,
      ...editorRowAttr,
      ...listContextAttr,
      ...areaContextAttr,
    ];
    _cloneElementContextProperties(copyElement, cloneElement, cloneAttr);
    draw.insertElementList(<IElement>[cloneElement]);
  }

  DivElement getContainer() {
    final dynamic container = draw.getContainer();
    return container is DivElement ? container : DivElement();
  }

  List<ITitleValueItem<IElement>> getTitleValue(IGetTitleValueOption payload) {
    final String conceptId = payload.conceptId;
    final List<ITitleValueItem<IElement>> result =
        <ITitleValueItem<IElement>>[];

    void collect(List<IElement> elementList, EditorZone zone) {
      var i = 0;
      while (i < elementList.length) {
        final IElement element = elementList[i];
        i += 1;
        if (element.type == ElementType.table) {
          final List<dynamic>? trList = element.trList;
          if (trList != null) {
            for (final dynamic tr in trList) {
              final List<dynamic>? tdList = tr?.tdList as List<dynamic>?;
              if (tdList == null) {
                continue;
              }
              for (final dynamic td in tdList) {
                final List<IElement>? valueList = td?.value as List<IElement>?;
                if (valueList != null) {
                  collect(valueList, zone);
                }
              }
            }
          }
        }
        final ITitle? title = element.title;
        if (title?.conceptId != conceptId) {
          continue;
        }
        final List<IElement> valueList = <IElement>[];
        var j = i;
        while (j < elementList.length) {
          final IElement nextElement = elementList[j];
          if (element.titleId == nextElement.titleId) {
            j += 1;
            continue;
          }
          if (nextElement.level != null &&
              element.level != null &&
              titleOrderNumberMapping[nextElement.level]! <=
                  titleOrderNumberMapping[element.level!]!) {
            break;
          }
          valueList.add(nextElement);
          j += 1;
        }
        result.add(
          ITitleValueItem<IElement>(
            conceptId: title?.conceptId,
            deletable: title?.deletable,
            disabled: title?.disabled,
            value: element_utils.getTextFromElementList(valueList),
            elementList: element_utils.zipElementList(valueList),
            zone: zone,
          ),
        );
        i = j;
      }
    }

    collect(_castElementList(draw.getHeaderElementList()), EditorZone.header);
    collect(
        _castElementList(draw.getOriginalMainElementList()), EditorZone.main);
    collect(_castElementList(draw.getFooterElementList()), EditorZone.footer);
    return result;
  }

  IPositionContextByEventResult? getPositionContextByEvent(
    MouseEvent evt, [
    IPositionContextByEventOption? options,
  ]) {
    final Element? target = evt.target as Element?;
    final String? indexValue = target?.dataset['index'];
    if (indexValue == null) {
      return null;
    }
    final bool isMustDirectHit = options?.isMustDirectHit ?? true;
    final int pageNo = int.tryParse(indexValue) ?? 0;
    final IGetPositionByXYPayload payload = IGetPositionByXYPayload(
      x: evt.offset.x.toDouble(),
      y: evt.offset.y.toDouble(),
      pageNo: pageNo,
    );
    final dynamic positionContext = position.getPositionByXY(payload);
    if (positionContext == null) {
      return null;
    }
    if ((isMustDirectHit && positionContext.isDirectHit != true) ||
        (positionContext.zone != null &&
            positionContext.zone != zone.getZone())) {
      return null;
    }

    IElement? targetElement;
    ITableInfoByEvent? tableInfo;
    final List<IElement> originalList =
        _castElementList(draw.getOriginalElementList());
    final List<dynamic> positionList =
        position.getOriginalPositionList() as List<dynamic>;
    if (positionContext.isTable == true) {
      final int tableIndex = positionContext.index as int? ?? 0;
      final IElement tableElement = originalList[tableIndex];
      final int trIndex = positionContext.trIndex as int? ?? 0;
      final int tdIndex = positionContext.tdIndex as int? ?? 0;
      final dynamic td = tableElement.trList?[trIndex].tdList[tdIndex];
      final List<IElement>? valueList = td?.value as List<IElement>?;
      final List<dynamic>? tdPositionList = td?.positionList as List<dynamic>?;
      if (valueList != null && tdPositionList != null) {
        final int valueIndex = positionContext.tdValueIndex as int? ?? 0;
        targetElement = valueIndex >= 0 && valueIndex < valueList.length
            ? valueList[valueIndex]
            : null;
        tableInfo = ITableInfoByEvent(
          element: tableElement,
          trIndex: trIndex,
          tdIndex: tdIndex,
        );
      }
    } else {
      final int index = positionContext.index as int? ?? 0;
      targetElement = index >= 0 && index < originalList.length
          ? originalList[index]
          : null;
    }

    RangeRect? rangeRect;
    final dynamic selectionPosition = positionContext.isTable == true
        ? null
        : (positionContext.index as int?) != null
            ? positionList[positionContext.index as int]
            : null;
    if (selectionPosition != null) {
      final List<dynamic> leftTop =
          selectionPosition.coordinate?.leftTop as List<dynamic>? ??
              <dynamic>[0, 0];
      final List<dynamic> rightTop =
          selectionPosition.coordinate?.rightTop as List<dynamic>? ??
              <dynamic>[0, 0];
      final double height = _asNum(draw.getOriginalHeight()).toDouble();
      final double pageGap = _asNum(draw.getOriginalPageGap()).toDouble();
      rangeRect = RangeRect(
        x: _asNum(leftTop.isNotEmpty ? leftTop.first : 0).toDouble(),
        y: _asNum(leftTop.length > 1 ? leftTop[1] : 0).toDouble() +
            pageNo * (height + pageGap),
        width: _asNum(rightTop.isNotEmpty ? rightTop.first : 0).toDouble() -
            _asNum(leftTop.isNotEmpty ? leftTop.first : 0).toDouble(),
        height: _asNum(selectionPosition.lineHeight).toDouble(),
      );
    }

    return IPositionContextByEventResult(
      pageNo: pageNo,
      element: targetElement,
      rangeRect: rangeRect,
      tableInfo: tableInfo,
    );
  }

  void insertTitle(IElement payload) {
    if (_isReadonly() || _isDisabled()) {
      return;
    }
    final List<IElement> elementList = _castElementList(draw.getElementList());
    final int startIndex = range.getRange().startIndex;
    final IElement? copyElement =
        element_utils.getAnchorElement(elementList, startIndex);
    if (copyElement == null) {
      return;
    }
    final List<IElement> cloneList =
        element_utils.cloneElementList(<IElement>[payload]);
    final IElement cloneElement = cloneList.first;
    final List<String> cloneAttr = <String>[
      ...tableContextAttr,
      ...editorRowAttr,
      ...listContextAttr,
      ...areaContextAttr,
    ];
    cloneElement.valueList?.forEach(
      (IElement valueItem) =>
          _cloneElementContextProperties(copyElement, valueItem, cloneAttr),
    );
    draw.insertElementList(<IElement>[cloneElement]);
  }

  void focus([IFocusOption? payload]) {
    final LocationPosition positionType =
        payload?.position ?? LocationPosition.after;
    final bool isMoveCursorToVisible = payload?.isMoveCursorToVisible ?? true;
    int curIndex = -1;
    if (payload?.range != null) {
      range.replaceRange(payload!.range!);
      curIndex = positionType == LocationPosition.before
          ? payload.range!.startIndex
          : payload.range!.endIndex;
    } else if (payload?.rowNo != null) {
      final List<dynamic> rowList = draw.getOriginalRowList() as List<dynamic>;
      final int rowNo = payload!.rowNo!;
      if (positionType == LocationPosition.before) {
        curIndex = _asInt(rowList[rowNo]?.startIndex);
      } else {
        curIndex = _asInt(rowList[rowNo + 1]?.startIndex) - 1;
      }
      if (curIndex < 0) {
        return;
      }
      range.setRange(curIndex, curIndex);
    } else {
      final List<IElement> mainList =
          _castElementList(draw.getOriginalMainElementList());
      curIndex =
          positionType == LocationPosition.before ? 0 : mainList.length - 1;
      range.setRange(curIndex, curIndex);
    }

    final IDrawOption renderParams = IDrawOption(
      isCompute: false,
      isSetCursor: false,
      isSubmitHistory: false,
    );
    if (curIndex >= 0 && range.getIsCollapsed() == true) {
      renderParams.curIndex = curIndex;
      renderParams.isSetCursor = true;
    }
    draw.render(renderParams);

    if (isMoveCursorToVisible && curIndex >= 0) {
      final List<dynamic> positionList =
          position.getPositionList() as List<dynamic>;
      if (curIndex < positionList.length) {
        final dynamic cursorPosition = positionList[curIndex];
        draw.getCursor().moveCursorToVisible(
              cursorPosition: cursorPosition,
              direction: MoveDirection.down,
            );
      }
    }
  }

  dynamic insertArea(IInsertAreaOption payload) {
    return draw.getArea().insertArea(payload);
  }

  dynamic setAreaValue(ISetAreaValueOption payload) {
    return draw.getArea().setAreaValue(payload);
  }

  void setAreaProperties(ISetAreaPropertiesOption payload) {
    draw.getArea().setAreaProperties(payload);
  }

  void locationArea(String areaId, [ILocationAreaOption? options]) {
    if (options?.isAppendLastLineBreak == true &&
        options?.position == LocationPosition.outerAfter) {
      final List<IElement> elementList =
          _castElementList(draw.getOriginalMainElementList());
      if (elementList.isNotEmpty && elementList.last.areaId == areaId) {
        draw.appendElementList(
          <IElement>[IElement(value: ZERO)],
          IAppendElementListOption(isSubmitHistory: false),
        );
      }
    }
    final dynamic context = draw.getArea().getContextByAreaId(areaId, options);
    if (context == null) {
      return;
    }
    final IRange areaRange = context.range as IRange;
    final IElementPosition elementPosition =
        context.elementPosition as IElementPosition;
    position.setPositionContext(IPositionContext(isTable: false));
    range.setRange(areaRange.endIndex, areaRange.endIndex);
    draw.render(
      IDrawOption(
        curIndex: areaRange.endIndex,
        isSetCursor: true,
        isCompute: false,
        isSubmitHistory: false,
      ),
    );
    position.setCursorPosition(elementPosition);
    draw.getCursor().moveCursorToVisible(
          cursorPosition: elementPosition,
          direction: MoveDirection.up,
        );
  }

  // ---------------------------------------------------------------------------
  // Helpers

  void _applyElementOverrides(IElement target, IElement source) {
    target.value = source.value;
    if (source.id != null) {
      target.id = source.id;
    }
    if (source.type != null) {
      target.type = source.type;
    }
    if (source.extension != null) {
      target.extension = source.extension;
    }
    if (source.externalId != null) {
      target.externalId = source.externalId;
    }
    if (source.font != null) {
      target.font = source.font;
    }
    if (source.size != null) {
      target.size = source.size;
    }
    if (source.width != null) {
      target.width = source.width;
    }
    if (source.height != null) {
      target.height = source.height;
    }
    if (source.bold != null) {
      target.bold = source.bold;
    }
    if (source.color != null) {
      target.color = source.color;
    }
    if (source.highlight != null) {
      target.highlight = source.highlight;
    }
    if (source.italic != null) {
      target.italic = source.italic;
    }
    if (source.underline != null) {
      target.underline = source.underline;
    }
    if (source.strikeout != null) {
      target.strikeout = source.strikeout;
    }
    if (source.rowFlex != null) {
      target.rowFlex = source.rowFlex;
    }
    if (source.rowMargin != null) {
      target.rowMargin = source.rowMargin;
    }
    if (source.letterSpacing != null) {
      target.letterSpacing = source.letterSpacing;
    }
    if (source.textDecoration != null) {
      target.textDecoration = source.textDecoration;
    }
    if (source.hide != null) {
      target.hide = source.hide;
    }
    if (source.groupIds != null) {
      target.groupIds = List<String>.from(source.groupIds!);
    }
    if (source.colgroup != null) {
      target.colgroup = List<IColgroup>.from(source.colgroup!);
    }
    if (source.trList != null) {
      target.trList = List<ITr>.from(source.trList!);
    }
    if (source.borderType != null) {
      target.borderType = source.borderType;
    }
    if (source.borderColor != null) {
      target.borderColor = source.borderColor;
    }
    if (source.borderWidth != null) {
      target.borderWidth = source.borderWidth;
    }
    if (source.borderExternalWidth != null) {
      target.borderExternalWidth = source.borderExternalWidth;
    }
    if (source.translateX != null) {
      target.translateX = source.translateX;
    }
    if (source.tableToolDisabled != null) {
      target.tableToolDisabled = source.tableToolDisabled;
    }
    if (source.tdId != null) {
      target.tdId = source.tdId;
    }
    if (source.trId != null) {
      target.trId = source.trId;
    }
    if (source.tableId != null) {
      target.tableId = source.tableId;
    }
    if (source.conceptId != null) {
      target.conceptId = source.conceptId;
    }
    if (source.pagingId != null) {
      target.pagingId = source.pagingId;
    }
    if (source.pagingIndex != null) {
      target.pagingIndex = source.pagingIndex;
    }
    if (source.valueList != null) {
      target.valueList = element_utils.cloneElementList(source.valueList!);
    }
    if (source.url != null) {
      target.url = source.url;
    }
    if (source.hyperlinkId != null) {
      target.hyperlinkId = source.hyperlinkId;
    }
    if (source.actualSize != null) {
      target.actualSize = source.actualSize;
    }
    if (source.dashArray != null) {
      target.dashArray = List<double>.from(source.dashArray!);
    }
    if (source.control != null) {
      target.control = source.control;
    }
    if (source.controlId != null) {
      target.controlId = source.controlId;
    }
    if (source.controlComponent != null) {
      target.controlComponent = source.controlComponent;
    }
    if (source.checkbox != null) {
      target.checkbox = source.checkbox;
    }
    if (source.radio != null) {
      target.radio = source.radio;
    }
    if (source.laTexSVG != null) {
      target.laTexSVG = source.laTexSVG;
    }
    if (source.dateFormat != null) {
      target.dateFormat = source.dateFormat;
    }
    if (source.dateId != null) {
      target.dateId = source.dateId;
    }
    if (source.imgDisplay != null) {
      target.imgDisplay = source.imgDisplay;
    }
    if (source.imgFloatPosition != null) {
      target.imgFloatPosition = Map<String, num>.from(source.imgFloatPosition!);
    }
    if (source.imgToolDisabled != null) {
      target.imgToolDisabled = source.imgToolDisabled;
    }
    if (source.block != null) {
      target.block = source.block;
    }
    if (source.level != null) {
      target.level = source.level;
    }
    if (source.titleId != null) {
      target.titleId = source.titleId;
    }
    if (source.title != null) {
      target.title = source.title;
    }
    if (source.listType != null) {
      target.listType = source.listType;
    }
    if (source.listStyle != null) {
      target.listStyle = source.listStyle;
    }
    if (source.listId != null) {
      target.listId = source.listId;
    }
    if (source.listWrap != null) {
      target.listWrap = source.listWrap;
    }
    if (source.areaId != null) {
      target.areaId = source.areaId;
    }
    if (source.areaIndex != null) {
      target.areaIndex = source.areaIndex;
    }
    if (source.area != null) {
      target.area = source.area;
    }
  }

  void _cloneElementContextProperties(
    IElement source,
    IElement target,
    List<String> attributes,
  ) {
    for (final String attr in attributes) {
      switch (attr) {
        case 'tdId':
          target.tdId = source.tdId;
          break;
        case 'trId':
          target.trId = source.trId;
          break;
        case 'tableId':
          target.tableId = source.tableId;
          break;
        case 'rowFlex':
          target.rowFlex = source.rowFlex;
          break;
        case 'rowMargin':
          target.rowMargin = source.rowMargin;
          break;
        case 'listId':
          target.listId = source.listId;
          break;
        case 'listType':
          target.listType = source.listType;
          break;
        case 'listStyle':
          target.listStyle = source.listStyle;
          break;
        case 'areaId':
          target.areaId = source.areaId;
          break;
        case 'area':
          target.area = source.area;
          break;
      }
    }
  }

  void _applyEditorOptionUpdate(IUpdateOption payload) {
    final dynamic editorOptions = options;
    if (editorOptions == null) {
      return;
    }
    if (payload.locale != null) {
      editorOptions.locale = payload.locale;
    }
    if (payload.defaultType != null) {
      editorOptions.defaultType = payload.defaultType;
    }
    if (payload.defaultColor != null) {
      editorOptions.defaultColor = payload.defaultColor;
    }
    if (payload.defaultFont != null) {
      editorOptions.defaultFont = payload.defaultFont;
    }
    if (payload.defaultSize != null) {
      editorOptions.defaultSize = payload.defaultSize;
    }
    if (payload.minSize != null) {
      editorOptions.minSize = payload.minSize;
    }
    if (payload.maxSize != null) {
      editorOptions.maxSize = payload.maxSize;
    }
    if (payload.defaultBasicRowMarginHeight != null) {
      editorOptions.defaultBasicRowMarginHeight =
          payload.defaultBasicRowMarginHeight;
    }
    if (payload.defaultRowMargin != null) {
      editorOptions.defaultRowMargin = payload.defaultRowMargin;
    }
    if (payload.defaultTabWidth != null) {
      editorOptions.defaultTabWidth = payload.defaultTabWidth;
    }
    if (payload.underlineColor != null) {
      editorOptions.underlineColor = payload.underlineColor;
    }
    if (payload.strikeoutColor != null) {
      editorOptions.strikeoutColor = payload.strikeoutColor;
    }
    if (payload.rangeColor != null) {
      editorOptions.rangeColor = payload.rangeColor;
    }
    if (payload.rangeAlpha != null) {
      editorOptions.rangeAlpha = payload.rangeAlpha;
    }
    if (payload.rangeMinWidth != null) {
      editorOptions.rangeMinWidth = payload.rangeMinWidth;
    }
    if (payload.searchMatchColor != null) {
      editorOptions.searchMatchColor = payload.searchMatchColor;
    }
    if (payload.searchNavigateMatchColor != null) {
      editorOptions.searchNavigateMatchColor = payload.searchNavigateMatchColor;
    }
    if (payload.searchMatchAlpha != null) {
      editorOptions.searchMatchAlpha = payload.searchMatchAlpha;
    }
    if (payload.highlightAlpha != null) {
      editorOptions.highlightAlpha = payload.highlightAlpha;
    }
    if (payload.highlightMarginHeight != null) {
      editorOptions.highlightMarginHeight = payload.highlightMarginHeight;
    }
    if (payload.resizerColor != null) {
      editorOptions.resizerColor = payload.resizerColor;
    }
    if (payload.resizerSize != null) {
      editorOptions.resizerSize = payload.resizerSize;
    }
    if (payload.marginIndicatorSize != null) {
      editorOptions.marginIndicatorSize = payload.marginIndicatorSize;
    }
    if (payload.marginIndicatorColor != null) {
      editorOptions.marginIndicatorColor = payload.marginIndicatorColor;
    }
    if (payload.margins != null) {
      editorOptions.margins = payload.margins;
    }
    if (payload.renderMode != null) {
      editorOptions.renderMode = payload.renderMode;
    }
    if (payload.defaultHyperlinkColor != null) {
      editorOptions.defaultHyperlinkColor = payload.defaultHyperlinkColor;
    }
    if (payload.inactiveAlpha != null) {
      editorOptions.inactiveAlpha = payload.inactiveAlpha;
    }
    if (payload.printPixelRatio != null) {
      editorOptions.printPixelRatio = payload.printPixelRatio;
    }
    if (payload.maskMargin != null) {
      editorOptions.maskMargin = payload.maskMargin;
    }
    if (payload.letterClass != null) {
      editorOptions.letterClass = List<String>.from(payload.letterClass!);
    }
    if (payload.contextMenuDisableKeys != null) {
      editorOptions.contextMenuDisableKeys =
          List<String>.from(payload.contextMenuDisableKeys!);
    }
    if (payload.shortcutDisableKeys != null) {
      editorOptions.shortcutDisableKeys =
          List<String>.from(payload.shortcutDisableKeys!);
    }
    if (payload.pageOuterSelectionDisable != null) {
      editorOptions.pageOuterSelectionDisable =
          payload.pageOuterSelectionDisable;
    }
    if (payload.wordBreak != null) {
      editorOptions.wordBreak = payload.wordBreak;
    }
    if (payload.table != null) {
      editorOptions.table = payload.table;
    }
    if (payload.header != null) {
      editorOptions.header = payload.header;
    }
    if (payload.footer != null) {
      editorOptions.footer = payload.footer;
    }
    if (payload.pageNumber != null) {
      editorOptions.pageNumber = payload.pageNumber;
    }
    if (payload.watermark != null) {
      editorOptions.watermark = payload.watermark;
    }
    if (payload.control != null) {
      editorOptions.control = payload.control;
    }
    if (payload.checkbox != null) {
      editorOptions.checkbox = payload.checkbox;
    }
    if (payload.radio != null) {
      editorOptions.radio = payload.radio;
    }
    if (payload.cursor != null) {
      editorOptions.cursor = payload.cursor;
    }
    if (payload.title != null) {
      editorOptions.title = payload.title;
    }
    if (payload.placeholder != null) {
      editorOptions.placeholder = payload.placeholder;
    }
    if (payload.group != null) {
      editorOptions.group = payload.group;
    }
    if (payload.pageBreak != null) {
      editorOptions.pageBreak = payload.pageBreak;
    }
    if (payload.zone != null) {
      editorOptions.zone = payload.zone;
    }
    if (payload.background != null) {
      editorOptions.background = payload.background;
    }
    if (payload.lineBreak != null) {
      editorOptions.lineBreak = payload.lineBreak;
    }
    if (payload.separator != null) {
      editorOptions.separator = payload.separator;
    }
    if (payload.lineNumber != null) {
      editorOptions.lineNumber = payload.lineNumber;
    }
    if (payload.pageBorder != null) {
      editorOptions.pageBorder = payload.pageBorder;
    }
    if (payload.badge != null) {
      editorOptions.badge = payload.badge;
    }
    if (payload.modeRule != null) {
      editorOptions.modeRule = payload.modeRule;
    }
  }

  bool _isReadonly() => draw.isReadonly() == true;

  bool _isDisabled() => draw.isDisabled() == true;

  List<IElement> _safeSublist(List<IElement> source, int start, int end) {
    if (source.isEmpty) {
      return <IElement>[];
    }
    int normalizedStart = start;
    int normalizedEnd = end;
    if (normalizedStart < 0) {
      normalizedStart = 0;
    }
    if (normalizedEnd > source.length) {
      normalizedEnd = source.length;
    }
    if (normalizedStart >= normalizedEnd) {
      return <IElement>[];
    }
    return source.sublist(normalizedStart, normalizedEnd);
  }

  int? _resolveTitleSize(dynamic titleOption, TitleLevel level) {
    if (titleOption == null) {
      return null;
    }
    dynamic lookupKey = titleSizeMapping[level];
    if (lookupKey is String) {
      final dynamic value = titleOption is Map
          ? titleOption[lookupKey]
          : _readTitleOptionProperty(titleOption, lookupKey);
      if (value is num) {
        return value.round();
      }
    }
    return null;
  }

  dynamic _readTitleOptionProperty(dynamic titleOption, String key) {
    switch (key) {
      case 'defaultFirstSize':
        return titleOption.defaultFirstSize;
      case 'defaultSecondSize':
        return titleOption.defaultSecondSize;
      case 'defaultThirdSize':
        return titleOption.defaultThirdSize;
      case 'defaultFourthSize':
        return titleOption.defaultFourthSize;
      case 'defaultFifthSize':
        return titleOption.defaultFifthSize;
      case 'defaultSixthSize':
        return titleOption.defaultSixthSize;
      default:
        return null;
    }
  }

  List<IElement> _castElementList(dynamic value) {
    if (value is List<IElement>) {
      return value;
    }
    if (value is List) {
      return value.whereType<IElement>().toList();
    }
    return <IElement>[];
  }

  dynamic _getElementAttr(IElement element, String attr) {
    switch (attr) {
      case 'bold':
        return element.bold;
      case 'color':
        return element.color;
      case 'highlight':
        return element.highlight;
      case 'font':
        return element.font;
      case 'size':
        return element.size;
      case 'italic':
        return element.italic;
      case 'underline':
        return element.underline;
      case 'strikeout':
        return element.strikeout;
      case 'textDecoration':
        return element.textDecoration;
      default:
        return null;
    }
  }

  dynamic _getStyleValue(IElementStyle style, String attr) {
    switch (attr) {
      case 'bold':
        return style.bold;
      case 'color':
        return style.color;
      case 'highlight':
        return style.highlight;
      case 'font':
        return style.font;
      case 'size':
        return style.size;
      case 'italic':
        return style.italic;
      case 'underline':
        return style.underline;
      case 'strikeout':
        return style.strikeout;
      case 'textDecoration':
        return style.textDecoration;
      default:
        return null;
    }
  }

  void _setStyleValue(IElementStyle style, String attr, dynamic value) {
    switch (attr) {
      case 'bold':
        style.bold = value as bool?;
        break;
      case 'color':
        style.color = value as String?;
        break;
      case 'highlight':
        style.highlight = value as String?;
        break;
      case 'font':
        style.font = value as String?;
        break;
      case 'size':
        style.size = value as int?;
        break;
      case 'italic':
        style.italic = value as bool?;
        break;
      case 'underline':
        style.underline = value as bool?;
        break;
      case 'strikeout':
        style.strikeout = value as bool?;
        break;
      case 'textDecoration':
        style.textDecoration = value as ITextDecoration?;
        break;
    }
  }

  void _clearElementAttr(IElement element, String attr) {
    switch (attr) {
      case 'bold':
        element.bold = null;
        break;
      case 'color':
        element.color = null;
        break;
      case 'highlight':
        element.highlight = null;
        break;
      case 'font':
        element.font = null;
        break;
      case 'size':
        element.size = null;
        break;
      case 'italic':
        element.italic = null;
        break;
      case 'underline':
        element.underline = null;
        break;
      case 'strikeout':
        element.strikeout = null;
        break;
      case 'textDecoration':
        element.textDecoration = null;
        break;
    }
  }

  Map<String, dynamic>? _textDecorationToMap(ITextDecoration? decoration) {
    if (decoration == null) {
      return null;
    }
    return <String, dynamic>{
      'style': decoration.style,
    };
  }

  IEditorOption? _editorOption() {
    final dynamic editorOptions = options;
    return editorOptions is IEditorOption ? editorOptions : null;
  }

  int _clampIndex(int index, int length) {
    if (length <= 0) {
      return 0;
    }
    if (index < 0) {
      return 0;
    }
    if (index >= length) {
      return length - 1;
    }
    return index;
  }

  int _asInt(dynamic value) => _asNum(value).toInt();

  num _asNum(dynamic value) {
    if (value is num) {
      return value;
    }
    if (value is String) {
      final double? parsed = double.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }
}
