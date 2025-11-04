import 'dart:async';
import 'dart:html';

import '../../dataset/enum/observer.dart';
import '../../interface/editor.dart';
import '../draw/draw.dart';
import '../range/range_manager.dart';

class SelectionObserver {
	SelectionObserver(Draw draw)
		: _rangeManager = draw.getRange() as RangeManager,
			_selectionContainer = _resolveSelectionContainer(draw),
			_requestAnimationFrameId = null,
			_isMousedown = false,
			_isMoving = false,
			_clientWidth = 0,
			_clientHeight = 0,
			_containerRect = null {
		_addEvent();
	}

	static const double _step = 5;
	static const List<double> _thresholdPoints = <double>[70, 40, 10, 20];

	final RangeManager _rangeManager;
	final dynamic _selectionContainer;
	final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];
	int? _requestAnimationFrameId;
	bool _isMousedown;
	bool _isMoving;
	double _clientWidth;
	double _clientHeight;
	Rectangle<num>? _containerRect;

	void dispose() {
		_stopMove();
		for (final StreamSubscription<dynamic> subscription in _subscriptions) {
			subscription.cancel();
		}
		_subscriptions.clear();
	}

	void _addEvent() {
		_subscriptions
			..add(_mouseDownStream().listen(_mousedown))
			..add(_mouseMoveStream().listen(_mousemove))
			..add(_mouseUpStream().listen((_) => _mouseup()))
			..add(document.onMouseLeave.listen((_) => _mouseup()));
	}

	Stream<MouseEvent> _mouseDownStream() {
		if (_selectionContainer is Document) {
			return document.onMouseDown;
		}
		return (_selectionContainer as Element).onMouseDown;
	}

	Stream<MouseEvent> _mouseMoveStream() {
		if (_selectionContainer is Document) {
			return document.onMouseMove;
		}
		return (_selectionContainer as Element).onMouseMove;
	}

	Stream<MouseEvent> _mouseUpStream() {
		if (_selectionContainer is Document) {
			return document.onMouseUp;
		}
		return (_selectionContainer as Element).onMouseUp;
	}

	void _mousedown(MouseEvent _) {
		_isMousedown = true;
		if (_selectionContainer is Document) {
			_clientWidth = document.documentElement?.clientWidth.toDouble() ?? window.innerWidth?.toDouble() ?? 0;
			_clientHeight = document.documentElement?.clientHeight.toDouble() ?? window.innerHeight?.toDouble() ?? 0;
			_containerRect = null;
		} else {
			final Element container = _selectionContainer as Element;
			_clientWidth = container.clientWidth.toDouble();
			_clientHeight = container.clientHeight.toDouble();
			_containerRect = container.getBoundingClientRect();
		}
	}

	void _mouseup() {
		_isMousedown = false;
		_stopMove();
	}

	void _mousemove(MouseEvent evt) {
		if (!_isMousedown || _rangeManager.getIsCollapsed()) {
			return;
		}
		double x = evt.client.x.toDouble();
		double y = evt.client.y.toDouble();
		if (_containerRect != null) {
			x -= _containerRect!.left.toDouble();
			y -= _containerRect!.top.toDouble();
		}
		if (y < _thresholdPoints[0]) {
			_startMove(MoveDirection.up);
		} else if (_clientHeight - y <= _thresholdPoints[1]) {
			_startMove(MoveDirection.down);
		} else if (x < _thresholdPoints[2]) {
			_startMove(MoveDirection.left);
		} else if (_clientWidth - x < _thresholdPoints[3]) {
			_startMove(MoveDirection.right);
		} else {
			_stopMove();
		}
	}

	void _move(MoveDirection direction) {
		if (_selectionContainer is Document) {
			final double x = window.scrollX.toDouble();
			final double y = window.scrollY.toDouble();
			if (direction == MoveDirection.down) {
				window.scrollTo(x, y + _step);
			} else if (direction == MoveDirection.up) {
				window.scrollTo(x, y - _step);
			} else if (direction == MoveDirection.left) {
				window.scrollTo(x - _step, y);
			} else {
				window.scrollTo(x + _step, y);
			}
		} else {
			final Element container = _selectionContainer as Element;
			final int x = container.scrollLeft;
			final int y = container.scrollTop;
			if (direction == MoveDirection.down) {
				container.scrollTop = (y + _step).round();
			} else if (direction == MoveDirection.up) {
				container.scrollTop = (y - _step).round();
			} else if (direction == MoveDirection.left) {
				container.scrollLeft = (x - _step).round();
			} else {
				container.scrollLeft = (x + _step).round();
			}
		}
		_requestAnimationFrameId = window.requestAnimationFrame((_) => _move(direction));
	}

	void _startMove(MoveDirection direction) {
		if (_isMoving) {
			return;
		}
		_isMoving = true;
		_move(direction);
	}

	void _stopMove() {
		if (_requestAnimationFrameId != null) {
			window.cancelAnimationFrame(_requestAnimationFrameId!);
			_requestAnimationFrameId = null;
		}
		_isMoving = false;
	}

	static dynamic _resolveSelectionContainer(Draw draw) {
		final IEditorOption? options = draw.getOptions() as IEditorOption?;
		final String? selector = options?.scrollContainerSelector;
		if (selector != null && selector.isNotEmpty) {
			final Element? container = document.querySelector(selector);
			if (container != null) {
				return container;
			}
		}
		return document;
	}
}