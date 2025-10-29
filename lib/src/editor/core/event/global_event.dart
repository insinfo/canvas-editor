// TODO: Translate from C:\\MyTsProjects\\canvas-editor\\src\\editor\\core\\event\\GlobalEvent.ts
import 'dart:async';
import 'dart:html';
import 'dart:js_util' as js_util;

import '../../dataset/constant/editor.dart';
import '../../dataset/constant/shortcut.dart';
import '../../interface/draw.dart';
import '../../interface/editor.dart';
import '../../interface/range.dart';
import '../../utils/index.dart' show findParent;
import '../cursor/cursor.dart';
import '../range/range_manager.dart';

class GlobalEvent {
	GlobalEvent(this.draw, this.canvasEvent)
			: options = draw.getOptions() as IEditorOption,
				range = draw.getRange() as RangeManager,
				previewer = draw.getPreviewer(),
				tableTool = draw.getTableTool(),
				hyperlinkParticle = draw.getHyperlinkParticle(),
				control = draw.getControl(),
				dateParticle = draw.getDateParticle(),
				imageParticle = draw.getImageParticle(),
				dprMediaQueryList = window.matchMedia(
					'(resolution: ${window.devicePixelRatio}dppx)',
				) {
		_initListeners();
	}

	final dynamic draw;
	final IEditorOption options;
	Cursor? cursor;
	final dynamic canvasEvent;
	final RangeManager range;
	final dynamic previewer;
	final dynamic tableTool;
	final dynamic hyperlinkParticle;
	final dynamic control;
	final dynamic dateParticle;
	final dynamic imageParticle;
	final MediaQueryList dprMediaQueryList;

	late final EventListener _clearSideEffectListener;
	late final EventListener _setCanvasEventAbilityListener;
	late final EventListener _setPageScaleListener;
	late final EventListener _visibilityChangeListener;
	late final dynamic _dprChangeListener;
	bool _dprUsesEventListener = false;
	bool _isRegistered = false;

	void register() {
		cursor = draw.getCursor() as Cursor?;
		if (_isRegistered) {
			return;
		}
		_addEvent();
		_isRegistered = true;
	}

	void removeEvent() {
		if (!_isRegistered) {
			return;
		}
		window.removeEventListener('blur', _clearSideEffectListener);
		document.removeEventListener('mousedown', _clearSideEffectListener);
		document.removeEventListener('mouseup', _setCanvasEventAbilityListener);
		document.removeEventListener('wheel', _setPageScaleListener);
		document.removeEventListener('visibilitychange', _visibilityChangeListener);
		if (_dprUsesEventListener) {
			js_util.callMethod(
				dprMediaQueryList,
				'removeEventListener',
				<dynamic>['change', _dprChangeListener],
			);
		} else {
			js_util.callMethod(
				dprMediaQueryList,
				'removeListener',
				<dynamic>[_dprChangeListener],
			);
		}
		_isRegistered = false;
	}

	void clearSideEffect(Event evt) {
		if (cursor == null) {
			return;
		}

		final Element? target = _resolveEventTarget(evt);
		if (target == null) {
			_resetState();
			return;
		}

		final List<Element> pageList = _resolvePageList();
		final Element? innerEditorDom = findParent(
			target,
			(Element element) => pageList.contains(element),
			true,
		);
		if (innerEditorDom != null) {
			return;
		}

		final Element? outerEditorDom = findParent(
			target,
			(Element element) {
				final String? attribute = element.getAttribute(editorComponent);
				return attribute != null && attribute.isNotEmpty;
			},
			true,
		);

		if (outerEditorDom != null) {
			watchCursorActive();
			return;
		}

		_resetState();
	}

	void setCanvasEventAbility([Event? _]) {
		try {
			canvasEvent.setIsAllowDrag(false);
		} catch (_) {}
		try {
			canvasEvent.setIsAllowSelection(false);
		} catch (_) {}
	}

	void watchCursorActive() {
		if (range.getIsCollapsed() != true) {
			return;
		}
		Timer.run(() {
			final bool isActive = cursor?.getAgentIsActive() ?? false;
			if (!isActive) {
				cursor?.drawCursor(IDrawCursorOption(
					isFocus: false,
					isBlink: false,
				));
			}
		});
	}

