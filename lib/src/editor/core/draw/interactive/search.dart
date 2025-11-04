import 'dart:html';

import '../../../dataset/constant/common.dart';
import '../../../dataset/constant/element.dart' as element_constants;
import '../../../dataset/enum/control.dart';
import '../../../dataset/enum/editor.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/position.dart';
import '../../../interface/search.dart';
import '../../../interface/table/tr.dart';
import '../../../interface/table/td.dart';
import '../../../utils/element.dart' as element_utils;
import '../../../utils/index.dart' show getUUID, isNumber;
import '../../position/position.dart';
import '../../range/range_manager.dart';
import '../draw.dart';

const double _anchorOverflowSize = 50;

class Search {
	Search(Draw draw)
			: _draw = draw,
				_options = draw.getOptions(),
				_position = draw.getPosition() as Position,
				searchMatchList = <ISearchResult>[];

	final Draw _draw;
	final IEditorOption _options;
	final Position _position;
	String? searchKeyword;
	int? searchNavigateIndex;
	List<ISearchResult> searchMatchList;

	String? getSearchKeyword() => searchKeyword;

	void setSearchKeyword(String? payload) {
		searchKeyword = payload;
		searchNavigateIndex = null;
		if (payload == null || payload.isEmpty) {
			searchMatchList.clear();
		}
	}

	int? searchNavigatePre() {
		if (searchMatchList.isEmpty || searchKeyword == null || searchKeyword!.isEmpty) {
			return null;
		}
		if (searchNavigateIndex == null) {
			searchNavigateIndex = 0;
			return searchNavigateIndex;
		}
		final int keywordLength = searchKeyword!.length;
		final int currentIndex = searchNavigateIndex!;
		if (currentIndex < 0 || currentIndex >= searchMatchList.length) {
			searchNavigateIndex = 0;
			return searchNavigateIndex;
		}
		final String searchNavigateId = searchMatchList[currentIndex].groupId;
		var index = currentIndex - 1;
		var hasPrevious = false;
		while (index >= 0) {
			final ISearchResult match = searchMatchList[index];
			if (match.groupId != searchNavigateId) {
				hasPrevious = true;
				searchNavigateIndex = index - (keywordLength - 1);
				break;
			}
			index -= 1;
		}
		if (!hasPrevious) {
			final ISearchResult lastMatch = searchMatchList.last;
			if (lastMatch.groupId == searchNavigateId) {
				return null;
			}
			searchNavigateIndex = searchMatchList.length - keywordLength;
		}
		return searchNavigateIndex;
	}

	int? searchNavigateNext() {
		if (searchMatchList.isEmpty || searchKeyword == null || searchKeyword!.isEmpty) {
			return null;
		}
		if (searchNavigateIndex == null) {
			searchNavigateIndex = 0;
			return searchNavigateIndex;
		}
		final int keywordLength = searchKeyword!.length;
		final int currentIndex = searchNavigateIndex!;
		if (currentIndex < 0 || currentIndex >= searchMatchList.length) {
			searchNavigateIndex = 0;
			return searchNavigateIndex;
		}
		final String searchNavigateId = searchMatchList[currentIndex].groupId;
		var index = currentIndex + 1;
		var hasNext = false;
		while (index < searchMatchList.length) {
			final ISearchResult match = searchMatchList[index];
			if (match.groupId != searchNavigateId) {
				hasNext = true;
				searchNavigateIndex = index;
				break;
			}
			index += 1;
		}
		if (!hasNext) {
			final ISearchResult firstMatch = searchMatchList.first;
			if (firstMatch.groupId == searchNavigateId) {
				return null;
			}
			searchNavigateIndex = 0;
		}
		if (searchNavigateIndex != null && searchNavigateIndex! + keywordLength > searchMatchList.length) {
			searchNavigateIndex = searchMatchList.length - keywordLength;
		}
		return searchNavigateIndex;
	}

