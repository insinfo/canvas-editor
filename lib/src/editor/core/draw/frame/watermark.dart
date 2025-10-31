import 'dart:html';
import 'dart:math' as math;

import '../../../dataset/constant/page_number.dart';
import '../../../dataset/constant/watermark.dart';
import '../../../dataset/enum/common.dart';
import '../../../dataset/enum/watermark.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/watermark.dart';
import '../draw.dart';
import 'page_number.dart';

class Watermark {
	Watermark(this._draw)
			: _options = _draw.getOptions(),
				_imageCache = <String, ImageElement>{};

	final Draw _draw;
	final IEditorOption _options;
	final Map<String, ImageElement> _imageCache;

	IWatermark get _watermarkConfig => _options.watermark ?? defaultWatermarkOption;

	void render(CanvasRenderingContext2D ctx, int pageNo) {
		final IWatermark config = _watermarkConfig;
		if (config.data.isEmpty || config.opacity == 0) {
			return;
		}
		if (config.type == WatermarkType.image) {
			_renderImage(ctx, config);
		} else {
			_renderText(ctx, pageNo, config);
		}
	}

	void _renderText(
		CanvasRenderingContext2D ctx,
		int pageNo,
		IWatermark config,
	) {
		final double scale = (_options.scale ?? 1).toDouble();
		final double opacity = (config.opacity ?? defaultWatermarkOption.opacity)!;
		final String fontFamily = config.font ?? defaultWatermarkOption.font!;
		final double fontSize = (config.size ?? defaultWatermarkOption.size)!.toDouble();
		final String color = config.color ?? defaultWatermarkOption.color!;
		final bool repeat = config.repeat ?? defaultWatermarkOption.repeat!;
		final List<double> gap = config.gap ?? defaultWatermarkOption.gap!;
		final NumberType? numberType = config.numberType;

		String text = config.data;
		final RegExp pageNoReg =
				RegExp(PageNumberFormatPlaceholder.pageNo, caseSensitive: false);
		if (pageNoReg.hasMatch(text)) {
			text = PageNumber.formatNumberPlaceholder(
				text,
				pageNo + 1,
				pageNoReg,
				numberType,
			);
		}
		final RegExp pageCountReg =
				RegExp(PageNumberFormatPlaceholder.pageCount, caseSensitive: false);
		if (pageCountReg.hasMatch(text)) {
			text = PageNumber.formatNumberPlaceholder(
				text,
				_draw.getPageCount(),
				pageCountReg,
				numberType,
			);
		}

		final double docWidth = _draw.getWidth();
		final double docHeight = _draw.getHeight();

		ctx.save();
		ctx.globalAlpha = opacity;
		ctx.font = '${fontSize * scale}px $fontFamily';

		final TextMetrics metrics = ctx.measureText(text);
		final double textWidth = (metrics.width as num).toDouble();
		final double ascent = (metrics.actualBoundingBoxAscent ?? fontSize).toDouble();
		final double descent =
				(metrics.actualBoundingBoxDescent ?? fontSize / 2).toDouble();
		final double textHeight = ascent + descent;

		if (repeat) {
			final double scaledGapX = gap.isNotEmpty ? gap[0] * scale : 0;
			final double scaledGapY = gap.length > 1 ? gap[1] * scale : 0;
			final double diagonalLength =
					math.sqrt(math.pow(textWidth, 2) + math.pow(textHeight, 2));
			final double patternWidth = diagonalLength + 2 * scaledGapX;
			final double patternHeight = diagonalLength + 2 * scaledGapY;
			final double dpr = _draw.getPagePixelRatio();

			final CanvasElement tempCanvas = CanvasElement()
				..width = math.max(1, (patternWidth * dpr).ceil())
				..height = math.max(1, (patternHeight * dpr).ceil());
			tempCanvas.style
				..width = '${patternWidth}px'
				..height = '${patternHeight}px';
			final CanvasRenderingContext2D? tempCtx = tempCanvas.context2D;
			if (tempCtx == null) {
				ctx.restore();
				return;
			}
			tempCtx
				..setTransform(1, 0, 0, 1, 0, 0)
				..scale(dpr, dpr)
				..translate(patternWidth / 2, patternHeight / 2)
				..rotate(-45 * math.pi / 180)
				..translate(-patternWidth / 2, -patternHeight / 2)
				..font = '${fontSize * scale}px $fontFamily'
				..fillStyle = color
				..fillText(
					text,
					(patternWidth - textWidth) / 2,
					(patternHeight - textHeight) / 2 + ascent,
				);

			final CanvasPattern? pattern = ctx.createPattern(tempCanvas, 'repeat');
			if (pattern != null) {
				ctx.fillStyle = pattern;
				ctx.fillRect(0, 0, docWidth, docHeight);
			}
		} else {
			ctx
				..fillStyle = color
				..translate(docWidth / 2, docHeight / 2)
				..rotate(-45 * math.pi / 180)
				..fillText(
					text,
					-textWidth / 2,
					ascent - (fontSize * scale) / 2,
				);
		}

		ctx.restore();
	}

