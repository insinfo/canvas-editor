import 'dart:html';

import '../../../dataset/constant/group.dart';
import '../../../dataset/enum/editor.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/group.dart';
import '../../../interface/range.dart';
import '../../../interface/table/td.dart';
import '../../../utils/index.dart' as utils;
import '../../range/range_manager.dart';
import '../draw.dart';

class GroupContext {
	GroupContext({
		required this.isTable,
		required this.startIndex,
		required this.endIndex,
		this.index,
		this.trIndex,
		this.tdIndex,
		this.tdId,
		this.trId,
		this.tableId,
	});

	final bool isTable;
	final int startIndex;
	final int endIndex;
	final int? index;
	final int? trIndex;
	final int? tdIndex;
	final String? tdId;
	final String? trId;
	final String? tableId;
}

class Group {
	Group(Draw draw)
			: _draw = draw,
				_options = draw.getOptions(),
				_range = draw.getRange() as RangeManager;

	final Draw _draw;
	final IEditorOption _options;
	final RangeManager _range;
	final Map<String, IElementFillRect> _fillRectMap =
			<String, IElementFillRect>{};

		String? setGroup() {
			if (_draw.isReadonly()) {
				return null;
			}
			if (_draw.getZone().getZone() != EditorZone.main) {
				return null;
			}
			final IGroup groupOption = _resolveGroupOption();
			if (groupOption.disabled == true) {
				return null;
			}
			final List<IElement>? selection = _range.getSelection();
			if (selection == null || selection.isEmpty) {
				return null;
			}
			final String groupId = utils.getUUID();
			for (final IElement element in selection) {
				final List<String> groupIds = element.groupIds != null
						? List<String>.from(element.groupIds!)
						: <String>[];
				groupIds.add(groupId);
				element.groupIds = groupIds;
			}
			_draw.render(
				IDrawOption(
					isSetCursor: false,
					isCompute: false,
				),
			);
			return groupId;
		}

	List<IElement> getElementListByGroupId(
		List<IElement> elementList,
		String groupId,
	) {
		final List<IElement> groupElementList = <IElement>[];
		for (int e = 0; e < elementList.length; e++) {
			final IElement element = elementList[e];
			if (element.type == ElementType.table && element.trList != null) {
				for (int r = 0; r < element.trList!.length; r++) {
					final ITr tr = element.trList![r];
					for (int d = 0; d < tr.tdList.length; d++) {
						final ITd td = tr.tdList[d];
						final List<IElement> nested =
								getElementListByGroupId(td.value, groupId);
						if (nested.isNotEmpty) {
							groupElementList.addAll(nested);
							return groupElementList;
						}
					}
				}
			}
			final List<String>? groupIds = element.groupIds;
			if (groupIds != null && groupIds.contains(groupId)) {
				groupElementList.add(element);
				final IElement? nextElement =
						e + 1 < elementList.length ? elementList[e + 1] : null;
				if (nextElement?.groupIds?.contains(groupId) != true) {
					break;
				}
			}
		}
		return groupElementList;
	}

	void deleteGroup(String groupId) {
			if (_draw.isReadonly()) {
			return;
		}
			final IGroup groupOption = _resolveGroupOption();
			if (groupOption.deletable == false) {
			return;
		}
		final List<IElement> elementList = _draw.getOriginalMainElementList();
		final List<IElement> groupElementList =
				getElementListByGroupId(elementList, groupId);
		if (groupElementList.isEmpty) {
			return;
		}
		for (final IElement element in groupElementList) {
			final List<String>? groupIds = element.groupIds;
			if (groupIds == null) {
				continue;
			}
			groupIds.removeWhere((String id) => id == groupId);
			if (groupIds.isEmpty) {
				element.groupIds = null;
			}
		}
		_draw.render(
			IDrawOption(
				isSetCursor: false,
				isCompute: false,
			),
		);
	}

	GroupContext? getContextByGroupId(
		List<IElement> elementList,
		String groupId,
	) {
		for (int e = 0; e < elementList.length; e++) {
			final IElement element = elementList[e];
			if (element.type == ElementType.table && element.trList != null) {
				for (int r = 0; r < element.trList!.length; r++) {
					final ITr tr = element.trList![r];
					for (int d = 0; d < tr.tdList.length; d++) {
						final ITd td = tr.tdList[d];
						final GroupContext? context =
								getContextByGroupId(td.value, groupId);
						if (context != null) {
							return GroupContext(
								isTable: true,
								startIndex: context.startIndex,
								endIndex: context.endIndex,
								index: e,
								trIndex: r,
								tdIndex: d,
								tdId: td.id,
								trId: tr.id,
								tableId: element.tableId,
							);
						}
					}
				}
			}
			final List<String>? groupIds = element.groupIds;
			final IElement? nextElement =
					e + 1 < elementList.length ? elementList[e + 1] : null;
			if (groupIds?.contains(groupId) == true &&
					nextElement?.groupIds?.contains(groupId) != true) {
				return GroupContext(
					isTable: false,
					startIndex: e,
					endIndex: e,
				);
			}
		}
		return null;
	}

	void clearFillInfo() {
		_fillRectMap.clear();
	}

	void recordFillInfo(
		IElement element,
		double x,
		double y,
		double width,
		double height,
	) {
		final List<String>? groupIds = element.groupIds;
		if (groupIds == null || groupIds.isEmpty) {
			return;
		}
		for (final String groupId in groupIds) {
			final IElementFillRect? rect = _fillRectMap[groupId];
			if (rect == null) {
				_fillRectMap[groupId] = IElementFillRect(
					x: x,
					y: y,
					width: width,
					height: height,
				);
			} else {
				rect.width += width;
			}
		}
	}

	void render(CanvasRenderingContext2D ctx) {
		if (_fillRectMap.isEmpty) {
			return;
		}
		final IRange range = _range.getRange();
		final List<IElement> elementList = _draw.getElementList();
		List<String>? anchorGroupIds;
		if (range.endIndex >= 0 && range.endIndex < elementList.length) {
			anchorGroupIds = elementList[range.endIndex].groupIds;
		}
			final IGroup groupOption = _resolveGroupOption();
			final double inactiveOpacity =
					groupOption.opacity ?? defaultGroupOption.opacity ?? 0.1;
			final double activeOpacity =
					groupOption.activeOpacity ?? defaultGroupOption.activeOpacity ?? 0.5;
			const String fallbackColor = '#5175f4';
			final String inactiveColor = groupOption.backgroundColor ??
				defaultGroupOption.backgroundColor ??
				fallbackColor;
			final String activeColor = groupOption.activeBackgroundColor ??
				groupOption.backgroundColor ??
				defaultGroupOption.activeBackgroundColor ??
				fallbackColor;

		ctx.save();
		_fillRectMap.forEach((String groupId, IElementFillRect rect) {
			final bool isActive = anchorGroupIds?.contains(groupId) == true;
			ctx.globalAlpha = isActive ? activeOpacity : inactiveOpacity;
				ctx.fillStyle = isActive ? activeColor : inactiveColor;
			ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
		});
		ctx.restore();
		clearFillInfo();
	}

		IGroup _resolveGroupOption() {
			return _options.group ?? defaultGroupOption;
		}
}