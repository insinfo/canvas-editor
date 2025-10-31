// Ported from C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\SeparatorParticle.ts
import 'dart:html';

import '../../../interface/editor.dart';
import '../../../interface/row.dart';
import '../draw.dart';

class SeparatorParticle {
	SeparatorParticle(Draw draw) : _options = draw.getOptions();

	final IEditorOption _options;

	void render(
		CanvasRenderingContext2D ctx,
		IRowElement element,
		double x,
		double y,
	) {
		ctx.save();
		final double scale = (_options.scale ?? 1).toDouble();
		final double lineWidth = (_options.separator?.lineWidth ?? 1).toDouble();
		final String strokeStyle =
			_options.separator?.strokeStyle ?? '#000000';
		ctx.lineWidth = lineWidth * scale;
		ctx.strokeStyle = element.color ?? strokeStyle;
		final List<double>? dashArray = element.dashArray;
		if (dashArray != null && dashArray.isNotEmpty) {
			ctx.setLineDash(dashArray);
		}
		final double offsetY = y.roundToDouble();
		ctx.translate(0, ctx.lineWidth / 2);
		ctx.beginPath();
		ctx.moveTo(x, offsetY);
		final double width = (element.width ?? 0) * scale;
		ctx.lineTo(x + width, offsetY);
		ctx.stroke();
		ctx.restore();
	}
}
// TODO: Translate from C:\\MyTsProjects\\canvas-editor\\src\\editor\\core\\draw\\particle\\SeparatorParticle.ts