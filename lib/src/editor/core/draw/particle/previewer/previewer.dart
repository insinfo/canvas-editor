import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

import '../../../../dataset/constant/editor.dart';
import '../../../../dataset/enum/editor.dart';
import '../../../../interface/draw.dart';
import '../../../../interface/editor.dart';
import '../../../../interface/element.dart';
import '../../../../interface/event_bus.dart';
import '../../../../interface/previewer.dart';
import '../../../../utils/index.dart';
import '../../../event/eventbus/event_bus.dart';
import '../../draw.dart';

class Previewer {
	Previewer(this._draw)
			: _container = _draw.getContainer(),
				_options = _draw.getOptions(),
				_eventBus = _draw.getEventBus() as EventBus<EventBusMap>? {
		final IPreviewerCreateResult createResult = _createResizerDom();
		_resizerSelection = createResult.resizerSelection;
		_resizerHandleList = createResult.resizerHandleList;
		_resizerImageContainer = createResult.resizerImageContainer;
		_resizerImage = createResult.resizerImage;
		_resizerSize = createResult.resizerSize;
		_keydownListener = (Event _) => _onKeydown();
	}

	final Draw _draw;
	final DivElement _container;
	final IEditorOption _options;
	final EventBus<EventBusMap>? _eventBus;

	CanvasElement? _canvas;
	IElement? _curElement;
	String _curElementSrc = '';
	IPreviewerDrawOption _previewerDrawOption = IPreviewerDrawOption();
	IElementPosition? _curPosition;
	List<IElement> _imageList = <IElement>[];
	IElement? _curShowElement;
	SpanElement? _imageCount;
	Element? _imagePre;
	Element? _imageNext;

	late final EventListener _keydownListener;
	bool _keydownBound = false;

	late final DivElement _resizerSelection;
	late final List<DivElement> _resizerHandleList;
	late final DivElement _resizerImageContainer;
	late final ImageElement _resizerImage;
	late final SpanElement _resizerSize;
	double _width = 0;
	double _height = 0;
	double _mousedownX = 0;
	double _mousedownY = 0;
	int _curHandleIndex = 0;

	DivElement? _previewerContainer;
	ImageElement? _previewerImage;

	double _scale() => (_options.scale ?? 1).toDouble();

	CanvasElement? _resolveCurrentCanvas() {
		final List<Element> pageList = _draw.getPageList();
		if (pageList.isEmpty) {
			return null;
		}
		int pageIndex = _draw.getPageNo();
		if (pageIndex < 0 || pageIndex >= pageList.length) {
			pageIndex = 0;
		}
		final Element element = pageList[pageIndex];
		return element is CanvasElement ? element : null;
	}

	Map<String, double> _getElementPosition(
		IElement element,
		IElementPosition? position,
	) {
		final double scale = _scale();
		double x = 0;
		double y = 0;
		final double height = _draw.getHeight();
		final double pageGap = _draw.getPageGap();
		final int pageNo = position?.pageNo ?? _draw.getPageNo();
		final double preY = pageNo * (height + pageGap);
		final Map<String, num>? floatPosition = element.imgFloatPosition;
		if (floatPosition != null) {
			final num? floatX = floatPosition['x'];
			final num? floatY = floatPosition['y'];
			if (floatX != null) {
				x = floatX.toDouble() * scale;
			}
			if (floatY != null) {
				y = floatY.toDouble() * scale + preY;
			}
		} else if (position != null) {
			final List<double>? leftTop = position.coordinate['leftTop'];
			if (leftTop != null && leftTop.length >= 2) {
				x = leftTop[0];
				y = leftTop[1] + preY + position.ascent;
			}
		}
		return <String, double>{'x': x, 'y': y};
	}

