import 'dart:html';

import '../../../dataset/constant/placeholder.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/placeholder.dart';
import '../../../interface/position.dart';
import '../../../interface/row.dart';
import '../../../utils/element.dart' as element_utils;
import '../../position/position.dart';
import '../draw.dart';
import '../particle/line_break_particle.dart';

class PlaceholderRenderOption {
	PlaceholderRenderOption({this.placeholder, this.startY});

	IPlaceholder? placeholder;
	double? startY;
}

class Placeholder {
	Placeholder(Draw draw)
			: _draw = draw,
				_position = draw.getPosition() as Position,
				_options = draw.getOptions(),
				_elementList = <IElement>[],
				_rowList = <IRow>[],
				_positionList = <IElementPosition>[];

	final Draw _draw;
	final Position _position;
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

	void _recovery() {
		_elementList = <IElement>[];
		_rowList = <IRow>[];
		_positionList = <IElementPosition>[];
	}

	void _compute(PlaceholderRenderOption? options) {
		_computeRowList();
		_computePositionList(options);
	}

	void _computeRowList() {
		final double innerWidth = _draw.getInnerWidth();
			final List<IRow> rows = _drawDynamic((dynamic target) {
					final dynamic result = target.computeRowList(
						IComputeRowListPayload(
							innerWidth: innerWidth,
							elementList: _elementList,
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

	void _computePositionList(PlaceholderRenderOption? options) {
		final double scale = (_options.scale ?? 1).toDouble();
		final double headerExtraHeight = _resolveHeaderExtraHeight();
		final double innerWidth = _draw.getInnerWidth();
		final List<double> margins = _draw.getMargins();
		double startX = margins[3];
		final bool isLineBreakEnabled = _options.lineBreak?.disabled != true;
		if (isLineBreakEnabled) {
			startX += (LineBreakParticle.width + LineBreakParticle.gap) * scale;
		}
		final double startY = options?.startY ?? (margins[0] + headerExtraHeight);
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
			),
		);
	}

	double _resolveHeaderExtraHeight() {
		try {
			final dynamic header = (_draw as dynamic).getHeader();
			final dynamic extra = header?.getExtraHeight();
			if (extra is num) {
				return extra.toDouble();
			}
		} catch (_) {}
		return 0;
	}

	void render(CanvasRenderingContext2D ctx, [PlaceholderRenderOption? options]) {
		final PlaceholderRenderOption resolved = options ?? PlaceholderRenderOption();
		final IPlaceholder placeholder = resolved.placeholder ??
				_options.placeholder ??
				defaultPlaceholderOption;

		_recovery();
		_elementList = <IElement>[
			IElement(
				value: placeholder.data,
				font: placeholder.font,
				size: placeholder.size?.round(),
				color: placeholder.color,
			),
		];
			element_utils.formatElementList(
				_elementList,
				element_utils.FormatElementListOption(
					editorOptions: _options,
					isForceCompensation: true,
				),
			);

		_compute(options);

		final double innerWidth = _draw.getInnerWidth();
		ctx.save();
		ctx.globalAlpha = placeholder.opacity ?? 1;
		_drawDynamic((dynamic target) {
			target.drawRow(
				ctx,
				IDrawRowPayload(
					elementList: _elementList,
					positionList: _positionList,
					rowList: _rowList,
					pageNo: 0,
					startIndex: 0,
					innerWidth: innerWidth,
					isDrawLineBreak: false,
				),
			);
			return null;
		});
		ctx.restore();
	}
}
