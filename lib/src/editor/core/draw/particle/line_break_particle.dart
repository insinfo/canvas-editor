// Ported from C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\LineBreakParticle.ts
import 'dart:html';

import '../../../interface/editor.dart';
import '../../../interface/row.dart';
import '../draw.dart';

class LineBreakParticle {
	LineBreakParticle(Draw draw) : _options = draw.getOptions();

	static const double width = 12;
	static const double height = 9;
	static const double gap = 3;

	final IEditorOption _options;

	void render(
		CanvasRenderingContext2D ctx,
		IRowElement element,
		double x,
		double y,
	) {
		final double scale = (_options.scale ?? 1).toDouble();
		final double lineWidth = (_options.lineBreak?.lineWidth ?? 1).toDouble();
		final String color = _options.lineBreak?.color ?? '#000000';
		ctx.save();
		ctx.beginPath();
		final double top = y - (height * scale) / 2;
		final double left = x + element.metrics.width;
		ctx.translate(left, top);
		ctx.scale(scale, scale);
		ctx.strokeStyle = color;
		ctx.lineWidth = lineWidth;
		ctx.lineCap = 'round';
		ctx.lineJoin = 'round';
		ctx.moveTo(8, 0);
		ctx.lineTo(12, 0);
		ctx.lineTo(12, 6);
		ctx.lineTo(3, 6);
		ctx.moveTo(3, 6);
		ctx.lineTo(6, 3);
		ctx.moveTo(3, 6);
		ctx.lineTo(6, 9);
		ctx.stroke();
		ctx.closePath();
		ctx.restore();
	}
}