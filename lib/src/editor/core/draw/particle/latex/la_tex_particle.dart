import 'dart:async';
import 'dart:html';

import '../../../../interface/element.dart';
import '../image_particle.dart';
import 'utils/la_tex_utils.dart';

class LaTexParticle extends ImageParticle {
	LaTexParticle(super.draw);

	static LaTexSvg convertLaTextToSVG(String laTex) {
		return LaTexUtils(laTex).svg(
			const ExportOpt(
				scaleX: 10,
				scaleY: 10,
				marginX: 0,
				marginY: 0,
			),
		);
	}

	@override
	void render(
		CanvasRenderingContext2D ctx,
		IElement element,
		double x,
		double y,
	) {
		final double scale = (options.scale ?? 1).toDouble();
		final double width = (element.width ?? 0) * scale;
		final double height = (element.height ?? 0) * scale;
		final String? svgData = element.laTexSVG;

		if (width <= 0 || height <= 0 || svgData == null || svgData.isEmpty) {
			return;
		}

		final String cacheKey = element.value;
		final ImageElement? cached = imageCache[cacheKey];
		if (cached != null) {
			ctx.drawImageScaled(cached, x, y, width, height);
			return;
		}

		final Completer<IElement> completer = Completer<IElement>();
		final ImageElement img = ImageElement()..src = svgData;

		img.onLoad.first.then((_) {
			imageCache[cacheKey] = img;
			ctx.drawImageScaled(img, x, y, width, height);
			if (!completer.isCompleted) {
				completer.complete(element);
			}
		});

		img.onError.first.then((dynamic error) {
			if (!completer.isCompleted) {
				completer.completeError(error ?? StateError('latex image load error'));
			}
		});

		registerImageObserver(completer.future);
	}
}