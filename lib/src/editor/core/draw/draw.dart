import 'dart:html';

import '../../dataset/enum/editor.dart';
import '../../interface/draw.dart';
import '../../interface/editor.dart';
import '../../interface/element.dart';
import '../i18n/i18n.dart';

/// Partial port of the massive TypeScript `Draw` class.
///
/// The current implementation focuses on exposing the structural pieces that
/// other subsystems rely on (containers, options, painter-style utilities,
/// simple geometry helpers). Rendering and advanced behaviours will be filled
/// in incrementally as the remaining modules from the original project are
/// translated.
class Draw {
	Draw(
		HtmlElement rootContainer,
		IEditorOption options,
		IEditorData data,
		dynamic listener,
		dynamic eventBus,
		dynamic override,
	)   : _rootContainer = rootContainer,
				_options = options,
				_listener = listener,
				_eventBus = eventBus,
				_override = override,
				_mode = options.mode ?? EditorMode.design,
				_elementList = List<IElement>.from(data.main),
				_headerElementList = List<IElement>.from(data.header ?? const <IElement>[]),
				_footerElementList = List<IElement>.from(data.footer ?? const <IElement>[]),
				_container = DivElement(),
				_pageContainer = DivElement(),
				_pageList = <CanvasElement>[],
				_ctxList = <CanvasRenderingContext2D>[],
				_pageNo = 0,
				_renderCount = 0,
			_pagePixelRatio = window.devicePixelRatio.toDouble(),
				_visiblePageNoList = <int>[],
				_intersectionPageNo = 0,
				_i18n = I18n(options.locale ?? 'en');
        
	final HtmlElement _rootContainer;
	final dynamic _listener;
	final dynamic _eventBus;
	final dynamic _override;

	final DivElement _container;
	final DivElement _pageContainer;
	final List<CanvasElement> _pageList;
	final List<CanvasRenderingContext2D> _ctxList;

	final List<int> _visiblePageNoList;
	int _intersectionPageNo;

	IEditorOption _options;
	EditorMode _mode;

	final List<IElement> _elementList;
	final List<IElement> _headerElementList;
	final List<IElement> _footerElementList;

	int _pageNo;
	int _renderCount;
	double? _pagePixelRatio;

	final I18n _i18n;

	IElementStyle? _painterStyle;
	IPainterOption? _painterOptions;

	dynamic _historyManager;
	dynamic _rangeManager;
	dynamic _position;
	dynamic _cursor;
	dynamic _canvasEvent;
	dynamic _globalEvent;
	dynamic _previewer;
	dynamic _tableTool;
	dynamic _tableParticle;
	dynamic _tableOperate;
	dynamic _hyperlinkParticle;
	dynamic _control;
	dynamic _dateParticle;
	dynamic _imageParticle;

	// ---------------------------------------------------------------------------
	// Lifecycle & container helpers
	// ---------------------------------------------------------------------------

	/// Lazily ensure the DOM structure mirrors the editor expectations.
	void ensureContainerMounted() {
		if (_container.isConnected != true) {
			_rootContainer.append(_container);
		}
		if (_pageContainer.isConnected != true) {
			_container.append(_pageContainer);
		}
		if (_pageList.isEmpty) {
			_createPage(0);
		}
	}

	void destroy() {
		_globalEvent?.removeEvent();
		_pageContainer.children.clear();
		_pageList.clear();
		_ctxList.clear();
		_container.remove();
	}

	// ---------------------------------------------------------------------------
	// Public getters exposed to other subsystems
	// ---------------------------------------------------------------------------

	IEditorOption getOptions() => _options;

	dynamic getListener() => _listener;

	dynamic getEventBus() => _eventBus;

	dynamic getOverride() => _override;

	I18n getI18n() => _i18n;

	DivElement getContainer() {
		ensureContainerMounted();
		return _container;
	}

	DivElement getPageContainer() {
		ensureContainerMounted();
		return _pageContainer;
	}

	List<Element> getPageList() {
		ensureContainerMounted();
		return List<Element>.from(_pageList);
	}

	List<CanvasRenderingContext2D> getCtxList() => List<CanvasRenderingContext2D>.from(_ctxList);

	int getPageNo() => _pageNo;

	void setPageNo(int value) {
		if (value < 0 || value >= _pageList.length) {
			return;
		}
		_pageNo = value;
	}

	int getRenderCount() => _renderCount;

	List<int> getVisiblePageNoList() => List<int>.from(_visiblePageNoList);

