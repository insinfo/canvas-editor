import 'dart:async';
import 'package:canvas_text_editor/src/dom/dom.dart';

import '../../dataset/constant/editor.dart';
import '../../dataset/constant/shortcut.dart';
import '../../interface/draw.dart';
import '../../interface/editor.dart';
import '../../interface/range.dart';
import '../../utils/index.dart' show findParent;
import '../cursor/cursor.dart';
import '../range/range_manager.dart';
import '../draw/control/control.dart';
import '../draw/draw.dart';
import '../draw/particle/date/date_particle.dart';
import '../draw/particle/hyperlink_particle.dart';
import '../draw/particle/image_particle.dart';
import '../draw/particle/previewer/previewer.dart';
import '../draw/particle/table/table_tool.dart';
import './canvas_event.dart';

class GlobalEvent {
	GlobalEvent(this.draw, this.canvasEvent)
			: options = draw.getOptions(),
				range = draw.getRange() as RangeManager,
				previewer = draw.getPreviewer() as Previewer?,
				tableTool = draw.getTableTool() as TableTool?,
				hyperlinkParticle = draw.getHyperlinkParticle() as HyperlinkParticle?,
				control = draw.getControl() as Control?,
				dateParticle = draw.getDateParticle() as DateParticle?,
				imageParticle = draw.getImageParticle() as ImageParticle?,
				dprMediaQueryList = window.matchMedia(
					'(resolution: ${window.devicePixelRatio}dppx)',
				) {
		_initListeners();
	}

	final Draw draw;
	final IEditorOption options;
	Cursor? cursor;
	final CanvasEvent canvasEvent;
	final RangeManager range;
	final Previewer? previewer;
	final TableTool? tableTool;
	final HyperlinkParticle? hyperlinkParticle;
	final Control? control;
	final DateParticle? dateParticle;
	final ImageParticle? imageParticle;
	final MediaQueryList dprMediaQueryList;

	late final EventListener _clearSideEffectListener;
	late final EventListener _setCanvasEventAbilityListener;
	late final EventListener _setPageScaleListener;
	late final EventListener _visibilityChangeListener;
	late final dynamic _dprChangeListener;
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
		dprMediaQueryList.removeEventListener('change', _dprChangeListener);
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
		canvasEvent.setIsAllowDrag(false);
		canvasEvent.setIsAllowSelection(false);
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
		final List<String> disableKeys = options.shortcutDisableKeys ?? const <String>[];
		if (pageScaleKey != null && disableKeys.contains(pageScaleKey)) {
			return;
		}
		if (!evt.ctrlKey) {
			return;
		}
		evt.preventDefault();
		final double scale = (options.scale ?? 1).toDouble();
		if (evt.deltaY < 0) {
			final double nextScale = scale * 10 + 1;
			if (nextScale <= 30) {
				draw.setPageScale(nextScale / 10);
			}
		} else {
			final double nextScale = scale * 10 - 1;
			if (nextScale >= 5) {
				draw.setPageScale(nextScale / 10);
			}
		}
	}

	void _handleVisibilityChange([Event? _]) {
		if (document.visibilityState != 'visible') {
			return;
		}
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
	}

	void _handleDprChange([Event? _]) {
		draw.setPageDevicePixel();
	}

	void _addEvent() {
		window.addEventListener('blur', _clearSideEffectListener);
		document.addEventListener('mousedown', _clearSideEffectListener);
		document.addEventListener('mouseup', _setCanvasEventAbilityListener);
		document.addEventListener(
			'wheel',
			_setPageScaleListener,
			AddEventListenerOptions(passive: false),
		);
		document.addEventListener('visibilitychange', _visibilityChangeListener);
		dprMediaQueryList.addEventListener('change', _dprChangeListener);
	}

	void _initListeners() {
		// Callbacks convertidos UMA vez (.toJS de novo geraria outra função JS e
		// o removeEventListener não acharia o listener registrado).
		_clearSideEffectListener = ((Event event) => clearSideEffect(event)).toJS;
		_setCanvasEventAbilityListener =
				((Event event) => setCanvasEventAbility(event)).toJS;
		_setPageScaleListener = ((Event event) {
			if (event.isA<WheelEvent>()) {
				setPageScale(event as WheelEvent);
			}
		}).toJS;
		_visibilityChangeListener =
				((Event event) => _handleVisibilityChange(event)).toJS;
		_dprChangeListener = ((Event event) => _handleDprChange(event)).toJS;
	}

	void _resetState() {
		cursor?.recoveryCursor();
		range.recoveryRangeStyle();
		previewer?.clearResizer();
		tableTool?.dispose();
		hyperlinkParticle?.clearHyperlinkPopup();
		control?.destroyControl();
		dateParticle?.clearDatePicker();
		imageParticle?.destroyFloatImage();
	}

	Element? _resolveEventTarget(Event event) {
		try {
			final JSArray<EventTarget> path = event.composedPath();
			if (path.length > 0) {
				final Element? first = asElement(path[0]);
				if (first != null) {
					return first;
				}
			}
		} catch (_) {}
		return asElement(event.target);
	}

	List<Element> _resolvePageList() {
		final dynamic pageList = draw.getPageList();
		if (pageList is List<Element>) {
			return pageList;
		}
		if (pageList is Iterable) {
			return List<Element>.from(pageList);
		}
		return <Element>[];
	}
}