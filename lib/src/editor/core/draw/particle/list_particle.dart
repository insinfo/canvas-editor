// TODO: Translate from C:\\MyTsProjects\\canvas-editor\\src\\editor\\core\\draw\\particle\\ListParticle.ts
import 'dart:html';

import '../../../dataset/constant/common.dart';
import '../../../dataset/constant/list.dart';
import '../../../dataset/enum/element.dart';
import '../../../dataset/enum/key_map.dart';
import '../../../dataset/enum/list.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/range.dart';
import '../../../interface/row.dart';
import '../../../utils/index.dart';
import '../../range/range_manager.dart';
import '../draw.dart';
import 'checkbox_particle.dart';

class ListParticle {
	ListParticle(this._draw)
			: _range = _draw.getRange() as RangeManager,
				_options = _draw.getOptions();

	final Draw _draw;
	final RangeManager _range;
	final IEditorOption _options;

	static const double _unCountStyleWidth = 20;
	static const String _measureBaseText = '0';
	static const double _listGap = 10;

	void setList(ListType? listType, [ListStyle? listStyle]) {
		if (_draw.isReadonly()) {
			return;
		}
		final IRange currentRange = _range.getRange();
		final int startIndex = currentRange.startIndex;
		final int endIndex = currentRange.endIndex;
		if (startIndex == -1 && endIndex == -1) {
			return;
		}
		final List<IElement>? changeElementList =
			_range.getRangeParagraphElementList();
		if (changeElementList == null || changeElementList.isEmpty) {
			return;
		}
		final bool shouldUnset = changeElementList.any(
			(IElement el) => el.listType == listType && el.listStyle == listStyle,
		);
		if (shouldUnset || listType == null) {
			unsetList();
			return;
		}
		final String listId = getUUID();
		for (final IElement element in changeElementList) {
			element
				..listId = listId
				..listType = listType
				..listStyle = listStyle;
		}
		final bool isSetCursor = startIndex == endIndex;
		final int curIndex = isSetCursor ? endIndex : startIndex;
		_draw.render(
			IDrawOption(
				curIndex: curIndex,
				isSetCursor: isSetCursor,
			),
		);
	}

	void unsetList() {
		if (_draw.isReadonly()) {
			return;
		}
		final IRange currentRange = _range.getRange();
		final int startIndex = currentRange.startIndex;
		final int endIndex = currentRange.endIndex;
		if (startIndex == -1 && endIndex == -1) {
			return;
		}
		final List<IElement>? changeElementList = _range
			.getRangeParagraphElementList()
			?.where((IElement el) => el.listId != null)
			.toList();
		if (changeElementList == null || changeElementList.isEmpty) {
			return;
		}
		final List<IElement> elementList = _draw.getElementList();
		if (endIndex >= 0 && endIndex < elementList.length) {
			final IElement endElement = elementList[endIndex];
			if (endElement.listId != null) {
				var pointer = endIndex + 1;
				while (pointer < elementList.length) {
					final IElement element = elementList[pointer];
					if (element.value == ZERO && element.listWrap != true) {
						break;
					}
					if (element.listId != endElement.listId) {
						_draw.spliceElementList(
							elementList,
							pointer,
							0,
							<IElement>[IElement(value: ZERO)],
						);
						break;
					}
					pointer += 1;
				}
			}
		}
		for (final IElement element in changeElementList) {
			element
				..listId = null
				..listType = null
				..listStyle = null
				..listWrap = null;
		}
		final bool isSetCursor = startIndex == endIndex;
		final int curIndex = isSetCursor ? endIndex : startIndex;
		_draw.render(
			IDrawOption(
				curIndex: curIndex,
				isSetCursor: isSetCursor,
			),
		);
	}

	Map<String, double> computeListStyle(
		CanvasRenderingContext2D ctx,
		List<IElement> elementList,
	) {
		final Map<String, double> listStyleMap = <String, double>{};
		if (elementList.isEmpty) {
			return listStyleMap;
		}
		int pointer = 0;
		String? currentListId = elementList[pointer].listId;
		List<IElement> currentElementList = <IElement>[];
		while (pointer < elementList.length) {
			final IElement currentElement = elementList[pointer];
			if (currentListId != null && currentListId == currentElement.listId) {
				currentElementList.add(currentElement);
			} else if (currentElement.listId != null &&
				currentElement.listId != currentListId) {
				if (currentElementList.isNotEmpty && currentListId != null) {
					final double width =
						getListStyleWidth(ctx, currentElementList);
					listStyleMap[currentListId] = width;
				}
				currentListId = currentElement.listId;
				currentElementList = currentListId != null
						? <IElement>[currentElement]
						: <IElement>[];
			}
			pointer += 1;
		}
		if (currentElementList.isNotEmpty && currentListId != null) {
			listStyleMap[currentListId] =
				getListStyleWidth(ctx, currentElementList);
		}
		return listStyleMap;
	}

