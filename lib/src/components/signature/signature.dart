import 'dart:html';
import 'dart:math' as math;

import '../../editor/dataset/constant/editor.dart';
import '../../editor/dataset/enum/editor.dart';

class SignatureResult {
	SignatureResult({required this.value, required this.width, required this.height});

	final String value;
	final double width;
	final double height;
}

class SignatureOptions {
	SignatureOptions({this.width, this.height, this.onClose, this.onCancel, this.onConfirm});

	final double? width;
	final double? height;
	final void Function()? onClose;
	final void Function()? onCancel;
	final void Function(SignatureResult?)? onConfirm;
}

class Signature {
	Signature(SignatureOptions options) : _options = options {
		_dpr = window.devicePixelRatio.toDouble();
		_canvasWidth = (options.width ?? _defaultWidth) * _dpr;
		_canvasHeight = (options.height ?? _defaultHeight) * _dpr;
		final _RenderResult renderResult = _render();
		_mask = renderResult.mask;
		_container = renderResult.container;
		_trashContainer = renderResult.trashContainer;
		_undoContainer = renderResult.undoContainer;
		_canvas = renderResult.canvas;
		final CanvasRenderingContext2D? context = _canvas.getContext('2d') as CanvasRenderingContext2D?;
		if (context == null) {
			throw StateError('Failed to obtain 2D context for signature canvas.');
		}
		_ctx = context
			..scale(_dpr, _dpr)
			..lineCap = 'round';
		_bindEvent();
		_clearUndoFn();
		document.documentElement?.classes.add('overflow-hidden');
		document.body?.classes.add('overflow-hidden');
		_container.classes.add('overflow-hidden');
	}

	static const int _maxRecordCount = 1000;
	static const double _defaultWidth = 390;
	static const double _defaultHeight = 180;

	final SignatureOptions _options;
	late final double _dpr;
	late final double _canvasWidth;
	late final double _canvasHeight;
	final List<Point<double>> _linePoints = <Point<double>>[];
	List<void Function()> _undoStack = <void Function()>[];
	double _x = 0;
	double _y = 0;
	double _preTimeStamp = 0;
	bool _isDrawing = false;
	bool _isDrawn = false;
	late final DivElement _mask;
	late final DivElement _container;
	late final DivElement _trashContainer;
	late final DivElement _undoContainer;
	late final CanvasElement _canvas;
	late final CanvasRenderingContext2D _ctx;

	_RenderResult _render() {
		final body = document.body;
		if (body == null) {
			throw StateError('Document body is not available.');
		}
		final mask = DivElement()
			..classes.add('signature-mask')
			..setAttribute(editorComponent, EditorComponent.component.name);
		body.append(mask);
		final container = DivElement()
			..classes.add('signature-container')
			..setAttribute(editorComponent, EditorComponent.component.name);
		final signatureContainer = DivElement()..classes.add('signature');
		container.append(signatureContainer);
		final titleContainer = DivElement()..classes.add('signature-title');
		final titleSpan = SpanElement()..text = '插入签名';
		final titleClose = Element.tag('i');
		titleClose.onClick.listen((_) {
			_options.onClose?.call();
			_dispose();
		});
		titleContainer
			..append(titleSpan)
			..append(titleClose);
		signatureContainer.append(titleContainer);
		final operationContainer = DivElement()..classes.add('signature-operation');
		final undoContainer = DivElement()..classes.add('signature-operation__undo');
		final undoIcon = Element.tag('i');
		final undoLabel = SpanElement()..text = '撤销';
		undoContainer
			..append(undoIcon)
			..append(undoLabel);
		operationContainer.append(undoContainer);
		final trashContainer = DivElement()..classes.add('signature-operation__trash');
		final trashIcon = Element.tag('i');
		final trashLabel = SpanElement()..text = '清空';
		trashContainer
			..append(trashIcon)
			..append(trashLabel);
		operationContainer.append(trashContainer);
		signatureContainer.append(operationContainer);
		final canvasContainer = DivElement()..classes.add('signature-canvas');
		final canvas = CanvasElement()
			..width = _canvasWidth.round()
			..height = _canvasHeight.round();
		canvas.style
			..width = '${_canvasWidth / _dpr}px'
			..height = '${_canvasHeight / _dpr}px';
		canvasContainer.append(canvas);
		signatureContainer.append(canvasContainer);
		final menuContainer = DivElement()..classes.add('signature-menu');
		final cancelButton = ButtonElement()
			..classes.add('signature-menu__cancel')
			..text = '取消'
			..type = 'button';
		cancelButton.onClick.listen((_) {
			_options.onCancel?.call();
			_dispose();
		});
		menuContainer.append(cancelButton);
		final confirmButton = ButtonElement()
			..text = '确定'
			..type = 'submit';
		confirmButton.onClick.listen((_) {
			_options.onConfirm?.call(_toData());
			_dispose();
		});
		menuContainer.append(confirmButton);
		signatureContainer.append(menuContainer);
		body.append(container);
		return _RenderResult(
			mask: mask,
			container: container,
			trashContainer: trashContainer,
			undoContainer: undoContainer,
			canvas: canvas,
		);
	}

	void _bindEvent() {
		_trashContainer.onClick.listen((_) => _clearCanvas());
		_undoContainer.onClick.listen((_) => _undo());
		_canvas.onMouseDown.listen(_startDraw);
		_canvas.onMouseMove.listen(_draw);
		_container.onMouseUp.listen((_) => _stopDraw());
		_container.onTouchStart.listen(registerTouchstart);
		_container.onTouchMove.listen(registerTouchmove);
		_container.onTouchEnd.listen((_) => registerTouchend());
	}

