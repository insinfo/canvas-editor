// NOTE: Translated from C:\\MyTsProjects\\canvas-editor\\src\\editor\\core\\draw\\frame\\Background.ts
import 'dart:html';

import '../../../dataset/enum/background.dart';
import '../../../interface/background.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../draw.dart';

class Background {
	Background(this._draw)
			: _options = _draw.getOptions(),
				_imageCache = <String, ImageElement>{};

	final Draw _draw;
	final IEditorOption _options;
	final Map<String, ImageElement> _imageCache;

	void _renderBackgroundColor(
		CanvasRenderingContext2D ctx,
		String? color,
		double width,
		double height,
	) {
		if (color == null || color.isEmpty) {
			return;
		}
		ctx.save();
		ctx.fillStyle = color;
		ctx.fillRect(0, 0, width, height);
		ctx.restore();
	}

	void _drawImage(
		CanvasRenderingContext2D ctx,
		ImageElement imageElement,
		double width,
		double height,
	) {
		final IBackgroundOption background =
				_options.background ?? IBackgroundOption();
		final double scale = (_options.scale ?? 1).toDouble();
		final int? naturalWidthRaw = imageElement.naturalWidth;
		final int? naturalHeightRaw = imageElement.naturalHeight;
		final int fallbackWidth = naturalWidthRaw ?? imageElement.width ?? 0;
		final int fallbackHeight = naturalHeightRaw ?? imageElement.height ?? 0;
		final double naturalWidth = fallbackWidth.toDouble();
		final double naturalHeight = fallbackHeight.toDouble();
		final double imageWidth = naturalWidth * scale;
		final double imageHeight = naturalHeight * scale;

		final BackgroundRepeat? repeat = background.repeat;
		final bool isRepeatX =
				repeat == BackgroundRepeat.repeat || repeat == BackgroundRepeat.repeatX;
		final bool isRepeatY =
				repeat == BackgroundRepeat.repeat || repeat == BackgroundRepeat.repeatY;

		if (background.size == BackgroundSize.contain) {
			if (repeat == null || repeat == BackgroundRepeat.noRepeat) {
				ctx.drawImageScaled(imageElement, 0, 0, imageWidth, imageHeight);
				return;
			}

			double startX = 0;
			double startY = 0;
			final int repeatXCount = isRepeatX && imageWidth > 0
					? ((width * scale) / imageWidth).ceil()
					: 1;
			final int repeatYCount = isRepeatY && imageHeight > 0
					? ((height * scale) / imageHeight).ceil()
					: 1;

			for (int x = 0; x < repeatXCount; x++) {
				for (int y = 0; y < repeatYCount; y++) {
					ctx.drawImageScaled(
						imageElement,
						startX,
						startY,
						imageWidth,
						imageHeight,
					);
					startY += imageHeight;
				}
				startY = 0;
				startX += imageWidth;
			}
			return;
		}

		ctx.drawImageScaled(imageElement, 0, 0, width * scale, height * scale);
	}

	void _renderBackgroundImage(
		CanvasRenderingContext2D ctx,
		double width,
		double height,
	) {
		final IBackgroundOption background =
				_options.background ?? IBackgroundOption();
		final String? image = background.image;
		if (image == null || image.isEmpty) {
			return;
		}

		final ImageElement? cachedImage = _imageCache[image];
		if (cachedImage != null) {
			if (cachedImage.complete == true) {
				_drawImage(ctx, cachedImage, width, height);
			}
			return;
		}

		final ImageElement img = ImageElement()
			..crossOrigin = 'Anonymous'
			..src = image;

		img.onLoad.first.then((_) {
			_imageCache[image] = img;
			_drawImage(ctx, img, width, height);
			_draw.render(IDrawOption(isCompute: false, isSubmitHistory: false));
		});
	}

	void render(CanvasRenderingContext2D ctx, int pageNo) {
		final IBackgroundOption? background = _options.background;
		if (background == null) {
			return;
		}

		final List<int>? applyPageNumbers = background.applyPageNumbers;
		final String? image = background.image;

		final bool shouldUseImage = image != null && image.isNotEmpty &&
				(applyPageNumbers == null ||
						applyPageNumbers.isEmpty ||
						applyPageNumbers.contains(pageNo));

		if (shouldUseImage) {
			final double width = _options.width ?? _draw.getWidth();
			final double height = _options.height ?? _draw.getHeight();
			_renderBackgroundImage(ctx, width, height);
			return;
		}

		final double width = _draw.getCanvasWidth(pageNo);
		final double height = _draw.getCanvasHeight(pageNo);
		_renderBackgroundColor(ctx, background.color, width, height);
	}
}