import '../../dataset/constant/common.dart';
import '../../dataset/constant/element.dart';
import '../../dataset/enum/control.dart';
import '../../dataset/enum/editor.dart';
import '../../dataset/enum/element.dart';
import '../../dataset/enum/row.dart';
import '../../interface/editor.dart';
import '../../interface/element.dart';
import '../../interface/listener.dart';
import '../../interface/range.dart';
import '../../utils/element.dart' as element_utils;

class RangeManager {
  RangeManager(dynamic drawInstance)
      : draw = drawInstance,
        options = drawInstance.getOptions() as IEditorOption,
        listener = drawInstance.getListener(),
        eventBus = drawInstance.getEventBus(),
        position = drawInstance.getPosition(),
        historyManager = drawInstance.getHistoryManager(),
        range = IRange(startIndex: -1, endIndex: -1);

  final dynamic draw;
  final IEditorOption options;
  final dynamic listener;
  final dynamic eventBus;
  final dynamic position;
  final dynamic historyManager;

  IRange range;
  IRangeElementStyle? defaultStyle;

  IRange getRange() {
    return range;
  }

  void clearRange() {
    setRange(-1, -1);
  }

  void setDefaultStyle(IRangeElementStyle? style) {
    if (style == null) {
      defaultStyle = null;
      return;
    }
    final IRangeElementStyle? previous = defaultStyle;
    defaultStyle = IRangeElementStyle(
      bold: style.bold ?? previous?.bold,
      color: style.color ?? previous?.color,
      highlight: style.highlight ?? previous?.highlight,
      font: style.font ?? previous?.font,
      size: style.size ?? previous?.size,
      italic: style.italic ?? previous?.italic,
      underline: style.underline ?? previous?.underline,
      strikeout: style.strikeout ?? previous?.strikeout,
    );
  }

  IRangeElementStyle? getDefaultStyle() {
    return defaultStyle;
  }

  IElement? getRangeAnchorStyle(List<IElement> elementList, int anchorIndex) {
    final IElement? anchor =
        element_utils.getAnchorElement(elementList, anchorIndex);
    if (anchor == null) {
      return null;
    }
    final List<IElement> cloneList =
        element_utils.cloneElementList(<IElement>[anchor]);
    final IElement cloned = cloneList.first;
    if (defaultStyle != null) {
      cloned
        ..bold = defaultStyle?.bold ?? cloned.bold
        ..color = defaultStyle?.color ?? cloned.color
        ..highlight = defaultStyle?.highlight ?? cloned.highlight
        ..font = defaultStyle?.font ?? cloned.font
        ..size = defaultStyle?.size ?? cloned.size
        ..italic = defaultStyle?.italic ?? cloned.italic
        ..underline = defaultStyle?.underline ?? cloned.underline
        ..strikeout = defaultStyle?.strikeout ?? cloned.strikeout;
    }
    return cloned;
  }

  bool getIsRangeChange(
    int startIndex,
    int endIndex, [
    String? tableId,
    int? startTdIndex,
    int? endTdIndex,
    int? startTrIndex,
    int? endTrIndex,
  ]) {
    return range.startIndex != startIndex ||
        range.endIndex != endIndex ||
        range.tableId != tableId ||
        range.startTdIndex != startTdIndex ||
        range.endTdIndex != endTdIndex ||
        range.startTrIndex != startTrIndex ||
        range.endTrIndex != endTrIndex;
  }

  bool getIsCollapsed() {
    return range.startIndex == range.endIndex;
  }

