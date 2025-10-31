// Ported from C:\\MyTsProjects\\canvas-editor\\src\\editor\\core\\draw\\particle\\RadioParticle.ts
import 'dart:html';
import 'dart:math' as math;

import '../../../dataset/constant/common.dart';
import '../../../dataset/enum/vertical_align.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/row.dart';
import '../draw.dart';

class RadioRenderPayload {
	RadioRenderPayload({
		required this.ctx,
		required this.x,
		required this.y,
		required this.row,
		required this.index,
	});

	final CanvasRenderingContext2D ctx;
	final double x;
	final double y;
	final IRow row;
	final int index;
}

class RadioParticle {
	RadioParticle(this._draw) : _options = _draw.getOptions();

	final Draw _draw;
	final IEditorOption _options;

	void setSelect(IElement element) {
		final IRadio? radio = element.radio;
		if (radio != null) {
			radio.value = !(radio.value ?? false);
		} else {
			element.radio = IRadio(value: true);
		}
		_draw.render(
			IDrawOption(
				isCompute: false,
				isSetCursor: false,
			),
		);
	}

	void render(RadioRenderPayload payload) {
		final CanvasRenderingContext2D ctx = payload.ctx;
		double y = payload.y;
		final double x = payload.x;
		final IRow row = payload.row;
		final int index = payload.index;
		if (index < 0 || index >= row.elementList.length) {
			return;
		}
		final IRowElement element = row.elementList[index];
		final IElementMetrics metrics = element.metrics;
		final double scale = (_options.scale ?? 1).toDouble();
		final double gap = (_options.radio?.gap ?? 5).toDouble();
		final double lineWidth = (_options.radio?.lineWidth ?? 1).toDouble();
		final String fillStyle = _options.radio?.fillStyle ?? '#5175f4';
		final String strokeStyle = _options.radio?.strokeStyle ?? '#000000';
		final VerticalAlign verticalAlign =
			_options.radio?.verticalAlign ?? VerticalAlign.bottom;
		final bool isTopAlign = verticalAlign == VerticalAlign.top;
		final bool isMiddleAlign = verticalAlign == VerticalAlign.middle;
		if (isTopAlign || isMiddleAlign) {
			IRowElement? nextElement;
			int nextIndex = index + 1;
			while (nextIndex < row.elementList.length) {
				final IRowElement candidate = row.elementList[nextIndex];
				if (candidate.value != ZERO && candidate.value != NBSP) {
					nextElement = candidate;
					break;
				}
				nextIndex += 1;
			}
			if (nextElement != null) {
				final IElementMetrics nextMetrics = nextElement.metrics;
				final double textHeight =
					nextMetrics.boundingBoxAscent + nextMetrics.boundingBoxDescent;
				if (textHeight > metrics.height) {
					if (isTopAlign) {
						y -= nextMetrics.boundingBoxAscent - metrics.height;
					} else {
						y -= (textHeight - metrics.height) / 2;
					}
				}
			}
		}
		final double left = (x + gap * scale).roundToDouble();
		final double top = (y - metrics.height + lineWidth).roundToDouble();
		final double width = metrics.width - gap * 2 * scale;
		final double height = metrics.height;
		ctx.save();
		ctx.beginPath();
		ctx.translate(0.5, 0.5);
		ctx.strokeStyle = (element.radio?.value ?? false) ? fillStyle : strokeStyle;
		ctx.lineWidth = lineWidth;
		final double centerX = left + width / 2;
		final double centerY = top + height / 2;
		final double radius = width / 2;
		ctx.arc(centerX, centerY, radius, 0, math.pi * 2);
		ctx.stroke();
		if (element.radio?.value == true) {
			ctx.beginPath();
			ctx.fillStyle = fillStyle;
			ctx.arc(centerX, centerY, radius / 1.5, 0, math.pi * 2);
			ctx.fill();
		}
		ctx.closePath();
		ctx.restore();
	}
}