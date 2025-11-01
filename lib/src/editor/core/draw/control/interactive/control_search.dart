import 'dart:html';

import '../../../../dataset/constant/common.dart';
import '../../../../dataset/enum/control.dart';
import '../../../../dataset/enum/editor.dart';
import '../../../../dataset/enum/element.dart';
import '../../../../interface/editor.dart';
import '../../../../interface/element.dart';
import '../../../../interface/search.dart';
import '../../draw.dart';
import '../control.dart';

class ControlHighlightMatchResult extends ISearchResult {
  ControlHighlightMatchResult({
    required this.keyword,
    double? matchAlpha,
    String? matchBackgroundColor,
    required EditorContext type,
    required int index,
    required String groupId,
    String? tableId,
    int? tableIndex,
    int? trIndex,
    int? tdIndex,
    String? tdId,
    int? startIndex,
  })  : alpha = matchAlpha,
      backgroundColor = matchBackgroundColor,
      super(
        type: type,
        index: index,
        groupId: groupId,
        tableId: tableId,
        tableIndex: tableIndex,
        trIndex: trIndex,
        tdIndex: tdIndex,
        tdId: tdId,
        startIndex: startIndex,
      );

  final String keyword;
  final double? alpha;
  final String? backgroundColor;
}

class ControlSearch {
  ControlSearch(Control control)
      : _control = control,
        _draw = control.getDraw(),
        _options = control.getDraw().getOptions(),
        _highlightList = <IControlHighlight>[],
        _highlightMatchResult = <ControlHighlightMatchResult>[];

  final Control _control;
  final Draw _draw;
  final IEditorOption _options;
  List<IControlHighlight> _highlightList;
  List<ControlHighlightMatchResult> _highlightMatchResult;

  List<IControlHighlight> getHighlightList() => _highlightList;

  void setHighlightList(List<IControlHighlight> payload) {
    _highlightList = List<IControlHighlight>.from(payload);
  }

  List<ControlHighlightMatchResult> getHighlightMatchResult() =>
      _highlightMatchResult;

  String? getControlHighlight(List<IElement> elementList, int index) {
    if (index < 0 || index >= elementList.length) {
      return null;
    }
    final IElement element = elementList[index];
    final String? elementHighlight = element.highlight;
    if (elementHighlight != null && elementHighlight.isNotEmpty) {
      return elementHighlight;
    }
    final IControlOption? controlOption = _options.control;
    if (controlOption == null) {
      return null;
    }
    final bool isPrintMode = _draw.isPrintMode();
    final IElement? activeControlElement =
        _control.getActiveControl()?.getElement();
    bool isActiveControlHighlight = false;
    bool isDisabledControlHighlight = false;
    bool isExistValueControlHighlight = false;
    bool isNoValueControlHighlight = false;
    if (!isPrintMode &&
        (controlOption.activeBackgroundColor?.isNotEmpty ?? false) &&
        activeControlElement != null &&
        element.controlId != null &&
        element.controlId == activeControlElement.controlId &&
        !_control.getIsRangeInPostfix()) {
      isActiveControlHighlight = true;
    }
    if (!isActiveControlHighlight &&
        !isPrintMode &&
        (controlOption.disabledBackgroundColor?.isNotEmpty ?? false) &&
        element.control?.disabled == true) {
      isDisabledControlHighlight = true;
    }
    if (!isDisabledControlHighlight &&
        !isPrintMode &&
        (controlOption.existValueBackgroundColor?.isNotEmpty ?? false) &&
        element.controlId != null &&
        _control.getIsExistValueByElementListIndex(elementList, index)) {
      isExistValueControlHighlight = true;
    }
    if (!isExistValueControlHighlight &&
        !isPrintMode &&
        (controlOption.noValueBackgroundColor?.isNotEmpty ?? false) &&
        element.controlId != null &&
        !_control.getIsExistValueByElementListIndex(elementList, index)) {
      isNoValueControlHighlight = true;
    }
    if (isActiveControlHighlight) {
      return controlOption.activeBackgroundColor;
    }
    if (isDisabledControlHighlight) {
      return controlOption.disabledBackgroundColor;
    }
    if (isExistValueControlHighlight) {
      return controlOption.existValueBackgroundColor;
    }
    if (isNoValueControlHighlight) {
      return controlOption.noValueBackgroundColor;
    }
    return null;
  }