	IPreviewerCreateResult _createResizerDom() {
		final double scale = _scale();
		final DivElement resizerSelection = DivElement()
			..classes.add('$editorPrefix-resizer-selection')
			..style.display = 'none'
			..style.borderColor = _options.resizerColor ?? '#3B76F0'
			..style.borderWidth = '${scale}px';

		final List<DivElement> resizerHandleList = <DivElement>[];
		for (int i = 0; i < 8; i++) {
			final DivElement handleDom = DivElement()
				..classes.addAll(<String>['resizer-handle', 'handle-$i'])
				..dataset['index'] = '$i'
				..style.background = _options.resizerColor ?? '#3B76F0';
			handleDom.onMouseDown.listen(_onHandleMouseDown);
			resizerSelection.append(handleDom);
			resizerHandleList.add(handleDom);
		}
		_container.append(resizerSelection);

		final DivElement resizerSizeView = DivElement()
			..classes.add('$editorPrefix-resizer-size-view');
		final SpanElement resizerSize = SpanElement();
		resizerSizeView.append(resizerSize);
		resizerSelection.append(resizerSizeView);

		final DivElement resizerImageContainer = DivElement()
			..classes.add('$editorPrefix-resizer-image')
			..style.display = 'none';
		final ImageElement resizerImage = ImageElement();
		resizerImageContainer.append(resizerImage);
		_container.append(resizerImageContainer);

		return IPreviewerCreateResult(
			resizerSelection: resizerSelection,
			resizerHandleList: resizerHandleList,
			resizerImageContainer: resizerImageContainer,
			resizerImage: resizerImage,
			resizerSize: resizerSize,
		);
	}

	void _onKeydown() {
		if (_resizerSelection.style.display == 'block') {
			clearResizer();
		}
	}

	void _onHandleMouseDown(MouseEvent evt) {
		_canvas = _resolveCurrentCanvas();
		final CanvasElement? canvas = _canvas;
		final IElement? element = _curElement;
		if (canvas == null || element == null) {
			return;
		}
		_mousedownX = evt.client.x.toDouble();
		_mousedownY = evt.client.y.toDouble();
		final Element? target = evt.target as Element?;
		if (target != null) {
			final String? indexValue = target.dataset['index'];
			if (indexValue != null) {
				_curHandleIndex = int.tryParse(indexValue) ?? 0;
			}
			final CssStyleDeclaration style = target.getComputedStyle();
			final String cursor = style.cursor.isEmpty ? 'default' : style.cursor;
			document.body?.style.cursor = cursor;
			canvas.style.cursor = cursor;
		}

		_resizerImage.src = _curElementSrc;
		_resizerImageContainer.style.display = 'block';

		final Map<String, double> position =
				_getElementPosition(element, _curPosition);
		_resizerImageContainer
			..style.left = '${position['x'] ?? 0}px'
			..style.top = '${position['y'] ?? 0}px';

		final double scale = _scale();
		final double elementWidth = (element.width ?? 0) * scale;
		final double elementHeight = (element.height ?? 0) * scale;
		_resizerImage
			..style.width = '${elementWidth}px'
			..style.height = '${elementHeight}px';

		final StreamSubscription<MouseEvent> moveSub =
				document.onMouseMove.listen(_onMouseMove);
		late StreamSubscription<MouseEvent>? upSub;
		upSub = document.onMouseUp.listen((MouseEvent _) {
			if (_curElement != null && _previewerDrawOption.dragDisable != true) {
				_curElement!
					..width = _width
					..height = _height;
				_draw.render(IDrawOption(
					isSetCursor: true,
					curIndex: _curPosition?.index,
				));
			}
			_resizerImageContainer.style.display = 'none';
			document.body?.style.cursor = '';
			canvas.style.cursor = 'text';
			moveSub.cancel();
			upSub?.cancel();
		});

		evt.preventDefault();
	}

