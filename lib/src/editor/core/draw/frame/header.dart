import 'dart:html';
import 'dart:math' as math;

import '../../../dataset/constant/common.dart';
import '../../../dataset/enum/common.dart' show MaxHeightRatio;
import '../../../dataset/enum/editor.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/header.dart';
import '../../../interface/position.dart';
import '../../../interface/row.dart';
import '../../../utils/element.dart' as element_utils;
import '../../position/position.dart';
import '../../zone/zone.dart';
import '../draw.dart';

class Header {
	Header(Draw draw, [List<IElement>? data])
			: _draw = draw,
				_position = draw.getPosition() as Position,
				_zone = draw.getZone(),
				_options = draw.getOptions(),
				_elementList = List<IElement>.from(data ?? const <IElement>[]),
				_rowList = <IRow>[],
				_positionList = <IElementPosition>[];

	final Draw _draw;
	final Position _position;
	final Zone _zone;
	final IEditorOption _options;

	List<IElement> _elementList;
	List<IRow> _rowList;
	List<IElementPosition> _positionList;

	dynamic _drawDynamic<T>(T Function(dynamic target) callback) {
		try {
			return callback(_draw as dynamic);
		} catch (_) {
			return null;
		}
	}

	List<IRow> getRowList() => _rowList;

	void setElementList(List<IElement> elementList) {
		_elementList = elementList;
	}

	List<IElement> getElementList() => _elementList;

	List<IElementPosition> getPositionList() => _positionList;

	void compute() {
		recovery();
		_computeRowList();
		_computePositionList();
	}

	void recovery() {
		_rowList = <IRow>[];
		_positionList = <IElementPosition>[];
	}

	void _computeRowList() {
		final double innerWidth = _draw.getInnerWidth();
		final List<double> margins = _draw.getMargins();
		final List<IElement> surroundElementList =
				element_utils.pickSurroundElementList(_elementList);
		final List<IRow> rows = _drawDynamic((dynamic target) {
					final dynamic result = target.computeRowList(
						IComputeRowListPayload(
							startX: margins[3],
							startY: getHeaderTop(),
							innerWidth: innerWidth,
							elementList: _elementList,
							surroundElementList: surroundElementList,
						),
					);
					if (result is List) {
						return result.whereType<IRow>().toList();
					}
					return <IRow>[];
				}) as List<IRow>? ??
				const <IRow>[];
		_rowList = List<IRow>.from(rows);
	}

	void _computePositionList() {
		final double headerTop = getHeaderTop();
		final double innerWidth = _draw.getInnerWidth();
		final List<double> margins = _draw.getMargins();
		final double startX = margins[3];
		final double startY = headerTop;
		_position.computePageRowPosition(
			IComputePageRowPositionPayload(
				positionList: _positionList,
				rowList: _rowList,
				pageNo: 0,
				startRowIndex: 0,
				startIndex: 0,
				startX: startX,
				startY: startY,
				innerWidth: innerWidth,
				zone: EditorZone.header,
			),
		);
	}

	double getHeaderTop() {
		final IHeader header = _resolveHeader();
		if (header.disabled == true) {
			return 0;
		}
		final double top = (header.top ?? 0).toDouble();
		final double scale = (_options.scale ?? 1).toDouble();
		return (top * scale).floorToDouble();
	}

	double getMaxHeight() {
		final IHeader header = _resolveHeader();
		final MaxHeightRatio ratio = header.maxHeightRadio ?? MaxHeightRatio.quarter;
		final double mapping = maxHeightRadioMapping[ratio] ?? 0;
		final double height = _draw.getHeight();
		return math.min(height, height * mapping).floorToDouble();
	}

	double getHeight() {
		final IHeader header = _resolveHeader();
		if (header.disabled == true) {
			return 0;
		}
		final double maxHeight = getMaxHeight();
		final double rowHeight = getRowHeight();
		return rowHeight > maxHeight ? maxHeight : rowHeight;
	}

	double getRowHeight() {
		double total = 0;
		for (final IRow row in _rowList) {
			total += row.height;
		}
		return total;
	}

	double getExtraHeight() {
		final List<double> margins = _draw.getMargins();
		final double headerHeight = getHeight();
		final double headerTop = getHeaderTop();
		final double extraHeight = headerTop + headerHeight - margins[0];
		return extraHeight <= 0 ? 0 : extraHeight;
	}

	void render(CanvasRenderingContext2D ctx, int pageNo) {
		ctx.save();
		final IHeader header = _resolveHeader();
		ctx.globalAlpha = _zone.isHeaderActive() ? 1 : (header.inactiveAlpha ?? 1);
		final double innerWidth = _draw.getInnerWidth();
		final double maxHeight = getMaxHeight();
		final List<IRow> renderRows = <IRow>[];
		double curHeight = 0;
		for (final IRow row in _rowList) {
			if (curHeight + row.height > maxHeight) {
				break;
			}
			renderRows.add(row);
			curHeight += row.height;
		}
		_drawDynamic((dynamic target) {
			target.drawRow(
				ctx,
				IDrawRowPayload(
					elementList: _elementList,
					positionList: _positionList,
					rowList: renderRows,
					pageNo: pageNo,
					startIndex: 0,
					innerWidth: innerWidth,
					zone: EditorZone.header,
				),
			);
			return null;
		});
		ctx.restore();
	}

	IHeader _resolveHeader() {
		final IHeader header = _options.header ??= IHeader();
		header.disabled ??= false;
		header.top ??= 0;
		header.inactiveAlpha ??= 0.6;
		header.maxHeightRadio ??= MaxHeightRatio.quarter;
		return header;
	}
}
