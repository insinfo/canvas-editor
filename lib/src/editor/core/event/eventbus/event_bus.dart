import 'dart:collection';

/// Simple pub/sub hub mirroring the TypeScript implementation.
class EventBus<T> {
	EventBus() : _eventHub = HashMap<String, Set<Function>>();

	final Map<String, Set<Function>> _eventHub;

	void on(String eventName, Function callback) {
		if (eventName.isEmpty) {
			return;
		}
		final callbacks = _eventHub.putIfAbsent(eventName, () => <Function>{});
		callbacks.add(callback);
	}

	void emit(String eventName, [dynamic payload]) {
		if (eventName.isEmpty) {
			return;
		}
		final callbacks = _eventHub[eventName];
		if (callbacks == null || callbacks.isEmpty) {
			return;
		}
		if (callbacks.length == 1) {
			callbacks.first(payload);
			return;
		}
		for (final callback in callbacks) {
			callback(payload);
		}
	}

	void off(String eventName, Function callback) {
		if (eventName.isEmpty) {
			return;
		}
		final callbacks = _eventHub[eventName];
		callbacks?.remove(callback);
	}

	bool isSubscribe(String eventName) {
		final callbacks = _eventHub[eventName];
		return callbacks != null && callbacks.isNotEmpty;
	}
}