	void _undo() {
		if (_undoStack.length > 1) {
			_undoStack.removeLast();
			if (_undoStack.isNotEmpty) {
				_undoStack.last();
			}
		}
	}

	void _saveUndoFn(void Function() fn) {
		_undoStack.add(fn);
		while (_undoStack.length > _maxRecordCount) {
			_undoStack.removeAt(0);
		}
	}

	void _clearUndoFn() {
		void clearFn() {
			_ctx.clearRect(0, 0, _canvasWidth, _canvasHeight);
		}
		_undoStack = <void Function()>[clearFn];
	}

	void _clearCanvas() {
		_clearUndoFn();
		_ctx.clearRect(0, 0, _canvasWidth, _canvasHeight);
	}

	void _startDraw(MouseEvent event) {
		_isDrawing = true;
		_x = event.offset.x.toDouble();
		_y = event.offset.y.toDouble();
		_ctx.lineWidth = 1;
	}

	void _draw(MouseEvent event) {
		if (!_isDrawing) {
			return;
		}
		final double currentTimestamp = window.performance.now();
		final double dx = event.offset.x.toDouble() - _x;
		final double dy = event.offset.y.toDouble() - _y;
		final double distance = math.sqrt(dx * dx + dy * dy);
		final double delta = currentTimestamp - _preTimeStamp;
		final double speed = delta <= 0 ? 0 : distance / delta;
		const double speedFactor = 3;
		const double smoothFactor = 0.2;
		final double targetLineWidth = math.min(5, math.max(1, 5 - speed * speedFactor));
		_ctx.lineWidth = _ctx.lineWidth * (1 - smoothFactor) + targetLineWidth * smoothFactor;
		final double offsetX = event.offset.x.toDouble();
		final double offsetY = event.offset.y.toDouble();
		_ctx
			..beginPath()
			..moveTo(_x, _y)
			..lineTo(offsetX, offsetY)
			..stroke();
		_x = offsetX;
		_y = offsetY;
		_linePoints.add(Point<double>(offsetX, offsetY));
		_isDrawn = true;
		_preTimeStamp = currentTimestamp;
	}

	void _stopDraw() {
		_isDrawing = false;
		if (_isDrawn) {
			final ImageData imageData = _ctx.getImageData(0, 0, _canvasWidth.round(), _canvasHeight.round());
				final double width = _canvasWidth;
				final double height = _canvasHeight;
			_saveUndoFn(() {
				_ctx.clearRect(0, 0, width, height);
				_ctx.putImageData(imageData, 0, 0);
			});
			_isDrawn = false;
		}
	}

	SignatureResult? _toData() {
		if (_linePoints.isEmpty) {
			return null;
		}
		double minX = _linePoints.first.x;
		double minY = _linePoints.first.y;
		double maxX = minX;
		double maxY = minY;
		for (final point in _linePoints) {
			if (minX > point.x) {
				minX = point.x;
			}
			if (maxX < point.x) {
				maxX = point.x;
			}
			if (minY > point.y) {
				minY = point.y;
			}
			if (maxY < point.y) {
				maxY = point.y;
			}
		}
		final double lineWidth = _ctx.lineWidth.toDouble();
		minX = minX < lineWidth ? 0 : minX - lineWidth;
		minY = minY < lineWidth ? 0 : minY - lineWidth;
		maxX += lineWidth;
		maxY += lineWidth;
		final double sw = maxX - minX;
		final double sh = maxY - minY;
		final ImageData imageData = _ctx.getImageData(
			(minX * _dpr).round(),
			(minY * _dpr).round(),
			(sw * _dpr).round(),
			(sh * _dpr).round(),
		);
		final CanvasElement canvas = CanvasElement()
			..style.width = '${sw}px'
			..style.height = '${sh}px'
			..width = (sw * _dpr).round()
			..height = (sh * _dpr).round();
		final CanvasRenderingContext2D? context = canvas.getContext('2d') as CanvasRenderingContext2D?;
		if (context == null) {
			return null;
		}
		context.putImageData(imageData, 0, 0);
		final String value = canvas.toDataUrl();
		return SignatureResult(value: value, width: sw, height: sh);
	}

	void registerTouchmove(TouchEvent event) {
		_registerTouchEvent(event, 'mousemove');
	}

	void registerTouchstart(TouchEvent event) {
		_registerTouchEvent(event, 'mousedown');
	}

	void registerTouchend() {
		final MouseEvent mouseEvent = MouseEvent('mouseup');
		_canvas.dispatchEvent(mouseEvent);
	}

	void _registerTouchEvent(TouchEvent event, String eventName) {
		final TouchList? touches = event.touches;
		if (touches == null || touches.length == 0) {
			return;
		}
		final Touch? touch = touches.item(0);
		if (touch == null) {
			return;
		}
		final Point<num>? client = touch.client;
		if (client == null) {
			return;
		}
		final MouseEvent mouseEvent = MouseEvent(
			eventName,
			clientX: client.x.toInt(),
			clientY: client.y.toInt(),
		);
		_canvas.dispatchEvent(mouseEvent);
	}

	void _dispose() {
		_mask.remove();
		_container.remove();
		document.documentElement?.classes.remove('overflow-hidden');
		document.body?.classes.remove('overflow-hidden');
	}
}

class _RenderResult {
	_RenderResult({required this.mask, required this.container, required this.trashContainer, required this.undoContainer, required this.canvas});

	final DivElement mask;
	final DivElement container;
	final DivElement trashContainer;
	final DivElement undoContainer;
	final CanvasElement canvas;
}