	void _onMouseMove(MouseEvent evt) {
		final IElement? element = _curElement;
		if (element == null || _previewerDrawOption.dragDisable == true) {
			return;
		}
		final double elementWidth = (element.width ?? 0).toDouble();
		final double elementHeight = (element.height ?? 0).toDouble();
		if (elementWidth <= 0 || elementHeight <= 0) {
			return;
		}

		final double scale = _scale();
		double dx = 0;
		double dy = 0;

		switch (_curHandleIndex) {
			case 0:
				{
					final double offsetX = _mousedownX - evt.client.x.toDouble();
					final double offsetY = _mousedownY - evt.client.y.toDouble();
					dx = _cubeRoot(_cube(offsetX) + _cube(offsetY));
					dy = (elementHeight * dx) / elementWidth;
				}
				break;
			case 1:
				dy = _mousedownY - evt.client.y.toDouble();
				break;
			case 2:
				{
					final double offsetX = evt.client.x.toDouble() - _mousedownX;
					final double offsetY = _mousedownY - evt.client.y.toDouble();
					dx = _cubeRoot(_cube(offsetX) + _cube(offsetY));
					dy = (elementHeight * dx) / elementWidth;
				}
				break;
			case 3:
				dx = evt.client.x.toDouble() - _mousedownX;
				break;
			case 4:
				{
					final double offsetX = evt.client.x.toDouble() - _mousedownX;
					final double offsetY = evt.client.y.toDouble() - _mousedownY;
					dx = _cubeRoot(_cube(offsetX) + _cube(offsetY));
					dy = (elementHeight * dx) / elementWidth;
				}
				break;
			case 5:
				dy = evt.client.y.toDouble() - _mousedownY;
				break;
			case 6:
				{
					final double offsetX = _mousedownX - evt.client.x.toDouble();
					final double offsetY = evt.client.y.toDouble() - _mousedownY;
					dx = _cubeRoot(_cube(offsetX) + _cube(offsetY));
					dy = (elementHeight * dx) / elementWidth;
				}
				break;
			case 7:
				dx = _mousedownX - evt.client.x.toDouble();
				break;
			default:
				break;
		}

		final double dw = elementWidth + dx / scale;
		final double dh = elementHeight + dy / scale;
		if (dw <= 0 || dh <= 0) {
			return;
		}

		_width = dw;
		_height = dh;

		final double displayWidth = dw * scale;
		final double displayHeight = dh * scale;

		_resizerImage
			..style.width = '${displayWidth}px'
			..style.height = '${displayHeight}px';

		_updateResizerRect(displayWidth, displayHeight);
		_updateResizerSizeView(displayWidth, displayHeight);

		evt.preventDefault();

		if (_eventBus?.isSubscribe('imageSizeChange') == true) {
			_eventBus?.emit('imageSizeChange', <String, dynamic>{'element': element});
		}
	}

	void _drawPreviewer() {
		final DivElement previewerContainer = DivElement()
			..classes.add('$editorPrefix-image-previewer');

		final Element closeBtn = Element.tag('i')..classes.add('image-close');
		closeBtn.onClick.listen((_) => _clearPreviewer());
		previewerContainer.append(closeBtn);

		final DivElement imgContainer = DivElement()
			..classes.add('$editorPrefix-image-container');
		final ImageElement img = ImageElement()
			..src = _curElementSrc
			..draggable = false;
		imgContainer.append(img);
		_previewerImage = img;
		previewerContainer.append(imgContainer);

		double translateX = 0;
		double translateY = 0;
		double scaleSize = 1;
		double rotateQuarter = 0;

		final DivElement menuContainer = DivElement()
			..classes.add('$editorPrefix-image-menu');

		final DivElement navigateContainer = DivElement()
			..classes.add('image-navigate');
		final Element imagePre = Element.tag('i')..classes.add('image-pre');
		imagePre.onClick.listen((_) {
			final int currentIndex = _imageList
					.indexWhere((IElement el) => el.id == _curShowElement?.id);
			if (currentIndex <= 0) {
				return;
			}
			_curShowElement = _imageList[currentIndex - 1];
			img.src = _resolveElementSrc(
				_curShowElement!,
				_previewerDrawOption.srcKey,
			);
			_updateImageNavigate();
		});
		navigateContainer.append(imagePre);
		_imagePre = imagePre;

		final SpanElement imageCount = SpanElement()
			..classes.add('image-count');
		navigateContainer.append(imageCount);
		_imageCount = imageCount;

		final Element imageNext = Element.tag('i')..classes.add('image-next');
		imageNext.onClick.listen((_) {
			final int currentIndex = _imageList
					.indexWhere((IElement el) => el.id == _curShowElement?.id);
			if (currentIndex < 0 || currentIndex >= _imageList.length - 1) {
				return;
			}
			_curShowElement = _imageList[currentIndex + 1];
			img.src = _resolveElementSrc(
				_curShowElement!,
				_previewerDrawOption.srcKey,
			);
			_updateImageNavigate();
		});
		navigateContainer.append(imageNext);
		_imageNext = imageNext;

		menuContainer.append(navigateContainer);

		final Element zoomIn = Element.tag('i')..classes.add('zoom-in');
		zoomIn.onClick.listen((_) {
			scaleSize += 0.1;
			_setPreviewerTransform(scaleSize, rotateQuarter, translateX, translateY);
		});
		menuContainer.append(zoomIn);

		final Element zoomOut = Element.tag('i')..classes.add('zoom-out');
		zoomOut.onClick.listen((_) {
			if (scaleSize - 0.1 <= 0.1) {
				return;
			}
			scaleSize -= 0.1;
			_setPreviewerTransform(scaleSize, rotateQuarter, translateX, translateY);
		});
		menuContainer.append(zoomOut);

		final Element rotate = Element.tag('i')..classes.add('rotate');
		rotate.onClick.listen((_) {
			rotateQuarter += 1;
			_setPreviewerTransform(scaleSize, rotateQuarter, translateX, translateY);
		});
		menuContainer.append(rotate);

		final Element originalSize = Element.tag('i')..classes.add('original-size');
		originalSize.onClick.listen((_) {
			translateX = 0;
			translateY = 0;
			scaleSize = 1;
			rotateQuarter = 0;
			_setPreviewerTransform(scaleSize, rotateQuarter, translateX, translateY);
		});
		menuContainer.append(originalSize);

		final Element imageDownload = Element.tag('i')..classes.add('image-download');
		imageDownload.onClick.listen((_) {
					final String extension =
							_previewerDrawOption.mime?.value ?? PreviewerMime.png.value;
					final String name = _curElement?.id ?? 'image';
					final String src = img.src ?? '';
					if (src.isEmpty) {
						return;
					}
					downloadFile(src, '$name.$extension');
		});
		menuContainer.append(imageDownload);

		previewerContainer.append(menuContainer);
		_previewerContainer = previewerContainer;
		document.body?.append(previewerContainer);

		double startX = 0;
		double startY = 0;
		bool allowDrag = false;

		img.onMouseDown.listen((MouseEvent evt) {
			allowDrag = true;
			startX = evt.client.x.toDouble();
			startY = evt.client.y.toDouble();
			previewerContainer.style.cursor = 'move';
			evt.preventDefault();
		});

		previewerContainer.onMouseMove.listen((MouseEvent evt) {
			if (!allowDrag) {
				return;
			}
			translateX += evt.client.x.toDouble() - startX;
			translateY += evt.client.y.toDouble() - startY;
			startX = evt.client.x.toDouble();
			startY = evt.client.y.toDouble();
			_setPreviewerTransform(scaleSize, rotateQuarter, translateX, translateY);
		});

		previewerContainer.onMouseUp.listen((MouseEvent _) {
			allowDrag = false;
			previewerContainer.style.cursor = 'auto';
		});

		previewerContainer.onWheel.listen((WheelEvent evt) {
			evt.preventDefault();
			evt.stopPropagation();
			if (evt.deltaY < 0) {
				scaleSize += 0.1;
			} else {
				if (scaleSize - 0.1 <= 0.1) {
					return;
				}
				scaleSize -= 0.1;
			}
			_setPreviewerTransform(scaleSize, rotateQuarter, translateX, translateY);
		});

		_updateImageNavigate();
	}