	void _renderImage(CanvasRenderingContext2D ctx, IWatermark config) {
		final double scale = (_options.scale ?? 1).toDouble();
		final double opacity = (config.opacity ?? defaultWatermarkOption.opacity)!;
		final bool repeat = config.repeat ?? defaultWatermarkOption.repeat!;
		final List<double> gap = config.gap ?? defaultWatermarkOption.gap!;
		final double imageWidth = (config.width ?? defaultWatermarkOption.width)!.toDouble() * scale;
		final double imageHeight =
				(config.height ?? defaultWatermarkOption.height)!.toDouble() * scale;
		final double docWidth = _draw.getWidth();
		final double docHeight = _draw.getHeight();
		final String data = config.data;

		if (!_imageCache.containsKey(data)) {
			final ImageElement img = ImageElement()
				..crossOrigin = 'Anonymous'
				..src = data;
			img.onLoad.listen((_) {
				_imageCache[data] = img;
				_draw.render(IDrawOption(isCompute: false, isSubmitHistory: false));
			});
			return;
		}

		ctx.save();
		ctx.globalAlpha = opacity;

		final ImageElement cachedImage = _imageCache[data]!;

		if (repeat) {
			final double scaledGapX = gap.isNotEmpty ? gap[0] * scale : 0;
			final double scaledGapY = gap.length > 1 ? gap[1] * scale : 0;
			final double diagonalLength =
					math.sqrt(math.pow(imageWidth, 2) + math.pow(imageHeight, 2));
			final double patternWidth = diagonalLength + 2 * scaledGapX;
			final double patternHeight = diagonalLength + 2 * scaledGapY;
			final double dpr = _draw.getPagePixelRatio();

			final CanvasElement tempCanvas = CanvasElement()
				..width = math.max(1, (patternWidth * dpr).ceil())
				..height = math.max(1, (patternHeight * dpr).ceil());
			tempCanvas.style
				..width = '${patternWidth}px'
				..height = '${patternHeight}px';
			final CanvasRenderingContext2D? tempCtx = tempCanvas.context2D;
			if (tempCtx != null) {
				tempCtx
					..setTransform(1, 0, 0, 1, 0, 0)
					..scale(dpr, dpr)
					..translate(patternWidth / 2, patternHeight / 2)
					..rotate(-45 * math.pi / 180)
					..translate(-patternWidth / 2, -patternHeight / 2)
					..drawImageScaled(
						cachedImage,
						(patternWidth - imageWidth) / 2,
						(patternHeight - imageHeight) / 2,
						imageWidth,
						imageHeight,
					);
				final CanvasPattern? pattern = ctx.createPattern(tempCanvas, 'repeat');
				if (pattern != null) {
					ctx.fillStyle = pattern;
					ctx.fillRect(0, 0, docWidth, docHeight);
				}
			}
		} else {
			ctx
				..translate(docWidth / 2, docHeight / 2)
				..rotate(-45 * math.pi / 180)
				..drawImageScaled(
					cachedImage,
					-imageWidth / 2,
					-imageHeight / 2,
					imageWidth,
					imageHeight,
				);
		}

		ctx.restore();
	}
}