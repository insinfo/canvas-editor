import 'dart:html';

import '../../../dataset/enum/line_number.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/line_number.dart';
import '../../../interface/row.dart';
import '../../../interface/text.dart';
import '../draw.dart';

class LineNumber {
	LineNumber(this._draw) : _options = _draw.getOptions();

	final Draw _draw;
	final IEditorOption _options;

	dynamic _drawDynamic<T>(T Function(dynamic target) callback) {
		try {
			return callback(_draw as dynamic);
		} catch (_) {
			return null;
		}
	}

	void render(CanvasRenderingContext2D ctx, int pageNo) {
		final ILineNumberOption? lineNumberOption = _options.lineNumber;
		if (lineNumberOption == null) {
			return;
		}
		final LineNumberType? type = lineNumberOption.type;
		if (type == null || lineNumberOption.disabled == true) {
			return;
		}

		final double scale = (_options.scale ?? 1).toDouble();
		final String color = lineNumberOption.color ?? '#606266';
		final double size = (lineNumberOption.size ?? 12).toDouble();
		final String font = lineNumberOption.font ?? 'sans-serif';
		final double right = (lineNumberOption.right ?? 8).toDouble();

		final dynamic textParticle = _drawDynamic((dynamic target) {
			try {
				return target.getTextParticle();
			} catch (_) {
				return null;
			}
		});
		if (textParticle == null) {
			return;
		}

		final List<double> margins = _draw.getMargins();
		final dynamic positionManager = _draw.getPosition();
		final List<IElementPosition> positionList =
				(positionManager?.getOriginalMainPositionList() as List<dynamic>? ??
								const <dynamic>[])
						.whereType<IElementPosition>()
						.toList();
		final dynamic pageRowListDynamic =
			_drawDynamic((dynamic target) => target.getPageRowList());
		if (pageRowListDynamic is! List ||
			pageNo < 0 ||
			pageNo >= pageRowListDynamic.length) {
			return;
		}
		final List<IRow> rowList =
			(pageRowListDynamic[pageNo] as List<dynamic>? ?? const <dynamic>[])
				.whereType<IRow>()
				.toList();

		ctx.save();
		ctx.fillStyle = color;
		ctx.font = '${size * scale}px ${font}';

			for (int i = 0; i < rowList.length; i++) {
				final IRow row = rowList[i];
				final int startIndex = row.startIndex;
				if (startIndex < 0 || startIndex >= positionList.length) {
				continue;
			}
			final IElementPosition position = positionList[startIndex];
				final List<double> leftBottom = List<double>.from(
					position.coordinate['leftBottom'] ?? const <double>[],
				);
				final List<double> leftTop = List<double>.from(
					position.coordinate['leftTop'] ?? const <double>[],
				);
				final List<double> rightTop = List<double>.from(
					position.coordinate['rightTop'] ?? const <double>[],
				);
				if (leftBottom.length < 2 || leftTop.length < 2 || rightTop.length < 2) {
				continue;
			}
				final int seq =
						type == LineNumberType.page ? i + 1 : row.rowIndex + 1;
			final IElement numberElement = IElement(value: '$seq');
			final dynamic metricsResult = textParticle.measureText(ctx, numberElement);
			final ITextMetrics? metrics = metricsResult is ITextMetrics
					? metricsResult
					: (metricsResult as ITextMetrics?);
			if (metrics == null) {
				continue;
			}
			final double textWidth = metrics.width;
			final double x = margins[3] - (textWidth + right) * scale;
			  final double y =
				  leftBottom[1] - metrics.actualBoundingBoxAscent * scale;
			ctx.fillText('$seq', x, y);
		}

		ctx.restore();
	}
}
