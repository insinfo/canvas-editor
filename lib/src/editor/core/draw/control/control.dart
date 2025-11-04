import 'dart:html';

import '../../../dataset/constant/common.dart';
import '../../../dataset/enum/common.dart';
import '../../../dataset/constant/element.dart' as element_constants;
import '../../../dataset/enum/control.dart';
import '../../../dataset/enum/editor.dart';
import '../../../dataset/enum/element.dart';
import '../../../dataset/enum/observer.dart';
import '../../../dataset/enum/row.dart';
import '../../../interface/control.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/event_bus.dart';
import '../../../interface/position.dart';
import '../../../interface/range.dart';
import '../../../interface/row.dart';
import '../../../interface/table/td.dart';
import '../../../interface/table/tr.dart';
import '../../../utils/element.dart' as element_utils;
import '../../../utils/index.dart' as utils;
import '../../cursor/cursor.dart' show IMoveCursorToVisibleOption;
import '../../event/eventbus/event_bus.dart';
import '../../listener/listener.dart';
import '../../range/range_manager.dart';
import '../draw.dart';
import 'checkbox/checkbox_control.dart';
import 'date/date_control.dart';
import 'interactive/control_search.dart';
import 'number/number_control.dart';
import 'radio/radio_control.dart';
import 'richtext/border.dart';
import 'select/select_control.dart';
import 'text/text_control.dart';

class Control {
  Control(this._draw)
      : _controlBorder = ControlBorder(_draw),
        _range = (_draw.getRange() as RangeManager),
        _listener = _draw.getListener() as Listener?,
        _eventBus = _draw.getEventBus() as EventBus<EventBusMap>?,
        _options = _draw.getOptions(),
        _controlOptions = _draw.getOptions().control ?? IControlOption(),
        _activeControlValue = <IElement>[] {
    _controlSearch = ControlSearch(this);
  }

  final Draw _draw;
  final ControlBorder _controlBorder;
  final RangeManager _range;
  final Listener? _listener;
  final EventBus<EventBusMap>? _eventBus;
  late final ControlSearch _controlSearch;
  final IEditorOption _options;
  final IControlOption _controlOptions;

  IControlInstance? _activeControl;
  List<IElement> _activeControlValue;
  IElement? _preElement;

  Draw getDraw() => _draw;

  void setHighlightList(List<IControlHighlight> payload) {
    _controlSearch.setHighlightList(payload);
  }

  void computeHighlightList() {
    if (_controlSearch.getHighlightList().isEmpty) {
      return;
    }
    _controlSearch.computeHighlightList();
  }

  void renderHighlightList(CanvasRenderingContext2D ctx, int pageNo) {
    if (_controlSearch.getHighlightMatchResult().isEmpty) {
      return;
    }
    _controlSearch.renderHighlightList(ctx, pageNo);
  }

  List<IElement> getElementList() => _draw.getElementList();

  ControlBorder getControlBorder() => _controlBorder;

  IControlOption getControlOptions() => _controlOptions;

  IElement? getPreviousElement() => _preElement;

  void setPreviousElement(IElement? element) {
    _preElement = element;
  }

  IRange getRange() => _range.getRange();

  void shrinkBoundary([IControlContext? context]) {
    if (context != null) {
      _range.shrinkBoundary(context);
    } else {
      _range.shrinkBoundary();
    }
  }

  List<IElement> filterAssistElement(List<IElement> elementList) {
    final List<IElement> filtered = <IElement>[];
    for (int index = 0; index < elementList.length; index++) {
      final IElement element = elementList[index];
      if (element.type == ElementType.table && element.trList != null) {
        for (final ITr tr in element.trList!) {
          for (final ITd td in tr.tdList) {
            td.value = filterAssistElement(td.value);
          }
        }
      }
      if (element.controlId == null) {
        filtered.add(element);
        continue;
      }
      final IControl? control = element.control;
      final double? minWidth = control?.minWidth;
      if (minWidth != null && minWidth > 0) {
        if (element.controlComponent == ControlComponent.prefix ||
                         element.controlComponent == ControlComponent.postfix) {
          element.value = '';
          filtered.add(element);
          continue;
        }
      } else {
        if (control?.preText?.isNotEmpty == true &&
                 element.controlComponent == ControlComponent.preText) {
          bool isExistValue = false;
          int cursor = index + 1;
          while (cursor < elementList.length) {
            final IElement nextElement = elementList[cursor];
            if (nextElement.controlId != element.controlId) {
              break;
            }
            if (nextElement.controlComponent == ControlComponent.value) {
              isExistValue = true;
              break;
            }
            cursor += 1;
          }
          if (!isExistValue) {
            continue;
          }
        }
        if (control?.postText?.isNotEmpty == true &&
                 element.controlComponent == ControlComponent.postText) {
          bool isExistValue = false;
          int cursor = index - 1;
          while (cursor >= 0) {
            final IElement prevElement = elementList[cursor];
            if (prevElement.controlId != element.controlId) {
              break;
            }
            if (prevElement.controlComponent == ControlComponent.value) {
              isExistValue = true;
              break;
            }
            cursor -= 1;
          }
          if (!isExistValue) {
            continue;
          }
        }
      }
      if (element.controlComponent == ControlComponent.prefix ||
             element.controlComponent == ControlComponent.postfix ||
             element.controlComponent == ControlComponent.placeholder) {
        continue;
      }
      filtered.add(element);
    }
    return filtered;
  }