	double getListStyleWidth(
		CanvasRenderingContext2D ctx,
		List<IElement> listElementList,
	) {
		if (listElementList.isEmpty) {
			return 0;
		}
		final double scale = _resolveScale();
		final IElement startElement = listElementList.first;
		if (startElement.listStyle != null &&
			startElement.listStyle != ListStyle.decimal) {
			if (startElement.listStyle == ListStyle.checkbox) {
				final double checkboxWidth =
					(_options.checkbox?.width ?? 0).toDouble();
				return (checkboxWidth + _listGap) * scale;
			}
			return _unCountStyleWidth * scale;
		}
		final int count = listElementList.fold<int>(
			0,
			(int prev, IElement element) =>
				(element.value == ZERO) ? prev + 1 : prev,
		);
		if (count == 0) {
			return 0;
		}
		final String text =
			'${_repeat(_measureBaseText, count.toString().length)}${KeyMap.period.value}';
		final TextMetrics metrics = ctx.measureText(text);
		final double measuredWidth = (metrics.width ?? 0).toDouble();
		return ((measuredWidth + _listGap) * scale).ceilToDouble();
	}

	void drawListStyle(
		CanvasRenderingContext2D ctx,
		IRow row,
		IElementPosition position,
	) {
		final List<IRowElement> elementList = row.elementList;
		if (elementList.isEmpty) {
			return;
		}
		final IRowElement startElement = elementList.first;
		if (startElement.value != ZERO || startElement.listWrap == true) {
			return;
		}
		double tabWidth = 0;
		final double defaultTabWidth = _resolveDefaultTabWidth();
		final double scale = _resolveScale();
		for (int i = 1; i < elementList.length; i++) {
			final IRowElement element = elementList[i];
			if (element.type != ElementType.tab) {
				break;
			}
			tabWidth += defaultTabWidth * scale;
		}
		final List<double> leftTop =
			position.coordinate['leftTop'] ?? <double>[0, 0];
		final double startX = leftTop.isNotEmpty ? leftTop.first : 0;
		final double startY =
			leftTop.length > 1 ? leftTop[1] : (position.coordinate['leftTop']?[0] ?? 0);
		final double x = startX - (row.offsetX ?? 0) + tabWidth;
		final double y = startY + row.ascent;
		if (startElement.listStyle == ListStyle.checkbox) {
			final CheckboxParticle? checkboxParticle =
				_draw.getCheckboxParticle() as CheckboxParticle?;
			if (checkboxParticle == null) {
				return;
			}
			final double gap = (_options.checkbox?.gap ?? 0).toDouble();
			final IRowElement checkboxRowElement =
				_buildCheckboxRowElement(startElement, scale, gap);
			final IRow checkboxRow = IRow(
				width: row.width,
				height: row.height,
				ascent: row.ascent,
				rowFlex: row.rowFlex,
				startIndex: row.startIndex,
				isPageBreak: row.isPageBreak,
				isList: row.isList,
				listIndex: row.listIndex,
				offsetX: row.offsetX,
				offsetY: row.offsetY,
				elementList: <IRowElement>[checkboxRowElement, ...row.elementList],
				isWidthNotEnough: row.isWidthNotEnough,
				rowIndex: row.rowIndex,
				isSurround: row.isSurround,
			);
			checkboxParticle.render(
				CheckboxRenderPayload(
					ctx: ctx,
					x: x - gap * scale,
					y: y,
					index: 0,
					row: checkboxRow,
				),
			);
			return;
		}
		String text = '';
		if (startElement.listType == ListType.unordered) {
			final UlStyle? ulStyle = _toUlStyle(startElement.listStyle);
			text = ulStyleMapping[ulStyle] ?? ulStyleMapping[UlStyle.disc] ?? '';
		} else {
			final int listIndex = (row.listIndex ?? 0) + 1;
			text = '$listIndex${KeyMap.period.value}';
		}
		if (text.isEmpty) {
			return;
		}
		ctx.save();
		ctx.font = '${_resolveDefaultSize() * scale}px ${_resolveDefaultFont()}';
		ctx.fillText(text, x, y);
		ctx.restore();
	}

