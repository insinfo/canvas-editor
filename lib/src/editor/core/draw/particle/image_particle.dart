import 'dart:async';
import 'dart:html';

import '../../../dataset/constant/editor.dart';
import '../../../dataset/enum/common.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/table/td.dart';
import '../../../utils/index.dart';
import '../draw.dart';
import '../../observer/image_observer.dart';

class ImageParticle {
	ImageParticle(this._draw)
			: _options = _draw.getOptions(),
				_container = _draw.getContainer(),
				_imageCache = <String, ImageElement>{};

	final Draw _draw;
	final IEditorOption _options;
	final DivElement _container;
	final Map<String, ImageElement> _imageCache;

	IEditorOption get options => _options;
	Map<String, ImageElement> get imageCache => _imageCache;
	void registerImageObserver(Future<dynamic> future) => _addImageObserver(future);

	DivElement? _floatImageContainer;
	ImageElement? _floatImage;

	double _scale() => (_options.scale ?? 1).toDouble();

	List<IElement> getOriginalMainImageList() {
		final List<IElement> imageList = <IElement>[];

		void collect(List<IElement>? elements) {
			if (elements == null || elements.isEmpty) {
				return;
			}
			for (final IElement element in elements) {
				if (element.type == ElementType.table) {
					final List<ITr>? trList = element.trList;
					if (trList == null) {
						continue;
					}
					for (final ITr tr in trList) {
						for (final ITd td in tr.tdList) {
							collect(td.value);
						}
					}
				} else if (element.type == ElementType.image) {
					imageList.add(element);
				}
			}
		}

		collect(_draw.getOriginalMainElementList());
		return imageList;
	}

	void createFloatImage(IElement element) {
		final Map<String, num>? floatPosition = element.imgFloatPosition;
		if (floatPosition == null) {
			return;
		}
		final double scale = _scale();
		DivElement? container = _floatImageContainer;
		ImageElement? img = _floatImage;
		if (container == null) {
			container = DivElement()
				..classes.add('$editorPrefix-float-image');
			_container.append(container);
			_floatImageContainer = container;
		}
		if (img == null) {
			img = ImageElement();
			container.append(img);
			_floatImage = img;
		}

		container.style.display = 'none';
		img
			..style.width = '${(element.width ?? 0) * scale}px'
			..style.height = '${(element.height ?? 0) * scale}px'
			..src = element.value;

		final double height = _draw.getHeight();
		final double pageGap = _draw.getPageGap();
		final double preY = _draw.getPageNo() * (height + pageGap);
		container
			..style.left = '${(floatPosition['x'] ?? 0) * scale}px'
			..style.top = '${preY + (floatPosition['y'] ?? 0) * scale}px';
	}

	void dragFloatImage(double movementX, double movementY) {
		final DivElement? container = _floatImageContainer;
		if (container == null) {
			return;
		}
		container.style.display = 'block';
		final double previousX = double.tryParse(container.style.left) ?? 0;
		final double previousY = double.tryParse(container.style.top) ?? 0;
		container
			..style.left = '${previousX + movementX}px'
			..style.top = '${previousY + movementY}px';
	}

	void destroyFloatImage() {
		_floatImageContainer?.style.display = 'none';
	}

	void _addImageObserver(Future<dynamic> future) {
		final dynamic observer = _draw.getImageObserver();
		if (observer is ImageObserver) {
			observer.add(future);
			return;
		}
		try {
			observer?.add(future);
		} catch (_) {
			// Observer not attached yet; ignore.
		}
	}

	ImageElement _buildFallbackImage(double width, double height) {
		const int tileSize = 8;
		final double safeWidth = width <= 0 ? tileSize.toDouble() : width;
		final double safeHeight = height <= 0 ? tileSize.toDouble() : height;
		final double tilesX = (safeWidth / tileSize).ceilToDouble();
		final double tilesY = (safeHeight / tileSize).ceilToDouble();
		final double offsetX = (safeWidth - tilesX * tileSize) / 2;
		final double offsetY = (safeHeight - tilesY * tileSize) / 2;

		final String svg = '<svg xmlns="http://www.w3.org/2000/svg" width="${safeWidth.toStringAsFixed(0)}" height="${safeHeight.toStringAsFixed(0)}" viewBox="0 0 ${safeWidth.toStringAsFixed(0)} ${safeHeight.toStringAsFixed(0)}">'
				'<rect width="${safeWidth.toStringAsFixed(0)}" height="${safeHeight.toStringAsFixed(0)}" fill="url(#mosaic)" />'
				'<defs>'
				'<pattern id="mosaic" x="${offsetX.toStringAsFixed(2)}" y="${offsetY.toStringAsFixed(2)}" width="${(tileSize * 2).toString()}" height="${(tileSize * 2).toString()}" patternUnits="userSpaceOnUse">'
				'<rect width="$tileSize" height="$tileSize" fill="#cccccc" />'
				'<rect width="$tileSize" height="$tileSize" fill="#cccccc" transform="translate($tileSize, $tileSize)" />'
				'</pattern>'
				'</defs>'
				'</svg>';

		final ImageElement fallback = ImageElement();
		fallback.src = 'data:image/svg+xml;base64,${convertStringToBase64(svg)}';
		return fallback;
	}