	void setPageScale(WheelEvent evt) {
		final String? pageScaleKey = internalShortcutKey['PAGE_SCALE'];
		final List<String>? disableKeys = options.shortcutDisableKeys;
		if (pageScaleKey != null && disableKeys != null) {
			if (disableKeys.contains(pageScaleKey)) {
				return;
			}
		}
		if (!evt.ctrlKey) {
			return;
		}
		evt.preventDefault();
		final double scale = options.scale?.toDouble() ?? 1;
		if (evt.deltaY < 0) {
			final double nextScale = scale * 10 + 1;
			if (nextScale <= 30) {
				try {
					draw.setPageScale(nextScale / 10);
				} catch (_) {}
			}
		} else {
			final double nextScale = scale * 10 - 1;
			if (nextScale >= 5) {
				try {
					draw.setPageScale(nextScale / 10);
				} catch (_) {}
			}
		}
	}

	void _handleVisibilityChange([Event? _]) {
		if (document.visibilityState != 'visible') {
			return;
		}
		try {
			final IRange currentRange = range.getRange();
			final bool isSetCursor = currentRange.startIndex >= 0 &&
					currentRange.endIndex >= 0 &&
					currentRange.startIndex == currentRange.endIndex;
			range.replaceRange(currentRange);
					draw.render(IDrawOption(
						isSetCursor: isSetCursor,
						isCompute: false,
						isSubmitHistory: false,
						curIndex: currentRange.startIndex,
					));
		} catch (_) {}
	}

	void _handleDprChange([Event? _]) {
		try {
			draw.setPageDevicePixel();
		} catch (_) {}
	}

	void _addEvent() {
		window.addEventListener('blur', _clearSideEffectListener);
		document.addEventListener('mousedown', _clearSideEffectListener);
		document.addEventListener('mouseup', _setCanvasEventAbilityListener);
		js_util.callMethod(
			document,
			'addEventListener',
			<dynamic>[
				'wheel',
				_setPageScaleListener,
				js_util.jsify(<String, dynamic>{'passive': false}),
			],
		);
		document.addEventListener('visibilitychange', _visibilityChangeListener);
		if (_dprUsesEventListener) {
			js_util.callMethod(
				dprMediaQueryList,
				'addEventListener',
				<dynamic>['change', _dprChangeListener],
			);
		} else {
			js_util.callMethod(
				dprMediaQueryList,
				'addListener',
				<dynamic>[_dprChangeListener],
			);
		}
	}

	void _initListeners() {
		_clearSideEffectListener = js_util.allowInterop(clearSideEffect);
		_setCanvasEventAbilityListener = js_util.allowInterop(setCanvasEventAbility);
		_setPageScaleListener = js_util.allowInterop((Event event) {
			if (event is WheelEvent) {
				setPageScale(event);
			}
		});
		_visibilityChangeListener = js_util.allowInterop(_handleVisibilityChange);
		_dprUsesEventListener =
				js_util.hasProperty(dprMediaQueryList, 'addEventListener') == true;
		_dprChangeListener = js_util.allowInterop((Event? event) {
			_handleDprChange(event);
		});
	}

	void _resetState() {
		cursor?.recoveryCursor();
		try {
			range.recoveryRangeStyle();
		} catch (_) {}
		if (previewer != null) {
			try {
				previewer.clearResizer();
			} catch (_) {}
		}
		if (tableTool != null) {
			try {
				tableTool.dispose();
			} catch (_) {}
		}
		if (hyperlinkParticle != null) {
			try {
				hyperlinkParticle.clearHyperlinkPopup();
			} catch (_) {}
		}
		if (control != null) {
			try {
				control.destroyControl();
			} catch (_) {}
		}
		if (dateParticle != null) {
			try {
				dateParticle.clearDatePicker();
			} catch (_) {}
		}
		if (imageParticle != null) {
			try {
				imageParticle.destroyFloatImage();
			} catch (_) {}
		}
	}

	Element? _resolveEventTarget(Event event) {
		try {
			if (js_util.hasProperty(event, 'composedPath')) {
				final dynamic path = js_util.callMethod(event, 'composedPath', const []);
				final dynamic dartPath = js_util.dartify(path);
				if (dartPath is List && dartPath.isNotEmpty) {
					final dynamic first = dartPath.first;
					if (first is Element) {
						return first;
					}
				}
				final dynamic first = js_util.getProperty(path, '0');
				if (first is Element) {
					return first;
				}
			}
		} catch (_) {}
		final EventTarget? target = event.target;
		if (target is Element) {
			return target;
		}
		return null;
	}

	List<Element> _resolvePageList() {
		try {
			final dynamic pageList = draw.getPageList();
			if (pageList is List<Element>) {
				return pageList;
			}
			if (pageList is Iterable) {
				return pageList.whereType<Element>().toList();
			}
		} catch (_) {}
		return <Element>[];
	}
}