	void setVisiblePageNoList(List<int> value) {
		_visiblePageNoList
			..clear()
			..addAll(value);
		final dynamic callback = _listener?.visiblePageNoListChange;
		if (callback != null) {
			callback(_visiblePageNoList);
		}
	}

	int getIntersectionPageNo() => _intersectionPageNo;

	void setIntersectionPageNo(int value) {
		_intersectionPageNo = value;
		final dynamic callback = _listener?.intersectionPageNoChange;
		callback?.call(value);
	}

	EditorMode getMode() => _mode;

	void setMode(EditorMode payload) {
		if (_mode == payload) {
			return;
		}
		_mode = payload;
		_options.mode = payload;
	}

	bool isReadonly() {
		return _mode == EditorMode.readonly || _mode == EditorMode.print;
	}

	bool isDisabled() {
		return isReadonly();
	}

	bool isDesignMode() => _mode == EditorMode.design;

	bool isPrintMode() => _mode == EditorMode.print;

	// ---------------------------------------------------------------------------
	// Painter (format brush) helpers
	// ---------------------------------------------------------------------------

	void setPainterStyle(IElementStyle? payload, [IPainterOption? options]) {
		_painterStyle = payload;
		_painterOptions = options;
		for (final CanvasElement page in _pageList) {
			page.style.cursor = payload == null ? 'text' : 'copy';
		}
	}

	IElementStyle? getPainterStyle() => _painterStyle;

	IPainterOption? getPainterOptions() => _painterOptions;

	// ---------------------------------------------------------------------------
	// Element list accessors (simplified)
	// ---------------------------------------------------------------------------

	List<IElement> getElementList() => _elementList;

	List<IElement> getOriginalElementList() => _elementList;

	List<IElement> getHeaderElementList() => _headerElementList;

	List<IElement> getFooterElementList() => _footerElementList;

	List<IElement> getOriginalMainElementList() => _elementList;

	void setEditorData(IEditorData payload) {
		_elementList
			..clear()
			..addAll(payload.main);
		_headerElementList
			..clear()
			..addAll(payload.header ?? const <IElement>[]);
		_footerElementList
			..clear()
			..addAll(payload.footer ?? const <IElement>[]);
	}

	// ---------------------------------------------------------------------------
	// Geometry helpers (scaled sizing derived from options)
	// ---------------------------------------------------------------------------

	double _resolveScale() => (_options.scale ?? 1).toDouble();

	double getOriginalWidth() {
		final double width = (_options.width ?? _defaultOriginalWidth).toDouble();
		final double height = (_options.height ?? _defaultOriginalHeight).toDouble();
		return _options.paperDirection == PaperDirection.horizontal ? height : width;
	}

	double getOriginalHeight() {
		final double width = (_options.width ?? _defaultOriginalWidth).toDouble();
		final double height = (_options.height ?? _defaultOriginalHeight).toDouble();
		return _options.paperDirection == PaperDirection.horizontal ? width : height;
	}

	double getWidth() => (getOriginalWidth() * _resolveScale()).floorToDouble();

	double getHeight() => (getOriginalHeight() * _resolveScale()).floorToDouble();

	double getPageGap() => (_options.pageGap ?? _defaultPageGap).toDouble() * _resolveScale();

	double getOriginalPageGap() => (_options.pageGap ?? _defaultPageGap).toDouble();

	List<double> getMargins() {
		final List<double> margins = getOriginalMargins();
		final double scale = _resolveScale();
		return margins.map((double value) => value * scale).toList();
	}

	List<double> getOriginalMargins() {
		final List<double> defaultMargins = List<double>.from(_options.margins ?? _defaultMargins);
		if (_options.paperDirection == PaperDirection.horizontal) {
			return <double>[defaultMargins[1], defaultMargins[2], defaultMargins[3], defaultMargins[0]];
		}
		return defaultMargins;
	}

	double getInnerWidth() {
		final List<double> margins = getMargins();
		return getWidth() - margins[1] - margins[3];
	}

	double getOriginalInnerWidth() {
		final List<double> margins = getOriginalMargins();
		return getOriginalWidth() - margins[1] - margins[3];
	}

		double getPagePixelRatio() => _pagePixelRatio ?? window.devicePixelRatio.toDouble();

	void setPagePixelRatio(double? value) {
		_pagePixelRatio = value;
	}

	// ---------------------------------------------------------------------------
	// Rendering (placeholder)
	// ---------------------------------------------------------------------------

	void render([IDrawOption? _]) {
		ensureContainerMounted();
		_renderCount += 1;
	}