	void _drawImageWithCrop(
		CanvasRenderingContext2D ctx,
		ImageElement image,
		IElement element,
		double x,
		double y,
		double width,
		double height,
	) {
		final IImageCrop? crop = element.imgCrop;
		if (crop == null) {
			ctx.drawImageScaled(image, x, y, width, height);
			return;
		}
		ctx.drawImageScaledFromSource(
			image,
			crop.x.toDouble(),
			crop.y.toDouble(),
			crop.width.toDouble(),
			crop.height.toDouble(),
			x,
			y,
			width,
			height,
		);
	}

	int _countImagesBeforeTarget(List<IElement> imageList, IElement target) {
		for (var index = 0; index < imageList.length; index += 1) {
			if (identical(imageList[index], target)) {
				return index;
			}
		}
		return imageList.indexOf(target);
	}

	void _renderCaption(
		CanvasRenderingContext2D ctx,
		IElement element,
		double x,
		double y,
		double width,
		double height,
	) {
		final IImageCaption? caption = element.imgCaption;
		if (caption == null || caption.value.isEmpty) {
			return;
		}
		final double scale = _scale();
		final IImgCaptionOption option =
				options.imgCaption ?? const IImgCaptionOption();
		String captionText = caption.value;
		if (captionText.contains('{imageNo}')) {
			final imageNo =
					_countImagesBeforeTarget(getOriginalMainImageList(), element) + 1;
			captionText = captionText.replaceAll('{imageNo}', '$imageNo');
		}
		final double fontSize =
				(caption.size ?? option.size ?? 12).toDouble() * scale;
		final String fontFamily = caption.font ?? option.font ?? 'Microsoft YaHei';
		final String color = caption.color ?? option.color ?? '#666666';
		ctx.save();
		ctx
			..font = '${fontSize}px $fontFamily'
			..fillStyle = color
			..textAlign = 'center';

		String displayText = captionText;
		final TextMetrics fullMetrics = ctx.measureText(captionText);
		if ((fullMetrics.width ?? 0) > width) {
			var left = 0;
			var right = captionText.length;
			while (left < right) {
				final mid = ((left + right + 1) / 2).floor();
				final String truncated = captionText.substring(0, mid);
				if ((ctx.measureText('$truncated...').width ?? 0) <= width) {
					left = mid;
				} else {
					right = mid - 1;
				}
			}
			displayText = '${captionText.substring(0, left)}...';
		}
		final TextMetrics displayMetrics = ctx.measureText(displayText);
		final double captionTop =
				(caption.top ?? option.top ?? 5).toDouble() * scale;
		final double ascent = displayMetrics.actualBoundingBoxAscent == null ||
				displayMetrics.actualBoundingBoxAscent!.isNaN
			? fontSize
			: displayMetrics.actualBoundingBoxAscent!.toDouble();
		final double captionY = y + height + captionTop + ascent;
		final double captionX = x + width / 2;
		ctx.fillText(displayText, captionX, captionY);
		ctx.restore();
	}

	String _normalizeImageSource(String rawSource) {
		final String trimmed = rawSource.trim();
		if (!trimmed.startsWith('data:image/')) {
			return trimmed;
		}

		final int commaIndex = trimmed.indexOf(',');
		if (commaIndex == -1) {
			return trimmed.replaceAll(RegExp(r'\s+'), '');
		}

		final String header = trimmed.substring(0, commaIndex).replaceAll(RegExp(r'\s+'), '');
		final String payload = trimmed.substring(commaIndex + 1).replaceAll(RegExp(r'\s+'), '');
		return '$header,$payload';
	}

	void render(
		CanvasRenderingContext2D ctx,
		IElement element,
		double x,
		double y,
	) {
		final double scale = _scale();
		final double width = (element.width ?? 0) * scale;
		final double height = (element.height ?? 0) * scale;
		if (width <= 0 || height <= 0) {
			return;
		}

		final String source = _normalizeImageSource(element.value);
		final String cacheKey = source;
		final ImageElement? cached = _imageCache[cacheKey];
		if (cached != null) {
			_drawImageWithCrop(ctx, cached, element, x, y, width, height);
			_renderCaption(ctx, element, x, y, width, height);
			return;
		}

		final int renderCountSnapshot = _draw.getRenderCount();
		final Completer<IElement> completer = Completer<IElement>();
		final ImageElement image = ImageElement()
			..crossOrigin = 'Anonymous'
			..src = source;

		image.onLoad.first.then((_) {
			_imageCache[cacheKey] = image;
			if (!completer.isCompleted) {
				completer.complete(element);
			}
			if (renderCountSnapshot != _draw.getRenderCount()) {
				return;
			}
			if (element.imgDisplay == ImageDisplay.floatBottom) {
				_draw.render(
					IDrawOption(
						isCompute: false,
						isSetCursor: false,
						isSubmitHistory: false,
					),
				);
			} else {
				_drawImageWithCrop(ctx, image, element, x, y, width, height);
				_renderCaption(ctx, element, x, y, width, height);
			}
		});

		image.onError.first.then((dynamic error) {
			final ImageElement fallback = _buildFallbackImage(width, height);
			fallback.onLoad.first.then((_) {
				_drawImageWithCrop(ctx, fallback, element, x, y, width, height);
				_renderCaption(ctx, element, x, y, width, height);
				_imageCache[cacheKey] = fallback;
				if (!completer.isCompleted) {
					completer.complete(element);
				}
			});
			fallback.onError.first.then((dynamic fallbackError) {
				if (!completer.isCompleted) {
					completer.completeError(
						fallbackError ?? error ?? StateError('image load error'),
					);
				}
			});
		});

		_addImageObserver(completer.future);
	}
}