	void _updateImageNavigate() {
		final SpanElement? count = _imageCount;
		final Element? pre = _imagePre;
		final Element? next = _imageNext;
		if (count == null || pre == null || next == null) {
			return;
		}
		if (_imageList.isEmpty || _curShowElement == null) {
			count.text = '0 / 0';
			pre.classes.add('disabled');
			next.classes.add('disabled');
			return;
		}

		int currentIndex =
				_imageList.indexWhere((IElement el) => el.id == _curShowElement?.id);
		if (currentIndex < 0) {
			currentIndex = 0;
			_curShowElement = _imageList.first;
			_previewerImage?.src = _resolveElementSrc(
				_curShowElement!,
				_previewerDrawOption.srcKey,
			);
		}

		count.text = '${currentIndex + 1} / ${_imageList.length}';

		if (currentIndex <= 0) {
			pre.classes.add('disabled');
		} else {
			pre.classes.remove('disabled');
		}

		if (currentIndex >= _imageList.length - 1) {
			next.classes.add('disabled');
		} else {
			next.classes.remove('disabled');
		}
	}

	void _setPreviewerTransform(
		double scale,
		double rotate,
		double x,
		double y,
	) {
		final ImageElement? image = _previewerImage;
		if (image == null) {
			return;
		}
		image
			..style.left = '${x}px'
			..style.top = '${y}px'
			..style.transform =
					'scale(${scale.toStringAsFixed(2)}) rotate(${(rotate * 90).toStringAsFixed(0)}deg)';
	}

	void _clearPreviewer() {
		_previewerContainer?.remove();
		_previewerContainer = null;
		_previewerImage = null;
		document.body?.style.overflow = 'auto';
	}

