import 'dart:html';

import '../../../interface/editor.dart';
import '../draw.dart';
import 'abstract_rich_text.dart';

class Strikeout extends AbstractRichText {
	Strikeout(Draw draw)
			: _options = draw.getOptions();

	final IEditorOption _options;

	@override
	void render(CanvasRenderingContext2D ctx) {
		if (fillRect.width <= 0) {
			return;
		}
		final double scale = (_options.scale ?? 1).toDouble();
		final double lineWidth = scale <= 0 ? 1 : scale;
		final String strokeColor = fillColor ?? _options.strikeoutColor ?? '#000000';
		final double adjustY = fillRect.y + 0.5;
		ctx.save();
		ctx
			..lineWidth = lineWidth
			..strokeStyle = strokeColor
			..beginPath()
			..moveTo(fillRect.x, adjustY)
			..lineTo(fillRect.x + fillRect.width, adjustY)
			..stroke();
		ctx.restore();
		clearFillInfo();
	}
}