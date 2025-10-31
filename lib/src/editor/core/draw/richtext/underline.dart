import 'dart:html';
import 'dart:math' as math;

import '../../../dataset/enum/text.dart';
import '../../../interface/editor.dart';
import '../draw.dart';
import 'abstract_rich_text.dart';

class Underline extends AbstractRichText {
	Underline(Draw draw)
			: _options = draw.getOptions();

	final IEditorOption _options;

	void _drawLine(
		CanvasRenderingContext2D ctx,
		double startX,
		double startY,
		double width, [
		DashType? dashType,
	]) {
		switch (dashType) {
			case DashType.dashed:
				ctx.setLineDash(<double>[3, 1]);
				break;
			case DashType.dotted:
				ctx.setLineDash(<double>[1, 1]);
				break;
			default:
				ctx.setLineDash(<double>[]);
				break;
		}
		ctx
			..beginPath()
			..moveTo(startX, startY)
			..lineTo(startX + width, startY)
			..stroke();
	}

	void _drawDouble(
		CanvasRenderingContext2D ctx,
		double startX,
		double startY,
		double width,
	) {
		const double spacing = 3;
		final double scale = (_options.scale ?? 1).toDouble();
		final double endX = startX + width;
		final double endY = startY + spacing * scale;
		ctx
			..setLineDash(<double>[])
			..beginPath()
			..moveTo(startX, startY)
			..lineTo(endX, startY)
			..stroke()
			..beginPath()
			..moveTo(startX, endY)
			..lineTo(endX, endY)
			..stroke();
	}

	void _drawWave(
		CanvasRenderingContext2D ctx,
		double startX,
		double startY,
		double width,
	) {
		final double scale = (_options.scale ?? 1).toDouble();
		final double amplitude = 1.2 * scale;
		final double frequency = scale == 0 ? 0 : 1 / scale;
		final double adjustY = startY + 2 * amplitude;
		ctx
			..setLineDash(<double>[])
			..beginPath();
			for (double dx = 0; dx < width; dx += 1) {
				final double dy = amplitude * math.sin(frequency * dx);
			ctx.lineTo(startX + dx, adjustY + dy);
		}
		ctx.stroke();
	}

	@override
	void render(CanvasRenderingContext2D ctx) {
		if (fillRect.width <= 0) {
			return;
		}
		final double scale = (_options.scale ?? 1).toDouble();
		final double lineWidth = scale <= 0 ? 1 : scale;
		final String strokeColor = fillColor ?? _options.underlineColor ?? '#000000';
		final double adjustY = (fillRect.y + 2 * lineWidth).floorToDouble() + 0.5;
		ctx.save();
		ctx
			..strokeStyle = strokeColor
			..lineWidth = lineWidth;
		switch (fillDecorationStyle) {
			case TextDecorationStyle.wavy:
				_drawWave(ctx, fillRect.x, adjustY, fillRect.width);
				break;
			case TextDecorationStyle.double_:
				_drawDouble(ctx, fillRect.x, adjustY, fillRect.width);
				break;
			case TextDecorationStyle.dashed:
				_drawLine(ctx, fillRect.x, adjustY, fillRect.width, DashType.dashed);
				break;
			case TextDecorationStyle.dotted:
				_drawLine(ctx, fillRect.x, adjustY, fillRect.width, DashType.dotted);
				break;
			default:
				_drawLine(ctx, fillRect.x, adjustY, fillRect.width);
				break;
		}
		ctx.restore();
		clearFillInfo();
	}
}