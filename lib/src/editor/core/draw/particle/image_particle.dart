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

		final String cacheKey = element.value;
		final ImageElement? cached = _imageCache[cacheKey];
		if (cached != null) {
			ctx.drawImageScaled(cached, x, y, width, height);
			return;
		}

		final int renderCountSnapshot = _draw.getRenderCount();
		final Completer<IElement> completer = Completer<IElement>();
		final ImageElement image = ImageElement()
			..crossOrigin = 'Anonymous'
			..src = element.value;

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
				ctx.drawImageScaled(image, x, y, width, height);
			}
		});

		image.onError.first.then((dynamic error) {
			final ImageElement fallback = _buildFallbackImage(width, height);
			fallback.onLoad.first.then((_) {
				ctx.drawImageScaled(fallback, x, y, width, height);
				_imageCache[cacheKey] = fallback;
			});
			if (!completer.isCompleted) {
				completer.completeError(error ?? StateError('image load error'));
			}
		});

		_addImageObserver(completer.future);
	}
}