  bool getIsRangeCanCaptureEvent() {
    if (_activeControl == null) {
      return false;
    }
    final IRange range = getRange();
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex < 0 && endIndex < 0) {
      return false;
    }
    final List<IElement> elementList = getElementList();
    if (startIndex < 0 || startIndex >= elementList.length) {
      return false;
    }
    final IElement startElement = elementList[startIndex];
    if (startIndex == endIndex &&
        startElement.controlComponent == ControlComponent.postfix) {
      return true;
    }
    if (endIndex < 0 || endIndex >= elementList.length) {
      return false;
    }
    final IElement endElement = elementList[endIndex];
    if (startElement.controlId != null &&
        startElement.controlId == endElement.controlId &&
        endElement.controlComponent != ControlComponent.postfix) {
      return true;
    }
    return false;
  }

  bool getIsDisabledControl([IControlContext? context]) {
    if (_draw.isDesignMode() || _activeControl == null) {
      return false;
    }
    final IRange range = context?.range ?? _range.getRange();
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex == endIndex && startIndex >= 0 && endIndex >= 0) {
      final List<IElement> elementList = context?.elementList ?? getElementList();
      if (startIndex < elementList.length) {
        final IElement startElement = elementList[startIndex];
        if (startElement.controlComponent == ControlComponent.postfix) {
          return false;
        }
      }
    }
    return _activeControl?.getElement().control?.disabled == true;
  }

  bool getIsDisabledPasteControl([IControlContext? context]) {
    if (_draw.isDesignMode() || _activeControl == null) {
      return false;
    }
    final IRange range = context?.range ?? _range.getRange();
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex == endIndex && startIndex >= 0 && endIndex >= 0) {
      final List<IElement> elementList = context?.elementList ?? getElementList();
      if (startIndex < elementList.length) {
        final IElement startElement = elementList[startIndex];
        if (startElement.controlComponent == ControlComponent.postfix) {
          return false;
        }
      }
    }
    return _activeControl?.getElement().control?.pasteDisabled == true;
  }

  int? removeControl(int startIndex, [IControlContext? context]) {
    final List<IElement> elementList = context?.elementList ?? getElementList();
    if (startIndex < 0 || startIndex >= elementList.length) {
      return startIndex;
    }
    final IElement startElement = elementList[startIndex];
    if (startElement.controlId == null) {
      return startIndex;
    }
    if (!_draw.isDesignMode() &&
        startElement.hide != true &&
        startElement.control?.hide != true &&
        startElement.area?.hide != true) {
      final bool deletable = startElement.control?.deletable ?? true;
      if (!deletable) {
        return null;
      }
      final EditorMode mode = _draw.getMode();
      final IModeRule? modeRule = _options.modeRule;
      if (mode == EditorMode.form &&
          modeRule?.form?.controlDeletableDisabled == true) {
        return null;
      }
    }
    int leftBoundary = startIndex;
    while (leftBoundary > 0) {
      final IElement previous = elementList[leftBoundary - 1];
      if (previous.controlId != startElement.controlId) {
        break;
      }
      leftBoundary -= 1;
    }
    int rightBoundary = startIndex;
    while (rightBoundary + 1 < elementList.length) {
      final IElement next = elementList[rightBoundary + 1];
      if (next.controlId != startElement.controlId) {
        break;
      }
      rightBoundary += 1;
    }
    final int deleteCount = rightBoundary - leftBoundary + 1;
    if (deleteCount <= 0) {
      return startIndex;
    }
    _draw.spliceElementList(elementList, leftBoundary, deleteCount);
    final int newIndex = leftBoundary > 0 ? leftBoundary - 1 : 0;
    return newIndex;
  }

  void removePlaceholder(int startIndex, [IControlContext? context]) {
    final List<IElement> elementList = context?.elementList ?? getElementList();
    if (startIndex < 0 || startIndex >= elementList.length) {
      return;
    }
    final IElement startElement = elementList[startIndex];
    final IElement? nextElement =
        startIndex + 1 < elementList.length ? elementList[startIndex + 1] : null;
    final bool isCurrentPlaceholder =
        startElement.controlComponent == ControlComponent.placeholder;
    final bool isNextPlaceholder =
        nextElement?.controlComponent == ControlComponent.placeholder;
    if (!isCurrentPlaceholder && !isNextPlaceholder) {
      return;
    }
    bool isHistoryAdjusted = false;
    int index = startIndex;
    while (index < elementList.length) {
      final IElement current = elementList[index];
      if (current.controlId != startElement.controlId) {
        break;
      }
      if (current.controlComponent == ControlComponent.placeholder) {
        if (!isHistoryAdjusted) {
          isHistoryAdjusted = true;
          final dynamic historyManager = _draw.getHistoryManager();
          final dynamic popUndo = historyManager?.popUndo;
          if (popUndo is Function) {
            popUndo();
          }
          _draw.submitHistory(startIndex);
        }
        elementList.removeAt(index);
        continue;
      }
      index += 1;
    }
  }

  void addPlaceholder(int startIndex, [IControlContext? context]) {
    final List<IElement> elementList = context?.elementList ?? getElementList();
    if (startIndex < 0 || startIndex >= elementList.length) {
      return;
    }
    final IElement startElement = elementList[startIndex];
    final IControl? control = startElement.control;
    final String? placeholder = control?.placeholder;
    if (placeholder == null || placeholder.isEmpty) {
      return;
    }
    final List<String> placeholderUnits = utils.splitText(placeholder);
    final IElement anchorStyle = element_utils.pickElementAttr(
      startElement,
      extraPickAttrs: element_constants.controlStyleAttr,
    );
    final String? placeholderColor = _controlOptions.placeholderColor;
    for (int p = 0; p < placeholderUnits.length; p++) {
      final String rawValue = placeholderUnits[p];
      final IElement newElement = IElement(
        value: rawValue == '\n' ? ZERO : rawValue,
        controlId: startElement.controlId,
        type: ElementType.control,
        control: control,
        controlComponent: ControlComponent.placeholder,
        color: placeholderColor,
        font: anchorStyle.font,
        size: anchorStyle.size,
        bold: anchorStyle.bold,
        highlight: anchorStyle.highlight,
        italic: anchorStyle.italic,
        strikeout: anchorStyle.strikeout,
        underline: anchorStyle.underline,
      );
      element_utils.formatElementContext(
        elementList,
        <IElement>[newElement],
        startIndex,
        options: element_utils.FormatElementContextOption(
          editorOptions: _options,
        ),
      );
      _draw.spliceElementList(
        elementList,
        startIndex + p + 1,
        0,
        <IElement>[newElement],
      );
    }
  }

  void destroyControl([IDestroyControlOption? options]) {
    final IControlInstance? active = _activeControl;
    if (active == null) {
      return;
    }
    final bool isEmitEvent = options?.isEmitEvent ?? true;
    if (active is SelectControl) {
      active.destroy();
    } else if (active is DateControl) {
      active.destroy();
    }
    if (isEmitEvent &&
        _preElement?.controlComponent != ControlComponent.postfix) {
      emitControlChange(ControlState.inactive);
    }
    _preElement = null;
    _activeControl = null;
    _activeControlValue = <IElement>[];
  }

  void reAwakeControl() {
    final IControlInstance? active = _activeControl;
    if (active == null) {
      return;
    }
    final List<IElement> elementList = getElementList();
    final IRange range = getRange();
    final int index = range.startIndex;
    if (index < 0 || index >= elementList.length) {
      return;
    }
    final IElement element = elementList[index];
    active.setElement(element);
    if (active is SelectControl && active.getIsPopup()) {
      active.destroy();
      active.awake();
    } else if (active is DateControl && active.getIsPopup()) {
      active.destroy();
      active.awake();
    }
  }

  IMoveCursorResult moveCursor(IControlInitOption position) {
    List<IElement> elementList = _draw.getOriginalElementList();
    if (elementList.isEmpty) {
      return IMoveCursorResult(newIndex: 0, newElement: IElement(value: ''));
    }

    final bool isTable = position.isTable ?? false;
    final int baseIndex = position.index;
    final int safeBaseIndex = baseIndex < 0
        ? 0
        : (baseIndex >= elementList.length ? elementList.length - 1 : baseIndex);

    int resolvedIndex = isTable
        ? (position.tdValueIndex ?? safeBaseIndex)
        : safeBaseIndex;
    IElement element;

    if (isTable) {
      final IElement tableElement = elementList[safeBaseIndex];
      final int? trIndex = position.trIndex;
      final int? tdIndex = position.tdIndex;
      final int? tdValueIndex = position.tdValueIndex;
      if (trIndex == null || tdIndex == null || tdValueIndex == null) {
        element = tableElement;
      } else {
        final List<ITr>? trList = tableElement.trList;
        if (trList == null || trIndex < 0 || trIndex >= trList.length) {
          element = tableElement;
        } else {
          final List<ITd> tdList = trList[trIndex].tdList;
          if (tdIndex < 0 || tdIndex >= tdList.length) {
            element = tableElement;
          } else {
            final List<IElement> valueList = tdList[tdIndex].value;
            if (valueList.isEmpty) {
              element = tableElement;
            } else {
              resolvedIndex = tdValueIndex < 0
                  ? 0
                  : (tdValueIndex >= valueList.length
                      ? valueList.length - 1
                      : tdValueIndex);
              elementList = valueList;
              element = valueList[resolvedIndex];
            }
          }
        }
      }
    } else {
      element = elementList[safeBaseIndex];
    }

    if (element.hide == true ||
        element.control?.hide == true ||
        element.area?.hide == true) {
      final int visibleIndex = element_utils.getNonHideElementIndex(elementList, resolvedIndex);
      return IMoveCursorResult(
        newIndex: visibleIndex,
        newElement: elementList[visibleIndex],
      );
    }

    if (element.controlComponent == ControlComponent.value) {
      return IMoveCursorResult(newIndex: resolvedIndex, newElement: element);
    }

    if (element.controlComponent == ControlComponent.postfix) {
      int cursor = resolvedIndex + 1;
      while (cursor < elementList.length) {
        final IElement nextElement = elementList[cursor];
        if (nextElement.controlId != element.controlId) {
          final int resolvedTarget = cursor - 1;
          return IMoveCursorResult(
            newIndex: resolvedTarget,
            newElement: elementList[resolvedTarget],
          );
        }
        cursor += 1;
      }
    } else if (element.controlComponent == ControlComponent.prefix ||
        element.controlComponent == ControlComponent.preText) {
      int cursor = resolvedIndex + 1;
      while (cursor < elementList.length) {
        final IElement nextElement = elementList[cursor];
        if (nextElement.controlId != element.controlId ||
            (nextElement.controlComponent != ControlComponent.prefix &&
                nextElement.controlComponent != ControlComponent.preText)) {
          final int resolvedTarget = cursor - 1;
          return IMoveCursorResult(
            newIndex: resolvedTarget,
            newElement: elementList[resolvedTarget],
          );
        }
        cursor += 1;
      }
    } else if (element.controlComponent == ControlComponent.placeholder ||
        element.controlComponent == ControlComponent.postText) {
      int cursor = resolvedIndex - 1;
      while (cursor >= 0) {
        final IElement previous = elementList[cursor];
        if (previous.controlId != element.controlId ||
            previous.controlComponent == ControlComponent.value ||
            previous.controlComponent == ControlComponent.prefix ||
            previous.controlComponent == ControlComponent.preText) {
          return IMoveCursorResult(
            newIndex: cursor,
            newElement: elementList[cursor],
          );
        }
        cursor -= 1;
      }
    }

    return IMoveCursorResult(newIndex: resolvedIndex, newElement: element);
  }

  void repaintControl([IRepaintControlOption? options]) {
    final int? curIndex = options?.curIndex;
    final bool isCompute = options?.isCompute ?? true;
    final bool isSubmitHistory = options?.isSubmitHistory ?? true;
    final bool isSetCursor = options?.isSetCursor ?? true;
    if (curIndex == null) {
      _range.clearRange();
      _draw.render(
        IDrawOption(
          isCompute: isCompute,
          isSubmitHistory: isSubmitHistory,
          isSetCursor: false,
        ),
      );
      return;
    }
    _range.setRange(curIndex, curIndex);
    _draw.render(
      IDrawOption(
        curIndex: curIndex,
        isCompute: isCompute,
        isSubmitHistory: isSubmitHistory,
        isSetCursor: isSetCursor,
      ),
    );
  }

  void emitControlContentChange([IControlChangeOption? options]) {
    final bool hasListener = _listener?.controlContentChange != null;
    final bool hasSubscribers =
        _eventBus?.isSubscribe('controlContentChange') == true;
    if (!hasListener && !hasSubscribers) {
      return;
    }
    final IElement? controlElement =
        options?.controlElement ?? _activeControl?.getElement();
    if (controlElement == null || controlElement.controlId == null) {
      return;
    }
    final List<IElement> elementList =
        options?.context?.elementList ?? getElementList();
    final IRange range = options?.context?.range ?? getRange();
    final int startIndex = range.startIndex;
    if (startIndex < 0 || startIndex >= elementList.length) {
      return;
    }
    if (elementList[startIndex].controlId == null) {
      return;
    }
    final List<IElement> controlValue =
        options?.controlValue ?? getControlElementList(options?.context);
    IControl? control;
    if (controlValue.isNotEmpty) {
      final List<IElement> zipped = element_utils.zipElementList(controlValue);
      if (zipped.isNotEmpty) {
        control = zipped.first.control;
      }
    }
    control ??= controlElement.control;
    if (control == null) {
      return;
    }
    if (controlValue.isEmpty) {
      control.value = <IElement>[];
    }
    final IControlContentChangeResult payload = IControlContentChangeResult(
      control: control,
      controlId: controlElement.controlId!,
    );
    _listener?.controlContentChange?.call(payload);
    if (hasSubscribers) {
      _eventBus?.emit('controlContentChange', payload);
    }
  }

  bool getIsRangeInPostfix() {
    final IControlInstance? active = _activeControl;
    if (active == null) {
      return false;
    }
    final IRange range = _range.getRange();
    if (range.startIndex != range.endIndex) {
      return false;
    }
    final List<IElement> elementList = getElementList();
    if (range.startIndex < 0 || range.startIndex >= elementList.length) {
      return false;
    }
    final IElement element = elementList[range.startIndex];
    return element.controlComponent == ControlComponent.postfix;
  }

  bool getIsExistValueByElementListIndex(List<IElement> elementList, int index) {
    if (index < 0 || index >= elementList.length) {
      return false;
    }
    final IElement element = elementList[index];
    if (element.controlId == null) {
      return false;
    }
    final ControlType? controlType = element.control?.type;
    if (controlType == ControlType.checkbox || controlType == ControlType.radio) {
      final String? code = element.control?.code;
      return code != null && code.isNotEmpty;
    }
    final ControlComponent? component = element.controlComponent;
    if (component == ControlComponent.value) {
      return true;
    }
    if (component == ControlComponent.placeholder) {
      return false;
    }
    if (component == ControlComponent.prefix || component == ControlComponent.preText) {
      int cursor = index + 1;
      while (cursor < elementList.length) {
        final IElement nextElement = elementList[cursor];
        if (nextElement.controlId != element.controlId) {
          return false;
        }
        if (nextElement.controlComponent == ControlComponent.value) {
          return true;
        }
        if (nextElement.controlComponent == ControlComponent.placeholder) {
          return false;
        }
        cursor += 1;
      }
    }
    if (component == ControlComponent.postfix || component == ControlComponent.postText) {
      int cursor = index - 1;
      while (cursor >= 0) {
        final IElement previousElement = elementList[cursor];
        if (previousElement.controlId != element.controlId) {
          return false;
        }
        if (previousElement.controlComponent == ControlComponent.value) {
          return true;
        }
        if (previousElement.controlComponent == ControlComponent.placeholder) {
          return false;
        }
        cursor -= 1;
      }
    }
    return false;
  }

  String? getControlHighlight(List<IElement> elementList, int index) {
    return _controlSearch.getControlHighlight(elementList, index);
  }

  DivElement getContainer() => _draw.getContainer();

  IElementPosition? getPosition() {
    final dynamic positionManager = _draw.getPosition();
    if (positionManager == null) {
      return null;
    }
    final dynamic rawList = positionManager.getPositionList();
    if (rawList is! List) {
      return null;
    }
    final List<IElementPosition> positionList =
      rawList.whereType<IElementPosition>().toList();
    if (positionList.isEmpty) {
      return null;
    }
    final int endIndex = _range.getRange().endIndex;
    if (endIndex < 0 || endIndex >= positionList.length) {
      return null;
    }
    return positionList[endIndex];
  }

  double getPreY() {
    final double height = _draw.getHeight();
    final double pageGap = _draw.getPageGap();
    final int pageNo = getPosition()?.pageNo ?? _draw.getPageNo();
    return pageNo * (height + pageGap);
  }

  List<IElement> getControlElementList([IControlContext? context]) {
    final List<IElement> elementList = context?.elementList ?? getElementList();
    final IRange range = context?.range ?? getRange();
    final int startIndex = range.startIndex;
    if (startIndex < 0 || startIndex >= elementList.length) {
      return <IElement>[];
    }
    final IElement startElement = elementList[startIndex];
    if (startElement.controlId == null) {
      return <IElement>[];
    }
    final List<IElement> data = <IElement>[];
    int preIndex = startIndex;
    while (preIndex >= 0) {
      final IElement preElement = elementList[preIndex];
      if (preElement.controlId != startElement.controlId) {
        break;
      }
      data.insert(0, preElement);
      preIndex -= 1;
    }
    int nextIndex = startIndex + 1;
    while (nextIndex < elementList.length) {
      final IElement nextElement = elementList[nextIndex];
      if (nextElement.controlId != startElement.controlId) {
        break;
      }
      data.add(nextElement);
      nextIndex += 1;
    }
    return data;
  }

  void updateActiveControlValue() {
    if (_activeControl != null) {
      _activeControlValue = getControlElementList();
    }
  }

  void emitControlChange(ControlState state) {
    final IControlInstance? activeControl = _activeControl;
    if (activeControl == null) {
      return;
    }
    final bool hasListener = _listener?.controlChange != null;
    final bool hasSubscribers = _eventBus?.isSubscribe('controlChange') == true;
    if (!hasListener && !hasSubscribers) {
      return;
    }
    final List<IElement> value = _activeControlValue;
    final IElement activeElement = activeControl.getElement();
    final String? controlId = activeElement.controlId;
    if (controlId == null) {
      return;
    }
    IControl? control;
    if (value.isNotEmpty) {
      final List<IElement> zipped = element_utils.zipElementList(value);
      if (zipped.isNotEmpty) {
        control = zipped.first.control;
      }
    }
    control ??= element_utils.pickElementAttr(activeElement).control;
    if (control == null) {
      return;
    }
    if (value.isEmpty) {
      control.value = <IElement>[];
    }
    final IControlChangeResult payload = IControlChangeResult(
      state: state,
      control: control,
      controlId: controlId,
    );
    _listener?.controlChange?.call(payload);
    if (hasSubscribers) {
      _eventBus?.emit('controlChange', payload);
    }
  }

  bool getIsRangeWithinControl() {
    final IRange range = getRange();
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex < 0 && endIndex < 0) {
      return false;
    }
    final List<IElement> elementList = getElementList();
    if (startIndex < 0 || startIndex >= elementList.length) {
      return false;
    }
    if (endIndex < 0 || endIndex >= elementList.length) {
      return false;
    }
    final IElement startElement = elementList[startIndex];
    final IElement endElement = elementList[endIndex];
    if (startElement.controlId != null &&
        startElement.controlId == endElement.controlId &&
        endElement.controlComponent != ControlComponent.postfix) {
      return true;
    }
    return false;
  }

  bool getIsElementListContainFullControl(List<IElement> elementList) {
    if (!elementList.any((IElement element) => element.controlId != null)) {
      return false;
    }
    int prefixCount = 0;
    int postfixCount = 0;
    for (final IElement element in elementList) {
      if (element.controlComponent == ControlComponent.prefix) {
        prefixCount += 1;
      } else if (element.controlComponent == ControlComponent.postfix) {
        postfixCount += 1;
      }
    }
    if (prefixCount == 0 || postfixCount == 0) {
      return false;
    }
    return prefixCount == postfixCount;
  }

  IControlInstance? getActiveControl() => _activeControl;

  int setValue(List<IElement> data) {
    final IControlInstance? active = _activeControl;
    if (active == null) {
      throw StateError('active control is null');
    }
    return active.setValue(data);
  }

  void setControlProperties(
    Map<String, dynamic> properties, {
    IControlContext? context,
  }) {
    if (properties.isEmpty) {
      return;
    }
    final IControlContext ctx = context ?? IControlContext();
    final List<IElement> elementList =
        ctx.elementList ?? getElementList();
    final IRange range = ctx.range ?? getRange();
    final int startIndex = range.startIndex;
    if (startIndex < 0 || startIndex >= elementList.length) {
      return;
    }
    final IElement startElement = elementList[startIndex];
    if (startElement.controlId == null) {
      return;
    }

    _mergeControlProperties(startElement, properties);

    int cursor = startIndex - 1;
    while (cursor >= 0) {
      final IElement current = elementList[cursor];
      if (current.controlId != startElement.controlId) {
        break;
      }
      _mergeControlProperties(current, properties);
      cursor -= 1;
    }

    cursor = startIndex + 1;
    while (cursor < elementList.length) {
      final IElement current = elementList[cursor];
      if (current.controlId != startElement.controlId) {
        break;
      }
      _mergeControlProperties(current, properties);
      cursor += 1;
    }
  }

  int? keydown(dynamic evt) {
    final IControlInstance? active = _activeControl;
    if (active == null) {
      throw StateError('active control is null');
    }
    return active.keydown(evt);
  }

  int cut() {
    final IControlInstance? active = _activeControl;
    if (active == null) {
      throw StateError('active control is null');
    }
    return active.cut();
  }

  IGetControlValueResult? getValueById(IGetControlValueOption payload) {
    final String? id = _normalizeString(payload.id);
    final String? conceptId = _normalizeString(payload.conceptId);
    final String? groupId = _normalizeString(payload.groupId);
    final String? areaId = _normalizeString(payload.areaId);

    if (id == null && conceptId == null && groupId == null && areaId == null) {
      return null;
    }

    IGetControlValueResult? resolved;

    void collect(List<IElement> elementList, EditorZone zone) {
      var index = 0;
      while (index < elementList.length && resolved == null) {
        final IElement element = elementList[index];
        index += 1;

        if (element.type == ElementType.table && element.trList != null) {
          for (final ITr tr in element.trList!) {
            for (final ITd td in tr.tdList) {
              collect(td.value, zone);
              if (resolved != null) {
                return;
              }
            }
          }
        }

        final IControl? control = element.control;
        if (control == null) {
          continue;
        }

        if (!_matchesIdentifier(groupId, control.groupId) ||
            !_matchesIdentifier(id, element.controlId) ||
            !_matchesIdentifier(conceptId, control.conceptId) ||
            !_matchesIdentifier(areaId, element.areaId)) {
          continue;
        }

        final ControlType type = control.type;
        final String? controlId = element.controlId;
        var cursor = index;
        final StringBuffer textBuffer = StringBuffer();
        final List<IElement> textElementList = <IElement>[];

        while (cursor < elementList.length) {
          final IElement nextElement = elementList[cursor];
          if (nextElement.controlId != controlId) {
            break;
          }
          if (_isTextControl(type) &&
              nextElement.controlComponent == ControlComponent.value) {
            textBuffer.write(nextElement.value);
            final IElement sanitized = element_utils.pickElementAttr(nextElement)
              ..control = null
              ..controlId = null
              ..controlComponent = null;
            textElementList.add(sanitized);
          }
          cursor += 1;
        }

        if (_isTextControl(type)) {
          final String rawText = textBuffer.toString().replaceAll(ZERO, '');
          final List<IElement> zipped = textElementList.isEmpty
              ? <IElement>[]
              : element_utils.zipElementList(
                  textElementList,
                  options: const element_utils.ZipElementListOption(
                    isClone: true,
                  ),
                );
          resolved = _buildControlValueResult(
            control,
            zone: zone,
            value: _normalizeString(rawText),
            innerText: _normalizeString(rawText),
            elementList: zipped.isEmpty ? null : zipped,
          );
        } else if (_isSelectableControl(type)) {
          final String? rawCode = control.code;
          final String? normalizedCode = _normalizeString(rawCode);
          final String? innerText =
              _normalizeString(_buildSelectInnerText(normalizedCode, control.valueSets));
          resolved = _buildControlValueResult(
            control,
            zone: zone,
            value: normalizedCode,
            innerText: innerText,
            elementList: null,
          );
        }

        if (resolved != null) {
          return;
        }

        index = cursor;
      }
    }

    collect(_draw.getHeaderElementList(), EditorZone.header);
    if (resolved != null) {
      return resolved;
    }

    collect(_draw.getOriginalMainElementList(), EditorZone.main);
    if (resolved != null) {
      return resolved;
    }

    collect(_draw.getFooterElementList(), EditorZone.footer);
    return resolved;
  }

  void setValueListById(List<ISetControlValueOption> payload) {
    if (payload.isEmpty) {
      return;
    }

    var isExistSet = false;
    var isExistSubmitHistory = false;

    void setValue(List<IElement> elementList) {
      var i = 0;
      while (i < elementList.length) {
        final IElement element = elementList[i];
        i += 1;

        if (element.type == ElementType.table && element.trList != null) {
          for (final ITr tr in element.trList!) {
            for (final ITd td in tr.tdList) {
              setValue(td.value);
            }
          }
          continue;
        }

        final IControl? control = element.control;
        if (control == null) {
          continue;
        }

        final ISetControlValueOption? payloadItem =
            _findValueOption(payload, element);
        if (payloadItem == null) {
          continue;
        }

        final dynamic rawValue = payloadItem.value;
        final bool isSubmitHistory = payloadItem.isSubmitHistory ?? true;

        isExistSet = true;
        if (isSubmitHistory) {
          isExistSubmitHistory = true;
        }

        final ControlType type = control.type;
        var currentEndIndex = i;
        while (currentEndIndex < elementList.length) {
          final IElement nextElement = elementList[currentEndIndex];
          if (nextElement.controlId != element.controlId) {
            break;
          }
          currentEndIndex += 1;
        }

        final int startIndex = i - 1;
        final int computedEndIndex = currentEndIndex - 2;
        final int endIndex =
            computedEndIndex >= startIndex ? computedEndIndex : startIndex;

        final IControlContext controlContext = IControlContext(
          range: IRange(startIndex: startIndex, endIndex: endIndex),
          elementList: elementList,
        );
        final IControlRuleOption controlRule = IControlRuleOption(
          isIgnoreDisabledRule: true,
          isIgnoreDeletedRule: true,
        );

        if (type == ControlType.text) {
          final List<IElement> formatValue = _resolveElementValue(rawValue);
          if (formatValue.isNotEmpty) {
            element_utils.formatElementList(
              formatValue,
              element_utils.FormatElementListOption(
                editorOptions: _options,
                isHandleFirstElement: false,
              ),
            );
          }
          final TextControl textControl = TextControl(element, this);
          _activeControl = textControl;
          if (formatValue.isNotEmpty) {
            textControl.setValue(
              formatValue,
              context: controlContext,
              options: controlRule,
            );
          } else {
            textControl.clearValue(
              context: controlContext,
              options: controlRule,
            );
          }
        } else if (type == ControlType.select) {
          if (rawValue is List) {
            i = currentEndIndex;
            continue;
          }
          final SelectControl selectControl = SelectControl(element, this);
          _activeControl = selectControl;
          final String? stringValue = _stringFromValue(rawValue);
          if (stringValue != null && stringValue.isNotEmpty) {
            selectControl.setSelect(
              stringValue,
              context: controlContext,
              options: controlRule,
            );
          } else {
            selectControl.clearSelect(
              context: controlContext,
              options: controlRule,
            );
          }
        } else if (type == ControlType.checkbox) {
          if (rawValue is List) {
            i = currentEndIndex;
            continue;
          }
          final CheckboxControl checkboxControl =
              CheckboxControl(element, this);
          _activeControl = checkboxControl;
          final String? stringValue = _stringFromValue(rawValue);
          final List<String> codes = stringValue == null || stringValue.isEmpty
              ? <String>[]
              : stringValue.split(',');
          checkboxControl.setSelect(
            codes,
            context: controlContext,
            options: controlRule,
          );
        } else if (type == ControlType.radio) {
          if (rawValue is List) {
            i = currentEndIndex;
            continue;
          }
          final RadioControl radioControl = RadioControl(element, this);
          _activeControl = radioControl;
          final String? stringValue = _stringFromValue(rawValue);
          final List<String> codes = stringValue == null || stringValue.isEmpty
              ? <String>[]
              : <String>[stringValue];
          radioControl.setSelect(
            codes,
            context: controlContext,
            options: controlRule,
          );
        } else if (type == ControlType.date) {
          final DateControl dateControl = DateControl(element, this);
          _activeControl = dateControl;
          if (rawValue is List) {
            final List<IElement> formatValue = _resolveElementValue(rawValue);
            if (formatValue.isNotEmpty) {
              element_utils.formatElementList(
                formatValue,
                element_utils.FormatElementListOption(
                  editorOptions: _options,
                  isHandleFirstElement: false,
                ),
              );
              dateControl.setValue(
                formatValue,
                context: controlContext,
                options: controlRule,
              );
            } else {
              dateControl.clearSelect(
                context: controlContext,
                options: controlRule,
              );
            }
          } else {
            final String? stringValue = _stringFromValue(rawValue);
            if (stringValue != null && stringValue.isNotEmpty) {
              dateControl.setSelect(
                stringValue,
                context: controlContext,
                options: controlRule,
              );
            } else {
              dateControl.clearSelect(
                context: controlContext,
                options: controlRule,
              );
            }
          }
        } else if (type == ControlType.number) {
          final List<IElement> formatValue = _resolveElementValue(rawValue);
          if (formatValue.isNotEmpty) {
            element_utils.formatElementList(
              formatValue,
              element_utils.FormatElementListOption(
                editorOptions: _options,
                isHandleFirstElement: false,
              ),
            );
          }
          final NumberControl numberControl = NumberControl(element, this);
          _activeControl = numberControl;
          if (formatValue.isNotEmpty) {
            numberControl.setValue(
              formatValue,
              context: controlContext,
              options: controlRule,
            );
          } else {
            numberControl.clearValue(
              context: controlContext,
              options: controlRule,
            );
          }
        }

        emitControlContentChange(
          IControlChangeOption(context: controlContext),
        );
        _activeControl = null;

        var newEndIndex = i;
        while (newEndIndex < elementList.length) {
          final IElement nextElement = elementList[newEndIndex];
          if (nextElement.controlId != element.controlId) {
            break;
          }
          newEndIndex += 1;
        }
        i = newEndIndex;
      }
    }

    destroyControl(IDestroyControlOption(isEmitEvent: false));

    final List<List<IElement>> data = <List<IElement>>[
      _draw.getHeaderElementList(),
      _draw.getOriginalMainElementList(),
      _draw.getFooterElementList(),
    ];
    for (final List<IElement> elementList in data) {
      setValue(elementList);
    }

    if (!isExistSet) {
      return;
    }
    if (!isExistSubmitHistory) {
      final dynamic historyManager = _draw.getHistoryManager();
      final dynamic recovery = historyManager?.recovery;
      if (recovery is Function) {
        recovery();
      }
    }

    _draw.render(
      IDrawOption(
        isSubmitHistory: isExistSubmitHistory,
        isSetCursor: false,
      ),
    );
  }

  void setExtensionListById(List<ISetControlExtensionOption> payload) {
    if (payload.isEmpty) {
      return;
    }

    void setExtension(List<IElement> elementList) {
      var i = 0;
      while (i < elementList.length) {
        final IElement element = elementList[i];
        i += 1;

        if (element.type == ElementType.table && element.trList != null) {
          for (final ITr tr in element.trList!) {
            for (final ITd td in tr.tdList) {
              setExtension(td.value);
            }
          }
          continue;
        }

        final IControl? control = element.control;
        if (control == null) {
          continue;
        }

        final ISetControlExtensionOption? payloadItem =
            _findExtensionOption(payload, element);
        if (payloadItem == null) {
          continue;
        }

        setControlProperties(
          <String, dynamic>{
            'extension': utils.deepClone(payloadItem.extension),
          },
          context: IControlContext(
            elementList: elementList,
            range: IRange(startIndex: i, endIndex: i),
          ),
        );

        var newEndIndex = i;
        while (newEndIndex < elementList.length) {
          final IElement nextElement = elementList[newEndIndex];
          if (nextElement.controlId != element.controlId) {
            break;
          }
          newEndIndex += 1;
        }
        i = newEndIndex;
      }
    }

    final List<List<IElement>> data = <List<IElement>>[
      _draw.getHeaderElementList(),
      _draw.getOriginalMainElementList(),
      _draw.getFooterElementList(),
    ];
    for (final List<IElement> elementList in data) {
      setExtension(elementList);
    }
  }

  void setPropertiesListById(List<ISetControlProperties> payload) {
    if (payload.isEmpty) {
      return;
    }

    var isExistUpdate = false;
    var isExistSubmitHistory = false;

    void setProperties(List<IElement> elementList) {
      var i = 0;
      while (i < elementList.length) {
        final IElement element = elementList[i];
        i += 1;

        if (element.type == ElementType.table && element.trList != null) {
          for (final ITr tr in element.trList!) {
            for (final ITd td in tr.tdList) {
              setProperties(td.value);
            }
          }
          continue;
        }

        final IControl? control = element.control;
        if (control == null) {
          continue;
        }

        final ISetControlProperties? payloadItem =
            _findPropertiesOption(payload, element);
        if (payloadItem == null) {
          continue;
        }

        isExistUpdate = true;
        final bool isSubmitHistory = payloadItem.isSubmitHistory ?? true;
        if (isSubmitHistory) {
          isExistSubmitHistory = true;
        }

        final Map<String, dynamic> updateMap =
            _normalizeProperties(payloadItem.properties);
        final Map<String, dynamic> controlBase = _controlToMap(control)
          ..addAll(updateMap)
          ..['value'] = control.value == null
              ? null
              : element_utils.cloneElementList(control.value!);

        setControlProperties(
          controlBase,
          context: IControlContext(
            elementList: elementList,
            range: IRange(startIndex: i, endIndex: i),
          ),
        );

        _applyElementStyleFromProperties(element, updateMap);

        var newEndIndex = i;
        while (newEndIndex < elementList.length) {
          final IElement nextElement = elementList[newEndIndex];
          if (nextElement.controlId != element.controlId) {
            break;
          }
          newEndIndex += 1;
        }
        i = newEndIndex;
      }
    }

    final List<List<IElement>> data = <List<IElement>>[
      _draw.getHeaderElementList(),
      _draw.getOriginalMainElementList(),
      _draw.getFooterElementList(),
    ];
    for (final List<IElement> elementList in data) {
      setProperties(elementList);
    }

    if (!isExistUpdate) {
      return;
    }

    final List<IElement> headerList = _draw.getHeaderElementList();
    final List<IElement> mainList = _draw.getOriginalMainElementList();
    final List<IElement> footerList = _draw.getFooterElementList();

    final List<IElement> headerZipped = element_utils.zipElementList(
      headerList,
      options: const element_utils.ZipElementListOption(
        isClassifyArea: true,
        extraPickAttrs: <String>['id'],
      ),
    );
    final List<IElement> mainZipped = element_utils.zipElementList(
      mainList,
      options: const element_utils.ZipElementListOption(
        isClassifyArea: true,
        extraPickAttrs: <String>['id'],
      ),
    );
    final List<IElement> footerZipped = element_utils.zipElementList(
      footerList,
      options: const element_utils.ZipElementListOption(
        isClassifyArea: true,
        extraPickAttrs: <String>['id'],
      ),
    );

    element_utils.formatElementList(
      headerZipped,
      element_utils.FormatElementListOption(
        editorOptions: _options,
        isForceCompensation: true,
      ),
    );
    element_utils.formatElementList(
      mainZipped,
      element_utils.FormatElementListOption(
        editorOptions: _options,
        isForceCompensation: true,
      ),
    );
    element_utils.formatElementList(
      footerZipped,
      element_utils.FormatElementListOption(
        editorOptions: _options,
        isForceCompensation: true,
      ),
    );

    _draw.setEditorData(
      IEditorData(
        header: headerZipped,
        main: mainZipped,
        footer: footerZipped,
      ),
    );

    if (!isExistSubmitHistory) {
      final dynamic historyManager = _draw.getHistoryManager();
      final dynamic recovery = historyManager?.recovery;
      if (recovery is Function) {
        recovery();
      }
    }

    _draw.render(
      IDrawOption(
        isSubmitHistory: isExistSubmitHistory,
        isSetCursor: false,
      ),
    );
  }

  INextControlContext? getPreControlContext() {
    final IControlInstance? activeControl = _activeControl;
    if (activeControl == null) {
      return null;
    }
    final dynamic positionManager = _draw.getPosition();
    final IPositionContext? positionContext =
        positionManager?.getPositionContext() as IPositionContext?;
    if (positionContext == null) {
      return null;
    }
    final IElement controlElement = activeControl.getElement();

    INextControlContext? getPreContext(
      List<IElement> elementList,
      int start,
    ) {
      for (int e = start; e >= 0; e--) {
        if (e < 0 || e >= elementList.length) {
          continue;
        }
        final IElement element = elementList[e];
        if (element.type == ElementType.table && element.trList != null) {
          final List<ITr> trList = element.trList!;
          for (int r = trList.length - 1; r >= 0; r--) {
            final ITr tr = trList[r];
            final List<ITd> tdList = tr.tdList;
            for (int d = tdList.length - 1; d >= 0; d--) {
              final ITd td = tdList[d];
              final INextControlContext? context =
                  getPreContext(td.value, td.value.length - 1);
              if (context != null) {
                return INextControlContext(
                  positionContext: IPositionContext(
                    isTable: true,
                    index: e,
                    trIndex: r,
                    tdIndex: d,
                    tdId: td.id,
                    trId: tr.id,
                    tableId: element.id,
                  ),
                  nextIndex: context.nextIndex,
                );
              }
            }
          }
        }
        if (element.controlId == null ||
            element.controlId == controlElement.controlId) {
          continue;
        }
        var nextIndex = e;
        while (nextIndex > 0) {
          final IElement nextElement = elementList[nextIndex];
          if (nextElement.controlComponent == ControlComponent.value ||
              nextElement.controlComponent == ControlComponent.prefix ||
              nextElement.controlComponent == ControlComponent.preText) {
            break;
          }
          nextIndex -= 1;
        }
        if (nextIndex < 0) {
          nextIndex = 0;
        }
        return INextControlContext(
          positionContext: IPositionContext(isTable: false),
          nextIndex: nextIndex,
        );
      }
      return null;
    }

    final IRange currentRange = _range.getRange();
    final List<IElement> elementList = getElementList();
    final INextControlContext? context =
        getPreContext(elementList, currentRange.startIndex);
    if (context != null) {
      final IPositionContext resolvedPositionContext =
          positionContext.isTable ? positionContext : context.positionContext;
      return INextControlContext(
        positionContext: resolvedPositionContext,
        nextIndex: context.nextIndex,
      );
    }

    if (controlElement.tableId != null) {
      final List<IElement> originalElementList = _draw.getOriginalElementList();
      final int? tableIndex = positionContext.index;
      final int? trIndex = positionContext.trIndex;
      final int? tdIndex = positionContext.tdIndex;
      if (tableIndex != null &&
          trIndex != null &&
          tdIndex != null &&
          tableIndex >= 0 &&
          tableIndex < originalElementList.length) {
        final List<ITr>? trList = originalElementList[tableIndex].trList;
        if (trList != null && trIndex < trList.length) {
          for (int r = trIndex; r >= 0; r--) {
            final ITr tr = trList[r];
            final List<ITd> tdList = tr.tdList;
            for (int d = tdList.length - 1; d >= 0; d--) {
              if (r == trIndex && d >= tdIndex) {
                continue;
              }
              final ITd td = tdList[d];
              final INextControlContext? nestedContext =
                  getPreContext(td.value, td.value.length - 1);
              if (nestedContext != null) {
                return INextControlContext(
                  positionContext: IPositionContext(
                    isTable: true,
                    index: tableIndex,
                    trIndex: r,
                    tdIndex: d,
                    tdId: td.id,
                    trId: tr.id,
                    tableId: controlElement.tableId,
                  ),
                  nextIndex: nestedContext.nextIndex,
                );
              }
            }
          }
        }
        final INextControlContext? outerContext =
            getPreContext(originalElementList, tableIndex - 1);
        if (outerContext != null) {
          return INextControlContext(
            positionContext: IPositionContext(isTable: false),
            nextIndex: outerContext.nextIndex,
          );
        }
      }
    }

    return null;
  }

  INextControlContext? getNextControlContext() {
    final IControlInstance? activeControl = _activeControl;
    if (activeControl == null) {
      return null;
    }
    final dynamic positionManager = _draw.getPosition();
    final IPositionContext? positionContext =
        positionManager?.getPositionContext() as IPositionContext?;
    if (positionContext == null) {
      return null;
    }
    final IElement controlElement = activeControl.getElement();

    INextControlContext? getNextContext(
      List<IElement> elementList,
      int start,
    ) {
      for (int e = start; e < elementList.length; e++) {
        final IElement element = elementList[e];
        if (element.type == ElementType.table && element.trList != null) {
          final List<ITr> trList = element.trList!;
          for (int r = 0; r < trList.length; r++) {
            final ITr tr = trList[r];
            final List<ITd> tdList = tr.tdList;
            for (int d = 0; d < tdList.length; d++) {
              final ITd td = tdList[d];
              final INextControlContext? context =
                  getNextContext(td.value, 0);
              if (context != null) {
                return INextControlContext(
                  positionContext: IPositionContext(
                    isTable: true,
                    index: e,
                    trIndex: r,
                    tdIndex: d,
                    tdId: td.id,
                    trId: tr.id,
                    tableId: element.id,
                  ),
                  nextIndex: context.nextIndex,
                );
              }
            }
          }
        }
        if (element.controlId == null ||
            element.controlId == controlElement.controlId) {
          continue;
        }
        final IElement? nextElement =
            e + 1 < elementList.length ? elementList[e + 1] : null;
        if (nextElement?.controlComponent == ControlComponent.prefix ||
            nextElement?.controlComponent == ControlComponent.preText) {
          continue;
        }
        return INextControlContext(
          positionContext: IPositionContext(isTable: false),
          nextIndex: e,
        );
      }
      return null;
    }

    final IRange currentRange = _range.getRange();
    final List<IElement> elementList = getElementList();
    final INextControlContext? context =
        getNextContext(elementList, currentRange.endIndex);
    if (context != null) {
      final IPositionContext resolvedPositionContext =
          positionContext.isTable ? positionContext : context.positionContext;
      return INextControlContext(
        positionContext: resolvedPositionContext,
        nextIndex: context.nextIndex,
      );
    }

    if (controlElement.tableId != null) {
      final List<IElement> originalElementList = _draw.getOriginalElementList();
      final int? tableIndex = positionContext.index;
      final int? trIndex = positionContext.trIndex;
      final int? tdIndex = positionContext.tdIndex;
      if (tableIndex != null &&
          trIndex != null &&
          tdIndex != null &&
          tableIndex >= 0 &&
          tableIndex < originalElementList.length) {
        final List<ITr>? trList = originalElementList[tableIndex].trList;
        if (trList != null && trIndex < trList.length) {
          for (int r = trIndex; r < trList.length; r++) {
            final ITr tr = trList[r];
            final List<ITd> tdList = tr.tdList;
            for (int d = 0; d < tdList.length; d++) {
              if (r == trIndex && d <= tdIndex) {
                continue;
              }
              final ITd td = tdList[d];
              final INextControlContext? nestedContext =
                  getNextContext(td.value, 0);
              if (nestedContext != null) {
                return INextControlContext(
                  positionContext: IPositionContext(
                    isTable: true,
                    index: tableIndex,
                    trIndex: r,
                    tdIndex: d,
                    tdId: td.id,
                    trId: tr.id,
                    tableId: controlElement.tableId,
                  ),
                  nextIndex: nestedContext.nextIndex,
                );
              }
            }
          }
        }
        final INextControlContext? outerContext =
            getNextContext(originalElementList, tableIndex + 1);
        if (outerContext != null) {
          return INextControlContext(
            positionContext: IPositionContext(isTable: false),
            nextIndex: outerContext.nextIndex,
          );
        }
      }
    }

    return null;
  }

  void initNextControl([IInitNextControlOption? option]) {
    final MoveDirection direction = option?.direction ?? MoveDirection.down;
    final INextControlContext? context = direction == MoveDirection.up
        ? getPreControlContext()
        : getNextControlContext();
    if (context == null) {
      return;
    }

    final dynamic positionManager = _draw.getPosition();
    final IPositionContext positionContext = context.positionContext;
    positionManager?.setPositionContext(positionContext);

    final int nextIndex = context.nextIndex;
    _range.replaceRange(
      IRange(
        startIndex: nextIndex,
        endIndex: nextIndex,
        tableId: positionContext.tableId,
        startTdIndex: positionContext.tdIndex,
        endTdIndex: positionContext.tdIndex,
        startTrIndex: positionContext.trIndex,
        endTrIndex: positionContext.trIndex,
      ),
    );

    _draw.render(
      IDrawOption(
        curIndex: nextIndex,
        isCompute: false,
        isSetCursor: true,
        isSubmitHistory: false,
      ),
    );

    final dynamic positionListDynamic = positionManager?.getPositionList();
    if (positionListDynamic is! List) {
      return;
    }
    final List<IElementPosition> positionList =
        positionListDynamic.whereType<IElementPosition>().toList();
    if (nextIndex < 0 || nextIndex >= positionList.length) {
      return;
    }

    final dynamic cursor = _draw.getCursor();
    if (cursor == null) {
      return;
    }
    final IMoveCursorToVisibleOption payload = IMoveCursorToVisibleOption(
      direction: direction,
      cursorPosition: positionList[nextIndex],
    );
    try {
      cursor.moveCursorToVisible(payload);
    } catch (_) {
      final dynamic method = cursor.moveCursorToVisible;
      if (method is Function) {
        method(payload);
      }
    }
  }

  void setMinWidthControlInfo(ISetControlRowFlexOption option) {
    final IRow row = option.row;
    final IRowElement rowElement = option.rowElement;
    final IControl? control = rowElement.control;
    final double? minWidth = control?.minWidth;
    if (control == null || minWidth == null) {
      return;
    }

    final double scale = _options.scale ?? 1;
    final double controlMinWidth = minWidth * scale;

    IRowElement? controlFirstElement;
    if (control.rowFlex == RowFlex.center || control.rowFlex == RowFlex.right) {
      double controlContentWidth = rowElement.metrics.width;
      int controlElementIndex = row.elementList.length - 1;
      while (controlElementIndex >= 0) {
        final IRowElement controlRowElement =
            row.elementList[controlElementIndex];
        controlContentWidth += controlRowElement.metrics.width;
        final int previousIndex = controlElementIndex - 1;
        if (previousIndex >= 0) {
          final IRowElement previous = row.elementList[previousIndex];
          if (previous.controlComponent == ControlComponent.prefix) {
            controlFirstElement = controlRowElement;
            break;
          }
        } else {
          controlFirstElement = controlRowElement;
          break;
        }
        controlElementIndex -= 1;
      }

      if (controlFirstElement != null &&
          controlContentWidth < controlMinWidth) {
        if (control.rowFlex == RowFlex.center) {
          controlFirstElement.left =
              (controlMinWidth - controlContentWidth) / 2;
        } else if (control.rowFlex == RowFlex.right) {
          controlFirstElement.left = controlMinWidth -
              controlContentWidth -
              rowElement.metrics.width;
        }
      }
    }

    final double extraWidth = controlMinWidth - option.controlRealWidth;
    if (extraWidth <= 0) {
      return;
    }

    final double controlFirstElementLeft = controlFirstElement?.left ?? 0;
    final double rowRemainingWidth =
        option.availableWidth - row.width - rowElement.metrics.width;
    final double left = rowRemainingWidth < extraWidth
        ? rowRemainingWidth
        : extraWidth;

    rowElement.left = left - controlFirstElementLeft;
    row.width += left - controlFirstElementLeft;
  }

  List<IElement> getList() {
    final List<IElement> controlElementList = <IElement>[];

    void collectControlElements(List<IElement> elements) {
      for (final IElement element in elements) {
        if (element.type == ElementType.table && element.trList != null) {
          for (final ITr tr in element.trList!) {
            for (final ITd td in tr.tdList) {
              collectControlElements(td.value);
            }
          }
        }
        if (element.controlId == null) {
          continue;
        }
        final IElement clone = element_utils.pickElementAttr(
          element,
          extraPickAttrs: <String>['controlId', 'controlComponent'],
        );
        clone
          ..level = null
          ..title = null
          ..titleId = null
          ..listId = null
          ..listType = null
          ..listStyle = null;
        controlElementList.add(clone);
      }
    }

    collectControlElements(_draw.getHeaderElementList());
    collectControlElements(_draw.getOriginalMainElementList());
    collectControlElements(_draw.getFooterElementList());

    return element_utils.zipElementList(
      controlElementList,
      options: const element_utils.ZipElementListOption(
        extraPickAttrs: <String>['controlId'],
      ),
    );
  }

  void recordBorderInfo(double x, double y, double width, double height) {
    _controlBorder.recordBorderInfo(x, y, width, height);
  }

  void drawBorder(CanvasRenderingContext2D ctx) {
    _controlBorder.render(ctx);
  }

  String? _normalizeString(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _matchesIdentifier(String? filter, String? target) {
    final String? normalizedFilter = _normalizeString(filter);
    if (normalizedFilter == null) {
      return true;
    }
    return normalizedFilter == target;
  }

  bool _isTextControl(ControlType type) {
    return type == ControlType.text ||
        type == ControlType.date ||
        type == ControlType.number;
  }

  bool _isSelectableControl(ControlType type) {
    return type == ControlType.select ||
        type == ControlType.checkbox ||
        type == ControlType.radio;
  }

  List<IElement> _resolveElementValue(dynamic rawValue) {
    if (rawValue is List) {
      return _cloneElementListFromDynamic(rawValue);
    }
    final String? stringValue = _stringFromValue(rawValue);
    if (stringValue == null || stringValue.isEmpty) {
      return <IElement>[];
    }
    return <IElement>[IElement(value: stringValue)];
  }

  List<IElement> _cloneElementListFromDynamic(dynamic rawValue) {
    if (rawValue is List<IElement>) {
      return element_utils.cloneElementList(rawValue);
    }
    if (rawValue is List) {
      final List<IElement> result = <IElement>[];
      for (final dynamic item in rawValue) {
        if (item is IElement) {
          result.add(item);
        }
      }
      if (result.isEmpty) {
        return <IElement>[];
      }
      return element_utils.cloneElementList(result);
    }
    return <IElement>[];
  }

  String? _stringFromValue(dynamic rawValue) {
    if (rawValue == null) {
      return null;
    }
    if (rawValue is String) {
      return rawValue;
    }
    if (rawValue is num) {
      return rawValue.toString();
    }
    return null;
  }

  ISetControlValueOption? _findValueOption(
    List<ISetControlValueOption> payload,
    IElement element,
  ) {
    final IControl? control = element.control;
    if (control == null) {
      return null;
    }
    for (final ISetControlValueOption option in payload) {
      if (_isMatchingControlPayload(
        element,
        control,
        id: option.id,
        conceptId: option.conceptId,
        areaId: option.areaId,
        groupId: option.groupId,
      )) {
        return option;
      }
    }
    return null;
  }

  ISetControlExtensionOption? _findExtensionOption(
    List<ISetControlExtensionOption> payload,
    IElement element,
  ) {
    final IControl? control = element.control;
    if (control == null) {
      return null;
    }
    for (final ISetControlExtensionOption option in payload) {
      if (_isMatchingControlPayload(
        element,
        control,
        id: option.id,
        conceptId: option.conceptId,
        areaId: option.areaId,
        groupId: option.groupId,
      )) {
        return option;
      }
    }
    return null;
  }

  ISetControlProperties? _findPropertiesOption(
    List<ISetControlProperties> payload,
    IElement element,
  ) {
    final IControl? control = element.control;
    if (control == null) {
      return null;
    }
    for (final ISetControlProperties option in payload) {
      if (_isMatchingControlPayload(
        element,
        control,
        id: option.id,
        conceptId: option.conceptId,
        areaId: option.areaId,
        groupId: option.groupId,
      )) {
        return option;
      }
    }
    return null;
  }

  bool _isMatchingControlPayload(
    IElement element,
    IControl control, {
    String? id,
    String? conceptId,
    String? areaId,
    String? groupId,
  }) {
    final String? normalizedGroupId = _normalizeString(groupId);
    if (normalizedGroupId != null && normalizedGroupId != control.groupId) {
      return false;
    }

    final String? normalizedId = _normalizeString(id);
    final String? normalizedConceptId = _normalizeString(conceptId);
    final String? normalizedAreaId = _normalizeString(areaId);

    var hasIdentifier = false;
    var isMatched = false;

    if (normalizedId != null) {
      hasIdentifier = true;
      if (normalizedId == element.controlId) {
        isMatched = true;
      }
    }

    if (normalizedConceptId != null) {
      hasIdentifier = true;
      if (normalizedConceptId == control.conceptId) {
        isMatched = true;
      }
    }

    if (normalizedAreaId != null) {
      hasIdentifier = true;
      if (normalizedAreaId == element.areaId) {
        isMatched = true;
      }
    }

    if (!hasIdentifier) {
      return false;
    }

    return isMatched;
  }

  Map<String, dynamic> _normalizeProperties(dynamic properties) {
    if (properties == null) {
      return <String, dynamic>{};
    }
    if (properties is Map<String, dynamic>) {
      return Map<String, dynamic>.from(properties);
    }
    if (properties is Map) {
      final Map<String, dynamic> result = <String, dynamic>{};
      properties.forEach((dynamic key, dynamic value) {
        if (key is String) {
          result[key] = value;
        }
      });
      return result;
    }
    if (properties is IControl) {
      return _controlToMap(properties);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _controlToMap(IControl control) {
    return <String, dynamic>{
      'type': control.type,
      'value': control.value == null
          ? null
          : element_utils.cloneElementList(control.value!),
      'placeholder': control.placeholder,
      'conceptId': control.conceptId,
      'groupId': control.groupId,
      'prefix': control.prefix,
      'postfix': control.postfix,
      'minWidth': control.minWidth,
      'underline': control.underline,
      'border': control.border,
      'extension': utils.deepClone(control.extension),
      'indentation': control.indentation,
      'rowFlex': control.rowFlex,
      'preText': control.preText,
      'postText': control.postText,
      'deletable': control.deletable,
      'disabled': control.disabled,
      'pasteDisabled': control.pasteDisabled,
      'hide': control.hide,
      'font': control.font,
      'size': control.size,
      'bold': control.bold,
      'highlight': control.highlight,
      'italic': control.italic,
      'strikeout': control.strikeout,
      'code': control.code,
      'valueSets': _cloneValueSets(control.valueSets),
      'isMultiSelect': control.isMultiSelect,
      'multiSelectDelimiter': control.multiSelectDelimiter,
      'selectExclusiveOptions': control.selectExclusiveOptions == null
          ? null
          : Map<String, bool>.from(control.selectExclusiveOptions!),
      'min': control.min,
      'max': control.max,
      'flexDirection': control.flexDirection,
      'dateFormat': control.dateFormat,
    };
  }

  void _applyElementStyleFromProperties(
    IElement element,
    Map<String, dynamic> properties,
  ) {
    for (final String key in element_constants.controlStyleAttr) {
      final dynamic value = properties[key];
      if (value == null) {
        continue;
      }
      switch (key) {
        case 'font':
          element.font = value as String?;
          break;
        case 'size':
          if (value is num) {
            element.size = value.toInt();
          } else if (value is int?) {
            element.size = value;
          }
          break;
        case 'bold':
          element.bold = value as bool?;
          break;
        case 'highlight':
          element.highlight = value as String?;
          break;
        case 'italic':
          element.italic = value as bool?;
          break;
        case 'strikeout':
          element.strikeout = value as bool?;
          break;
      }
    }
  }

  IGetControlValueResult _buildControlValueResult(
    IControl control, {
    required EditorZone zone,
    String? value,
    String? innerText,
    List<IElement>? elementList,
  }) {
    return IGetControlValueResult(
      type: control.type,
      placeholder: control.placeholder,
      conceptId: control.conceptId,
      groupId: control.groupId,
      prefix: control.prefix,
      postfix: control.postfix,
      minWidth: control.minWidth,
      underline: control.underline,
      border: control.border,
      extension: utils.deepClone(control.extension),
      indentation: control.indentation,
      rowFlex: control.rowFlex,
      preText: control.preText,
      postText: control.postText,
      deletable: control.deletable,
      disabled: control.disabled,
      pasteDisabled: control.pasteDisabled,
      hide: control.hide,
      font: control.font,
      size: control.size,
      bold: control.bold,
      highlight: control.highlight,
      italic: control.italic,
      strikeout: control.strikeout,
      code: control.code,
      valueSets: _cloneValueSets(control.valueSets),
      isMultiSelect: control.isMultiSelect,
      multiSelectDelimiter: control.multiSelectDelimiter,
      selectExclusiveOptions: control.selectExclusiveOptions == null
          ? null
          : Map<String, bool>.from(control.selectExclusiveOptions!),
      min: control.min,
      max: control.max,
      flexDirection: control.flexDirection,
      dateFormat: control.dateFormat,
      value: value,
      innerText: innerText,
      zone: zone,
      elementList: elementList,
    );
  }

  List<IValueSet> _cloneValueSets(List<IValueSet> valueSets) {
    return valueSets
        .map((IValueSet set) => IValueSet(value: set.value, code: set.code))
        .toList();
  }

  String? _buildSelectInnerText(String? code, List<IValueSet> valueSets) {
    if (code == null || code.isEmpty) {
      return null;
    }
    final List<String> parts = <String>[];
    for (final String selectCode in code.split(',')) {
      for (final IValueSet valueSet in valueSets) {
        if (valueSet.code == selectCode) {
          parts.add(valueSet.value);
          break;
        }
      }
    }
    if (parts.isEmpty) {
      return null;
    }
    final String joined = parts.join('');
    return joined.isEmpty ? null : joined;
  }

  void _mergeControlProperties(
    IElement element,
    Map<String, dynamic> properties,
  ) {
    final IControl? control = element.control;
    if (control == null) {
      return;
    }
    properties.forEach((String key, dynamic value) {
      _assignControlField(control, key, value);
    });
  }

  void _assignControlField(IControl control, String key, dynamic value) {
    switch (key) {
      case 'type':
        final ControlType? parsedType =
            _parseEnum<ControlType>(ControlType.values, value);
        if (parsedType != null) {
          control.type = parsedType;
        }
        break;
      case 'value':
        if (value == null || value is List<IElement>) {
          control.value = value as List<IElement>?;
        }
        break;
      case 'placeholder':
        control.placeholder = value as String?;
        break;
      case 'conceptId':
        control.conceptId = value as String?;
        break;
      case 'groupId':
        control.groupId = value as String?;
        break;
      case 'prefix':
        control.prefix = value as String?;
        break;
      case 'postfix':
        control.postfix = value as String?;
        break;
      case 'minWidth':
        control.minWidth = value == null ? null : (value as num).toDouble();
        break;
      case 'underline':
        control.underline = value as bool?;
        break;
      case 'border':
        control.border = value as bool?;
        break;
      case 'extension':
        control.extension = value;
        break;
      case 'indentation':
        control.indentation =
            _parseEnum<ControlIndentation>(ControlIndentation.values, value);
        break;
      case 'rowFlex':
        control.rowFlex = _parseEnum<RowFlex>(RowFlex.values, value);
        break;
      case 'preText':
        control.preText = value as String?;
        break;
      case 'postText':
        control.postText = value as String?;
        break;
      case 'deletable':
        control.deletable = value as bool?;
        break;
      case 'disabled':
        control.disabled = value as bool?;
        break;
      case 'pasteDisabled':
        control.pasteDisabled = value as bool?;
        break;
      case 'hide':
        control.hide = value as bool?;
        break;
      case 'font':
        control.font = value as String?;
        break;
      case 'size':
        control.size = value == null ? null : (value as num).toInt();
        break;
      case 'bold':
        control.bold = value as bool?;
        break;
      case 'highlight':
        control.highlight = value as String?;
        break;
      case 'italic':
        control.italic = value as bool?;
        break;
      case 'strikeout':
        control.strikeout = value as bool?;
        break;
      case 'code':
        control.code = value as String?;
        break;
      case 'valueSets':
        final List<IValueSet> valueSets = _castValueSetList(value);
        if (valueSets.isNotEmpty) {
          control.valueSets = valueSets;
        }
        break;
      case 'isMultiSelect':
        control.isMultiSelect = value as bool?;
        break;
      case 'multiSelectDelimiter':
        control.multiSelectDelimiter = value as String?;
        break;
      case 'selectExclusiveOptions':
        if (value == null) {
          control.selectExclusiveOptions = null;
        } else if (value is Map<String, bool>) {
          control.selectExclusiveOptions = Map<String, bool>.from(value);
        } else if (value is Map) {
          final Map<String, bool> casted = <String, bool>{};
          value.forEach((dynamic k, dynamic v) {
            if (k is String && v is bool) {
              casted[k] = v;
            }
          });
          control.selectExclusiveOptions = casted;
        }
        break;
      case 'min':
        control.min = value == null ? null : (value as num).toInt();
        break;
      case 'max':
        control.max = value == null ? null : (value as num).toInt();
        break;
      case 'flexDirection':
        final FlexDirection? flexDirection =
            _parseEnum<FlexDirection>(FlexDirection.values, value);
        if (flexDirection != null) {
          control.flexDirection = flexDirection;
        }
        break;
      case 'dateFormat':
        control.dateFormat = value as String?;
        break;
      default:
        break;
    }
  }

  List<IValueSet> _castValueSetList(dynamic value) {
    if (value is List<IValueSet>) {
      return value;
    }
    if (value is List) {
      final List<IValueSet> list = <IValueSet>[];
      for (final dynamic item in value) {
        if (item is IValueSet) {
          list.add(item);
        } else if (item is Map) {
          final dynamic code = item['code'];
          final dynamic text = item['value'];
          if (code is String && text is String) {
            list.add(IValueSet(code: code, value: text));
          }
        }
      }
      return list;
    }
    return <IValueSet>[];
  }

  T? _parseEnum<T extends Enum>(List<T> values, dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is T) {
      return raw;
    }
    if (raw is String) {
      for (final T entry in values) {
        if (entry.name == raw) {
          return entry;
        }
      }
    }
    return null;
  }
}
