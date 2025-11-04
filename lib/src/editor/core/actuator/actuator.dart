import '../../interface/event_bus.dart';
import '../../interface/listener.dart';
import '../../interface/position.dart';
import '../draw/draw.dart';
import '../event/eventbus/event_bus.dart';
import 'handlers/position_context_change.dart';

/// Bridges low-level editor events to concrete side-effect handlers.
class Actuator {
	Actuator(this._draw)
		: _eventBus = (_draw.getEventBus() as EventBus<EventBusMap>?) ?? EventBus<EventBusMap>() {
		_registerHandlers();
	}

	final Draw _draw;
	final EventBus<EventBusMap> _eventBus;

	void _registerHandlers() {
		_eventBus.on('positionContextChange', (dynamic payload) {
			final IPositionContextChangePayload? typedPayload = _normalizePayload(payload);
			if (typedPayload == null) {
				return;
			}
			positionContextChange(_draw, typedPayload);
		});
	}

	IPositionContextChangePayload? _normalizePayload(dynamic payload) {
		if (payload is IPositionContextChangePayload) {
			return payload;
		}
		if (payload is Map<String, dynamic>) {
			final dynamic value = payload['value'];
			final dynamic oldValue = payload['oldValue'];
			if (value is IPositionContext && oldValue is IPositionContext) {
				return IPositionContextChangePayload(value: value, oldValue: oldValue);
			}
		}
		return null;
	}
}