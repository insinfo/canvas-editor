import 'dart:html';
import '../../../dataset/constant/common.dart';
import '../../../dataset/enum/vertical_align.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/row.dart';
import '../draw.dart';

class CheckboxRenderPayload {
	CheckboxRenderPayload({
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

class CheckboxParticle {
	CheckboxParticle(this._draw) : _options = _draw.getOptions();

	final Draw _draw;
	final IEditorOption _options;

	void setSelect(IElement element) {
		final ICheckbox? checkbox = element.checkbox;
		if (checkbox != null) {
			checkbox.value = !(checkbox.value ?? false);
		} else {
			element.checkbox = ICheckbox(value: true);
		}
		_draw.render(
			IDrawOption(
				isCompute: false,
				isSetCursor: false,
			),
		);
	}

	void render(CheckboxRenderPayload payload) {
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
		final double gap = (_options.checkbox?.gap ?? 5).toDouble();
		final double lineWidth = (_options.checkbox?.lineWidth ?? 1).toDouble();
		final String fillStyle = _options.checkbox?.fillStyle ?? '#5175f4';
		final String strokeStyle = _options.checkbox?.strokeStyle ?? '#ffffff';
		final VerticalAlign verticalAlign =
			_options.checkbox?.verticalAlign ?? VerticalAlign.bottom;
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
		ctx.lineWidth = lineWidth;
		ctx.strokeStyle = fillStyle;
		if (element.checkbox?.value == true) {
			ctx.rect(left, top, width, height);
			ctx.stroke();
			ctx.beginPath();
			ctx.fillStyle = fillStyle;
			ctx.fillRect(left, top, width, height);
			ctx.beginPath();
			ctx.strokeStyle = strokeStyle;
			ctx.lineWidth = lineWidth * 2 * scale;
			ctx.moveTo(left + 2 * scale, top + height / 2);
			ctx.lineTo(left + width / 2, top + height - 3 * scale);
			ctx.lineTo(left + width - 2 * scale, top + 3 * scale);
			ctx.stroke();
		} else {
			ctx.rect(left, top, width, height);
			ctx.stroke();
		}
		ctx.closePath();
		ctx.restore();
	}
}
// TODO: Translate from C:\\MyTsProjects\\canvas-editor\\src\\editor\\core\\draw\\particle\\CheckboxParticle.ts