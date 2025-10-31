import 'dart:html';

import '../../../dataset/enum/text.dart';
import '../../../interface/element.dart';

abstract class AbstractRichText {
	AbstractRichText() : fillRect = IElementFillRect(x: 0, y: 0, width: 0, height: 0);

	IElementFillRect fillRect;
	String? fillColor;
	TextDecorationStyle? fillDecorationStyle;

	IElementFillRect clearFillInfo() {
		fillColor = null;
		fillDecorationStyle = null;
		fillRect = IElementFillRect(x: 0, y: 0, width: 0, height: 0);
		return fillRect;
	}

	void recordFillInfo(
		CanvasRenderingContext2D ctx,
		double x,
		double y,
		double width, [
		double? height,
		String? color,
		TextDecorationStyle? decorationStyle,
	]) {
		final bool isFirstRecord = fillRect.width == 0;
		if (!isFirstRecord && (fillColor != color || fillDecorationStyle != decorationStyle)) {
			render(ctx);
			clearFillInfo();
			recordFillInfo(ctx, x, y, width, height, color, decorationStyle);
			return;
		}
		if (isFirstRecord) {
			fillRect
				..x = x
				..y = y;
		}
		if (height != null && fillRect.height < height) {
			fillRect.height = height;
		}
		fillRect.width += width;
		fillColor = color;
		fillDecorationStyle = decorationStyle;
	}

	void render(CanvasRenderingContext2D ctx);
}