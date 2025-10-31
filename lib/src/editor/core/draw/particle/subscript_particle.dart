import 'dart:html';

import '../../../interface/row.dart';

class SubscriptParticle {
	double getOffsetY(IRowElement element) {
		return element.metrics.height / 2;
	}

	void render(
		CanvasRenderingContext2D ctx,
		IRowElement element,
		double x,
		double y,
	) {
		ctx.save();
		ctx.font = element.style;
		if (element.color != null) {
			ctx.fillStyle = element.color!;
		}
		ctx.fillText(element.value, x, y + getOffsetY(element));
		ctx.restore();
	}
}
