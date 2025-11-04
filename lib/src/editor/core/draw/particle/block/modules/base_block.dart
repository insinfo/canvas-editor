import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

import '../../../../../dataset/constant/editor.dart';
import '../../../../../dataset/enum/block.dart';
import '../../../../../interface/block.dart';
import '../../../../../interface/editor.dart';
import '../../../../../interface/element.dart';
import '../../../../../interface/row.dart';
import '../../../draw.dart';
import '../../../../observer/image_observer.dart';
import 'i_frame_block.dart';
import 'video_block.dart';

class BaseBlock {
	BaseBlock({
		required Draw draw,
		required DivElement blockContainer,
		required IRowElement element,
	})  : _draw = draw,
			_options = draw.getOptions(),
			_blockContainer = blockContainer,
			_element = element,
			_blockCache = <String, dynamic>{},
			_resizerHandleList = <DivElement>[],
			_width = 0,
			_height = 0,
			_mousedownX = 0,
			_mousedownY = 0,
			_curHandleIndex = 0,
			_isAllowResize = false {
		final _BlockItemParts parts = _createBlockItem();
		_blockItem = parts.blockItem;
		_resizerMask = parts.resizerMask;
		_resizerSelection = parts.resizerSelection;
		_resizerHandleList.addAll(parts.resizerHandleList);
		_blockContainer.append(_blockItem);
	}

	final Draw _draw;
	final IEditorOption _options;
	final DivElement _blockContainer;
	IRowElement _element;
	final Map<String, dynamic> _blockCache;
	late final DivElement _blockItem;
	late final DivElement _resizerMask;
	late final DivElement _resizerSelection;
	final List<DivElement> _resizerHandleList;
	double _width;
	double _height;
	double _mousedownX;
	double _mousedownY;
	int _curHandleIndex;
	bool _isAllowResize;
	StreamSubscription<MouseEvent>? _mousemoveSubscription;

	List<DivElement> get resizerHandleList => _resizerHandleList;

	IRowElement getBlockElement() => _element;

	void updateElement(IRowElement element) {
		_element = element;
	}

	double getBlockWidth() {
		final double? width = _element.width;
		if (width != null && width > 0) {
			return width;
		}
		return _element.metrics.width;
	}

	_BlockItemParts _createBlockItem() {
		final double scale = _options.scale?.toDouble() ?? 1;
		final String resizerColor = _options.resizerColor ?? '#4182D9';
		final DivElement blockItem = DivElement()
			..classes.add('$editorPrefix-block-item')
			..style.position = 'absolute';
		final DivElement resizerSelection = DivElement()
			..style.display = 'none'
			..classes.add('$editorPrefix-resizer-selection')
			..style.borderColor = resizerColor
			..style.borderWidth = '${scale}px';
		final List<DivElement> resizerHandleList = <DivElement>[];
		for (int i = 0; i < 8; i++) {
			final DivElement handle = DivElement()
				..style.backgroundColor = resizerColor
				..classes.addAll(<String>['resizer-handle', 'handle-$i'])
				..dataset['index'] = '$i';
			handle.onMouseDown.listen(_mousedown);
			resizerSelection.append(handle);
			resizerHandleList.add(handle);
		}
		final DivElement resizerMask = DivElement()
			..classes.add('$editorPrefix-resizer-mask')
			..style.display = 'none';
		blockItem
			..append(resizerMask)
			..append(resizerSelection)
			..onMouseEnter.listen((_) {
				if (_draw.isReadonly()) {
					return;
				}
				final IElementMetrics metrics = _element.metrics;
				_updateResizerRect(metrics.width, metrics.height);
				resizerSelection.style.display = 'block';
			})
			..onMouseLeave.listen((_) {
				if (_isAllowResize) {
					return;
				}
				resizerSelection.style.display = 'none';
			});
		return _BlockItemParts(
			blockItem: blockItem,
			resizerMask: resizerMask,
			resizerSelection: resizerSelection,
			resizerHandleList: resizerHandleList,
		);
	}

	void _updateResizerRect(double width, double height) {
		final double handleSize = (_options.resizerSize ?? 5).toDouble();
		final double scale = _options.scale?.toDouble() ?? 1;
		_resizerSelection.style
			..width = '${width}px'
			..height = '${height}px';
		for (int i = 0; i < _resizerHandleList.length; i++) {
			final DivElement handle = _resizerHandleList[i];
			double left;
			if (i == 0 || i == 6 || i == 7) {
				left = -handleSize;
			} else if (i == 1 || i == 5) {
				left = width / 2;
			} else {
				left = width - handleSize;
			}
			double top;
			if (i == 0 || i == 1 || i == 2) {
				top = -handleSize;
			} else if (i == 3 || i == 7) {
				top = height / 2 - handleSize;
			} else {
				top = height - handleSize;
			}
			handle.style
				..transform = 'scale($scale)'
				..left = '${left}px'
				..top = '${top}px';
		}
	}

	void _mousedown(MouseEvent evt) {
		final CanvasElement? canvas = _draw.getPage();
		if (canvas == null) {
			return;
		}
		_mousedownX = evt.client.x.toDouble();
		_mousedownY = evt.client.y.toDouble();
		_isAllowResize = true;
		final EventTarget? target = evt.currentTarget ?? evt.target;
		if (target is DivElement) {
			_curHandleIndex = int.tryParse(target.dataset['index'] ?? '') ?? 0;
			final String cursor = target.getComputedStyle().cursor;
			document.body?.style.cursor = cursor;
			canvas.style.cursor = cursor;
		}
		_resizerMask.style.display = 'block';
		_mousemoveSubscription?.cancel();
		_mousemoveSubscription = document.onMouseMove.listen(_mousemove);
		document.onMouseUp.first.then((MouseEvent event) {
			final double fallbackWidth = getBlockWidth();
			final double fallbackHeight = (_element.height ?? _element.metrics.height).toDouble();
			final double nextWidth = math.min(_width > 0 ? _width : fallbackWidth, _draw.getInnerWidth());
			final double nextHeight = _height > 0 ? _height : fallbackHeight;
			_element
				..width = nextWidth
				..height = nextHeight;
			_isAllowResize = false;
			_resizerSelection.style.display = 'none';
			_resizerMask.style.display = 'none';
			_mousemoveSubscription?.cancel();
			_mousemoveSubscription = null;
			document.body?.style.cursor = '';
			canvas.style.cursor = 'text';
			_draw.render();
		});
		evt.preventDefault();
	}

