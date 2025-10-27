import 'dart:async';
import 'dart:html';
import 'dart:js' as js;
import 'dart:js_util' as js_util;

typedef Callback = void Function();

Callback debounce(Callback func, Duration delay) {
	Timer? timer;
	return () {
		timer?.cancel();
		timer = Timer(delay, func);
	};
}

void scrollIntoView(Element container, Element? selected) {
	if (selected == null) {
		container.scrollTop = 0;
		return;
	}

	final offsetParents = <Element>[];
	Element? pointer = selected.offsetParent;
	while (pointer != null && pointer != container && container.contains(pointer)) {
		offsetParents.add(pointer);
		pointer = pointer.offsetParent;
	}

	final top = selected.offsetTop +
			offsetParents.fold<int>(0, (prev, curr) => prev + curr.offsetTop);
	final bottom = top + selected.offsetHeight;
	final viewRectTop = container.scrollTop;
	final viewRectBottom = viewRectTop + container.clientHeight;

	if (top < viewRectTop) {
		container.scrollTop = top;
	} else if (bottom > viewRectBottom) {
		container.scrollTop = bottom - container.clientHeight;
	}
}

void nextTick(Callback fn) {
	if (js_util.hasProperty(window, 'requestIdleCallback')) {
		js_util.callMethod(window, 'requestIdleCallback', [
			js.allowInterop((Object? _) => fn()),
		]);
	} else {
		Timer(Duration.zero, fn);
	}
}