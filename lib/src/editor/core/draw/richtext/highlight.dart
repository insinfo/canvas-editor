import 'dart:html';

import '../../../interface/editor.dart';
import '../draw.dart';
import 'abstract_rich_text.dart';

class Highlight extends AbstractRichText {
	Highlight(Draw draw)
			: _options = draw.getOptions();

	final IEditorOption _options;

	@override
	void render(CanvasRenderingContext2D ctx) {
		if (fillRect.width <= 0) {
			return;
		}
		final double alpha = (_options.highlightAlpha ?? 1).toDouble();
		final String color = fillColor ?? '#FFFF00';
		ctx.save();
		ctx.globalAlpha = alpha;
		ctx.fillStyle = color;
		ctx.fillRect(fillRect.x, fillRect.y, fillRect.width, fillRect.height);
		ctx.restore();
		clearFillInfo();
	}
}