	void _mousemove(MouseEvent evt) {
		if (!_isAllowResize) {
			return;
		}
		final double scale = _options.scale?.toDouble() ?? 1;
		double dx = 0;
		double dy = 0;
		final double blockWidth = getBlockWidth();
		final double elementHeight = (_element.height ?? _element.metrics.height).toDouble();
		switch (_curHandleIndex) {
			case 0:
				{
					final double offsetX = _mousedownX - evt.client.x;
					final double offsetY = _mousedownY - evt.client.y;
					dx = _combinedMagnitude(offsetX, offsetY);
					dy = (elementHeight * dx) / blockWidth;
				}
				break;
			case 1:
				dy = _mousedownY - evt.client.y;
				break;
			case 2:
				{
					final double offsetX = evt.client.x - _mousedownX;
					final double offsetY = _mousedownY - evt.client.y;
					dx = _combinedMagnitude(offsetX, offsetY);
					dy = (elementHeight * dx) / blockWidth;
				}
				break;
			case 4:
				{
					final double offsetX = evt.client.x - _mousedownX;
					final double offsetY = evt.client.y - _mousedownY;
					dx = _combinedMagnitude(offsetX, offsetY);
					dy = (elementHeight * dx) / blockWidth;
				}
				break;
			case 3:
				dx = evt.client.x - _mousedownX;
				break;
			case 5:
				dy = evt.client.y - _mousedownY;
				break;
			case 6:
				{
					final double offsetX = _mousedownX - evt.client.x;
					final double offsetY = evt.client.y - _mousedownY;
					dx = _combinedMagnitude(offsetX, offsetY);
					dy = (elementHeight * dx) / blockWidth;
				}
				break;
			case 7:
				dx = _mousedownX - evt.client.x;
				break;
		}
		final double dw = blockWidth + dx / scale;
		final double dh = elementHeight + dy / scale;
		if (dw <= 0 || dh <= 0) {
			return;
		}
		_width = dw;
		_height = dh;
		final double elementWidth = dw * scale;
		final double elementHeightPx = dh * scale;
		_updateResizerRect(elementWidth, elementHeightPx);
		_blockItem.style
			..width = '${elementWidth}px'
			..height = '${elementHeightPx}px';
		evt.preventDefault();
	}

	void snapshot(CanvasRenderingContext2D ctx, double x, double y) {
		final IBlock? block = _element.block;
		if (block == null || block.type != BlockType.video) {
			return;
		}
		_blockItem.style.display = 'none';
		final String? elementId = _element.id;
		if (elementId == null) {
			return;
		}
		if (_blockCache.containsKey(elementId)) {
			final VideoBlock videoBlock = _blockCache[elementId] as VideoBlock;
			videoBlock.snapshot(ctx, x, y);
			return;
		}
		final VideoBlock videoBlock = VideoBlock(_element);
		final Future<dynamic> promise = videoBlock.snapshot(ctx, x, y);
		final dynamic observer = _draw.getImageObserver();
		if (observer is ImageObserver) {
			observer.add(promise);
		} else {
			try {
				observer?.add(promise);
			} catch (_) {}
		}
		_blockCache[elementId] = videoBlock;
	}

	void render() {
		final IBlock? block = _element.block;
		if (block == null) {
			return;
		}
		_blockItem.children.clear();
		_blockItem
			..append(_resizerMask)
			..append(_resizerSelection);
		if (block.type == BlockType.iframe) {
			final IFrameBlock iframeBlock = IFrameBlock(_element);
			iframeBlock.render(_blockItem);
		} else if (block.type == BlockType.video) {
			final VideoBlock videoBlock = VideoBlock(_element);
			videoBlock.render(_blockItem);
		}
	}

	void setClientRects(int pageNo, double x, double y) {
		final double pageHeight = _draw.getHeight();
		final double pageGap = _draw.getPageGap();
		final double preY = pageNo * (pageHeight + pageGap);
		final IElementMetrics metrics = _element.metrics;
		_blockItem.style
			..display = 'block'
			..width = '${metrics.width}px'
			..height = '${metrics.height}px'
			..left = '${x}px'
			..top = '${preY + y}px';
	}

	void remove() {
		_blockItem.remove();
	}

	double _combinedMagnitude(double offsetX, double offsetY) {
		final num x3 = math.pow(offsetX, 3);
		final num y3 = math.pow(offsetY, 3);
		final double sum = (x3 + y3).toDouble();
		if (sum == 0) {
			return 0;
		}
		final bool isNegative = sum < 0;
		final double result = math.pow(sum.abs(), 1 / 3).toDouble();
		return isNegative ? -result : result;
	}
}

class _BlockItemParts {
	_BlockItemParts({
		required this.blockItem,
		required this.resizerMask,
		required this.resizerSelection,
		required this.resizerHandleList,
	});

	final DivElement blockItem;
	final DivElement resizerMask;
	final DivElement resizerSelection;
	final List<DivElement> resizerHandleList;
}