	void searchNavigateScrollIntoView(IElementPosition position) {
		final Map<String, List<double>> coordinate = position.coordinate;
		final List<double>? leftTop = coordinate['leftTop'];
		final List<double>? leftBottom = coordinate['leftBottom'];
		final List<double>? rightTop = coordinate['rightTop'];
		if (leftTop == null || leftBottom == null || rightTop == null) {
			return;
		}
		final int pageNo = position.pageNo;
		final double height = _draw.getHeight();
		final double pageGap = _draw.getPageGap();
		final double preY = pageNo * (height + pageGap);
		final DivElement anchor = DivElement()
			..style.position = 'absolute'
			..style.width = '${rightTop[0] - leftTop[0] + _anchorOverflowSize}px'
			..style.height = '${leftBottom[1] - leftTop[1] + _anchorOverflowSize}px'
			..style.left = '${leftTop[0]}px'
			..style.top = '${leftTop[1] + preY}px';
		_draw.getContainer().append(anchor);
		anchor.scrollIntoView(ScrollAlignment.BOTTOM);
		anchor.remove();
	}

	List<int> getSearchNavigateIndexList() {
		if (searchNavigateIndex == null || searchKeyword == null || searchKeyword!.isEmpty) {
			return const <int>[];
		}
		return List<int>.generate(
			searchKeyword!.length,
			(int offset) => searchNavigateIndex! + offset,
		);
	}

	List<ISearchResult> getSearchMatchList() {
		return searchMatchList;
	}

	INavigateInfo? getSearchNavigateInfo() {
		if (searchKeyword == null || searchKeyword!.isEmpty || searchMatchList.isEmpty) {
			return null;
		}
		final int keywordLength = searchKeyword!.length;
		final int index = searchNavigateIndex != null
				? (searchNavigateIndex! ~/ keywordLength) + 1
				: 0;
		int count = 0;
		String? groupId;
		for (final ISearchResult match in searchMatchList) {
			if (groupId == match.groupId) {
				continue;
			}
			groupId = match.groupId;
			count += 1;
		}
		return INavigateInfo(index: index, count: count);
	}

	List<ISearchResult> getMatchList(String payload, List<IElement> originalElementList) {
		final String keyword = payload.toLowerCase();
		final List<ISearchResult> matches = <ISearchResult>[];
		if (keyword.isEmpty) {
			return matches;
		}
		final List<_ElementListGroup> elementGroups = <_ElementListGroup>[];
		final int length = originalElementList.length;
		if (length == 0) {
			return matches;
		}
		final List<int> tableIndexList = <int>[];
		for (int i = 0; i < length; i++) {
			if (originalElementList[i].type == ElementType.table) {
				tableIndexList.add(i);
			}
		}
		var tablePointer = 0;
		var elementIndex = 0;
		while (elementIndex < length) {
			final int? tableIndex =
					tablePointer < tableIndexList.length ? tableIndexList[tablePointer] : null;
			final int endIndex = tableIndex ?? length;
			if (elementIndex < endIndex) {
				final List<IElement> pageElements =
						originalElementList.sublist(elementIndex, endIndex);
				if (pageElements.isNotEmpty) {
					elementGroups.add(
						_ElementListGroup(
							type: EditorContext.page,
							elementList: pageElements,
							index: elementIndex,
						),
					);
				}
				elementIndex = endIndex;
			}
			if (tableIndex != null && elementIndex == tableIndex && elementIndex < length) {
				final IElement tableElement = originalElementList[elementIndex];
				elementGroups.add(
					_ElementListGroup(
						type: EditorContext.table,
						elementList: <IElement>[tableElement],
						index: elementIndex,
					),
				);
				elementIndex += 1;
				tablePointer += 1;
			}
		}

		void searchClosure(
			String? value,
			EditorContext type,
			List<IElement> elementList,
			[ISearchResultRestArgs? restArgs]
		) {
			if (value == null || value.isEmpty) {
				return;
			}
			final Iterable<String> mapped = elementList.map((IElement element) {
				final ElementType? elementType = element.type;
				final bool shouldUseValue = elementType == null ||
						(element_constants.textlikeElementType.contains(elementType) &&
							element.controlComponent != ControlComponent.checkbox &&
							element.hide != true &&
							element.control?.hide != true &&
							element.area?.hide != true);
				return shouldUseValue ? element.value : ZERO;
			});
			final String text = mapped
					.where((String entry) => entry.isNotEmpty)
					.join()
					.toLowerCase();
			int index = text.indexOf(value);
			if (index == -1) {
				return;
			}
			final List<int> startIndexList = <int>[];
			while (index != -1) {
				startIndexList.add(index);
				index = text.indexOf(value, index + value.length);
			}
			for (final int startIndex in startIndexList) {
				final String groupId = getUUID();
				for (int i = 0; i < value.length; i++) {
					final int elementIndex =
							startIndex + i + (restArgs?.startIndex ?? 0);
					matches.add(
						ISearchResult(
							type: type,
							index: elementIndex,
							groupId: groupId,
							tableId: restArgs?.tableId,
							tableIndex: restArgs?.tableIndex,
							trIndex: restArgs?.trIndex,
							tdIndex: restArgs?.tdIndex,
							tdId: restArgs?.tdId,
							startIndex: restArgs?.startIndex,
						),
					);
				}
			}
		}

		for (final _ElementListGroup group in elementGroups) {
			if (group.type == EditorContext.table) {
				final IElement tableElement = group.elementList.first;
				final List<ITr>? trList = tableElement.trList;
				if (trList == null) {
					continue;
				}
				for (int trIndex = 0; trIndex < trList.length; trIndex++) {
					final ITr tr = trList[trIndex];
					for (int tdIndex = 0; tdIndex < tr.tdList.length; tdIndex++) {
						final ITd td = tr.tdList[tdIndex];
						searchClosure(
							keyword,
							group.type,
							td.value,
							ISearchResultRestArgs(
								tableId: tableElement.id,
								tableIndex: group.index,
								trIndex: trIndex,
								tdIndex: tdIndex,
								tdId: td.id,
							),
						);
					}
				}
			} else {
				searchClosure(
					keyword,
					group.type,
					group.elementList,
					ISearchResultRestArgs(startIndex: group.index),
				);
			}
		}
		return matches;
	}