  bool getIsSelection() {
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex == -1 && endIndex == -1) {
      return false;
    }
    return startIndex != endIndex;
  }

  List<IElement>? getSelection() {
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex == endIndex) {
      return null;
    }
    final List<IElement> elementList = _castElementList(draw.getElementList());
    final int from = startIndex + 1;
    final int to = endIndex + 1;
    if (from < 0 || to > elementList.length) {
      return null;
    }
    return elementList.sublist(from, to);
  }

  List<IElement>? getSelectionElementList() {
    if (range.isCrossRowCol == true) {
      final dynamic rowCol = draw.getTableParticle().getRangeRowCol();
      if (rowCol == null) {
        return null;
      }
      final List<IElement> elementList = <IElement>[];
      for (final dynamic row in rowCol as List<dynamic>) {
        if (row is! List) {
          continue;
        }
        for (final dynamic col in row) {
          final dynamic colValue = col is Map ? col['value'] : col?.value;
          elementList.addAll(_castElementList(colValue));
        }
      }
      return elementList;
    }
    return getSelection();
  }

  List<IElement>? getTextLikeSelection() {
    final List<IElement>? selection = getSelection();
    if (selection == null) {
      return null;
    }
    return selection.where(_isTextLikeElement).toList();
  }

  List<IElement>? getTextLikeSelectionElementList() {
    final List<IElement>? selection = getSelectionElementList();
    if (selection == null) {
      return null;
    }
    return selection.where(_isTextLikeElement).toList();
  }

  RangeRowMap? getRangeRow() {
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex == -1 && endIndex == -1) {
      return null;
    }
    final List<dynamic> positionList =
        position.getPositionList() as List<dynamic>;
    final RangeRowMap rangeRow = <int, Set<int>>{};
    for (var p = startIndex; p < endIndex + 1; p++) {
      if (p < 0 || p >= positionList.length) {
        continue;
      }
      final dynamic pos = positionList[p];
      final int pageNo = pos?.pageNo as int? ?? 0;
      final int rowNo = pos?.rowNo as int? ?? 0;
      final Set<int> rowSet = rangeRow.putIfAbsent(pageNo, () => <int>{});
      rowSet.add(rowNo);
    }
    return rangeRow;
  }

  List<IElement>? getRangeRowElementList() {
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex == -1 && endIndex == -1) {
      return null;
    }
    if (range.isCrossRowCol == true) {
      return getSelectionElementList();
    }
    final RangeRowMap? rangeRow = getRangeRow();
    if (rangeRow == null) {
      return null;
    }
    final List<dynamic> positionList =
        position.getPositionList() as List<dynamic>;
    final List<IElement> elementList = _castElementList(draw.getElementList());
    final List<IElement> rowElementList = <IElement>[];
    for (var p = 0; p < positionList.length; p++) {
      final dynamic pos = positionList[p];
      final int pageNo = pos?.pageNo as int? ?? -1;
      final int rowNo = pos?.rowNo as int? ?? -1;
      final Set<int>? rowSet = rangeRow[pageNo];
      if (rowSet == null || !rowSet.contains(rowNo)) {
        continue;
      }
      if (p < elementList.length) {
        rowElementList.add(elementList[p]);
      }
    }
    return rowElementList;
  }

  RangeRowArray? getRangeParagraph() {
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex == -1 && endIndex == -1) {
      return null;
    }
    final List<dynamic> positionList =
        position.getPositionList() as List<dynamic>;
    final List<IElement> elementList = _castElementList(draw.getElementList());
    final RangeRowArray rangeRow = <int, List<int>>{};

    void addRow(int pageNo, int rowNo, {bool prepend = false}) {
      final List<int> rowArray = rangeRow.putIfAbsent(pageNo, () => <int>[]);
      if (!rowArray.contains(rowNo)) {
        if (prepend) {
          rowArray.insert(0, rowNo);
        } else {
          rowArray.add(rowNo);
        }
      }
    }

    var start = startIndex;
    while (start >= 0 && start < positionList.length) {
      final dynamic pos = positionList[start];
      addRow(pos?.pageNo as int? ?? 0, pos?.rowNo as int? ?? 0, prepend: true);
      if (_isParagraphBreak(elementList, start)) {
        break;
      }
      start -= 1;
    }

    final bool isCollapsed = startIndex == endIndex;
    if (!isCollapsed) {
      var middle = startIndex + 1;
      while (middle < endIndex && middle < positionList.length) {
        final dynamic pos = positionList[middle];
        addRow(pos?.pageNo as int? ?? 0, pos?.rowNo as int? ?? 0);
        middle += 1;
      }
    }

    var end = endIndex;
    if (isCollapsed && elementList[startIndex].value == ZERO) {
      end += 1;
    }
    while (end < positionList.length) {
      if (_isParagraphBreak(elementList, end, forward: true)) {
        break;
      }
      final dynamic pos = positionList[end];
      addRow(pos?.pageNo as int? ?? 0, pos?.rowNo as int? ?? 0);
      end += 1;
    }
    return rangeRow;
  }

  IRangeParagraphInfo? getRangeParagraphInfo() {
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex == -1 && endIndex == -1) {
      return null;
    }
    int startPositionIndex = -1;
    final List<IElement> rangeElementList = <IElement>[];
    final RangeRowArray? rangeRow = getRangeParagraph();
    if (rangeRow == null) {
      return null;
    }
    final List<IElement> elementList = _castElementList(draw.getElementList());
    final List<dynamic> positionList =
        position.getPositionList() as List<dynamic>;
    for (var p = 0; p < positionList.length && p < elementList.length; p++) {
      final dynamic pos = positionList[p];
      final List<int>? rowArray = rangeRow[pos?.pageNo as int? ?? -1];
      if (rowArray == null || !rowArray.contains(pos?.rowNo as int? ?? -1)) {
        continue;
      }
      if (startPositionIndex == -1) {
        startPositionIndex = pos?.index as int? ?? p;
      }
      rangeElementList.add(elementList[p]);
    }
    if (rangeElementList.isEmpty) {
      return null;
    }
    return IRangeParagraphInfo(
      elementList: rangeElementList,
      startIndex: startPositionIndex,
    );
  }

  List<IElement>? getRangeParagraphElementList() {
    return getRangeParagraphInfo()?.elementList;
  }

  IElement? getRangeTableElement() {
    final dynamic positionContext = position.getPositionContext();
    if (positionContext == null || positionContext.isTable != true) {
      return null;
    }
    final List<IElement> elementList =
        _castElementList(draw.getOriginalElementList());
    final int index = positionContext.index as int? ?? -1;
    if (index < 0 || index >= elementList.length) {
      return null;
    }
    return elementList[index];
  }

  bool getIsSelectAll() {
    final List<IElement> elementList = _castElementList(draw.getElementList());
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    final dynamic positionContext = position.getPositionContext();
    return startIndex == 0 &&
        endIndex == elementList.length - 1 &&
        positionContext?.isTable != true;
  }

  bool getIsPointInRange(double x, double y) {
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    final List<dynamic> positionList =
        position.getPositionList() as List<dynamic>;
    for (var p = startIndex + 1; p <= endIndex; p++) {
      if (p < 0 || p >= positionList.length) {
        break;
      }
      final dynamic pos = positionList[p];
      if (pos == null) {
        continue;
      }
      final List<dynamic> leftTop =
          pos.coordinate?.leftTop as List<dynamic>? ?? <dynamic>[0, 0];
      final List<dynamic> rightBottom =
          pos.coordinate?.rightBottom as List<dynamic>? ?? <dynamic>[0, 0];
      final double left = (leftTop.first as num).toDouble();
      final double top =
          leftTop.length > 1 ? (leftTop[1] as num).toDouble() : left;
      final double right = (rightBottom.first as num).toDouble();
      final double bottom =
          rightBottom.length > 1 ? (rightBottom[1] as num).toDouble() : right;
      if (x >= left && x <= right && y >= top && y <= bottom) {
        return true;
      }
    }
    return false;
  }

  List<IRange> getKeywordRangeList(String payload) {
    final dynamic searchManager = draw.getSearch();
    final List<dynamic> matchList = searchManager.getMatchList(
      payload,
      draw.getOriginalElementList(),
    ) as List<dynamic>;
    final Map<String, IRange> rangeMap = <String, IRange>{};
    for (final dynamic match in matchList) {
      final String groupId = match.groupId as String? ?? '';
      if (groupId.isEmpty) {
        continue;
      }
      final IRange? existing = rangeMap[groupId];
      if (existing != null) {
        existing.endIndex += 1;
        continue;
      }
      final IRange rangeItem = IRange(
        startIndex: match.index as int? ?? 0,
        endIndex: match.index as int? ?? 0,
      );
      if (match.type == EditorContext.table) {
        rangeItem.tableId = match.tableId as String?;
        final int tdIndex = match.tdIndex as int? ?? 0;
        final int trIndex = match.trIndex as int? ?? 0;
        rangeItem.startTdIndex = tdIndex;
        rangeItem.endTdIndex = tdIndex;
        rangeItem.startTrIndex = trIndex;
        rangeItem.endTrIndex = trIndex;
      }
      rangeMap[groupId] = rangeItem;
    }
    return rangeMap.values.toList();
  }

  bool getIsCanInput() {
    final IRange currentRange = getRange();
    final int startIndex = currentRange.startIndex;
    final int endIndex = currentRange.endIndex;
    if (startIndex == -1 && endIndex == -1) {
      return false;
    }
    final List<IElement> elementList = _castElementList(draw.getElementList());
    if (startIndex < 0 || startIndex >= elementList.length) {
      return false;
    }
    final IElement startElement = elementList[startIndex];
    if (startIndex == endIndex) {
      final ControlComponent? startComponent = startElement.controlComponent;
      final ControlComponent? nextComponent =
          elementList.length > startIndex + 1
              ? elementList[startIndex + 1].controlComponent
              : null;
      return (startComponent != ControlComponent.preText ||
              nextComponent != ControlComponent.preText) &&
          startComponent != ControlComponent.postText;
    }
    if (endIndex < 0 || endIndex >= elementList.length) {
      return false;
    }
    final IElement endElement = elementList[endIndex];
    final bool isStartControl = startElement.controlId != null;
    final bool isEndControl = endElement.controlId != null;
    return (!isStartControl && !isEndControl) ||
        ((!isStartControl ||
                startElement.controlComponent == ControlComponent.postfix) &&
            (!isEndControl ||
                endElement.controlComponent == ControlComponent.postfix)) ||
        (isStartControl &&
            startElement.controlId == endElement.controlId &&
            endElement.controlComponent != ControlComponent.preText &&
            endElement.controlComponent != ControlComponent.postText &&
            endElement.controlComponent != ControlComponent.postfix);
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
    final bool isChange = getIsRangeChange(
      startIndex,
      endIndex,
      tableId,
      startTdIndex,
      endTdIndex,
      startTrIndex,
      endTrIndex,
    );
    if (isChange) {
      range
        ..startIndex = startIndex
        ..endIndex = endIndex
        ..tableId = tableId
        ..startTdIndex = startTdIndex
        ..endTdIndex = endTdIndex
        ..startTrIndex = startTrIndex
        ..endTrIndex = endTrIndex
        ..isCrossRowCol = _hasCrossRowCol(
          startTdIndex,
          endTdIndex,
          startTrIndex,
          endTrIndex,
        );
      setDefaultStyle(null);
    }
    try {
      range.zone = draw.getZone().getZone() as EditorZone?;
    } catch (_) {
      range.zone = null;
    }
    final dynamic control = draw.getControl();
    if (startIndex >= 0 && endIndex >= 0) {
      final List<IElement> elementList =
          _castElementList(draw.getElementList());
      if (startIndex < elementList.length) {
        final IElement element = elementList[startIndex];
        if (element.controlId != null) {
          try {
            control?.initControl();
          } catch (_) {}
          return;
        }
      }
    }
    try {
      control?.destroyControl();
    } catch (_) {}
  }

  void replaceRange(IRange nextRange) {
    setRange(
      nextRange.startIndex,
      nextRange.endIndex,
      nextRange.tableId,
      nextRange.startTdIndex,
      nextRange.endTdIndex,
      nextRange.startTrIndex,
      nextRange.endTrIndex,
    );
  }

  void shrinkRange() {
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex == endIndex || (startIndex < 0 && endIndex < 0)) {
      return;
    }
    replaceRange(IRange(
      startIndex: endIndex,
      endIndex: endIndex,
      tableId: range.tableId,
      startTdIndex: range.startTdIndex,
      endTdIndex: range.endTdIndex,
      startTrIndex: range.startTrIndex,
      endTrIndex: range.endTrIndex,
      isCrossRowCol: range.isCrossRowCol,
      zone: range.zone,
    ));
  }

  void setRangeStyle() {
    IRangeStyleChange? rangeStyleChangeListener;
    try {
      rangeStyleChangeListener =
          listener.rangeStyleChange as IRangeStyleChange?;
    } catch (_) {
      rangeStyleChangeListener = null;
    }
    bool isSubscribeRangeStyleChange = false;
    try {
      isSubscribeRangeStyleChange =
          (eventBus.isSubscribe('rangeStyleChange') as bool?) ?? false;
    } catch (_) {
      isSubscribeRangeStyleChange = false;
    }
    if (rangeStyleChangeListener == null && !isSubscribeRangeStyleChange) {
      return;
    }
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex < 0 && endIndex < 0) {
      return;
    }
    IElement? curElement;
    if (range.isCrossRowCol == true) {
      final List<IElement> originalElementList =
          _castElementList(draw.getOriginalElementList());
      dynamic positionContext;
      try {
        positionContext = position.getPositionContext();
      } catch (_) {
        positionContext = null;
      }
      final int index = positionContext?.index as int? ?? -1;
      if (index < 0 || index >= originalElementList.length) {
        return;
      }
      curElement = originalElementList[index];
    } else {
      final int index = endIndex >= 0 ? endIndex : 0;
      final List<IElement> elementList =
          _castElementList(draw.getElementList());
      curElement = getRangeAnchorStyle(elementList, index);
    }
    if (curElement == null) {
      return;
    }
    final List<IElement> curElementList =
        getSelection() ?? <IElement>[curElement];
    final ElementType type = curElement.type ?? ElementType.text;
    final String font = curElement.font ?? options.defaultFont ?? '';
    final double size = _toDouble(
      curElement.size ?? options.defaultSize,
      fallback: 0,
    );
    final bool bold = curElementList.every((IElement el) => el.bold == true);
    final bool italic =
        curElementList.every((IElement el) => el.italic == true);
    final bool underline = curElementList.every(
      (IElement el) => el.underline == true || el.control?.underline == true,
    );
    final bool strikeout =
        curElementList.every((IElement el) => el.strikeout == true);
    final String? color = curElement.color;
    final String? highlight = curElement.highlight;
    final RowFlex? rowFlex = curElement.rowFlex;
    final double rowMargin = _toDouble(
      curElement.rowMargin ?? options.defaultRowMargin,
      fallback: 0,
    );
    final List<double> dashArray = List<double>.from(
      curElement.dashArray ?? const <double>[],
    );
    final dynamic level = curElement.level;
    final dynamic listType = curElement.listType;
    final dynamic listStyle = curElement.listStyle;
    final List<String>? groupIds = curElement.groupIds;
    final ITextDecoration? textDecoration =
        underline ? curElement.textDecoration : null;
    final dynamic extension = curElement.extension;
    bool painter = false;
    try {
      painter = draw.getPainterStyle() != null;
    } catch (_) {
      painter = false;
    }
    bool undo = false;
    bool redo = false;
    try {
      undo = historyManager.isCanUndo() == true;
      redo = historyManager.isCanRedo() == true;
    } catch (_) {
      undo = false;
      redo = false;
    }
    final IRangeStyle rangeStyle = IRangeStyle(
      type: type,
      undo: undo,
      redo: redo,
      painter: painter,
      font: font,
      size: size,
      bold: bold,
      italic: italic,
      underline: underline,
      strikeout: strikeout,
      color: color,
      highlight: highlight,
      rowFlex: rowFlex,
      rowMargin: rowMargin,
      dashArray: dashArray,
      level: level,
      listType: listType,
      listStyle: listStyle,
      groupIds: groupIds,
      textDecoration: textDecoration,
      extension: extension,
    );
    if (rangeStyleChangeListener != null) {
      rangeStyleChangeListener(rangeStyle);
    }
    if (isSubscribeRangeStyleChange) {
      try {
        eventBus.emit('rangeStyleChange', rangeStyle);
      } catch (_) {}
    }
  }

  void recoveryRangeStyle() {
    IRangeStyleChange? rangeStyleChangeListener;
    try {
      rangeStyleChangeListener =
          listener.rangeStyleChange as IRangeStyleChange?;
    } catch (_) {
      rangeStyleChangeListener = null;
    }
    bool isSubscribeRangeStyleChange = false;
    try {
      isSubscribeRangeStyleChange =
          (eventBus.isSubscribe('rangeStyleChange') as bool?) ?? false;
    } catch (_) {
      isSubscribeRangeStyleChange = false;
    }
    if (rangeStyleChangeListener == null && !isSubscribeRangeStyleChange) {
      return;
    }
    bool painter = false;
    try {
      painter = draw.getPainterStyle() != null;
    } catch (_) {
      painter = false;
    }
    bool undo = false;
    bool redo = false;
    try {
      undo = historyManager.isCanUndo() == true;
      redo = historyManager.isCanRedo() == true;
    } catch (_) {
      undo = false;
      redo = false;
    }
    final IRangeStyle rangeStyle = IRangeStyle(
      type: null,
      undo: undo,
      redo: redo,
      painter: painter,
      font: options.defaultFont ?? '',
      size: _toDouble(options.defaultSize, fallback: 0),
      bold: false,
      italic: false,
      underline: false,
      strikeout: false,
      color: null,
      highlight: null,
      rowFlex: null,
      rowMargin: _toDouble(options.defaultRowMargin, fallback: 0),
      dashArray: const <double>[],
      level: null,
      listType: null,
      listStyle: null,
      groupIds: null,
      textDecoration: null,
      extension: null,
    );
    if (rangeStyleChangeListener != null) {
      rangeStyleChangeListener(rangeStyle);
    }
    if (isSubscribeRangeStyleChange) {
      try {
        eventBus.emit('rangeStyleChange', rangeStyle);
      } catch (_) {}
    }
  }

  void shrinkBoundary([IControlContext? context]) {
    final IControlContext resolvedContext = context ?? IControlContext();
    final List<IElement> elementList =
        resolvedContext.elementList ?? _castElementList(draw.getElementList());
    final IRange targetRange = resolvedContext.range ?? range;
    final int startIndex = targetRange.startIndex;
    final int endIndex = targetRange.endIndex;
    if ((startIndex < 0 && endIndex < 0) || elementList.isEmpty) {
      return;
    }
    if (startIndex >= elementList.length || endIndex >= elementList.length) {
      return;
    }
    final IElement startElement = elementList[startIndex];
    final IElement endElement = elementList[endIndex];
    if (startIndex == endIndex) {
      if (startElement.controlComponent == ControlComponent.placeholder) {
        var index = startIndex - 1;
        while (index > 0) {
          final IElement preElement = elementList[index];
          if (preElement.controlId != startElement.controlId ||
              preElement.controlComponent == ControlComponent.prefix ||
              preElement.controlComponent == ControlComponent.preText) {
            targetRange.startIndex = index;
            targetRange.endIndex = index;
            break;
          }
          index -= 1;
        }
      }
      return;
    }
    if (startElement.controlComponent == ControlComponent.placeholder ||
        endElement.controlComponent == ControlComponent.placeholder) {
      var index = endIndex - 1;
      while (index > 0) {
        final IElement preElement = elementList[index];
        if (preElement.controlId != endElement.controlId ||
            preElement.controlComponent == ControlComponent.prefix ||
            preElement.controlComponent == ControlComponent.preText) {
          targetRange.startIndex = index;
          targetRange.endIndex = index;
          return;
        }
        index -= 1;
      }
    }
    if (startElement.controlComponent == ControlComponent.prefix) {
      var index = startIndex + 1;
      while (index < elementList.length) {
        final IElement nextElement = elementList[index];
        if (nextElement.controlId != startElement.controlId ||
            nextElement.controlComponent == ControlComponent.value) {
          targetRange.startIndex = index - 1;
          break;
        } else if (nextElement.controlComponent ==
            ControlComponent.placeholder) {
          targetRange.startIndex = index - 1;
          targetRange.endIndex = index - 1;
          return;
        }
        index += 1;
      }
    }
    if (endElement.controlComponent != ControlComponent.value) {
      var index = startIndex - 1;
      while (index > 0) {
        final IElement preElement = elementList[index];
        if (preElement.controlId != startElement.controlId ||
            preElement.controlComponent == ControlComponent.value) {
          targetRange.startIndex = index;
          break;
        } else if (preElement.controlComponent ==
            ControlComponent.placeholder) {
          targetRange.startIndex = index;
          targetRange.endIndex = index;
          return;
        }
        index -= 1;
      }
    }
  }

  void render(dynamic ctx, double x, double y, double width, double height) {
    if (ctx == null) {
      return;
    }
    try {
      ctx.save();
    } catch (_) {}
    try {
      ctx.globalAlpha = _toDouble(options.rangeAlpha, fallback: 1);
    } catch (_) {}
    final dynamic color = options.rangeColor;
    if (color != null) {
      try {
        ctx.fillStyle = color;
      } catch (_) {}
    }
    try {
      ctx.fillRect(x, y, width, height);
    } catch (_) {}
    try {
      ctx.restore();
    } catch (_) {}
  }

  @override
  String toString() {
    final List<IElement>? selection = getTextLikeSelection();
    if (selection == null) {
      return '';
    }
    return selection
        .map((IElement element) => element.value)
        .join()
        .replaceAll(ZERO, '');
  }

  bool _isTextLikeElement(IElement element) {
    return element.type == null || textlikeElementType.contains(element.type);
  }

  bool _isParagraphBreak(List<IElement> elementList, int index,
      {bool forward = false}) {
    if (index < 0 || index >= elementList.length) {
      return true;
    }
    final IElement element = elementList[index];
    final IElement? neighbor = forward && index + 1 < elementList.length
        ? elementList[index + 1]
        : (!forward && index - 1 >= 0 ? elementList[index - 1] : null);
    final bool isBreak = (element.value == ZERO && element.listWrap != true) ||
        (neighbor != null &&
            (element.listId != neighbor.listId ||
                element.titleId != neighbor.titleId));
    return isBreak;
  }

  bool _hasCrossRowCol(
    int? startTdIndex,
    int? endTdIndex,
    int? startTrIndex,
    int? endTrIndex,
  ) {
    for (final int? value in <int?>[
      startTdIndex,
      endTdIndex,
      startTrIndex,
      endTrIndex,
    ]) {
      if (value != null && value != 0) {
        return true;
      }
    }
    return false;
  }

  double _toDouble(num? value, {double fallback = 0}) {
    return value?.toDouble() ?? fallback;
  }

  List<IElement> _castElementList(dynamic value) {
    if (value is List<IElement>) {
      return value;
    }
    if (value is Iterable) {
      return value.whereType<IElement>().toList();
    }
    return <IElement>[];
  }
}