	double _resolveScale() => (_options.scale ?? 1).toDouble();

	double _resolveDefaultTabWidth() => (_options.defaultTabWidth ?? 0).toDouble();

	IRowElement _buildCheckboxRowElement(
		IRowElement startElement,
		double scale,
		double gap,
	) {
		final IElementMetrics baseMetrics = startElement.metrics;
		final double configuredWidth =
			(_options.checkbox?.width ?? (baseMetrics.width / scale)).toDouble();
		final double configuredHeight =
			(_options.checkbox?.height ?? (baseMetrics.height / scale)).toDouble();
		final IElementMetrics metrics = IElementMetrics(
			width: (configuredWidth + gap * 2) * scale,
			height: configuredHeight * scale,
			boundingBoxAscent: baseMetrics.boundingBoxAscent,
			boundingBoxDescent: baseMetrics.boundingBoxDescent,
		);
		final ICheckbox? checkbox = startElement.checkbox;
		return IRowElement(
			metrics: metrics,
			style: startElement.style,
			left: startElement.left,
			id: startElement.id,
			type: startElement.type,
			value: startElement.value,
			extension: startElement.extension,
			externalId: startElement.externalId,
			font: startElement.font,
			size: startElement.size,
			width: startElement.width,
			height: startElement.height,
			bold: startElement.bold,
			color: startElement.color,
			highlight: startElement.highlight,
			italic: startElement.italic,
			underline: startElement.underline,
			strikeout: startElement.strikeout,
			rowFlex: startElement.rowFlex,
			rowMargin: startElement.rowMargin,
			letterSpacing: startElement.letterSpacing,
			textDecoration: startElement.textDecoration,
			hide: startElement.hide,
			groupIds: startElement.groupIds,
			colgroup: startElement.colgroup,
			trList: startElement.trList,
			borderType: startElement.borderType,
			borderColor: startElement.borderColor,
			borderWidth: startElement.borderWidth,
			borderExternalWidth: startElement.borderExternalWidth,
			translateX: startElement.translateX,
			tableToolDisabled: startElement.tableToolDisabled,
			tdId: startElement.tdId,
			trId: startElement.trId,
			tableId: startElement.tableId,
			conceptId: startElement.conceptId,
			pagingId: startElement.pagingId,
			pagingIndex: startElement.pagingIndex,
			valueList: startElement.valueList,
			url: startElement.url,
			hyperlinkId: startElement.hyperlinkId,
			actualSize: startElement.actualSize,
			dashArray: startElement.dashArray,
			control: startElement.control,
			controlId: startElement.controlId,
			controlComponent: startElement.controlComponent,
			checkbox: checkbox == null
					? ICheckbox(value: false)
					: ICheckbox(
							value: checkbox.value,
							code: checkbox.code,
							disabled: checkbox.disabled,
						),
			radio: startElement.radio,
			laTexSVG: startElement.laTexSVG,
			dateFormat: startElement.dateFormat,
			dateId: startElement.dateId,
			imgDisplay: startElement.imgDisplay,
			imgFloatPosition: startElement.imgFloatPosition,
			imgToolDisabled: startElement.imgToolDisabled,
			block: startElement.block,
			level: startElement.level,
			titleId: startElement.titleId,
			title: startElement.title,
			listType: startElement.listType,
			listStyle: startElement.listStyle,
			listId: startElement.listId,
			listWrap: startElement.listWrap,
			areaId: startElement.areaId,
			areaIndex: startElement.areaIndex,
			area: startElement.area,
		);
	}

	String _repeat(String value, int times) {
		if (times <= 0) {
			return '';
		}
		final StringBuffer buffer = StringBuffer();
		for (int i = 0; i < times; i++) {
			buffer.write(value);
		}
		return buffer.toString();
	}

	String _resolveDefaultFont() => _options.defaultFont ?? 'sans-serif';

	double _resolveDefaultSize() => (_options.defaultSize ?? 16).toDouble();

	UlStyle? _toUlStyle(ListStyle? listStyle) {
		if (listStyle == null) {
			return null;
		}
		for (final UlStyle item in UlStyle.values) {
			if (item.value == listStyle.value) {
				return item;
			}
		}
		return null;
	}
}