	void compute(String payload) {
		final List<IElement> elementList = _draw.getOriginalElementList();
		searchMatchList = getMatchList(payload, elementList);
	}

	void render(CanvasRenderingContext2D ctx, int pageIndex) {
		if (searchMatchList.isEmpty || searchKeyword == null || searchKeyword!.isEmpty) {
			return;
		}
		final double alpha = _options.searchMatchAlpha ?? 1;
		final String fillColor = _options.searchMatchColor ?? '#ffde7d';
		final String navigateColor =
				_options.searchNavigateMatchColor ?? _options.searchMatchColor ?? '#ffb74d';
		final List<IElementPosition> positionList = _position.getOriginalPositionList();
		final List<IElement> elementList = _draw.getOriginalElementList();
		final Set<int> navigateIndexSet = getSearchNavigateIndexList().toSet();
		ctx.save();
		ctx.globalAlpha = alpha;
		for (int i = 0; i < searchMatchList.length; i++) {
			final ISearchResult searchMatch = searchMatchList[i];
			late IElementPosition position;
			if (searchMatch.type == EditorContext.table) {
				final int? tableIndex = searchMatch.tableIndex;
				final int? trIndex = searchMatch.trIndex;
				final int? tdIndex = searchMatch.tdIndex;
				final int? idx = searchMatch.index;
				if (tableIndex == null || trIndex == null || tdIndex == null || idx == null) {
					continue;
				}
				if (tableIndex < 0 || tableIndex >= elementList.length) {
					continue;
				}
				final IElement element = elementList[tableIndex];
				final List<ITr>? trList = element.trList;
				if (trList == null || trIndex >= trList.length) {
					continue;
				}
				final ITr tr = trList[trIndex];
				if (tdIndex >= tr.tdList.length) {
					continue;
				}
				final ITd td = tr.tdList[tdIndex];
				final List<IElementPosition>? tdPositionList = td.positionList;
				if (tdPositionList == null || idx < 0 || idx >= tdPositionList.length) {
					continue;
				}
				position = tdPositionList[idx];
			} else {
				if (searchMatch.index < 0 || searchMatch.index >= positionList.length) {
					continue;
				}
				position = positionList[searchMatch.index];
			}
			if (position.pageNo != pageIndex) {
				continue;
			}
			final Map<String, List<double>> coordinate = position.coordinate;
			final List<double>? leftTop = coordinate['leftTop'];
			final List<double>? leftBottom = coordinate['leftBottom'];
			final List<double>? rightTop = coordinate['rightTop'];
			if (leftTop == null || leftBottom == null || rightTop == null) {
				continue;
			}
			if (navigateIndexSet.contains(i)) {
				ctx.fillStyle = navigateColor;
				final ISearchResult? previousMatch = i > 0 ? searchMatchList[i - 1] : null;
				if (previousMatch == null || previousMatch.groupId != searchMatch.groupId) {
					searchNavigateScrollIntoView(position);
				}
			} else {
				ctx.fillStyle = fillColor;
			}
			final double x = leftTop[0];
			final double y = leftTop[1];
			final double width = rightTop[0] - leftTop[0];
			final double height = leftBottom[1] - leftTop[1];
			ctx.fillRect(x, y, width, height);
		}
		ctx.restore();
	}

