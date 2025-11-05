import 'dart:html';
import '../../dataset/constant/common.dart';
import '../../dataset/constant/editor.dart';
import '../../dataset/constant/element.dart' as element_constants;
import '../../dataset/constant/group.dart' show defaultGroupOption;
import '../../dataset/constant/regular.dart' as regular;
import '../../dataset/enum/common.dart';
import '../../dataset/enum/control.dart';
import '../../dataset/enum/editor.dart';
import '../../dataset/enum/element.dart';
import '../../dataset/enum/row.dart';
import '../../interface/common.dart';
import '../../interface/draw.dart';
import '../../interface/editor.dart';
import '../../interface/element.dart';
import '../../interface/group.dart';
import '../../interface/margin.dart';
import '../../interface/position.dart';
import '../../interface/range.dart';
import '../../interface/row.dart';
import '../../interface/table/table.dart';
import '../../interface/table/td.dart';
import '../../utils/element.dart' as element_utils;
import '../../utils/index.dart' as utils;
import '../actuator/actuator.dart';
import '../cursor/cursor.dart';
import '../event/canvas_event.dart';
import '../event/eventbus/event_bus.dart';
import '../event/global_event.dart';
import '../history/history_manager.dart';
import '../i18n/i18n.dart';
import '../observer/mouse_observer.dart';
import '../observer/scroll_observer.dart';
import '../observer/selection_observer.dart';
import '../position/position.dart';
import '../range/range_manager.dart';
import '../worker/worker_manager.dart';
import '../zone/zone.dart';
import 'control/control.dart';
import 'frame/background.dart';
import 'frame/badge.dart';
import 'frame/footer.dart';
import 'frame/header.dart';
import 'frame/line_number.dart';
import 'frame/margin.dart';
import 'frame/page_border.dart';
import 'frame/page_number.dart';
import 'frame/placeholder.dart';
import 'frame/watermark.dart';
import 'interactive/area.dart';
import 'interactive/group.dart';
import 'interactive/search.dart';
import 'particle/block/block_particle.dart';
import 'particle/checkbox_particle.dart';
import 'particle/date/date_particle.dart';
import 'particle/hyperlink_particle.dart';
import 'particle/image_particle.dart';
import 'particle/list_particle.dart';
import 'particle/previewer/previewer.dart';
import 'particle/latex/la_tex_particle.dart';
import 'particle/line_break_particle.dart';
import 'particle/page_break_particle.dart';
import 'particle/radio_particle.dart';
import 'particle/separator_particle.dart';
import 'particle/subscript_particle.dart';
import 'particle/table/table_operate.dart';
import 'particle/table/table_particle.dart';
import 'particle/table/table_tool.dart';
import 'particle/text_particle.dart';
import 'particle/superscript_particle.dart';
import '../observer/image_observer.dart';
import 'richtext/highlight.dart';
import 'richtext/strikeout.dart';
import 'richtext/underline.dart';

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
				_pagePixelRatio = null,
				_visiblePageNoList = <int>[],
				_intersectionPageNo = 0,
				_i18n = I18n(options.locale ?? 'en'),
				_letterReg = _buildLetterReg(options.letterClass),
				_containerInitialized = false,
				_printModeData = null,
				_rowList = <IRow>[],
				_pageRowList = <List<IRow>>[],
				_badge = null,
				_area = null,
				_workerManager = null {
		_initializeContainers();
		_position = Position(this);
		_rangeManager = RangeManager(this);
		_historyManager = HistoryManager(this);
		_listParticle = ListParticle(this);
		_checkboxParticle = CheckboxParticle(this);
		_radioParticle = RadioParticle(this);
		_separatorParticle = SeparatorParticle(this);
		_hyperlinkParticle = HyperlinkParticle(this);
		_dateParticle = DateParticle(this);
		_pageBreakParticle = PageBreakParticle(this);
		_search = Search(this);
		_control = Control(this);
		_textParticle = TextParticle(this);
		_tableParticle = TableParticle(this);
		_imageParticle = ImageParticle(this);
		_laTexParticle = LaTexParticle(this);
		_superscriptParticle = SuperscriptParticle();
		_subscriptParticle = SubscriptParticle();
		_blockParticle = BlockParticle(this);
		_lineBreakParticle = LineBreakParticle(this);
		_underline = Underline(this);
		_strikeout = Strikeout(this);
		_highlight = Highlight(this);
		_group = Group(this);
		_background = Background(this);
		_margin = Margin(this);
		_watermark = Watermark(this);
		_pageNumber = PageNumber(this);
		_lineNumber = LineNumber(this);
		_pageBorder = PageBorder(this);
		_placeholder = Placeholder(this);
		_badge = Badge(this);
			_area = Area(this);
			_previewer = Previewer(this);
			_imageObserver = ImageObserver();
			_tableTool = TableTool(this);
			_tableOperate = TableOperate(this);
			final CanvasEvent canvasEvent = CanvasEvent(this);
			_canvasEvent = canvasEvent;
			_cursor = Cursor(this, canvasEvent);
			canvasEvent.register();
			final GlobalEvent globalEvent = GlobalEvent(this, canvasEvent);
			_globalEvent = globalEvent;
			globalEvent.register();
			_workerManager = WorkerManager(this);
			ScrollObserver? scrollObserver;
			try {
				scrollObserver = ScrollObserver(this);
			} catch (_) {
				scrollObserver = null;
			}
			_scrollObserver = scrollObserver;
			SelectionObserver? selectionObserver;
			try {
				selectionObserver = SelectionObserver(this);
			} catch (_) {
				selectionObserver = null;
			}
			_selectionObserver = selectionObserver;
			MouseObserver? mouseObserver;
			try {
				mouseObserver = MouseObserver(this);
			} catch (_) {
				mouseObserver = null;
			}
			_mouseObserver = mouseObserver;
			Actuator(this);
			_header = Header(this, _headerElementList);
			_footer = Footer(this, _footerElementList);
			_zone = Zone(this);

			render(
				IDrawOption(
					isInit: true,
					isSetCursor: false,
					isFirstRender: true,
				),
			);
	}
        
	final HtmlElement _rootContainer;
	final dynamic _listener;
	final dynamic _eventBus;
	final dynamic _override;

	late final Header _header;
	late final Footer _footer;
	final DivElement _container;
	final DivElement _pageContainer;
	final List<CanvasElement> _pageList;
	final List<CanvasRenderingContext2D> _ctxList;
	final List<int> _visiblePageNoList;
	int _intersectionPageNo;
	final IEditorOption _options;
	EditorMode _mode;
	final List<IElement> _elementList;
	final List<IElement> _headerElementList;
	final List<IElement> _footerElementList;
	int _pageNo;
	int _renderCount;
	double? _pagePixelRatio;
	final I18n _i18n;
	final RegExp? _letterReg;
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
	dynamic _search;
	dynamic _background;
	dynamic _margin;
	dynamic _control;
	dynamic _dateParticle;
	dynamic _imageObserver;
	dynamic _imageParticle;
	dynamic _checkboxParticle;
	dynamic _listParticle;
	dynamic _radioParticle;
	dynamic _separatorParticle;
	dynamic _pageBreakParticle;
	dynamic _textParticle;
	dynamic _laTexParticle;
	dynamic _superscriptParticle;
	dynamic _subscriptParticle;
	dynamic _blockParticle;
	dynamic _lineBreakParticle;
	dynamic _underline;
	dynamic _strikeout;
	dynamic _highlight;
	dynamic _group;
	dynamic _watermark;
	dynamic _pageNumber;
	dynamic _lineNumber;
	dynamic _pageBorder;
	dynamic _placeholder;
	bool _containerInitialized;
	IEditorData? _printModeData;
	final List<IRow> _rowList;
	final List<List<IRow>> _pageRowList;
	dynamic _badge;
	dynamic _area;
	WorkerManager? _workerManager;
	Zone? _zone;
	IntersectionObserver? _lazyRenderObserver;
	ScrollObserver? _scrollObserver;
	SelectionObserver? _selectionObserver;
	MouseObserver? _mouseObserver;

	void ensureContainerMounted() {
		if (!_containerInitialized) {
			_initializeContainers();
			return;
		}
		_wrapContainer();
		_ensurePageContainer();
		if (_pageList.isEmpty) {
			_createPage(0);
		}
	}

	void destroy() {
		(_globalEvent as GlobalEvent?)?.removeEvent();
		(_canvasEvent as CanvasEvent?)?.dispose();
		_scrollObserver?.removeEvent();
		_selectionObserver?.dispose();
		_mouseObserver?.dispose();
		(_tableTool as TableTool?)?.dispose();
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

	CanvasElement? getPage([int pageNo = -1]) {
		ensureContainerMounted();
		if (_pageList.isEmpty) {
			return null;
		}
		int index = pageNo >= 0 ? pageNo : _pageNo;
		if (index < 0 || index >= _pageList.length) {
			index = _pageNo;
			if (index < 0 || index >= _pageList.length) {
				index = 0;
			}
		}
		return _pageList[index];
	}

	List<Element> getPageList() {
		ensureContainerMounted();
		return List<Element>.from(_pageList);
	}

	int getPageCount() {
		ensureContainerMounted();
		return _pageList.length;
	}

	double getPageNumberBottom() {
		final double bottom =
			(_options.pageNumber?.bottom ?? _defaultPageNumberBottom).toDouble();
		return bottom * _resolveScale();
	}

	CanvasRenderingContext2D? getCtx() {
		ensureContainerMounted();
		if (_ctxList.isEmpty) {
			return null;
		}
		final int index = (_pageNo >= 0 && _pageNo < _ctxList.length) ? _pageNo : 0;
		return _ctxList[index];
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
		_emitEvent('visiblePageNoListChange', List<int>.from(_visiblePageNoList));
	}

	int getIntersectionPageNo() => _intersectionPageNo;

	void setIntersectionPageNo(int value) {
		_intersectionPageNo = value;
		final dynamic callback = _listener?.intersectionPageNoChange;
		callback?.call(value);
		_emitEvent('intersectionPageNoChange', value);
	}

	EditorMode getMode() => _mode;

	void setPrintData() {
		final IEditorData snapshot = IEditorData(
			header: _cloneOptionalElementList(_headerElementList),
			main: _cloneElementList(_elementList),
			footer: _cloneOptionalElementList(_footerElementList),
		);
		_printModeData = snapshot;
		final List<IElement>? headerFiltered =
			_filterAssistElementListNullable(snapshot.header);
		final List<IElement> mainFiltered =
			_filterAssistElementList(snapshot.main);
		final List<IElement>? footerFiltered =
			_filterAssistElementListNullable(snapshot.footer);
		setEditorData(
			IEditorData(
				header: headerFiltered,
				main: mainFiltered,
				footer: footerFiltered,
			),
		);
	}

	void clearPrintData() {
		final IEditorData? snapshot = _printModeData;
		if (snapshot == null) {
			return;
		}
		setEditorData(
			IEditorData(
				header: _cloneOptionalElementList(snapshot.header),
				main: _cloneElementList(snapshot.main),
				footer: _cloneOptionalElementList(snapshot.footer),
			),
		);
		_printModeData = null;
	}

	void setMode(EditorMode payload) {
		if (_mode == payload) {
			return;
		}
		if (payload == EditorMode.print) {
			setPrintData();
		}
		if (_mode == EditorMode.print && payload != EditorMode.print) {
			clearPrintData();
		}
		clearSideEffect();
		try {
			final dynamic rangeManager = _rangeManager;
			rangeManager?.clearRange?.call();
		} catch (_) {}
		_mode = payload;
		_options.mode = payload;
		render(
			IDrawOption(
				isSetCursor: false,
				isSubmitHistory: false,
			),
		);
	}

	bool isReadonly() {
		return _mode == EditorMode.readonly || _mode == EditorMode.print;
	}

	bool isDisabled() {
		return isReadonly();
	}

	bool isDesignMode() => _mode == EditorMode.design;

	bool isPrintMode() => _mode == EditorMode.print;

	Zone getZone() {
		_zone ??= Zone(this);
		return _zone!;
	}

	bool getIsPagingMode() {
		final PageMode pageMode = _options.pageMode ?? PageMode.paging;
		return pageMode == PageMode.paging;
	}

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

	RegExp? getLetterReg() => _letterReg;

	// ---------------------------------------------------------------------------
	// Element list accessors (simplified)
	// ---------------------------------------------------------------------------

	List<IElement> getElementList() => _elementList;

	List<IElement> getOriginalElementList() => _elementList;

	List<IElement> getHeaderElementList() => _headerElementList;

	List<IElement> getFooterElementList() => _footerElementList;

	List<IElement> getOriginalMainElementList() => _elementList;

	Header getHeader() => _header;

	Footer getFooter() => _footer;

	List<IRow> getRowList() => _rowList;

	List<List<IRow>> getPageRowList() => _pageRowList;

	IEditorData getOriginValue([dynamic options]) {
		// TODO: respect pagination slices once pageRowList is fully ported.
		final int? pageNo = options is IGetOriginValueOption
				? options.pageNo
				: options is IGetValueOption
						? options.pageNo
						: null;
		final List<IElement> mainElementList = List<IElement>.from(_elementList);
		if (pageNo != null) {
			// Pagination-aware slices will be honoured after pageRowList is ported.
		}
		return IEditorData(
			header: List<IElement>.from(_headerElementList),
			main: mainElementList,
			footer: List<IElement>.from(_footerElementList),
		);
	}

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
		_header.setElementList(List<IElement>.from(_headerElementList));
		_footer.setElementList(List<IElement>.from(_footerElementList));
	}

	// ---------------------------------------------------------------------------
	// Element list mutations (helpers mirroring JS Array#splice behaviour)
	// ---------------------------------------------------------------------------

	void spliceElementList(
		List<IElement> elementList,
		int start, [
		int? deleteCount,
		List<IElement>? insertList,
		ISpliceElementListOption? options,
	]) {
		final bool isIgnoreDeletedRule = options?.isIgnoreDeletedRule ?? false;
		if (elementList.isEmpty) {
			start = 0;
		}
		final int length = elementList.length;
		int normalizedStart = start;
		if (normalizedStart < 0) {
			normalizedStart = length + normalizedStart;
			if (normalizedStart < 0) {
				normalizedStart = 0;
			}
		} else if (normalizedStart > length) {
			normalizedStart = length;
		}
		int normalizedDeleteCount = deleteCount ?? (length - normalizedStart);
		if (normalizedDeleteCount < 0) {
			normalizedDeleteCount = 0;
		}
		final int maxRemovable = length - normalizedStart;
		if (normalizedDeleteCount > maxRemovable) {
			normalizedDeleteCount = maxRemovable;
		}
		if (normalizedDeleteCount > 0) {
			if (!isIgnoreDeletedRule) {
				// TODO: enforce the original deletion constraints once the related
				// subsystems (form mode, grouped elements, etc.) are fully ported.
			}
			elementList.removeRange(
				normalizedStart,
				normalizedStart + normalizedDeleteCount,
			);
		}
		if (insertList != null && insertList.isNotEmpty) {
			elementList.insertAll(normalizedStart, insertList);
		}
	}

	void submitHistory([int? curIndex]) {
		final HistoryManager? historyManager = _historyManager as HistoryManager?;
		final RangeManager? rangeManager = _rangeManager as RangeManager?;
		final Position? position = _position as Position?;
		if (historyManager == null || rangeManager == null || position == null) {
			return;
		}

		final List<IElement> elementSnapshot =
			element_utils.cloneElementList(_elementList);
		final List<IElement> headerSnapshot =
			element_utils.cloneElementList(_headerElementList);
		final List<IElement> footerSnapshot =
			element_utils.cloneElementList(_footerElementList);
		final IRange rangeSnapshot = _cloneRange(rangeManager.getRange());
		final IPositionContext positionContextSnapshot =
			_clonePositionContext(position.getPositionContext());
		final EditorZone zoneSnapshot = getZone().getZone();
		final int pageNoSnapshot = _pageNo;

			historyManager.execute(() {
			getZone().setZone(zoneSnapshot);
			setPageNo(pageNoSnapshot);
			position.setPositionContext(
				_clonePositionContext(positionContextSnapshot),
			);
			final List<IElement> restoredHeader =
				element_utils.cloneElementList(headerSnapshot);
			_headerElementList
				..clear()
				..addAll(restoredHeader);
			_header.setElementList(
				element_utils.cloneElementList(restoredHeader),
			);
			final List<IElement> restoredFooter =
				element_utils.cloneElementList(footerSnapshot);
			_footerElementList
				..clear()
				..addAll(restoredFooter);
			_footer.setElementList(
				element_utils.cloneElementList(restoredFooter),
			);
			final List<IElement> restoredMain =
				element_utils.cloneElementList(elementSnapshot);
			_elementList
				..clear()
				..addAll(restoredMain);
			rangeManager.replaceRange(_cloneRange(rangeSnapshot));
			render(
				IDrawOption(
					curIndex: curIndex,
					isSubmitHistory: false,
					isSourceHistory: true,
				),
			);
		});
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

	double getCanvasWidth(int pageNo) {
		ensureContainerMounted();
		if (_pageList.isEmpty) {
			return getWidth();
		}
		int index = pageNo;
		if (index < 0) {
			index = 0;
		} else if (index >= _pageList.length) {
			index = _pageList.length - 1;
		}
		final CanvasElement page = _pageList[index];
		final double ratio = getPagePixelRatio();
		final int rawWidth = page.width ?? 0;
		if (ratio <= 0) {
			return rawWidth.toDouble();
		}
		return rawWidth.toDouble() / ratio;
	}

	double getCanvasHeight(int pageNo) {
		ensureContainerMounted();
		if (_pageList.isEmpty) {
			return getHeight();
		}
		int index = pageNo;
		if (index < 0) {
			index = 0;
		} else if (index >= _pageList.length) {
			index = _pageList.length - 1;
		}
		final CanvasElement page = _pageList[index];
		final double ratio = getPagePixelRatio();
		final int rawHeight = page.height ?? 0;
		if (ratio <= 0) {
			return rawHeight.toDouble();
		}
		return rawHeight.toDouble() / ratio;
	}

	double getOriginalPageGap() => (_options.pageGap ?? _defaultPageGap).toDouble();

	double getDefaultBasicRowMarginHeight() {
		final double base =
			(_options.defaultBasicRowMarginHeight ?? 0).toDouble();
		return base * _resolveScale();
	}

	double getMarginIndicatorSize() {
		final double base =
			(_options.marginIndicatorSize ?? _defaultMarginIndicatorSize).toDouble();
		return base * _resolveScale();
	}

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

	String getElementFont(IElement element, [double scale = 1]) {
		final bool isItalic = element.italic == true;
		final bool isBold = element.bold == true;
		final String fontFamily = element.font ?? _options.defaultFont ?? 'sans-serif';
		final num baseSize = element.actualSize ?? element.size ?? _options.defaultSize ?? 16;
		final double scaledSize = baseSize.toDouble() * scale;
		final String sizeStr = scaledSize == scaledSize.roundToDouble()
			? scaledSize.toInt().toString()
			: scaledSize.toString();
		final StringBuffer buffer = StringBuffer();
		if (isItalic) {
			buffer.write('italic ');
		}
		if (isBold) {
			buffer.write('bold ');
		}
		buffer
			..write(sizeStr)
			..write('px ')
			..write(fontFamily);
		return buffer.toString();
	}

	double getElementSize(IElement element) {
		final num? actualSize = element.actualSize;
		final num? declaredSize = element.size;
		final num? defaultSize = _options.defaultSize;
		return (actualSize ?? declaredSize ?? defaultSize ?? 16).toDouble();
	}

	double getElementRowMargin(IElement element) {
		final double baseMargin = (_options.defaultBasicRowMarginHeight ?? 0).toDouble();
		final double defaultRowMargin = (_options.defaultRowMargin ?? 1).toDouble();
		return baseMargin * (element.rowMargin ?? defaultRowMargin) * _resolveScale();
	}

	double getHighlightMarginHeight() {
		final double base = (_options.highlightMarginHeight ?? 0).toDouble();
		return base * _resolveScale();
	}

	double getInnerWidth() {
		final List<double> margins = getMargins();
		return getWidth() - margins[1] - margins[3];
	}

	double getOriginalInnerWidth() {
		final List<double> margins = getOriginalMargins();
		return getOriginalWidth() - margins[1] - margins[3];
	}

	double getMainHeight() {
		return getHeight() - getMainOuterHeight();
	}

	double getMainOuterHeight() {
		final IMargin margins = getMargins();
		return margins[0] + margins[2] + _resolveHeaderExtraHeight() + _resolveFooterExtraHeight();
	}

	double getContextInnerWidth() {
		try {
			final dynamic positionInstance = _position;
			if (positionInstance == null) {
				return getOriginalInnerWidth();
			}
			final dynamic context = positionInstance.getPositionContext();
			if (context?.isTable == true) {
				final int? index = context.index as int?;
				final int? trIndex = context.trIndex as int?;
				final int? tdIndex = context.tdIndex as int?;
				if (index == null || trIndex == null || tdIndex == null) {
					return getOriginalInnerWidth();
				}
				final List<IElement> elementList = getOriginalElementList();
				if (index < 0 || index >= elementList.length) {
					return getOriginalInnerWidth();
				}
				final IElement tableElement = elementList[index];
				final List<ITr>? trList = tableElement.trList;
				if (trList == null || trIndex < 0 || trIndex >= trList.length) {
					return getOriginalInnerWidth();
				}
				final ITr tr = trList[trIndex];
				if (tdIndex < 0 || tdIndex >= tr.tdList.length) {
					return getOriginalInnerWidth();
				}
				final dynamic td = tr.tdList[tdIndex];
				final List<double> tdPadding = getTdPadding();
				final double width = td.width is num ? (td.width as num).toDouble() : 0;
				return width - tdPadding[1] - tdPadding[3];
			}
		} catch (_) {}
		return getOriginalInnerWidth();
	}

	List<double> getTdPadding() {
		final IPadding? padding = _options.table?.tdPadding;
		final double scale = _resolveScale();
		return <double>[
			(padding?.top ?? 0) * scale,
			(padding?.right ?? 0) * scale,
			(padding?.bottom ?? 0) * scale,
			(padding?.left ?? 0) * scale,
		];
	}

	double getPagePixelRatio() {
		return (_pagePixelRatio ?? window.devicePixelRatio).toDouble();
	}

	void setPagePixelRatio(double? value) {
		final double? normalized = value;
		if (normalized == null) {
			if (_pagePixelRatio == null) {
				return;
			}
			_pagePixelRatio = null;
		} else {
			if (_pagePixelRatio != null && (_pagePixelRatio! - normalized).abs() < 1e-6) {
				return;
			}
			_pagePixelRatio = normalized;
		}
		setPageDevicePixel();
		render(
			IDrawOption(
				isSetCursor: false,
				isSubmitHistory: false,
			),
		);
	}

	// -------------------------------------------------------------------------
	// Row computation & pagination (functional parity subset)
	// -------------------------------------------------------------------------

	List<IRow> computeRowList(IComputeRowListPayload payload) {
		final double innerWidth = payload.innerWidth;
		final List<IElement> elementList = payload.elementList;
		if (innerWidth <= 0 || elementList.isEmpty) {
			return <IRow>[];
		}
		final bool isPagingMode = payload.isPagingMode ?? false;
		final bool isFromTable = payload.isFromTable ?? false;
		final double startX = payload.startX ?? 0;
		final double startY = payload.startY ?? 0;
		final double pageHeight = payload.pageHeight ?? 0;
		final double mainOuterHeight = payload.mainOuterHeight ?? 0;
		final double scale = _resolveScale();
		final double defaultSize = (_options.defaultSize ?? 16).toDouble();
		final double defaultRowMargin = (_options.defaultRowMargin ?? 1).toDouble();
		final double defaultTabWidth = (_options.defaultTabWidth ?? defaultSize).toDouble();
		final double defaultBasicRowMarginHeight = getDefaultBasicRowMarginHeight();
		final ITableOption? tableOption = _options.table;
		final IPadding? tablePadding = tableOption?.tdPadding;
		final double tdPaddingWidth =
			((tablePadding?.right ?? 0) + (tablePadding?.left ?? 0)).toDouble();
		final double tdPaddingHeight =
			((tablePadding?.top ?? 0) + (tablePadding?.bottom ?? 0)).toDouble();
		final double defaultTrMinHeight =
			(tableOption?.defaultTrMinHeight ?? defaultSize).toDouble();
		final CanvasRenderingContext2D ctx = CanvasElement().context2D;
		final TextParticle? textParticle = _textParticle as TextParticle?;
		final ListParticle? listParticle = _listParticle as ListParticle?;
		final Position? position = _position as Position?;
		final Control? control = _control as Control?;
		final TableParticle? tableParticle = _tableParticle as TableParticle?;
		final Map<String, double> listStyleMap =
			listParticle?.computeListStyle(ctx, elementList) ?? <String, double>{};
		final List<IElement> surroundElementList =
			List<IElement>.from(payload.surroundElementList ?? const <IElement>[]);
		final List<IRow> rowList = <IRow>[];
		if (elementList.isNotEmpty) {
			rowList.add(
				IRow(
					width: 0,
					height: 0,
					ascent: 0,
					startIndex: 0,
					rowIndex: 0,
					rowFlex: elementList.first.rowFlex ??
						(elementList.length > 1 ? elementList[1].rowFlex : null),
					offsetX: 0,
					offsetY: 0,
					elementList: <IRowElement>[],
				),
			);
		}
		double x = startX;
		double y = startY;
		int pageNo = 0;
		int listIndex = 0;
		String? listId;
		double controlRealWidth = 0;
		for (int i = 0; i < elementList.length; i++) {
			final IRow curRow = rowList.last;
			final IElement element = elementList[i];
			final IElement? preElement = i > 0 ? elementList[i - 1] : null;
			final double rowMarginFactor = element.rowMargin ?? defaultRowMargin;
			final double rowMargin = defaultBasicRowMarginHeight * rowMarginFactor;
			final IElementMetrics metrics = IElementMetrics(
				width: 0,
				height: 0,
				boundingBoxAscent: 0,
				boundingBoxDescent: 0,
			);
			final double computedOffsetX = curRow.offsetX ??
				(element.listId != null ? (listStyleMap[element.listId!] ?? 0) : 0);
			final double availableWidth = innerWidth - computedOffsetX;
			final bool isStartElement = curRow.elementList.length == 1;
			if (isStartElement) {
				x += computedOffsetX;
				y += curRow.offsetY ?? 0;
			}
			if (curRow.elementList.isEmpty) {
				curRow.startIndex = i;
			}
			if ((element.hide == true ||
							element.control?.hide == true ||
							element.area?.hide == true) &&
				!isDesignMode()) {
				final IRowElement? prevRowElement =
					curRow.elementList.isNotEmpty ? curRow.elementList.last : null;
				metrics.height = prevRowElement?.metrics.height ?? defaultSize * scale;
				metrics.boundingBoxAscent =
					prevRowElement?.metrics.boundingBoxAscent ?? 0;
				metrics.boundingBoxDescent =
					prevRowElement?.metrics.boundingBoxDescent ?? 0;
			} else if (element.type == ElementType.image ||
				element.type == ElementType.latex) {
				if (element.imgDisplay == ImageDisplay.surround ||
					element.imgDisplay == ImageDisplay.floatTop ||
					element.imgDisplay == ImageDisplay.floatBottom) {
					metrics.width = 0;
					metrics.height = 0;
					metrics.boundingBoxDescent = 0;
				} else {
					final double rawWidth =
						element.width != null ? element.width!.toDouble() : availableWidth / scale;
					final double rawHeight =
						element.height != null ? element.height!.toDouble() : rawWidth;
					double elementWidth = rawWidth * scale;
					double elementHeight = rawHeight * scale;
					if (elementWidth > availableWidth && elementWidth > 0) {
						final double adaptiveHeight =
							(elementHeight * availableWidth) / elementWidth;
						element.width = availableWidth / scale;
						element.height = adaptiveHeight / scale;
						elementWidth = availableWidth;
						elementHeight = adaptiveHeight;
					}
					metrics.width = elementWidth;
					metrics.height = elementHeight;
					metrics.boundingBoxDescent = elementHeight;
				}
				metrics.boundingBoxAscent = 0;
			} else if (element.type == ElementType.table) {
				if (element.pagingId != null) {
					int tableIndex = i + 1;
					int combineCount = 0;
					while (tableIndex < elementList.length) {
						final IElement nextElement = elementList[tableIndex];
						if (nextElement.pagingId == element.pagingId) {
							final List<ITr> nextTrList = nextElement.trList
									?.where((ITr tr) => tr.pagingRepeat != true)
									.toList() ??
								<ITr>[];
							element.trList ??= <ITr>[];
							element.trList!.addAll(nextTrList);
							if (nextElement.height != null) {
								element.height = (element.height ?? 0) + nextElement.height!;
							}
							tableIndex += 1;
							combineCount += 1;
						} else {
							break;
						}
					}
					if (combineCount > 0) {
						elementList.removeRange(i + 1, i + 1 + combineCount);
					}
				}
				element.pagingIndex = element.pagingIndex ?? 0;
				final List<ITr>? trList = element.trList;
				if (trList != null) {
					for (final ITr tr in trList) {
						tr.height = tr.minHeight ?? defaultTrMinHeight;
						tr.minHeight = tr.height;
					}
				}
				tableParticle?.computeRowColInfo(element);
				if (trList != null) {
					for (int t = 0; t < trList.length; t++) {
						final ITr tr = trList[t];
						for (int d = 0; d < tr.tdList.length; d++) {
							final ITd td = tr.tdList[d];
							final double tdInnerWidth =
								((td.width ?? 0) - tdPaddingWidth) * scale;
							final List<IRow> tdRowList = computeRowList(
								IComputeRowListPayload(
									innerWidth: tdInnerWidth <= 0 ? innerWidth : tdInnerWidth,
									elementList: td.value,
									isFromTable: true,
									isPagingMode: isPagingMode,
								),
							);
							final double rowHeight = tdRowList.fold<double>(
								0,
								(double prev, IRow cur) => prev + cur.height,
							);
							td.rowList = tdRowList;
							final double curTdHeight = rowHeight / scale + tdPaddingHeight;
							final double tdHeight = td.height ?? 0;
							if (tdHeight < curTdHeight) {
								final double extraHeight = curTdHeight - tdHeight;
								final int targetIndex = t + td.rowspan - 1;
								if (targetIndex >= 0 && targetIndex < trList.length) {
									final ITr changeTr = trList[targetIndex];
									changeTr.height += extraHeight;
									for (final ITd changeTd in changeTr.tdList) {
										changeTd.height = (changeTd.height ?? 0) + extraHeight;
										if (changeTd.realHeight == null) {
											changeTd.realHeight = changeTd.height;
										} else {
											changeTd.realHeight =
												(changeTd.realHeight ?? 0) + extraHeight;
										}
									}
								}
							}
							double curTdMinHeight = 0;
							double curTdRealHeight = 0;
							int span = 0;
							while (span < td.rowspan) {
								final int index = t + span;
								final ITr currentTr =
									index < trList.length ? trList[index] : trList.last;
								curTdMinHeight += currentTr.minHeight ?? 0;
								curTdRealHeight += currentTr.height;
								span += 1;
							}
							td.realMinHeight = curTdMinHeight;
							td.realHeight = curTdRealHeight;
							td.mainHeight = curTdHeight;
						}
					}
					final List<ITr> reduceTrList =
						tableParticle?.getTrListGroupByCol(trList) ?? <ITr>[];
					for (int t = 0; t < reduceTrList.length; t++) {
						final ITr tr = reduceTrList[t];
						double? reduceHeight;
						for (final ITd td in tr.tdList) {
							final double curTdRealHeight = td.realHeight ?? 0;
							final double curTdHeight = td.mainHeight ?? 0;
							final double curTdMinHeight = td.realMinHeight ?? 0;
							final double curReduceHeight = curTdHeight < curTdMinHeight
									? curTdRealHeight - curTdMinHeight
									: curTdRealHeight - curTdHeight;
							if (reduceHeight == null || curReduceHeight < reduceHeight) {
								reduceHeight = curReduceHeight;
							}
						}
						if (reduceHeight != null && reduceHeight > 0) {
							final ITr changeTr = trList[t];
							changeTr.height -= reduceHeight;
							for (final ITd changeTd in changeTr.tdList) {
								changeTd.height = (changeTd.height ?? 0) - reduceHeight;
								changeTd.realHeight = (changeTd.realHeight ?? 0) - reduceHeight;
							}
						}
					}
				}
				tableParticle?.computeRowColInfo(element);
				final double tableHeight = tableParticle?.getTableHeight(element) ?? 0;
				final double tableWidth = tableParticle?.getTableWidth(element) ?? 0;
				element.width = tableWidth;
				element.height = tableHeight;
				final double elementWidth = tableWidth * scale;
				final double elementHeight = tableHeight * scale;
				metrics.width = elementWidth;
				metrics.height = elementHeight;
				metrics.boundingBoxDescent = elementHeight;
				metrics.boundingBoxAscent = -rowMargin;
				if (i + 1 < elementList.length &&
					elementList[i + 1].type == ElementType.table) {
					metrics.boundingBoxAscent -= rowMargin;
				}
			} else if (element.type == ElementType.separator) {
				final double lineWidth =
					(_options.separator?.lineWidth ?? 1).toDouble();
				element.width = availableWidth / scale;
				metrics.width = availableWidth;
				metrics.height = lineWidth * scale;
				metrics.boundingBoxAscent = -rowMargin;
				metrics.boundingBoxDescent = -rowMargin + metrics.height;
			} else if (element.type == ElementType.pageBreak) {
				element.width = availableWidth / scale;
				metrics.width = availableWidth;
				metrics.height = defaultSize * scale;
				metrics.boundingBoxAscent = metrics.height;
			} else if (element.type == ElementType.radio ||
				element.controlComponent == ControlComponent.radio) {
				final radioOption = _options.radio;
				final double optionWidth = (radioOption?.width ?? 0).toDouble();
				final double optionHeight = (radioOption?.height ?? 0).toDouble();
				final double gap = (radioOption?.gap ?? 0).toDouble();
				final double elementWidth = optionWidth + gap * 2;
				element.width = elementWidth;
				metrics.width = elementWidth * scale;
				metrics.height = optionHeight * scale;
				metrics.boundingBoxAscent = metrics.height;
				metrics.boundingBoxDescent = 0;
			} else if (element.type == ElementType.checkbox ||
				element.controlComponent == ControlComponent.checkbox) {
				final checkboxOption = _options.checkbox;
				final double optionWidth = (checkboxOption?.width ?? 0).toDouble();
				final double optionHeight = (checkboxOption?.height ?? 0).toDouble();
				final double gap = (checkboxOption?.gap ?? 0).toDouble();
				final double elementWidth = optionWidth + gap * 2;
				element.width = elementWidth;
				metrics.width = elementWidth * scale;
				metrics.height = optionHeight * scale;
				metrics.boundingBoxAscent = metrics.height;
				metrics.boundingBoxDescent = 0;
			} else if (element.type == ElementType.tab) {
				metrics.width = defaultTabWidth * scale;
				metrics.height = defaultSize * scale;
				metrics.boundingBoxAscent = metrics.height;
				metrics.boundingBoxDescent = 0;
			} else if (element.type == ElementType.block) {
				if (element.width == null) {
					metrics.width = availableWidth;
				} else {
					final double elementWidth = element.width!.toDouble() * scale;
					metrics.width =
						elementWidth > availableWidth ? availableWidth : elementWidth;
				}
				metrics.height = (element.height ?? 0) * scale;
				metrics.boundingBoxDescent = metrics.height;
				metrics.boundingBoxAscent = 0;
			} else {
				final int baseSize = element.size ?? defaultSize.toInt();
				if (element.type == ElementType.superscript ||
					element.type == ElementType.subscript) {
					element.actualSize = (baseSize * 0.6).ceil();
				}
				final double resolvedSize =
					(element.actualSize ?? element.size ?? defaultSize).toDouble();
				metrics.height = resolvedSize * scale;
				final String fontStyle = getElementFont(element, scale);
				ctx.font = fontStyle;
				final ITextMetrics? fontMetrics =
					textParticle?.measureText(ctx, element);
				final double measuredWidth = (fontMetrics?.width ?? 0) * scale;
				metrics.width = measuredWidth;
				if (element.letterSpacing != null) {
					metrics.width += element.letterSpacing! * scale;
				}
				metrics.boundingBoxAscent =
					(element.value == ZERO
						? (element.size ?? defaultSize).toDouble()
						: fontMetrics?.actualBoundingBoxAscent ?? resolvedSize) *
					scale;
				metrics.boundingBoxDescent =
					(fontMetrics?.actualBoundingBoxDescent ?? 0) * scale;
				if (element.type == ElementType.superscript) {
					metrics.boundingBoxAscent += metrics.height / 2;
				} else if (element.type == ElementType.subscript) {
					metrics.boundingBoxDescent += metrics.height / 2;
				}
			}
			final double ascent =
				!(element.hide == true ||
								 element.control?.hide == true ||
								 element.area?.hide == true) &&
					((element.imgDisplay != ImageDisplay.inline &&
						 element.type == ElementType.image) ||
					 element.type == ElementType.latex)
					? metrics.height + rowMargin
					: metrics.boundingBoxAscent + rowMargin;
			final double height =
				rowMargin + metrics.boundingBoxAscent + metrics.boundingBoxDescent + rowMargin;
			final String fontStyle = getElementFont(element, scale);
			final IRowElement rowElement = _buildRowElement(
				element,
				metrics,
				fontStyle,
			);
			rowElement.left = 0;
			if (rowElement.control?.minWidth != null) {
				if (rowElement.controlComponent != null) {
					controlRealWidth += metrics.width;
				}
				if (rowElement.controlComponent == ControlComponent.postfix &&
					control != null) {
					control.setMinWidthControlInfo(
						ISetControlRowFlexOption(
							row: curRow,
							rowElement: rowElement,
							availableWidth: availableWidth,
							controlRealWidth: controlRealWidth,
						),
					);
					controlRealWidth = 0;
				}
			} else {
				controlRealWidth = 0;
			}
			IElement? nextElement =
				i + 1 < elementList.length ? elementList[i + 1] : null;
			double curRowWidth = curRow.width + metrics.width;
			if (_options.wordBreak == WordBreak.breakWord && textParticle != null) {
				final bool isPreText = preElement == null ||
					preElement.type == null ||
					preElement.type == ElementType.text;
				final bool isCurText =
					element.type == null || element.type == ElementType.text;
				if (isPreText && isCurText) {
					final String word = '${preElement?.value ?? ''}${element.value}';
					final RegExp effectiveLetterReg = getLetterReg() ?? RegExp('[A-Za-z]');
					if (effectiveLetterReg.hasMatch(word)) {
						final IMeasureWordResult measureResult =
							textParticle.measureWord(ctx, elementList, i);
						final IElement? endElement = measureResult.endElement;
						final double wordWidth = measureResult.width * scale;
						if (endElement != null && wordWidth <= availableWidth) {
							nextElement = endElement;
							curRowWidth += wordWidth;
						}
					}
					final double punctuationWidth =
						textParticle.measurePunctuationWidth(ctx, nextElement) * scale;
					curRowWidth += punctuationWidth;
				}
			}
			if (element.listId != null) {
				if (element.listId != listId) {
					listIndex = 0;
				} else if (element.value == ZERO && element.listWrap != true) {
					listIndex += 1;
				}
			}
			listId = element.listId;
			final Map<String, double> surroundPosition =
				position?.setSurroundPosition(
					ISetSurroundPositionPayload(
						row: curRow,
						rowElement: rowElement,
						rowElementRect: IElementFillRect(
							x: x,
							y: y,
							width: metrics.width,
							height: height,
						),
						pageNo: pageNo,
						availableWidth: availableWidth,
						surroundElementList: surroundElementList,
					),
				) ??
					<String, double>{'x': x, 'rowIncreaseWidth': 0};
			x = surroundPosition['x'] ?? x;
			curRowWidth += surroundPosition['rowIncreaseWidth'] ?? 0;
			x += metrics.width;
			if (curRow.rowFlex == null && element.rowFlex != null) {
				curRow.rowFlex = element.rowFlex;
			}
			final bool isForceBreak =
				element.type == ElementType.separator ||
					 element.type == ElementType.table ||
					 preElement?.type == ElementType.table ||
					 preElement?.type == ElementType.block ||
					 element.type == ElementType.block ||
					 preElement?.imgDisplay == ImageDisplay.inline ||
					 element.imgDisplay == ImageDisplay.inline ||
					 preElement?.listId != element.listId ||
					 (preElement?.areaId != element.areaId && element.area?.hide != true) ||
					 (element.control?.flexDirection == FlexDirection.column &&
						 (element.controlComponent == ControlComponent.checkbox ||
							 element.controlComponent == ControlComponent.radio) &&
						 preElement?.controlComponent == ControlComponent.value) ||
					 (i != 0 && element.value == ZERO && element.area?.hide != true);
			final bool isWidthNotEnough = curRowWidth > availableWidth;
			final bool isWrap = isForceBreak || isWidthNotEnough;
			if (isWrap) {
				final IRow newRow = IRow(
					width: metrics.width,
					height: height,
					ascent: ascent,
					startIndex: i,
					rowIndex: curRow.rowIndex + 1,
					rowFlex: element.rowFlex ??
						(i + 1 < elementList.length
							? elementList[i + 1].rowFlex
							: null),
					isPageBreak: element.type == ElementType.pageBreak,
					elementList: <IRowElement>[rowElement],
					offsetX: 0,
					offsetY: 0,
				);
				if (rowElement.controlComponent != ControlComponent.prefix &&
					rowElement.control?.indentation == ControlIndentation.valueStart &&
					position != null) {
					final int preStartIndex = curRow.elementList.indexWhere(
						(IRowElement el) =>
							el.controlId == rowElement.controlId &&
							el.controlComponent != ControlComponent.prefix,
					);
					if (preStartIndex >= 0) {
						final List<IElementPosition> preRowPositionList =
							position.computeRowPosition(
								IComputeRowPositionPayload(
									row: curRow,
									innerWidth: getInnerWidth(),
								),
							);
						if (preStartIndex < preRowPositionList.length) {
							final IElementPosition valueStartPosition =
								preRowPositionList[preStartIndex];
							final List<double>? leftTop =
								valueStartPosition.coordinate['leftTop'];
							if (leftTop != null && leftTop.isNotEmpty) {
								newRow.offsetX = leftTop[0];
							}
						}
					}
				}
				if (element.listId != null) {
					newRow.isList = true;
					newRow.offsetX = listStyleMap[element.listId!] ?? 0;
					newRow.listIndex = listIndex;
				}
				if (!isFromTable &&
					element.area?.top != null &&
					element.areaId != preElement?.areaId) {
					newRow.offsetY = (element.area!.top ?? 0) * scale;
				}
				rowList.add(newRow);
			} else {
				curRow.width += metrics.width;
				if (i == 0 &&
						((elementList.length > 1 &&
								element_utils.getIsBlockElement(elementList[1])) ||
							(elementList.length > 1 && elementList[1].areaId != null))) {
					curRow.height = defaultBasicRowMarginHeight;
					curRow.ascent = defaultBasicRowMarginHeight;
				} else if (curRow.height < height) {
					curRow.height = height;
					curRow.ascent = ascent;
				}
				curRow.elementList.add(rowElement);
			}
			if (isWrap || i == elementList.length - 1) {
				curRow.isWidthNotEnough = isWidthNotEnough && !isForceBreak;
				if (curRow.isSurround != true &&
						(preElement?.rowFlex == RowFlex.justify ||
							(preElement?.rowFlex == RowFlex.alignment &&
								curRow.isWidthNotEnough == true))) {
					final List<IRowElement> rowElementList =
						curRow.elementList.isNotEmpty &&
							curRow.elementList.first.value == ZERO
								? curRow.elementList.sublist(1)
								: curRow.elementList;
					if (rowElementList.length > 1) {
						final double gap =
							(availableWidth - curRow.width) /
							(rowElementList.length - 1);
						for (int e = 0; e < rowElementList.length - 1; e++) {
							rowElementList[e].metrics.width += gap;
						}
						curRow.width = availableWidth;
					}
				}
			}
			if (isWrap) {
				x = startX;
				y += curRow.height;
				if (isPagingMode &&
						!isFromTable &&
						pageHeight > 0 &&
						(y - startY + mainOuterHeight + height > pageHeight ||
							element.type == ElementType.pageBreak)) {
					y = startY;
					element_utils.deleteSurroundElementList(
						surroundElementList,
						pageNo,
					);
					pageNo += 1;
				}
				rowElement.left = 0;
				final IRow nextRow = rowList.last;
				final Map<String, double> nextSurround =
					position?.setSurroundPosition(
						ISetSurroundPositionPayload(
							row: nextRow,
							rowElement: rowElement,
							rowElementRect: IElementFillRect(
								x: x,
								y: y,
								width: metrics.width,
								height: height,
							),
							pageNo: pageNo,
							availableWidth: availableWidth,
							surroundElementList: surroundElementList,
						),
					) ??
						<String, double>{'x': x, 'rowIncreaseWidth': 0};
				x = (nextSurround['x'] ?? x) + metrics.width;
			}
		}
		final List<IRow> normalizedRows =
			rowList.where((IRow row) => row.elementList.isNotEmpty).toList();
		for (int i = 0; i < normalizedRows.length; i++) {
			normalizedRows[i].rowIndex = i;
		}
		return normalizedRows;
	}

	IRowElement _buildRowElement(
		IElement source,
		IElementMetrics metrics,
		String fontStyle,
	) {
		return IRowElement(
			metrics: metrics,
			style: fontStyle,
			value: source.value,
			id: source.id,
			type: source.type,
			extension: source.extension,
			externalId: source.externalId,
			font: source.font,
			size: source.size,
			width: source.width,
			height: source.height,
			bold: source.bold,
			color: source.color,
			highlight: source.highlight,
			italic: source.italic,
			underline: source.underline,
			strikeout: source.strikeout,
			rowFlex: source.rowFlex,
			rowMargin: source.rowMargin,
			letterSpacing: source.letterSpacing,
			textDecoration: source.textDecoration,
			hide: source.hide,
			groupIds: source.groupIds,
			colgroup: source.colgroup,
			trList: source.trList,
			borderType: source.borderType,
			borderColor: source.borderColor,
			borderWidth: source.borderWidth,
			borderExternalWidth: source.borderExternalWidth,
			translateX: source.translateX,
			tableToolDisabled: source.tableToolDisabled,
			tdId: source.tdId,
			trId: source.trId,
			tableId: source.tableId,
			conceptId: source.conceptId,
			pagingId: source.pagingId,
			pagingIndex: source.pagingIndex,
			valueList: source.valueList,
			url: source.url,
			hyperlinkId: source.hyperlinkId,
			actualSize: source.actualSize,
			dashArray: source.dashArray,
			control: source.control,
			controlId: source.controlId,
			controlComponent: source.controlComponent,
			checkbox: source.checkbox,
			radio: source.radio,
			laTexSVG: source.laTexSVG,
			dateFormat: source.dateFormat,
			dateId: source.dateId,
			imgDisplay: source.imgDisplay,
			imgFloatPosition: source.imgFloatPosition,
			imgToolDisabled: source.imgToolDisabled,
			block: source.block,
			level: source.level,
			titleId: source.titleId,
			title: source.title,
			listType: source.listType,
			listStyle: source.listStyle,
			listId: source.listId,
			listWrap: source.listWrap,
			areaId: source.areaId,
			areaIndex: source.areaIndex,
			area: source.area,
		);
	}

	List<List<IRow>> _computePageList() {
		final List<IRow> rowList = _rowList;
		if (rowList.isEmpty) {
			return <List<IRow>>[<IRow>[]];
		}
		if (!getIsPagingMode()) {
			return <List<IRow>>[rowList];
		}
		final PageMode pageMode = _options.pageMode ?? PageMode.paging;
		final int? maxPageNo = _options.pageNumber?.maxPageNo;
		final double height = getHeight();
		final double marginHeight = getMainOuterHeight();
		if (pageMode == PageMode.continuity) {
			final List<List<IRow>> pageRowList = <List<IRow>>[rowList];
			double pageHeight = marginHeight;
			for (final IRow row in rowList) {
				pageHeight += row.height + (row.offsetY ?? 0);
			}
			final CanvasElement? pageDom = _pageList.isNotEmpty ? _pageList[0] : null;
			if (pageDom != null) {
				final double dpr = getPagePixelRatio();
				final double targetHeight = pageHeight > height ? pageHeight : height;
				pageDom.style.height = '${targetHeight}px';
				pageDom.height = (targetHeight * dpr).round();
				if (_ctxList.isNotEmpty) {
					_initPageContext(_ctxList[0]);
				}
			}
			return pageRowList;
		}
		final List<List<IRow>> pageRowList = <List<IRow>>[<IRow>[]];
		double pageHeight = marginHeight;
		int pageNo = 0;
		for (int i = 0; i < rowList.length; i++) {
			final IRow row = rowList[i];
			final double rowOffsetY = row.offsetY ?? 0;
			final bool shouldBreak =
				row.height + rowOffsetY + pageHeight > height ||
				(i > 0 && rowList[i - 1].isPageBreak == true);
			if (shouldBreak) {
				if (maxPageNo != null && pageNo >= maxPageNo) {
					if (row.startIndex >= 0 && row.startIndex <= _elementList.length) {
						_elementList.removeRange(row.startIndex, _elementList.length);
					}
					break;
				}
				pageHeight = marginHeight + row.height + rowOffsetY;
				pageRowList.add(<IRow>[row]);
				pageNo += 1;
			} else {
				pageHeight += row.height + rowOffsetY;
				pageRowList[pageNo].add(row);
			}
		}
		return pageRowList;
	}

	void _drawHighlight(CanvasRenderingContext2D ctx, IDrawRowPayload payload) {
		final Highlight? highlight = _highlight as Highlight?;
		if (highlight == null) {
			return;
		}
		final Control? control = _control as Control?;
		final List<IRow> rowList = payload.rowList;
		if (rowList.isEmpty) {
			return;
		}
		final List<IElementPosition> positionList = payload.positionList;
		final List<IElement> elementList = payload.elementList;
		final double marginHeight = getDefaultBasicRowMarginHeight();
		final double highlightMarginHeight = getHighlightMarginHeight();
		for (final IRow curRow in rowList) {
			for (int j = 0; j < curRow.elementList.length; j++) {
				final IRowElement element = curRow.elementList[j];
				final IRowElement? preElement = j > 0 ? curRow.elementList[j - 1] : null;
				final int elementIndex = curRow.startIndex + j;
				if (elementIndex < 0 || elementIndex >= positionList.length) {
					continue;
				}
				final IElementPosition position = positionList[elementIndex];
				final List<double> leftTop = position.coordinate['leftTop'] ?? <double>[0, 0];
				final double x = leftTop.isNotEmpty ? leftTop[0] : 0;
				final double y = leftTop.length > 1 ? leftTop[1] : 0;
				final double offsetX = element.left ?? 0;
				final String? highlightColor = element.highlight ??
					control?.getControlHighlight(elementList, elementIndex);
				if (highlightColor != null && highlightColor.isNotEmpty) {
					if (preElement?.highlight != null && preElement?.highlight != highlightColor) {
						highlight.render(ctx);
					}
					highlight.recordFillInfo(
						ctx,
						x - offsetX,
						y + marginHeight - highlightMarginHeight,
						element.metrics.width + offsetX,
						curRow.height - 2 * marginHeight + 2 * highlightMarginHeight,
						highlightColor,
					);
				} else if (preElement?.highlight != null) {
					highlight.render(ctx);
				}
			}
			highlight.render(ctx);
		}
	}

	void drawRow(CanvasRenderingContext2D ctx, IDrawRowPayload payload) {
		_drawHighlight(ctx, payload);
		final double scale = (_options.scale ?? 1).toDouble();
		final List<double> tdPadding = getTdPadding();
		final IGroup groupOption = _options.group ?? defaultGroupOption;
		final bool groupDisabled = groupOption.disabled == true;
		final bool isDrawLineBreak = payload.isDrawLineBreak ??
			(_options.lineBreak?.disabled != true);
		final List<IRow> rowList = payload.rowList;
		final List<IElementPosition> positionList = payload.positionList;
		final List<IElement> elementList = payload.elementList;
		final int pageNo = payload.pageNo;
		final EditorZone? zone = payload.zone;
		final bool isPrintMode = _mode == EditorMode.print;
		final RangeManager? rangeManager = _rangeManager as RangeManager?;
		final IRange? range = rangeManager?.getRange();
		final bool isCrossRowCol = range?.isCrossRowCol == true;
		final String? tableId = range?.tableId;
		int index = payload.startIndex < 0 ? 0 : payload.startIndex;
		final TextParticle? textParticle = _textParticle as TextParticle?;
		final HyperlinkParticle? hyperlinkParticle =
			_hyperlinkParticle as HyperlinkParticle?;
		final ImageParticle? imageParticle = _imageParticle as ImageParticle?;
		final LaTexParticle? laTexParticle = _laTexParticle as LaTexParticle?;
		final TableParticle? tableParticle = _tableParticle as TableParticle?;
		final SuperscriptParticle? superscriptParticle =
			_superscriptParticle as SuperscriptParticle?;
		final SubscriptParticle? subscriptParticle =
			_subscriptParticle as SubscriptParticle?;
		final SeparatorParticle? separatorParticle =
			_separatorParticle as SeparatorParticle?;
		final PageBreakParticle? pageBreakParticle =
			_pageBreakParticle as PageBreakParticle?;
		final CheckboxParticle? checkboxParticle =
			_checkboxParticle as CheckboxParticle?;
		final RadioParticle? radioParticle = _radioParticle as RadioParticle?;
		final LineBreakParticle? lineBreakParticle =
			_lineBreakParticle as LineBreakParticle?;
		final Control? control = _control as Control?;
		final Underline? underline = _underline as Underline?;
		final Strikeout? strikeout = _strikeout as Strikeout?;
		final Group? group = _group as Group?;
		final ListParticle? listParticle = _listParticle as ListParticle?;
		final BlockParticle? blockParticle = _blockParticle as BlockParticle?;
		final Position? position = _position as Position?;
		final double rangeMinWidth = (_options.rangeMinWidth ?? 5).toDouble();
		for (final IRow curRow in rowList) {
			final IElementFillRect rangeRecord =
				IElementFillRect(x: 0, y: 0, width: 0, height: 0);
			IElement? tableRangeElement;
			for (int j = 0; j < curRow.elementList.length; j++) {
				final IRowElement element = curRow.elementList[j];
				final IRowElement? preElement = j > 0 ? curRow.elementList[j - 1] : null;
				final int elementIndex = curRow.startIndex + j;
				if (elementIndex < 0 || elementIndex >= positionList.length) {
					index += 1;
					continue;
				}
				final IElementPosition pos = positionList[elementIndex];
				final List<double> leftTop = pos.coordinate['leftTop'] ?? <double>[0, 0];
				final double x = leftTop.isNotEmpty ? leftTop[0] : 0;
				final double y = leftTop.length > 1 ? leftTop[1] : 0;
				final double baselineOffset = pos.ascent;
				final IRowElement? nextElement =
					j + 1 < curRow.elementList.length ? curRow.elementList[j + 1] : null;
				final bool isHiddenElement =
					(element.hide == true ||
						element.control?.hide == true ||
						element.area?.hide == true) &&
						!isDesignMode();
				if (isHiddenElement) {
					textParticle?.complete();
				} else if (element.type == ElementType.image) {
					textParticle?.complete();
					final ImageDisplay? display = element.imgDisplay;
					if (display != ImageDisplay.surround &&
						display != ImageDisplay.floatTop &&
						display != ImageDisplay.floatBottom) {
						imageParticle?.render(ctx, element, x, y + baselineOffset);
					}
				} else if (element.type == ElementType.latex) {
					textParticle?.complete();
					laTexParticle?.render(ctx, element, x, y + baselineOffset);
				} else if (element.type == ElementType.table) {
					if (isCrossRowCol) {
						rangeRecord
							..x = x
							..y = y;
						tableRangeElement = element;
					}
					tableParticle?.render(ctx, element, x, y);
				} else if (element.type == ElementType.hyperlink) {
					textParticle?.complete();
					hyperlinkParticle?.render(ctx, element, x, y + baselineOffset);
				} else if (element.type == ElementType.date) {
					if (preElement == null || preElement.dateId != element.dateId) {
						textParticle?.complete();
					}
					textParticle?.record(ctx, element, x, y + baselineOffset);
					if (nextElement == null || nextElement.dateId != element.dateId) {
						textParticle?.complete();
					}
				} else if (element.type == ElementType.superscript) {
					textParticle?.complete();
					superscriptParticle?.render(ctx, element, x, y + baselineOffset);
				} else if (element.type == ElementType.subscript) {
					underline?.render(ctx);
					textParticle?.complete();
					subscriptParticle?.render(ctx, element, x, y + baselineOffset);
				} else if (element.type == ElementType.separator) {
					separatorParticle?.render(ctx, element, x, y);
				} else if (element.type == ElementType.pageBreak) {
					if (_mode != EditorMode.clean && !isPrintMode) {
						pageBreakParticle?.render(ctx, element, x, y);
					}
				} else if (element.type == ElementType.checkbox ||
					element.controlComponent == ControlComponent.checkbox) {
					textParticle?.complete();
					checkboxParticle?.render(
						CheckboxRenderPayload(
							ctx: ctx,
							x: x,
							y: y + baselineOffset,
							index: j,
							row: curRow,
						),
					);
				} else if (element.type == ElementType.radio ||
					element.controlComponent == ControlComponent.radio) {
					textParticle?.complete();
					radioParticle?.render(
						RadioRenderPayload(
							ctx: ctx,
							x: x,
							y: y + baselineOffset,
							index: j,
							row: curRow,
						),
					);
				} else if (element.type == ElementType.tab) {
					textParticle?.complete();
				} else if (element.rowFlex == RowFlex.alignment ||
					 element.rowFlex == RowFlex.justify) {
					textParticle?.record(ctx, element, x, y + baselineOffset);
					textParticle?.complete();
				} else if (element.type == ElementType.block) {
					textParticle?.complete();
					blockParticle?.render(ctx, pageNo, element, x, y + baselineOffset);
				} else {
					if ((element.left ?? 0) != 0) {
						textParticle?.complete();
					}
					textParticle?.record(ctx, element, x, y + baselineOffset);
					if (element.width != null || element.letterSpacing != null ||
						regular.punctuationReg.hasMatch(element.value)) {
						textParticle?.complete();
					}
				}

				if (
					isDrawLineBreak &&
					!isPrintMode &&
					_mode != EditorMode.clean &&
					curRow.isWidthNotEnough != true &&
					j == curRow.elementList.length - 1
				) {
					lineBreakParticle?.render(ctx, element, x, y + curRow.height / 2);
				}

				final bool hasCurrentBorder = element.control?.border == true;
				final bool hasPreviousBorder = preElement?.control?.border == true;
				if (hasCurrentBorder) {
					if (hasPreviousBorder && preElement?.controlId != element.controlId) {
						control?.drawBorder(ctx);
					}
					final double rowMargin = getElementRowMargin(element);
					control?.recordBorderInfo(
						x,
						y + rowMargin,
						element.metrics.width,
						curRow.height - 2 * rowMargin,
					);
				} else if (hasPreviousBorder) {
					control?.drawBorder(ctx);
				}

				if (element.underline == true || element.control?.underline == true) {
					if (preElement?.type == ElementType.subscript &&
						element.type != ElementType.subscript) {
						underline?.render(ctx);
					}
					final double rowMargin = getElementRowMargin(element);
					final double offsetX = element.left ?? 0;
					double underlineOffset = 0;
					if (element.type == ElementType.subscript && subscriptParticle != null) {
						underlineOffset = subscriptParticle.getOffsetY(element);
					}
					final String? underlineColor =
						element.control?.underline == true
							? _options.underlineColor
							: element.color;
					underline?.recordFillInfo(
						ctx,
						x - offsetX,
						y + curRow.height - rowMargin + underlineOffset,
						element.metrics.width + offsetX,
						0,
						underlineColor,
						element.textDecoration?.style,
					);
				} else if (preElement?.underline == true ||
					preElement?.control?.underline == true) {
					underline?.render(ctx);
				}

				if (element.strikeout == true) {
					final bool isTextLike = element.type == null ||
						(element.type != null &&
							element_constants.textlikeElementType.contains(element.type!));
					if (isTextLike && textParticle != null) {
						final bool shouldFlush = preElement != null &&
							((preElement.type == ElementType.subscript &&
								element.type != ElementType.subscript) ||
							 (preElement.type == ElementType.superscript &&
								element.type != ElementType.superscript) ||
							 getElementSize(preElement) != getElementSize(element));
						if (shouldFlush) {
							strikeout?.render(ctx);
						}
						final ITextMetrics basisMetrics =
							textParticle.measureBasisWord(ctx, getElementFont(element));
						double adjustY =
							y +
							baselineOffset +
							basisMetrics.actualBoundingBoxDescent * scale -
							element.metrics.height / 2;
						if (element.type == ElementType.subscript && subscriptParticle != null) {
							adjustY += subscriptParticle.getOffsetY(element);
						} else if (element.type == ElementType.superscript &&
							superscriptParticle != null) {
							adjustY += superscriptParticle.getOffsetY(element);
						}
						strikeout?.recordFillInfo(ctx, x, adjustY, element.metrics.width);
					}
				} else if (preElement?.strikeout == true) {
					strikeout?.render(ctx);
				}

				if (range != null &&
					zone != null &&
					range.zone == zone &&
					range.startIndex != range.endIndex &&
					range.startIndex <= index &&
					index <= range.endIndex) {
					final dynamic positionContext = position?.getPositionContext();
					final bool isTableContext = positionContext?.isTable == true;
					final String? tdId = element.tdId;
					final bool isSameTableContext =
						(!isTableContext && tdId == null) ||
						(positionContext?.tdId == tdId);
					if (isSameTableContext) {
						if (range.startIndex == index) {
							final int nextIndex = range.startIndex + 1;
							if (nextIndex < elementList.length &&
								elementList[nextIndex].value == ZERO) {
								rangeRecord
									..x = x + element.metrics.width
									..y = y
									..height = curRow.height;
								rangeRecord.width += rangeMinWidth;
							}
						} else {
							double rangeWidth = element.metrics.width;
							if (rangeWidth == 0 && curRow.elementList.length == 1) {
								rangeWidth = rangeMinWidth;
							}
							if (rangeRecord.width == 0) {
								rangeRecord
									..x = x
									..y = y
									..height = curRow.height;
							}
							rangeRecord.width += rangeWidth;
						}
					}
				}

				if (!groupDisabled && element.groupIds != null && element.groupIds!.isNotEmpty) {
					group?.recordFillInfo(element, x, y, element.metrics.width, curRow.height);
				}

				if (element.type == ElementType.table && element.hide != true) {
					final double tdPaddingWidth = tdPadding[1] + tdPadding[3];
					final List<ITr>? trList = element.trList;
					if (trList != null) {
						for (final ITr tr in trList) {
							for (final ITd td in tr.tdList) {
								final List<IRow>? tdRowList = td.rowList;
								final List<IElementPosition>? tdPositionList = td.positionList;
								if (tdRowList == null || tdPositionList == null) {
									continue;
								}
								final List<IElement> tdValue = td.value;
								final double tdWidth = (td.width ?? 0) - tdPaddingWidth;
								drawRow(
									ctx,
									IDrawRowPayload(
										elementList: tdValue,
										positionList: tdPositionList,
										rowList: tdRowList,
										pageNo: pageNo,
										startIndex: 0,
										innerWidth: tdWidth * scale,
										zone: zone,
										isDrawLineBreak: isDrawLineBreak,
									),
								);
							}
						}
					}
				}

				index += 1;
			}

			if (curRow.isList == true &&
				curRow.startIndex >= 0 &&
				curRow.startIndex < positionList.length) {
				final IElementPosition startPosition = positionList[curRow.startIndex];
				listParticle?.drawListStyle(ctx, curRow, startPosition);
			}

			textParticle?.complete();
			control?.drawBorder(ctx);
			underline?.render(ctx);
			strikeout?.render(ctx);
			group?.render(ctx);

			if (!isPrintMode) {
				if (rangeRecord.width > 0 && rangeRecord.height > 0) {
					rangeManager?.render(ctx, rangeRecord.x, rangeRecord.y, rangeRecord.width, rangeRecord.height);
				}
				if (isCrossRowCol &&
					tableRangeElement != null &&
					tableId != null &&
					tableRangeElement.id != null &&
					tableRangeElement.id == tableId &&
					curRow.startIndex >= 0 &&
					curRow.startIndex < positionList.length) {
					final IElementPosition startPosition = positionList[curRow.startIndex];
					final List<double> leftTop = startPosition.coordinate['leftTop'] ?? <double>[0, 0];
					final double startX = leftTop.isNotEmpty ? leftTop[0] : 0;
					final double startY = leftTop.length > 1 ? leftTop[1] : 0;
					tableParticle?.drawRange(ctx, tableRangeElement, startX, startY);
				}
			}
		}
	}

	void _drawFloat(CanvasRenderingContext2D ctx, IDrawFloatPayload payload) {
		final Position? position = _position as Position?;
		final ImageParticle? imageParticle = _imageParticle as ImageParticle?;
		if (position == null || imageParticle == null) {
			return;
		}
		final List<ImageDisplay> imgDisplays = payload.imgDisplays;
		if (imgDisplays.isEmpty) {
			return;
		}
		final List<IFloatPosition> floatPositionList =
			position.getFloatPositionList();
		if (floatPositionList.isEmpty) {
			return;
		}
		final double scale = (_options.scale ?? 1).toDouble();
		for (final IFloatPosition floatPosition in floatPositionList) {
			final IElement element = floatPosition.element;
			final ImageDisplay? display = element.imgDisplay;
			if ((floatPosition.pageNo == payload.pageNo ||
					floatPosition.zone == EditorZone.header ||
					floatPosition.zone == EditorZone.footer) &&
				display != null &&
				imgDisplays.contains(display) &&
				element.type == ElementType.image) {
				final Map<String, num>? floatPositionMap = element.imgFloatPosition;
				if (floatPositionMap == null) {
					continue;
				}
				final double x = (floatPositionMap['x'] ?? 0).toDouble() * scale;
				final double y = (floatPositionMap['y'] ?? 0).toDouble() * scale;
				imageParticle.render(ctx, element, x, y);
			}
		}
	}

	void _clearPage(int pageNo) {
		if (pageNo < 0 ||
			pageNo >= _ctxList.length ||
			pageNo >= _pageList.length) {
			return;
		}
		final CanvasRenderingContext2D ctx = _ctxList[pageNo];
		final CanvasElement page = _pageList[pageNo];
		final double pageWidth = (page.width ?? 0).toDouble();
		final double pageHeight = (page.height ?? 0).toDouble();
		final double clearWidth = pageWidth > getWidth() ? pageWidth : getWidth();
		final double clearHeight =
			pageHeight > getHeight() ? pageHeight : getHeight();
		ctx.clearRect(0, 0, clearWidth, clearHeight);
		final BlockParticle? blockParticle = _blockParticle as BlockParticle?;
		blockParticle?.clear();
	}

	void _drawPage(IDrawPagePayload payload) {
		final int pageNo = payload.pageNo;
		if (pageNo < 0 || pageNo >= _ctxList.length) {
			return;
		}
		final CanvasRenderingContext2D ctx = _ctxList[pageNo];
		final Background? background = _background as Background?;
		final Margin? margin = _margin as Margin?;
		final Watermark? watermark = _watermark as Watermark?;
		final PageNumber? pageNumber = _pageNumber as PageNumber?;
		final LineNumber? lineNumber = _lineNumber as LineNumber?;
		final PageBorder? pageBorder = _pageBorder as PageBorder?;
		final Placeholder? placeholder = _placeholder as Placeholder?;
		final Control? control = _control as Control?;
		final Area? area = _area as Area?;
		final Search? search = _search as Search?;
		final Badge? badge = _badge as Badge?;
		final bool isPrintMode = _mode == EditorMode.print;
		final Zone zone = getZone();
		final double inactiveAlpha = (_options.inactiveAlpha ?? 1).toDouble();
		ctx.globalAlpha = zone.isMainActive() ? 1 : inactiveAlpha;

		_clearPage(pageNo);
		background?.render(ctx, pageNo);

		if (!isPrintMode) {
			area?.render(ctx, pageNo);
		}

		final PageMode pageMode = _options.pageMode ?? PageMode.paging;
		if (pageMode != PageMode.continuity && _options.watermark?.data != null) {
			watermark?.render(ctx, pageNo);
		}

		if (!isPrintMode) {
			margin?.render(ctx, pageNo);
		}

		_drawFloat(
			ctx,
			IDrawFloatPayload(
				pageNo: pageNo,
				imgDisplays: <ImageDisplay>[ImageDisplay.floatBottom],
			),
		);

		if (!isPrintMode) {
			control?.renderHighlightList(ctx, pageNo);
		}

		final List<IRow> rowList = payload.rowList;
		final double innerWidth = getInnerWidth();
		final int startIndex = rowList.isNotEmpty ? rowList.first.startIndex : 0;

		drawRow(
			ctx,
			IDrawRowPayload(
				elementList: payload.elementList,
				positionList: payload.positionList,
				rowList: rowList,
				pageNo: pageNo,
				startIndex: startIndex,
				innerWidth: innerWidth,
				zone: EditorZone.main,
			),
		);

		if (getIsPagingMode()) {
			if ((_options.header?.disabled ?? false) != true) {
				_header.render(ctx, pageNo);
			}
			if ((_options.pageNumber?.disabled ?? false) != true) {
				pageNumber?.render(ctx, pageNo);
			}
			if ((_options.footer?.disabled ?? false) != true) {
				_footer.render(ctx, pageNo);
			}
		}

		_drawFloat(
			ctx,
			IDrawFloatPayload(
				pageNo: pageNo,
				imgDisplays: <ImageDisplay>[
					ImageDisplay.floatTop,
					ImageDisplay.surround,
				],
			),
		);

		if (!isPrintMode) {
			final String? keyword = search?.getSearchKeyword();
			if (keyword != null && keyword.isNotEmpty) {
				search?.render(ctx, pageNo);
			}
		}

		if (_elementList.length <= 1 &&
				(_elementList.isEmpty || _elementList.first.listId == null)) {
			placeholder?.render(ctx);
		}

		lineNumber?.render(ctx, pageNo);
		pageBorder?.render(ctx);
		badge?.render(ctx, pageNo);
		ctx.globalAlpha = 1;
	}

	void _disconnectLazyRender() {
		_lazyRenderObserver?.disconnect();
		_lazyRenderObserver = null;
	}

	void _lazyRender() {
		final Position? position = _position as Position?;
		if (position == null) {
			_immediateRender();
			return;
		}
		final List<IElementPosition> positionList =
			position.getOriginalMainPositionList();
		final List<IElement> elementList = getOriginalMainElementList();
		_disconnectLazyRender();
		final IntersectionObserver observer = IntersectionObserver((entries, observer) {
				for (final IntersectionObserverEntry entry in entries) {
				final double ratio = (entry.intersectionRatio ?? 0).toDouble();
				final bool isIntersecting =
					(entry as dynamic).isIntersecting == true || ratio > 0;
					if (!isIntersecting) {
						continue;
					}
				final Element? target = entry.target;
				if (target == null) {
					continue;
				}
				final String? indexAttr = target.dataset['index'];
					final int? pageIndex =
						indexAttr != null ? int.tryParse(indexAttr) : null;
					if (pageIndex == null ||
							pageIndex < 0 ||
							pageIndex >= _pageRowList.length) {
						continue;
					}
					_drawPage(
						IDrawPagePayload(
							elementList: elementList,
							positionList: positionList,
							rowList: _pageRowList[pageIndex],
							pageNo: pageIndex,
						),
					);
				}
		});
		_lazyRenderObserver = observer;
		for (final CanvasElement page in _pageList) {
			observer.observe(page);
		}
	}

	void _immediateRender() {
		final Position? position = _position as Position?;
		if (position == null) {
			return;
		}
		final List<IElementPosition> positionList =
			position.getOriginalMainPositionList();
		final List<IElement> elementList = getOriginalMainElementList();
		for (int i = 0; i < _pageRowList.length; i++) {
			_drawPage(
				IDrawPagePayload(
					elementList: elementList,
					positionList: positionList,
					rowList: _pageRowList[i],
					pageNo: i,
				),
			);
		}
	}

	// ---------------------------------------------------------------------------
	// Rendering (incremental implementation)
	// ---------------------------------------------------------------------------

	void render([IDrawOption? option]) {
		ensureContainerMounted();
		_renderCount += 1;
		final IDrawOption renderOption = option ?? IDrawOption();
		final bool isCompute = renderOption.isCompute ?? true;
		final bool isLazy = renderOption.isLazy ?? true;
		final bool isInit = renderOption.isInit ?? false;
		final bool isSubmitHistory = renderOption.isSubmitHistory ?? true;
		final bool isSourceHistory = renderOption.isSourceHistory ?? false;
		final bool isSetCursor = renderOption.isSetCursor ?? true;
		final bool isFirstRender = renderOption.isFirstRender ?? false;
		int? curIndex = renderOption.curIndex;
		final double innerWidth = getInnerWidth();
		if (innerWidth <= 0) {
			return;
		}
		final bool isPagingMode = getIsPagingMode();
		final int oldPageSize = _pageRowList.length;
		final Position? position = _position as Position?;
		final Area? area = _area as Area?;
		final Search? search = _search as Search?;
		final Control? control = _control as Control?;
		final RangeManager? rangeManager = _rangeManager as RangeManager?;
		final Header header = _header;
		final Footer footer = _footer;

		if (isCompute) {
			position?.setFloatPositionList(<IFloatPosition>[]);
			if (isPagingMode) {
				if ((_options.header?.disabled ?? false) != true) {
					header.compute();
				} else {
					header.recovery();
				}
				if ((_options.footer?.disabled ?? false) != true) {
					footer.compute();
				} else {
					footer.recovery();
				}
			}
			final List<double> margins = getMargins();
			final double pageHeight = getHeight();
			final double extraHeight = header.getExtraHeight();
			final double mainOuterHeight = getMainOuterHeight();
			final List<IElement> surroundElementList =
				element_utils.pickSurroundElementList(_elementList);
			final List<IRow> computedRows = computeRowList(
				IComputeRowListPayload(
					startX: margins[3],
					startY: margins[0] + extraHeight,
					pageHeight: pageHeight,
					mainOuterHeight: mainOuterHeight,
					isPagingMode: isPagingMode,
					innerWidth: innerWidth,
					surroundElementList: surroundElementList,
					elementList: _elementList,
				),
			);
			_rowList
				..clear()
				..addAll(computedRows);
			final List<List<IRow>> pageRows = _computePageList();
			_pageRowList
				..clear()
				..addAll(pageRows);
			position?.computePositionList();
			area?.compute();
			if (_mode != EditorMode.print) {
				final String? keyword = search?.getSearchKeyword();
				if (keyword != null && keyword.isNotEmpty) {
					search?.compute(keyword);
				}
				control?.computeHighlightList();
			}
		}

		final ImageObserver? imageObserver = _imageObserver as ImageObserver?;
		imageObserver?.clearAll();
		final Cursor? cursor = _cursor as Cursor?;
		cursor?.recoveryCursor();

		_syncPageCanvases();

		if (isLazy && isPagingMode) {
			_lazyRender();
		} else {
			_disconnectLazyRender();
			_immediateRender();
		}

		if (isSetCursor) {
			curIndex = setCursor(curIndex);
		} else if (rangeManager?.getIsSelection() == true) {
			cursor?.focus();
		}

		final HistoryManager? historyManager = _historyManager as HistoryManager?;
		final bool isHistoryStackEmpty = historyManager?.isStackEmpty() ?? false;
		if ((isSubmitHistory && !isFirstRender) ||
				(curIndex != null && isHistoryStackEmpty)) {
			submitHistory(curIndex);
		}

		utils.nextTick(() {
			rangeManager?.setRangeStyle();
			if (isCompute && control?.getActiveControl() != null) {
				try {
					control?.reAwakeControl();
				} catch (_) {}
			}
			if (isCompute &&
					!isReadonly() &&
					position?.getPositionContext().isTable == true) {
				final dynamic tableTool = _tableTool;
				tableTool?.render?.call();
			}
			if (isCompute && _mode != EditorMode.print && !getZone().isMainActive()) {
				getZone().drawZoneIndicator();
			}
			if (oldPageSize != _pageRowList.length) {
				_listener?.pageSizeChange?.call(_pageRowList.length);
				if (_eventBus?.isSubscribe?.call('pageSizeChange') == true) {
					_eventBus.emit('pageSizeChange', _pageRowList.length);
				}
			}
			if ((isSubmitHistory || isSourceHistory) && !isInit) {
				_listener?.contentChange?.call();
				if (_eventBus?.isSubscribe?.call('contentChange') == true) {
					_eventBus.emit('contentChange');
				}
			}
		});
	}

	int? setCursor([int? curIndex]) {
		final Position? position = _position as Position?;
		final Cursor? cursor = _cursor as Cursor?;
		if (position == null || cursor == null) {
			return curIndex;
		}

		final IPositionContext positionContext = position.getPositionContext();
		final List<IElementPosition> positionList = position.getPositionList();

		if (positionContext.isTable) {
			final int? elementIndex = positionContext.index;
			final int? trIndex = positionContext.trIndex;
			final int? tdIndex = positionContext.tdIndex;
			IElementPosition? tablePosition;
			final List<IElement> elementList = getOriginalElementList();
			if (elementIndex != null &&
					elementIndex >= 0 &&
					elementIndex < elementList.length) {
				final IElement tableElement = elementList[elementIndex];
				final List<ITr>? trList = tableElement.trList;
				if (trList != null &&
						trIndex != null &&
						trIndex >= 0 &&
						trIndex < trList.length) {
					final ITr tr = trList[trIndex];
					final List<ITd> tdList = tr.tdList;
					if (tdIndex != null &&
							tdIndex >= 0 &&
							tdIndex < tdList.length) {
						final ITd td = tdList[tdIndex];
						final List<IElementPosition>? tablePositionList =
							td.positionList;
						if (curIndex == null &&
								tablePositionList != null &&
								tablePositionList.isNotEmpty) {
							curIndex = tablePositionList.length - 1;
						}
						if (tablePositionList != null &&
								curIndex != null &&
								curIndex >= 0 &&
								curIndex < tablePositionList.length) {
							tablePosition = tablePositionList[curIndex];
						}
					}
				}
			}
			position.setCursorPosition(tablePosition);
		} else {
			IElementPosition? cursorPosition;
			if (curIndex != null &&
					curIndex >= 0 &&
					curIndex < positionList.length) {
				cursorPosition = positionList[curIndex];
			}
			position.setCursorPosition(cursorPosition);
		}

		bool isShowCursor = true;
		if (curIndex != null &&
				positionContext.isImage == true &&
				positionContext.isDirectHit == true) {
			final List<IElement> elementList = getElementList();
			if (curIndex >= 0 && curIndex < elementList.length) {
				final IElement element = elementList[curIndex];
				final ElementType? elementType = element.type;
				if (elementType != null &&
						element_constants.imageElementType.contains(elementType)) {
					isShowCursor = false;
					final Previewer? previewer = _previewer as Previewer?;
					final IElementPosition? cursorPosition =
						position.getCursorPosition();
					if (cursorPosition != null) {
						previewer?.updateResizer(element, cursorPosition);
					}
				}
			}
		}

		cursor.drawCursor(IDrawCursorOption(isShow: isShowCursor));
		return curIndex;
	}

	void setPageScale(double scale) {
		if (scale <= 0) {
			return;
		}
		_options.scale = scale;
		_formatContainer();
		_applyPageMetrics();
		render(
			IDrawOption(
				isSetCursor: true,
				isSubmitHistory: false,
			),
		);
		final dynamic callback = _listener?.pageScaleChange;
		callback?.call(scale);
		_emitEvent('pageScaleChange', scale);
	}

	void setPageDevicePixel() {
		_applyPageMetrics(updateStyles: false);
	}

	void setPaperSize(double width, double height) {
		if (width <= 0 || height <= 0) {
			return;
		}
		_options.width = width;
		_options.height = height;
		_formatContainer();
		_applyPageMetrics();
		render(
			IDrawOption(
				isSetCursor: false,
				isSubmitHistory: false,
			),
		);
	}

	void setPaperDirection(PaperDirection payload) {
		if (_options.paperDirection == payload) {
			return;
		}
		_options.paperDirection = payload;
		_formatContainer();
		_applyPageMetrics();
		render(
			IDrawOption(
				isSetCursor: false,
				isSubmitHistory: false,
			),
		);
	}

	void setPaperMargin(IMargin payload) {
		_options.margins = List<double>.from(payload);
		render(
			IDrawOption(
				isSetCursor: false,
				isSubmitHistory: false,
			),
		);
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

	void attachSearch(dynamic search) => _search = search;

	void attachControl(dynamic control) => _control = control;

	void attachDateParticle(dynamic dateParticle) => _dateParticle = dateParticle;

	void attachImageObserver(dynamic imageObserver) => _imageObserver = imageObserver;

	void attachImageParticle(dynamic imageParticle) => _imageParticle = imageParticle;

	void attachCheckboxParticle(dynamic checkboxParticle) => _checkboxParticle = checkboxParticle;

	void attachListParticle(dynamic listParticle) => _listParticle = listParticle;

	void attachRadioParticle(dynamic radioParticle) => _radioParticle = radioParticle;

	void attachSeparatorParticle(dynamic separatorParticle) =>
		_separatorParticle = separatorParticle;

	void attachPageBreakParticle(dynamic pageBreakParticle) =>
		_pageBreakParticle = pageBreakParticle;

	void attachBadge(dynamic badge) => _badge = badge;

	void attachArea(dynamic area) => _area = area;

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
	dynamic getTextParticle() => _textParticle;
	dynamic getHyperlinkParticle() => _hyperlinkParticle;
	dynamic getSearch() => _search;
	dynamic getControl() => _control;
	dynamic getDateParticle() => _dateParticle;
	dynamic getImageObserver() => _imageObserver;
	dynamic getImageParticle() => _imageParticle;
	dynamic getCheckboxParticle() => _checkboxParticle;
	dynamic getListParticle() => _listParticle;
	dynamic getRadioParticle() => _radioParticle;
	dynamic getSeparatorParticle() => _separatorParticle;
	dynamic getPageBreakParticle() => _pageBreakParticle;
	dynamic getBadge() => _badge;
	dynamic getArea() => _area;
	dynamic getWorkerManager() => _workerManager;

	void clearSideEffect() {
		_cursor?.recoveryCursor();
		(_previewer as Previewer?)?.clearResizer();
		final dynamic tableTool = _tableTool;
		if (tableTool != null) {
			try {
				tableTool.dispose();
			} catch (_) {}
		}
		(_hyperlinkParticle as HyperlinkParticle?)?.clearHyperlinkPopup();
		(_dateParticle as DateParticle?)?.clearDatePicker();
	}

	IPositionContext _clonePositionContext(IPositionContext source) {
		return IPositionContext(
			isTable: source.isTable,
			isCheckbox: source.isCheckbox,
			isRadio: source.isRadio,
			isControl: source.isControl,
			isImage: source.isImage,
			isDirectHit: source.isDirectHit,
			index: source.index,
			trIndex: source.trIndex,
			tdIndex: source.tdIndex,
			tdId: source.tdId,
			trId: source.trId,
			tableId: source.tableId,
		);
	}

	IRange _cloneRange(IRange source) {
		return IRange(
			startIndex: source.startIndex,
			endIndex: source.endIndex,
			isCrossRowCol: source.isCrossRowCol,
			tableId: source.tableId,
			startTdIndex: source.startTdIndex,
			endTdIndex: source.endTdIndex,
			startTrIndex: source.startTrIndex,
			endTrIndex: source.endTrIndex,
			zone: source.zone,
		);
	}

	// ---------------------------------------------------------------------------
	// Internal helpers
	// ---------------------------------------------------------------------------

	void _initializeContainers() {
		_wrapContainer();
		_formatContainer();
		_ensurePageContainer();
		if (_pageList.isEmpty) {
			_createPage(0);
		}
		_containerInitialized = true;
	}

	void _wrapContainer() {
		if (_container.isConnected != true) {
			_rootContainer.append(_container);
		}
	}

	void _formatContainer() {
		final double width = getWidth();
		_container.style
			..position = 'relative'
			..width = '${width}px';
		_container.setAttribute(EDITOR_COMPONENT, EditorComponent.main.name);
	}

	void _ensurePageContainer() {
		if (_pageContainer.isConnected != true) {
			_pageContainer.classes.add('$EDITOR_PREFIX-page-container');
			_container.append(_pageContainer);
		}
	}

	void _initPageContext(CanvasRenderingContext2D ctx) {
		final double dpr = getPagePixelRatio();
		ctx
			..setTransform(1, 0, 0, 1, 0, 0)
			..scale(dpr, dpr);
	}

	void _applyPageMetrics({bool updateStyles = true}) {
		if (_pageList.isEmpty) {
			return;
		}
		final double width = getWidth();
		final double height = getHeight();
		final double gap = getPageGap();
		final double ratio = getPagePixelRatio();
		for (int i = 0; i < _pageList.length; i++) {
			final CanvasElement page = _pageList[i];
			page
				..width = (width * ratio).round()
				..height = (height * ratio).round();
			if (updateStyles) {
				page
					..style.width = '${width}px'
					..style.height = '${height}px'
					..style.marginBottom = '${gap}px';
			}
			_initPageContext(_ctxList[i]);
		}
	}

	List<IElement> _cloneElementList(List<IElement> source) {
		return element_utils.cloneElementList(source);
	}

	List<IElement>? _cloneOptionalElementList(List<IElement>? source) {
		if (source == null || source.isEmpty) {
			return source == null ? null : <IElement>[];
		}
		return element_utils.cloneElementList(source);
	}

	List<IElement> _filterAssistElementList(List<IElement> source) {
		final List<IElement> working = element_utils.cloneElementList(source);
		final dynamic control = _control;
		if (control != null) {
			try {
				final dynamic result = control.filterAssistElement(working);
				if (result is List<IElement>) {
					return result;
				}
			} catch (_) {}
		}
		return working;
	}

	List<IElement>? _filterAssistElementListNullable(List<IElement>? source) {
		if (source == null) {
			return null;
		}
		if (source.isEmpty) {
			return <IElement>[];
		}
		return _filterAssistElementList(source);
	}

	double _resolveHeaderExtraHeight() {
		return _header.getExtraHeight();
	}

	void _emitEvent(String eventName, dynamic payload) {
		final dynamic bus = _eventBus;
		if (bus == null) {
			return;
		}
		try {
			final bool hasSubscriber;
			if (bus is EventBus) {
				hasSubscriber = bus.isSubscribe(eventName);
			} else {
				final dynamic result = bus.isSubscribe(eventName);
				hasSubscriber = result is bool ? result : false;
			}
			if (hasSubscriber) {
				bus.emit(eventName, payload);
			}
		} catch (_) {
			try {
				bus.emit(eventName, payload);
			} catch (_) {}
		}
	}

	double _resolveFooterExtraHeight() {
		return _footer.getExtraHeight();
	}

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
			..style.cursor = 'text'
			..dataset['index'] = '$index';

		final CanvasRenderingContext2D ctx = canvas.context2D;
		_initPageContext(ctx);

		_pageContainer.append(canvas);
		_pageList.add(canvas);
		_ctxList.add(ctx);
	}

	void _syncPageCanvases() {
		final int desiredPageCount = _pageRowList.isEmpty ? 1 : _pageRowList.length;
		while (_pageList.length < desiredPageCount) {
			_createPage(_pageList.length);
		}
		while (_pageList.length > desiredPageCount) {
			final CanvasElement removedCanvas = _pageList.removeLast();
			removedCanvas.remove();
			if (_ctxList.isNotEmpty) {
				_ctxList.removeLast();
			}
		}
		if (_pageNo >= desiredPageCount) {
			_pageNo = desiredPageCount - 1;
		}
		if (_pageNo < 0 && desiredPageCount > 0) {
			_pageNo = 0;
		}
		_applyPageMetrics();
	}

	static RegExp? _buildLetterReg(List<String>? letterClass) {
		if (letterClass == null || letterClass.isEmpty) {
			return null;
		}
		final String joined = letterClass.join();
		return RegExp('[$joined]');
	}

	static const double _defaultOriginalWidth = 794; // px ~ A4 portrait (210mm)
	static const double _defaultOriginalHeight = 1123; // px ~ A4 portrait (297mm)
	static const double _defaultPageGap = 20;
	static const List<double> _defaultMargins = <double>[96, 96, 96, 96];
	static const double _defaultMarginIndicatorSize = 35;
	static const double _defaultPageNumberBottom = 60;
}