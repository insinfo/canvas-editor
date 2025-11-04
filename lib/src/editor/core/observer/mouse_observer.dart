import 'dart:async';
import 'dart:html';

import '../../interface/event_bus.dart';
import '../draw/draw.dart';
import '../event/eventbus/event_bus.dart';


class MouseObserver {
	MouseObserver(Draw draw)
		: _eventBus = (draw.getEventBus() as EventBus<EventBusMap>?) ?? EventBus<EventBusMap>(),
			_pageContainer = draw.getPageContainer() {
		_register();
	}

	final EventBus<EventBusMap> _eventBus;
	final DivElement _pageContainer;
	final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

	void dispose() {
		for (final StreamSubscription<dynamic> subscription in _subscriptions) {
			subscription.cancel();
		}
		_subscriptions.clear();
	}

	void _register() {
		_subscriptions
			..add(_pageContainer.onMouseMove.listen((MouseEvent evt) => _emit('mousemove', evt)))
			..add(_pageContainer.onMouseEnter.listen((MouseEvent evt) => _emit('mouseenter', evt)))
			..add(_pageContainer.onMouseLeave.listen((MouseEvent evt) => _emit('mouseleave', evt)))
			..add(_pageContainer.onMouseDown.listen((MouseEvent evt) => _emit('mousedown', evt)))
			..add(_pageContainer.onMouseUp.listen((MouseEvent evt) => _emit('mouseup', evt)))
			..add(_pageContainer.onClick.listen((MouseEvent evt) => _emit('click', evt)));
	}

	void _emit(String eventName, MouseEvent evt) {
		if (_eventBus.isSubscribe(eventName)) {
			_eventBus.emit(eventName, evt);
		}
	}
}