	void setPageScale(double scale) {
		_options.scale = scale;
		if (_pageList.isEmpty) {
			return;
		}
		final double width = getWidth();
		final double height = getHeight();
		final double gap = getPageGap();
		for (int i = 0; i < _pageList.length; i++) {
			final CanvasElement page = _pageList[i];
			page
				..width = (width * getPagePixelRatio()).toInt()
				..height = (height * getPagePixelRatio()).toInt()
				..style.width = '${width}px'
				..style.height = '${height}px'
				..style.marginBottom = '${gap}px';
		}
	}

	void setPageDevicePixel() {
		if (_pageList.isEmpty) {
			return;
		}
		final double width = getWidth();
		final double height = getHeight();
		final double ratio = getPagePixelRatio();
		for (int i = 0; i < _pageList.length; i++) {
			final CanvasElement page = _pageList[i];
			page
				..width = (width * ratio).toInt()
				..height = (height * ratio).toInt();
			final CanvasRenderingContext2D ctx = _ctxList[i];
			ctx
				..setTransform(1, 0, 0, 1, 0, 0)
				..scale(ratio, ratio);
		}
	}

	// ---------------------------------------------------------------------------
	// Object graph setters for yet-to-be-ported modules
	// ---------------------------------------------------------------------------

	void attachHistoryManager(dynamic historyManager) => _historyManager = historyManager;

	void attachRangeManager(dynamic rangeManager) => _rangeManager = rangeManager;

	void attachPosition(dynamic position) => _position = position;

	void attachCursor(dynamic cursor) => _cursor = cursor;

	void attachCanvasEvent(dynamic canvasEvent) => _canvasEvent = canvasEvent;

	void attachGlobalEvent(dynamic globalEvent) => _globalEvent = globalEvent;

	void attachPreviewer(dynamic previewer) => _previewer = previewer;

	void attachTableTool(dynamic tableTool) => _tableTool = tableTool;

	void attachTableParticle(dynamic tableParticle) => _tableParticle = tableParticle;

	void attachTableOperate(dynamic tableOperate) => _tableOperate = tableOperate;

	void attachHyperlinkParticle(dynamic hyperlinkParticle) => _hyperlinkParticle = hyperlinkParticle;

	void attachControl(dynamic control) => _control = control;

	void attachDateParticle(dynamic dateParticle) => _dateParticle = dateParticle;

	void attachImageParticle(dynamic imageParticle) => _imageParticle = imageParticle;

	dynamic getHistoryManager() => _historyManager;
	dynamic getRange() => _rangeManager;
	dynamic getPosition() => _position;
	dynamic getCursor() => _cursor;
	dynamic getCanvasEvent() => _canvasEvent;
	dynamic getGlobalEvent() => _globalEvent;
	dynamic getPreviewer() => _previewer;
	dynamic getTableTool() => _tableTool;
	dynamic getTableParticle() => _tableParticle;
	dynamic getTableOperate() => _tableOperate;
	dynamic getHyperlinkParticle() => _hyperlinkParticle;
	dynamic getControl() => _control;
	dynamic getDateParticle() => _dateParticle;
	dynamic getImageParticle() => _imageParticle;

	void clearSideEffect() {
		_cursor?.recoveryCursor();
	}

	// ---------------------------------------------------------------------------
	// Internal helpers
	// ---------------------------------------------------------------------------

	void _createPage(int index) {
		final double width = getWidth();
		final double height = getHeight();
		final double marginGap = getPageGap();
		final double dpr = getPagePixelRatio();

		final CanvasElement canvas = CanvasElement()
			..width = (width * dpr).toInt()
			..height = (height * dpr).toInt()
			..style.width = '${width}px'
			..style.height = '${height}px'
			..style.marginBottom = '${marginGap}px'
			..style.display = 'block'
			..style.backgroundColor = '#ffffff'
			..dataset['index'] = '$index';

		final CanvasRenderingContext2D ctx = canvas.context2D
			..setTransform(1, 0, 0, 1, 0, 0)
			..scale(dpr, dpr);

		_pageContainer.append(canvas);
		_pageList.add(canvas);
		_ctxList.add(ctx);
	}

	static const double _defaultOriginalWidth = 794; // px ~ A4 portrait (210mm)
	static const double _defaultOriginalHeight = 1123; // px ~ A4 portrait (297mm)
	static const double _defaultPageGap = 20;
	static const List<double> _defaultMargins = <double>[96, 96, 96, 96];
}