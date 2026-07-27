import 'dart:async';
import 'package:canvas_text_editor/src/dom/dom.dart';
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
		_keydownListener = ((Event _) => _onKeydown()).toJS;
	}

	final Draw _draw;
	final HTMLDivElement _container;
	final IEditorOption _options;
	final EventBus<EventBusMap>? _eventBus;

	HTMLCanvasElement? _canvas;
	IElement? _curElement;
	String _curElementSrc = '';
	IPreviewerDrawOption _previewerDrawOption = IPreviewerDrawOption();
	IElementPosition? _curPosition;
	List<IElement> _imageList = <IElement>[];
	IElement? _curShowElement;
	HTMLSpanElement? _imageCount;
	Element? _imagePre;
	Element? _imageNext;

	late final EventListener _keydownListener;
	bool _keydownBound = false;

	late final HTMLDivElement _resizerSelection;
	late final List<HTMLDivElement> _resizerHandleList;
	late final HTMLDivElement _resizerImageContainer;
	late final HTMLImageElement _resizerImage;
	late final HTMLSpanElement _resizerSize;
	double _width = 0;
	double _height = 0;
	double _mousedownX = 0;
	double _mousedownY = 0;
	int _curHandleIndex = 0;

	HTMLDivElement? _previewerContainer;
	HTMLImageElement? _previewerImage;

	double _scale() => (_options.scale ?? 1).toDouble();

	HTMLCanvasElement? _resolveCurrentCanvas() {
		final List<Element> pageList = _draw.getPageList();
		if (pageList.isEmpty) {
			return null;
		}
		int pageIndex = _draw.getPageNo();
		if (pageIndex < 0 || pageIndex >= pageList.length) {
			pageIndex = 0;
		}
		final Element element = pageList[pageIndex];
		return asCanvasElement(element);
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
		final HTMLDivElement resizerSelection = HTMLDivElement()
			..classList.add('$editorPrefix-resizer-selection')
			..style.display = 'none'
			..style.borderColor = _options.resizerColor ?? '#3B76F0'
			..style.borderWidth = '${scale}px';

		final List<HTMLDivElement> resizerHandleList = <HTMLDivElement>[];
		for (int i = 0; i < 8; i++) {
			final HTMLDivElement handleDom = HTMLDivElement()
				..classList.addAll(<String>['resizer-handle', 'handle-$i'])
				..dataset['index'] = '$i'
				..style.background = _options.resizerColor ?? '#3B76F0';
			handleDom.onMouseDown.listen(_onHandleMouseDown);
			resizerSelection.append(handleDom);
			resizerHandleList.add(handleDom);
		}
		_container.append(resizerSelection);

		final HTMLDivElement resizerSizeView = HTMLDivElement()
			..classList.add('$editorPrefix-resizer-size-view');
		final HTMLSpanElement resizerSize = HTMLSpanElement();
		resizerSizeView.append(resizerSize);
		resizerSelection.append(resizerSizeView);

		final HTMLDivElement resizerImageContainer = HTMLDivElement()
			..classList.add('$editorPrefix-resizer-image')
			..style.display = 'none';
		final HTMLImageElement resizerImage = HTMLImageElement();
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
		final HTMLCanvasElement? canvas = _canvas;
		final IElement? element = _curElement;
		if (canvas == null || element == null) {
			return;
		}
		_mousedownX = evt.clientX.toDouble();
		_mousedownY = evt.clientY.toDouble();
		final Element? target = evt.target as Element?;
		if (target != null) {
			final String? indexValue = target.data('index');
			if (indexValue != null) {
				_curHandleIndex = int.tryParse(indexValue) ?? 0;
			}
			final CSSStyleDeclaration style = target.getComputedStyle();
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
					final double offsetX = _mousedownX - evt.clientX.toDouble();
					final double offsetY = _mousedownY - evt.clientY.toDouble();
					dx = _cubeRoot(_cube(offsetX) + _cube(offsetY));
					dy = (elementHeight * dx) / elementWidth;
				}
				break;
			case 1:
				dy = _mousedownY - evt.clientY.toDouble();
				break;
			case 2:
				{
					final double offsetX = evt.clientX.toDouble() - _mousedownX;
					final double offsetY = _mousedownY - evt.clientY.toDouble();
					dx = _cubeRoot(_cube(offsetX) + _cube(offsetY));
					dy = (elementHeight * dx) / elementWidth;
				}
				break;
			case 3:
				dx = evt.clientX.toDouble() - _mousedownX;
				break;
			case 4:
				{
					final double offsetX = evt.clientX.toDouble() - _mousedownX;
					final double offsetY = evt.clientY.toDouble() - _mousedownY;
					dx = _cubeRoot(_cube(offsetX) + _cube(offsetY));
					dy = (elementHeight * dx) / elementWidth;
				}
				break;
			case 5:
				dy = evt.clientY.toDouble() - _mousedownY;
				break;
			case 6:
				{
					final double offsetX = _mousedownX - evt.clientX.toDouble();
					final double offsetY = evt.clientY.toDouble() - _mousedownY;
					dx = _cubeRoot(_cube(offsetX) + _cube(offsetY));
					dy = (elementHeight * dx) / elementWidth;
				}
				break;
			case 7:
				dx = _mousedownX - evt.clientX.toDouble();
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
		final HTMLDivElement previewerContainer = HTMLDivElement()
			..classList.add('$editorPrefix-image-previewer');

		final Element closeBtn = document.createElement('i')..classList.add('image-close');
		closeBtn.onClick.listen((_) => _clearPreviewer());
		previewerContainer.append(closeBtn);

		final HTMLDivElement imgContainer = HTMLDivElement()
			..classList.add('$editorPrefix-image-container');
		final HTMLImageElement img = HTMLImageElement()
			..src = _curElementSrc
			..draggable = false;
		imgContainer.append(img);
		final HTMLDivElement cropLayer = HTMLDivElement()
			..classList.add('$editorPrefix-image-crop-layer')
			..style.display = 'none';
		final HTMLDivElement cropSelection = HTMLDivElement()
			..classList.add('$editorPrefix-image-crop-selection')
			..style.display = 'none';
		const List<String> cropHandleNames = <String>[
			'n',
			'ne',
			'e',
			'se',
			's',
			'sw',
			'w',
			'nw',
		];
		for (final String handleName in cropHandleNames) {
			cropSelection.append(
				HTMLDivElement()
					..classList.add('$editorPrefix-image-crop-handle')
					..dataset['handle'] = handleName,
			);
		}
		cropLayer.append(cropSelection);
		imgContainer.append(cropLayer);
		_previewerImage = img;
		previewerContainer.append(imgContainer);

		double translateX = 0;
		double translateY = 0;
		double scaleSize = 1;
		double rotateQuarter = 0;
		bool cropMode = false;
		bool cropDragging = false;
		String? cropDragMode;
		String? cropResizeHandle;
		double cropPointerStartX = 0;
		double cropPointerStartY = 0;
		double cropInitialLeft = 0;
		double cropInitialTop = 0;
		double cropInitialWidth = 0;
		double cropInitialHeight = 0;
		double cropLeft = 0;
		double cropTop = 0;
		double cropWidth = 0;
		double cropHeight = 0;
		const double cropMinSize = 12;

		final HTMLDivElement menuContainer = HTMLDivElement()
			..classList.add('$editorPrefix-image-menu');
		final HTMLButtonElement cropToggle = HTMLButtonElement()
			..classList.addAll(<String>['image-crop-action', 'crop-toggle'])
			..text = 'Recortar';
		final HTMLButtonElement cropApply = HTMLButtonElement()
			..classList.addAll(<String>['image-crop-action', 'crop-apply'])
			..text = 'Aplicar'
			..style.display = 'none';
		final HTMLButtonElement cropCancel = HTMLButtonElement()
			..classList.addAll(<String>['image-crop-action', 'crop-cancel'])
			..text = 'Cancelar'
			..style.display = 'none';

		void updateCropSelection(
			double left,
			double top,
			double width,
			double height,
		) {
			cropLeft = left;
			cropTop = top;
			cropWidth = width;
			cropHeight = height;
			cropSelection
				..style.display = 'block'
				..style.left = '${left}px'
				..style.top = '${top}px'
				..style.width = '${width}px'
				..style.height = '${height}px';
		}

		double clampCropValue(double value, double min, double max) {
			if (max <= min) {
				return min;
			}
			return math.max(min, math.min(max, value));
		}

		Point<double> getCropPointer(MouseEvent evt) {
			final DOMRect rect = cropLayer.getBoundingClientRect();
			return Point<double>(
				clampCropValue(
					evt.clientX.toDouble() - rect.left,
					0,
					rect.width.toDouble(),
				),
				clampCropValue(
					evt.clientY.toDouble() - rect.top,
					0,
					rect.height.toDouble(),
				),
			);
		}

		String cropCursorForHandle(String? handle) {
			switch (handle) {
				case 'n':
				case 's':
					return 'ns-resize';
				case 'e':
				case 'w':
					return 'ew-resize';
				case 'ne':
				case 'sw':
					return 'nesw-resize';
				case 'nw':
				case 'se':
					return 'nwse-resize';
				default:
					return 'crosshair';
			}
		}

		void beginCropInteraction(
			String mode,
			MouseEvent evt, {
			String? handle,
		}) {
			final Point<double> pointer = getCropPointer(evt);
			cropDragging = true;
			cropDragMode = mode;
			cropResizeHandle = handle;
			cropPointerStartX = pointer.x;
			cropPointerStartY = pointer.y;
			cropInitialLeft = cropLeft;
			cropInitialTop = cropTop;
			cropInitialWidth = cropWidth;
			cropInitialHeight = cropHeight;
			if (mode == 'create') {
				updateCropSelection(pointer.x, pointer.y, 1, 1);
			}
			previewerContainer.style.cursor =
					mode == 'move' ? 'move' : cropCursorForHandle(handle);
			evt.preventDefault();
			evt.stopPropagation();
		}

		void syncCropLayer() {
			final DOMRect rect = img.getBoundingClientRect();
			cropLayer
				..style.width = '${rect.width.toDouble()}px'
				..style.height = '${rect.height.toDouble()}px';
		}

		void syncCropSelectionFromElement() {
			syncCropLayer();
			final DOMRect rect = img.getBoundingClientRect();
			final double displayWidth = rect.width.toDouble();
			final double displayHeight = rect.height.toDouble();
			if (displayWidth <= 0 || displayHeight <= 0) {
				return;
			}
			final IImageCrop? crop = _curShowElement?.imgCrop;
			if (crop == null) {
				updateCropSelection(0, 0, displayWidth, displayHeight);
				return;
			}
			final double naturalWidth =
					img.naturalWidth > 0 ? img.naturalWidth.toDouble() : displayWidth;
			final double naturalHeight =
					img.naturalHeight > 0 ? img.naturalHeight.toDouble() : displayHeight;
			final double left = math.max(
					0,
					math.min(
						displayWidth,
						(crop.x.toDouble() / naturalWidth) * displayWidth,
					),
			);
			final double top = math.max(
					0,
					math.min(
						displayHeight,
						(crop.y.toDouble() / naturalHeight) * displayHeight,
					),
			);
			final double width = math.max(
					1,
					math.min(
						displayWidth - left,
						(crop.width.toDouble() / naturalWidth) * displayWidth,
					),
			);
			final double height = math.max(
					1,
					math.min(
						displayHeight - top,
						(crop.height.toDouble() / naturalHeight) * displayHeight,
					),
			);
			updateCropSelection(left, top, width, height);
		}

		void setCropMode(bool enabled) {
			cropMode = enabled;
			cropDragging = false;
			cropDragMode = null;
			cropResizeHandle = null;
			previewerContainer.classList.toggle('crop-mode', enabled);
			cropLayer.style.display = enabled ? 'block' : 'none';
			cropSelection.style.display = enabled ? cropSelection.style.display : 'none';
			cropToggle.style.display = enabled ? 'none' : 'inline-flex';
			cropApply.style.display = enabled ? 'inline-flex' : 'none';
			cropCancel.style.display = enabled ? 'inline-flex' : 'none';
			previewerContainer.style.cursor = enabled ? 'crosshair' : 'auto';
			if (enabled) {
				translateX = 0;
				translateY = 0;
				scaleSize = 1;
				rotateQuarter = 0;
				_setPreviewerTransform(scaleSize, rotateQuarter, translateX, translateY);
				syncCropSelectionFromElement();
			}
		}

		void applyCropSelection() {
			final DOMRect rect = img.getBoundingClientRect();
			final double displayWidth = rect.width.toDouble();
			final double displayHeight = rect.height.toDouble();
			if (displayWidth <= 0 || displayHeight <= 0) {
				return;
			}
			final double selectionLeft = cropWidth <= 1 ? 0 : cropLeft;
			final double selectionTop = cropHeight <= 1 ? 0 : cropTop;
			final double selectionWidth = cropWidth <= 1 ? displayWidth : cropWidth;
			final double selectionHeight = cropHeight <= 1 ? displayHeight : cropHeight;
			final double naturalWidth =
					img.naturalWidth > 0 ? img.naturalWidth.toDouble() : displayWidth;
			final double naturalHeight =
					img.naturalHeight > 0 ? img.naturalHeight.toDouble() : displayHeight;
			final IImageCrop crop = IImageCrop(
				x: ((selectionLeft / displayWidth) * naturalWidth).round(),
				y: ((selectionTop / displayHeight) * naturalHeight).round(),
				width: ((selectionWidth / displayWidth) * naturalWidth).round(),
				height: ((selectionHeight / displayHeight) * naturalHeight).round(),
			);
			_curShowElement?.imgCrop = crop;
			if (_curElement?.id == _curShowElement?.id) {
				_curElement?.imgCrop = crop;
			}
			_draw.render(
				IDrawOption(
					isSetCursor: false,
					isCompute: false,
				),
			);
			_clearPreviewer();
		}

		final HTMLDivElement navigateContainer = HTMLDivElement()
			..classList.add('image-navigate');
		final Element imagePre = document.createElement('i')..classList.add('image-pre');
		imagePre.onClick.listen((_) {
			if (cropMode) {
				setCropMode(false);
			}
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

		final HTMLSpanElement imageCount = HTMLSpanElement()
			..classList.add('image-count');
		navigateContainer.append(imageCount);
		_imageCount = imageCount;

		final Element imageNext = document.createElement('i')..classList.add('image-next');
		imageNext.onClick.listen((_) {
			if (cropMode) {
				setCropMode(false);
			}
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

		final Element zoomIn = document.createElement('i')..classList.add('zoom-in');
		zoomIn.onClick.listen((_) {
			scaleSize += 0.1;
			_setPreviewerTransform(scaleSize, rotateQuarter, translateX, translateY);
		});
		menuContainer.append(zoomIn);

		final Element zoomOut = document.createElement('i')..classList.add('zoom-out');
		zoomOut.onClick.listen((_) {
			if (scaleSize - 0.1 <= 0.1) {
				return;
			}
			scaleSize -= 0.1;
			_setPreviewerTransform(scaleSize, rotateQuarter, translateX, translateY);
		});
		menuContainer.append(zoomOut);

		final Element rotate = document.createElement('i')..classList.add('rotate');
		rotate.onClick.listen((_) {
			rotateQuarter += 1;
			_setPreviewerTransform(scaleSize, rotateQuarter, translateX, translateY);
		});
		menuContainer.append(rotate);

		final Element originalSize = document.createElement('i')..classList.add('original-size');
		originalSize.onClick.listen((_) {
			translateX = 0;
			translateY = 0;
			scaleSize = 1;
			rotateQuarter = 0;
			_setPreviewerTransform(scaleSize, rotateQuarter, translateX, translateY);
		});
		menuContainer.append(originalSize);

		final Element imageDownload = document.createElement('i')..classList.add('image-download');
		imageDownload.onClick.listen((_) {
					final String extension =
							_previewerDrawOption.mime?.value ?? PreviewerMime.png.value;
					final String name = _curElement?.id ?? 'image';
					final String src = img.src;
					if (src.isEmpty) {
						return;
					}
					downloadFile(src, '$name.$extension');
		});
		menuContainer.append(imageDownload);
		cropToggle.onClick.listen((_) {
			setCropMode(true);
		});
		cropApply.onClick.listen((_) {
			applyCropSelection();
		});
		cropCancel.onClick.listen((_) {
			setCropMode(false);
		});
		menuContainer
			..append(cropToggle)
			..append(cropApply)
			..append(cropCancel);

		previewerContainer.append(menuContainer);
		_previewerContainer = previewerContainer;
		document.body?.append(previewerContainer);

		double startX = 0;
		double startY = 0;
		bool allowDrag = false;

		img.onMouseDown.listen((MouseEvent evt) {
			if (cropMode) {
				return;
			}
			allowDrag = true;
			startX = evt.clientX.toDouble();
			startY = evt.clientY.toDouble();
			previewerContainer.style.cursor = 'move';
			evt.preventDefault();
		});

		cropSelection.onMouseDown.listen((MouseEvent evt) {
			if (!cropMode) {
				return;
			}
			final Element? target = evt.target as Element?;
			final String? handle = target?.data('handle');
			if (handle != null) {
				beginCropInteraction('resize', evt, handle: handle);
				return;
			}
			beginCropInteraction('move', evt);
		});

		cropLayer.onMouseDown.listen((MouseEvent evt) {
			if (!cropMode) {
				return;
			}
			if (evt.target != cropLayer) {
				return;
			}
			beginCropInteraction('create', evt);
		});

		previewerContainer.onMouseMove.listen((MouseEvent evt) {
			if (cropMode && cropDragging) {
				final DOMRect rect = cropLayer.getBoundingClientRect();
				final Point<double> pointer = getCropPointer(evt);
				final double currentX = pointer.x;
				final double currentY = pointer.y;
				final double layerWidth = rect.width.toDouble();
				final double layerHeight = rect.height.toDouble();
				if (cropDragMode == 'move') {
					final double maxLeft = math.max(0, layerWidth - cropInitialWidth);
					final double maxTop = math.max(0, layerHeight - cropInitialHeight);
					updateCropSelection(
						clampCropValue(
							cropInitialLeft + (currentX - cropPointerStartX),
							0,
							maxLeft,
						),
						clampCropValue(
							cropInitialTop + (currentY - cropPointerStartY),
							0,
							maxTop,
						),
						cropInitialWidth,
						cropInitialHeight,
					);
				} else if (cropDragMode == 'resize') {
					double nextLeft = cropInitialLeft;
					double nextTop = cropInitialTop;
					double nextRight = cropInitialLeft + cropInitialWidth;
					double nextBottom = cropInitialTop + cropInitialHeight;
					final String handle = cropResizeHandle ?? 'se';
					if (handle.contains('w')) {
						nextLeft = clampCropValue(
							cropInitialLeft + (currentX - cropPointerStartX),
							0,
							nextRight - cropMinSize,
						);
					}
					if (handle.contains('e')) {
						nextRight = clampCropValue(
							cropInitialLeft +
									cropInitialWidth +
									(currentX - cropPointerStartX),
							nextLeft + cropMinSize,
							layerWidth,
						);
					}
					if (handle.contains('n')) {
						nextTop = clampCropValue(
							cropInitialTop + (currentY - cropPointerStartY),
							0,
							nextBottom - cropMinSize,
						);
					}
					if (handle.contains('s')) {
						nextBottom = clampCropValue(
							cropInitialTop +
									cropInitialHeight +
									(currentY - cropPointerStartY),
							nextTop + cropMinSize,
							layerHeight,
						);
					}
					updateCropSelection(
						nextLeft,
						nextTop,
						nextRight - nextLeft,
						nextBottom - nextTop,
					);
				} else {
					final double left = math.min(cropPointerStartX, currentX);
					final double top = math.min(cropPointerStartY, currentY);
					final double width = math.max(1, (cropPointerStartX - currentX).abs());
					final double height = math.max(1, (cropPointerStartY - currentY).abs());
					updateCropSelection(left, top, width, height);
				}
				evt.preventDefault();
				return;
			}
			if (!allowDrag) {
				return;
			}
			translateX += evt.clientX.toDouble() - startX;
			translateY += evt.clientY.toDouble() - startY;
			startX = evt.clientX.toDouble();
			startY = evt.clientY.toDouble();
			_setPreviewerTransform(scaleSize, rotateQuarter, translateX, translateY);
		});

		previewerContainer.onMouseUp.listen((MouseEvent _) {
			if (cropMode) {
				cropDragging = false;
				cropDragMode = null;
				cropResizeHandle = null;
				previewerContainer.style.cursor = 'crosshair';
				return;
			}
			allowDrag = false;
			previewerContainer.style.cursor = 'auto';
		});

		previewerContainer.onWheel.listen((WheelEvent evt) {
			if (cropMode) {
				return;
			}
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
		final HTMLSpanElement? count = _imageCount;
		final Element? pre = _imagePre;
		final Element? next = _imageNext;
		if (count == null || pre == null || next == null) {
			return;
		}
		if (_imageList.isEmpty || _curShowElement == null) {
			count.text = '0 / 0';
			pre.classList.add('disabled');
			next.classList.add('disabled');
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
			pre.classList.add('disabled');
		} else {
			pre.classList.remove('disabled');
		}

		if (currentIndex >= _imageList.length - 1) {
			next.classList.add('disabled');
		} else {
			next.classList.remove('disabled');
		}
	}

	void _setPreviewerTransform(
		double scale,
		double rotate,
		double x,
		double y,
	) {
		final HTMLImageElement? image = _previewerImage;
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
			final HTMLDivElement handle = _resizerHandleList[i];
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