	void _updateResizerRect(double width, double height) {
		final double handleSize = (_options.resizerSize ?? 8).toDouble();
		final double scale = _scale();
		final bool isReadonly = _draw.isReadonly();
		_resizerSelection
			..style.width = '${width}px'
			..style.height = '${height}px';
		for (int i = 0; i < _resizerHandleList.length; i++) {
			final DivElement handle = _resizerHandleList[i];
			final double left = (i == 0 || i == 6 || i == 7)
					? -handleSize
					: (i == 1 || i == 5)
							? width / 2
							: width - handleSize;
			final double top = (i == 0 || i == 1 || i == 2)
					? -handleSize
					: (i == 3 || i == 7)
							? height / 2 - handleSize
							: height - handleSize;
			handle
				..style.transform = 'scale($scale)'
				..style.left = '${left}px'
				..style.top = '${top}px'
				..style.display = isReadonly ? 'none' : 'block';
		}
	}

	void _updateResizerSizeView(double width, double height) {
		_resizerSize.text = '${width.round()} × ${height.round()}';
	}

	void render() {
		final EditorMode mode = _draw.getMode();
		final IModeRule? modeRule = _options.modeRule;
		if (_curElement == null) {
			return;
		}
		if ((_curElement!.imgToolDisabled == true && !_draw.isDesignMode()) ||
				(mode == EditorMode.print &&
						modeRule?.print?.imagePreviewerDisabled == true) ||
				(mode == EditorMode.readonly &&
						modeRule?.readonly?.imagePreviewerDisabled == true)) {
			return;
		}

		_imageList = _resolveImageList();
		_curShowElement = _curElement;
		_drawPreviewer();
		document.body?.style.overflow = 'hidden';
	}

		void drawResizer(
			IElement element, [
			IElementPosition? position,
			IPreviewerDrawOption? options,
		]) {
		final EditorMode mode = _draw.getMode();
		final IModeRule? modeRule = _options.modeRule;
		if ((element.imgToolDisabled == true && !_draw.isDesignMode()) ||
				(mode == EditorMode.print &&
						modeRule?.print?.imagePreviewerDisabled == true) ||
				(mode == EditorMode.readonly &&
						modeRule?.readonly?.imagePreviewerDisabled == true)) {
			return;
		}

			final IPreviewerDrawOption resolvedOptions = options ?? IPreviewerDrawOption();
			_previewerDrawOption = IPreviewerDrawOption(
				mime: resolvedOptions.mime,
				srcKey: resolvedOptions.srcKey,
				dragDisable: resolvedOptions.dragDisable,
			);
		_curElementSrc = _resolveElementSrc(element, _previewerDrawOption.srcKey);
		updateResizer(element, position);
		if (!_keydownBound) {
			document.addEventListener('keydown', _keydownListener);
			_keydownBound = true;
		}
	}

	void updateResizer(IElement element, IElementPosition? position) {
		final double scale = _scale();
		final double elementWidth = (element.width ?? 0) * scale;
		final double elementHeight = (element.height ?? 0) * scale;
		_updateResizerSizeView(elementWidth, elementHeight);
		final Map<String, double> elementPosition =
				_getElementPosition(element, position);
		_resizerSelection
			..style.left = '${elementPosition['x'] ?? 0}px'
			..style.top = '${elementPosition['y'] ?? 0}px'
			..style.borderWidth = '${scale}px'
			..style.display = 'block';
		_updateResizerRect(elementWidth, elementHeight);
		_curElement = element;
		_curPosition = position;
		_width = elementWidth;
		_height = elementHeight;
	}

	void clearResizer() {
		_resizerSelection.style.display = 'none';
		_resizerImageContainer.style.display = 'none';
		if (_keydownBound) {
			document.removeEventListener('keydown', _keydownListener);
			_keydownBound = false;
		}
	}

	List<IElement> _resolveImageList() {
		final dynamic imageParticle = _draw.getImageParticle();
		if (imageParticle == null) {
			return <IElement>[];
		}
		try {
			final dynamic result = imageParticle.getOriginalMainImageList();
			if (result is List<IElement>) {
				return result;
			}
			if (result is List) {
				return List<IElement>.from(result);
			}
		} catch (_) {
			// ignore missing implementation until the image particle is ported
		}
		return <IElement>[];
	}

	String _resolveElementSrc(IElement element, String? key) {
		if (key == 'laTexSVG') {
			return element.laTexSVG ?? '';
		}
		return element.value;
	}

	double _cube(double value) => value * value * value;

	double _cubeRoot(double value) {
		if (value == 0) {
			return 0;
		}
		final double absValue = value.abs();
		final double root = math.pow(absValue, 1 / 3).toDouble();
		return value < 0 ? -root : root;
	}
}