  void computeHighlightList() {
    _highlightMatchResult = <ControlHighlightMatchResult>[];
    if (_highlightList.isEmpty) {
      return;
    }
    final dynamic search = _draw.getSearch();
    if (search == null) {
      return;
    }
    final List<ControlHighlightMatchResult> result =
        <ControlHighlightMatchResult>[];

    void compute(List<IElement> elementList,
        [ISearchResultRestArgs? restArgs]) {
      int i = 0;
      while (i < elementList.length) {
        final IElement element = elementList[i];
        i += 1;
        if (element.type == ElementType.table && element.trList != null) {
          final trList = element.trList!;
          for (int r = 0; r < trList.length; r++) {
            final tdList = trList[r].tdList;
            for (int d = 0; d < tdList.length; d++) {
              final td = tdList[d];
              final ISearchResultRestArgs tableRestArgs =
                  ISearchResultRestArgs(
                  tableId: element.id,
                  tableIndex: i - 1,
                  trIndex: r,
                  tdIndex: d,
                  tdId: td.id,
                );
              compute(td.value, tableRestArgs);
            }
          }
        }
        final IControl? currentControl = element.control;
        if (currentControl == null) {
          continue;
        }
        final int highlightIndex = _highlightList.indexWhere(
            (IControlHighlight highlight) =>
              highlight.id == element.controlId ||
                (currentControl.conceptId != null &&
                    highlight.conceptId == currentControl.conceptId),
        );
        if (highlightIndex < 0) {
          continue;
        }
        final int startIndex = i;
        int newEndIndex = i;
        while (newEndIndex < elementList.length) {
          final IElement nextElement = elementList[newEndIndex];
          if (nextElement.controlId != element.controlId) {
            break;
          }
          newEndIndex += 1;
        }
        i = newEndIndex;
        if (startIndex >= newEndIndex) {
          continue;
        }
        final List<IElement> controlValueElements = elementList
            .sublist(startIndex, newEndIndex)
            .map((IElement current) =>
                current.controlComponent == ControlComponent.value
                    ? current
                    : IElement(value: ZERO))
            .toList();
        if (controlValueElements.isEmpty) {
          continue;
        }
        final IControlHighlight highlight = _highlightList[highlightIndex];
        for (final IControlHighlightRule rule in highlight.ruleList) {
          final dynamic rawResult =
              search.getMatchList(rule.keyword, controlValueElements);
          if (rawResult is! List) {
            continue;
          }
          for (final dynamic entry in rawResult) {
            if (entry is! ISearchResult) {
              continue;
            }
            result.add(
                ControlHighlightMatchResult(
                  keyword: rule.keyword,
                  matchAlpha: rule.alpha,
                  matchBackgroundColor: rule.backgroundColor,
                  type: entry.type,
                  index: entry.index + startIndex,
                  groupId: entry.groupId,
                  tableId: restArgs?.tableId ?? entry.tableId,
                  tableIndex:
                    restArgs?.tableIndex ?? entry.tableIndex,
                  trIndex: restArgs?.trIndex ?? entry.trIndex,
                  tdIndex: restArgs?.tdIndex ?? entry.tdIndex,
                  tdId: restArgs?.tdId ?? entry.tdId,
                  startIndex:
                    restArgs?.startIndex ?? entry.startIndex,
                ),
            );
          }
        }
      }
    }

    compute(_draw.getOriginalMainElementList());
    _highlightMatchResult = result;
  }

  void renderHighlightList(CanvasRenderingContext2D ctx, int pageIndex) {
    if (_highlightMatchResult.isEmpty) {
      return;
    }
    final double searchMatchAlpha =
        (_options.searchMatchAlpha ?? 0.6).toDouble();
    final String searchMatchColor =
        _options.searchMatchColor ?? '#FFFF00';
    final dynamic positionManager = _draw.getPosition();
    final List<IElementPosition>? positionList =
        positionManager?.getOriginalPositionList()
          as List<IElementPosition>?;
    if (positionList == null) {
      return;
    }
    final List<IElement> elementList = _draw.getOriginalElementList();
    ctx.save();
    for (final ControlHighlightMatchResult match in _highlightMatchResult) {
      IElementPosition? position;
      if (match.tableId != null) {
        final int? tableIndex = match.tableIndex;
        final int? trIndex = match.trIndex;
        final int? tdIndex = match.tdIndex;
        final int charIndex = match.index;
        if (tableIndex != null &&
            tableIndex >= 0 &&
            tableIndex < elementList.length) {
          final trList = elementList[tableIndex].trList;
          if (trList != null &&
              trIndex != null &&
              trIndex >= 0 &&
              trIndex < trList.length) {
            final tdList = trList[trIndex].tdList;
            if (tdIndex != null &&
                  tdIndex >= 0 &&
                  tdIndex < tdList.length) {
              final positions = tdList[tdIndex].positionList;
              if (positions != null &&
                    charIndex >= 0 &&
                    charIndex < positions.length) {
                position = positions[charIndex];
              }
            }
          }
        }
      } else {
        final int index = match.index;
        if (index >= 0 && index < positionList.length) {
          position = positionList[index];
        }
      }
      if (position == null || position.pageNo != pageIndex) {
        continue;
      }
      final List<double>? leftTop = position.coordinate['leftTop'];
      final List<double>? leftBottom = position.coordinate['leftBottom'];
      final List<double>? rightTop = position.coordinate['rightTop'];
      if (leftTop == null || leftBottom == null || rightTop == null) {
        continue;
      }
      ctx.fillStyle = match.backgroundColor ?? searchMatchColor;
      ctx.globalAlpha = match.alpha ?? searchMatchAlpha;
      final double x = leftTop[0];
      final double y = leftTop[1];
      final double width = rightTop[0] - leftTop[0];
      final double height = leftBottom[1] - leftTop[1];
      ctx.fillRect(x, y, width, height);
    }
    ctx.restore();
  }
}
