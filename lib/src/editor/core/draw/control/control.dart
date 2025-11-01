import 'dart:html';

import '../../../dataset/constant/common.dart';
import '../../../dataset/constant/element.dart' as element_constants;
import '../../../dataset/enum/control.dart';
import '../../../dataset/enum/editor.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/event_bus.dart';
import '../../../interface/range.dart';
import '../../../interface/table/td.dart';
import '../../../interface/table/tr.dart';
import '../../../utils/element.dart' as element_utils;
import '../../../utils/index.dart' as utils;
import '../../event/eventbus/event_bus.dart';
import '../../listener/listener.dart';
import '../../range/range_manager.dart';
import '../draw.dart';
import 'interactive/control_search.dart';
import 'richtext/border.dart';

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
}