	void replace(String? payload, [IReplaceOption? option]) {
		if (_draw.isReadonly()) {
			return;
		}
		if (payload == null) {
			return;
		}
		List<ISearchResult> matchList = List<ISearchResult>.from(getSearchMatchList());
		final dynamic replaceIndex = option?.index;
		if (replaceIndex != null && isNumber(replaceIndex)) {
			final int targetIndex = replaceIndex is num ? replaceIndex.toInt() : 0;
			final List<List<ISearchResult>> groupedMatchList = <List<ISearchResult>>[];
			for (final ISearchResult match in matchList) {
				if (groupedMatchList.isEmpty ||
						groupedMatchList.last.first.groupId != match.groupId) {
					groupedMatchList.add(<ISearchResult>[match]);
				} else {
					groupedMatchList.last.add(match);
				}
			}
			if (targetIndex >= 0 && targetIndex < groupedMatchList.length) {
				matchList = groupedMatchList[targetIndex];
			} else {
				matchList = <ISearchResult>[];
			}
		}
		if (matchList.isEmpty) {
			return;
		}
		final bool isDesignMode = _draw.isDesignMode();
		int pageDiffCount = 0;
		int tableDiffCount = 0;
		String? curGroupId;
		String? curTdId;
		var firstMatchIndex = -1;
		final List<IElement> elementList = _draw.getOriginalElementList();
		for (int i = 0; i < matchList.length; i++) {
			final ISearchResult match = matchList[i];
			if (match.type == EditorContext.table) {
				final int? tableIndex = match.tableIndex;
				final int? trIndex = match.trIndex;
				final int? tdIndex = match.tdIndex;
				final int? index = match.index;
				final String? tdId = match.tdId;
				if (tableIndex == null || trIndex == null || tdIndex == null || index == null) {
					continue;
				}
				final int curTableIndex = tableIndex + pageDiffCount;
				if (curTableIndex < 0 || curTableIndex >= elementList.length) {
					continue;
				}
				final IElement tableElement = elementList[curTableIndex];
				final List<ITr>? trList = tableElement.trList;
				if (trList == null || trIndex < 0 || trIndex >= trList.length) {
					continue;
				}
				final ITr tr = trList[trIndex];
				if (tdIndex < 0 || tdIndex >= tr.tdList.length) {
					continue;
				}
				final ITd td = tr.tdList[tdIndex];
				final List<IElement> tableValue = td.value;
				if (tdId != null && curTdId != null && tdId != curTdId) {
					tableDiffCount = 0;
				}
				curTdId = tdId;
				final int curIndex = index + tableDiffCount;
				if (curIndex < 0 || curIndex >= tableValue.length) {
					continue;
				}
				final IElement tableElementItem = tableValue[curIndex];
				if (!isDesignMode &&
						(tableElementItem.control?.deletable == false ||
							tableElementItem.title?.deletable == false)) {
					continue;
				}
				if (payload.isEmpty) {
					_draw.spliceElementList(tableValue, curIndex, 1);
					tableDiffCount -= 1;
					if (firstMatchIndex < 0) {
						firstMatchIndex = i;
					}
					continue;
				}
				if (curGroupId == match.groupId) {
					_draw.spliceElementList(tableValue, curIndex, 1);
					tableDiffCount -= 1;
					continue;
				}
				if (firstMatchIndex < 0) {
					firstMatchIndex = i;
				}
				for (int p = 0; p < payload.length; p++) {
					final String value = payload[p];
					if (p == 0) {
						tableElementItem.value = value;
					} else {
						final IElement cloned =
								element_utils.cloneElementList(<IElement>[tableElementItem]).first;
						cloned.value = value;
						_draw.spliceElementList(
							tableValue,
							curIndex + p,
							0,
							<IElement>[cloned],
						);
						tableDiffCount += 1;
					}
				}
			} else {
				final int curIndex = match.index + pageDiffCount;
				if (curIndex < 0 || curIndex >= elementList.length) {
					continue;
				}
				final IElement element = elementList[curIndex];
				if ((!isDesignMode &&
							(element.control?.deletable == false ||
								element.title?.deletable == false)) ||
						(element.type == ElementType.control &&
							element.controlComponent != ControlComponent.value)) {
					continue;
				}
				if (payload.isEmpty) {
					_draw.spliceElementList(elementList, curIndex, 1);
					pageDiffCount -= 1;
					if (firstMatchIndex < 0) {
						firstMatchIndex = i;
					}
					continue;
				}
				if (curGroupId == match.groupId) {
					_draw.spliceElementList(elementList, curIndex, 1);
					pageDiffCount -= 1;
					continue;
				}
				if (firstMatchIndex < 0) {
					firstMatchIndex = i;
				}
				for (int p = 0; p < payload.length; p++) {
					final String value = payload[p];
					if (p == 0) {
						element.value = value;
					} else {
						final IElement cloned =
								element_utils.cloneElementList(<IElement>[element]).first;
						cloned.value = value;
						_draw.spliceElementList(
							elementList,
							curIndex + p,
							0,
							<IElement>[cloned],
						);
						pageDiffCount += 1;
					}
				}
			}
			curGroupId = match.groupId;
		}
		if (firstMatchIndex < 0) {
			return;
		}
		final ISearchResult firstMatch = matchList[firstMatchIndex];
		final int firstIndex = firstMatch.index + (payload.length - 1);
		if (firstMatch.type == EditorContext.table) {
			final int? tableIndex = firstMatch.tableIndex;
			final int? trIndex = firstMatch.trIndex;
			final int? tdIndex = firstMatch.tdIndex;
			final int? index = firstMatch.index;
			if (tableIndex != null &&
					trIndex != null &&
					tdIndex != null &&
					index != null &&
					tableIndex >= 0 &&
					tableIndex < elementList.length) {
				final IElement tableElement = elementList[tableIndex];
				final List<ITr>? trList = tableElement.trList;
				if (trList != null && trIndex >= 0 && trIndex < trList.length) {
					final ITr tr = trList[trIndex];
					if (tdIndex >= 0 && tdIndex < tr.tdList.length) {
						final ITd td = tr.tdList[tdIndex];
						final List<IElement> valueList = td.value;
						if (index >= 0 && index < valueList.length) {
							final IElement element = valueList[index];
							_position.setPositionContext(
								IPositionContext(
									isTable: true,
									index: tableIndex,
									trIndex: trIndex,
									tdIndex: tdIndex,
									tdId: element.tdId,
									trId: element.trId,
									tableId: element.tableId,
								),
							);
						}
					}
				}
			}
		} else {
			_position.setPositionContext(IPositionContext(isTable: false));
		}
		final RangeManager rangeManager = _draw.getRange() as RangeManager;
		rangeManager.setRange(firstIndex, firstIndex);
		_draw.render(IDrawOption(curIndex: firstIndex));
	}
}

class _ElementListGroup {
	_ElementListGroup({
		required this.type,
		required this.elementList,
		required this.index,
	});

	final EditorContext type;
	final List<IElement> elementList;
	final int index;
}