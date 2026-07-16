import 'dart:async';
import 'dart:html';
import 'package:canvas_text_editor/ce_fonts.dart' as ce_fonts;
import '../../dataset/constant/common.dart';
import '../../dataset/constant/editor.dart';
import '../../dataset/constant/element.dart' as element_constants;
import '../../dataset/constant/group.dart' show defaultGroupOption;
import '../../dataset/constant/regular.dart' as regular;
import '../../dataset/enum/common.dart';
import '../../dataset/enum/control.dart';
import '../../dataset/enum/editor.dart';
import '../../dataset/enum/element.dart';
import '../../dataset/enum/observer.dart' show MoveDirection;
import '../../dataset/enum/row.dart';
import '../../interface/draw.dart';
import '../../interface/editor.dart';
import '../../interface/element.dart';
import '../../interface/graffiti.dart';
import '../../interface/group.dart';
import '../../interface/margin.dart';
import '../../interface/position.dart';
import '../../interface/range.dart';
import '../../interface/row.dart';
import '../../interface/table/table.dart';
import '../../interface/table/td.dart';
import '../../utils/element.dart' as element_utils;
import '../../utils/index.dart' as utils;
import '../../utils/option.dart' as option_utils;
import '../actuator/actuator.dart';
import '../cursor/cursor.dart';
import '../document/document_locator.dart';
import '../document/document_model.dart';
import '../document/document_mutation.dart';
import '../document/document_range.dart';
import '../document/document_transaction.dart';
import '../event/canvas_event.dart';
import '../event/eventbus/event_bus.dart';
import '../event/global_event.dart';
import '../history/history_manager.dart';
import '../history/history_view_state.dart';
import '../i18n/i18n.dart';
import '../layout/layout_invalidation.dart';
import '../layout/page_row_index.dart';
import '../layout/layout_request.dart';
import '../layout/layout_scheduler.dart';
import '../observer/mouse_observer.dart';
import '../observer/scroll_observer.dart';
import '../observer/selection_observer.dart';
import '../position/position.dart';
import '../range/range_manager.dart';
import '../rendering/dirty_page_queue.dart';
import '../rendering/page_canvas_manager.dart';
import '../worker/worker_manager.dart';
import '../zone/zone.dart';
import 'control/control.dart';
import 'frame/background.dart';
import 'frame/badge.dart';
import 'frame/footer.dart';
import 'graffiti/graffiti.dart';
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
import 'particle/label_particle.dart';
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
import 'particle/text_box_tool.dart';
import 'particle/text_particle.dart';
import 'particle/superscript_particle.dart';
import 'particle/white_space_particle.dart';
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
const String _packageVersion = String.fromEnvironment(
  'CANVAS_EDITOR_VERSION',
  defaultValue: 'dev',
);

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
        _headerElementList =
            List<IElement>.from(data.header ?? const <IElement>[]),
        _footerElementList =
            List<IElement>.from(data.footer ?? const <IElement>[]),
        _container = DivElement(),
        _pageContainer = DivElement(),
        _pageNo = 0,
        _renderCount = 0,
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
        _graffiti = null,
        _workerManager = null {
    _documentModel = DocumentModel(
      main: _elementList,
      header: _headerElementList,
      footer: _footerElementList,
    );
    _pageCanvasManager = PageCanvasManager(
      pageContainer: _pageContainer,
      width: getWidth,
      height: getHeight,
      pageGap: getPageGap,
    );
    _initializeContainers();
    _position = Position(this);
    _rangeManager = RangeManager(this);
    _historyManager = HistoryManager(this);
    _listParticle = ListParticle(this);
    _checkboxParticle = CheckboxParticle(this);
    _radioParticle = RadioParticle(this);
    _separatorParticle = SeparatorParticle(this);
    _hyperlinkParticle = HyperlinkParticle(this);
    _textBoxTool = TextBoxTool(this);
    _dateParticle = DateParticle(this);
    _pageBreakParticle = PageBreakParticle(this);
    _search = Search(this);
    _control = Control(this);
    _textParticle = TextParticle(this);
    _whiteSpaceParticle = WhiteSpaceParticle(this);
    _tableParticle = TableParticle(this);
    _imageParticle = ImageParticle(this);
    _labelParticle = LabelParticle(this);
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
    _graffiti = Graffiti(this, data.graffiti);
    _previewer = Previewer(this);
    _imageObserver = ImageObserver();
    _tableTool = TableTool(this);
    _tableOperate = TableOperate(this);
    _scrollDrawQueue = DirtyPageQueue(
      paint: _drawQueuedScrollPage,
      shouldPaint: _shouldDrawQueuedScrollPage,
    );
    _layoutScheduler = LayoutScheduler<_ProgressiveLayoutContinuation, int>(
      frameBudget: const Duration(milliseconds: 10),
    );
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
    _documentLocatorIndex = DocumentLocatorIndex(_documentRegionRoots());

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
  late final PageCanvasManager _pageCanvasManager;
  List<CanvasElement> get _pageList => _pageCanvasManager.pageList;
  List<CanvasRenderingContext2D> get _ctxList => _pageCanvasManager.contextList;
  final List<int> _visiblePageNoList;
  int _intersectionPageNo;
  final IEditorOption _options;
  EditorMode _mode;
  final List<IElement> _elementList;
  final List<IElement> _headerElementList;
  final List<IElement> _footerElementList;
  late final DocumentModel _documentModel;
  late final DocumentLocatorIndex _documentLocatorIndex;
  int _pageNo;
  int _renderCount;
  int _deepHistorySnapshotCount = 0;
  int _compactHistoryTransitionCount = 0;
  int _compactHistoryMutationCount = 0;
  int _historyReplayDepth = 0;
  int _historyReplayRenderCount = 0;
  IDrawOption? _historyReplayRenderOption;

  // Instrumentação de fases do render (diagnóstico de performance F5).
  static bool debugRenderTiming = false;
  double _tPhase = 0;

  // Layout progressivo/fatiado (F5.5): a 1ª fatia é síncrona (viewport) e o
  // restante fica pendente. Inspirado no Google Docs/Kix, novas páginas só são
  // descobertas quando a rolagem encosta no fim já conhecido; não há corrida
  // em background para paginar o documento inteiro logo após abrir.
  // Repintura dirigida do fast path (P2+): faixa de rows recomputadas pelo
  // _tryFastParagraphLayout e se a altura do parágrafo ficou idêntica —
  // quando fica, só as páginas dessa faixa redesenham no _lazyRender.
  int? _fastLayoutDirtyRowIndexStart;
  int? _fastLayoutDirtyRowIndexEnd;
  bool _fastLayoutHeightUnchanged = false;
  int? _fastLayoutOldDirtyPage;
  double? _fastLayoutOldDirtyTop;
  double? _fastLayoutOldDirtyBottom;
  String _lastLayoutMode = 'none';
  int _fastTextLayoutCount = 0;
  int _fullLayoutCount = 0;
  int _partialPageRepaintCount = 0;
  int _lastPartialPageRepaintRowCount = 0;
  int _lastPaginationInspectedRowCount = 0;
  int _lastPaginationReusedPageCount = 0;
  int? _fastRepaintFromPage;
  int? _fastRepaintToPage;
  LayoutInvalidation? _pendingInvalidation;

  late final LayoutScheduler<_ProgressiveLayoutContinuation, int>
      _layoutScheduler;
  // Rows da 1ª fatia síncrona (~viewport + folga p/ E2E) e de cada tick.
  static const int _progressiveFirstChunkRows = 120;
  static const int _progressiveAheadPages = 8;
  static const int _progressiveNearEndPages = 3;
  // Só ativa em docs grandes o bastante para valer o custo do fatiamento.
  static const int _progressiveMinElements = 3000;
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
  TextBoxTool? _textBoxTool;
  dynamic _search;
  dynamic _background;
  dynamic _margin;
  dynamic _control;
  dynamic _dateParticle;
  dynamic _imageObserver;
  dynamic _imageParticle;
  dynamic _labelParticle;
  dynamic _checkboxParticle;
  dynamic _listParticle;
  dynamic _radioParticle;
  dynamic _separatorParticle;
  dynamic _pageBreakParticle;
  dynamic _textParticle;
  dynamic _whiteSpaceParticle;
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
  dynamic _graffiti;
  WorkerManager? _workerManager;
  Zone? _zone;
  IntersectionObserver? _lazyRenderObserver;
  // Páginas atualmente vivas (visíveis) e nº de páginas observado — usados pelo
  // caminho leve de redraw (perf de digitação): se a paginação não mudou, o
  // render não recomputa visibilidade (getBoundingClientRect em N páginas) nem
  // recria o observer; só redesenha as páginas vivas.
  final Set<int> _livePages = <int>{};
  int _observedPageCount = -1;
  late final DirtyPageQueue _scrollDrawQueue;
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
    (_graffiti as Graffiti?)?.dispose();
    _pageCanvasManager.dispose();
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

  List<CanvasRenderingContext2D> getCtxList() =>
      List<CanvasRenderingContext2D>.from(_ctxList);

  int getPageNo() => _pageNo;

  void setPageNo(int value) {
    if (value < 0 || value >= _pageList.length) {
      return;
    }
    _pageNo = value;
    // Header/footer first/even são escolhidos pela página atual. Atualizar a
    // página sem reativar a variante deixava edição e history replay presos à
    // lista da página anterior.
    final Zone? zone = _zone;
    if (zone?.isHeaderActive() == true) {
      _header.setActiveVariantForPage(value);
    } else if (zone?.isFooterActive() == true) {
      _footer.setActiveVariantForPage(value);
    }
  }

  int getRenderCount() => _renderCount;

  String getLastLayoutMode() => _lastLayoutMode;

  Map<String, int> getLayoutDiagnostics() {
    final Position? position = _position as Position?;
    return <String, int>{
      'fastTextLayouts': _fastTextLayoutCount,
      'fullLayouts': _fullLayoutCount,
      'paginationInspectedRows': _lastPaginationInspectedRowCount,
      'paginationReusedPages': _lastPaginationReusedPageCount,
      'positionRecomputedPages': position?.lastRecomputedPageCount ?? 0,
      'positionRebasedPages': position?.lastRebasedPageCount ?? 0,
      'positionFlattenedItems': position?.lastFlattenedPositionCount ?? 0,
      'partialPageRepaints': _partialPageRepaintCount,
      'partialPageRepaintRows': _lastPartialPageRepaintRowCount,
    };
  }

  void resetLayoutDiagnostics() {
    _lastLayoutMode = 'none';
    _fastTextLayoutCount = 0;
    _fullLayoutCount = 0;
    _lastPaginationInspectedRowCount = 0;
    _lastPaginationReusedPageCount = 0;
    _partialPageRepaintCount = 0;
    _lastPartialPageRepaintRowCount = 0;
  }

  Map<String, int> getHistoryDiagnostics() {
    final HistoryManager? history = _historyManager as HistoryManager?;
    return <String, int>{
      'deepSnapshots': _deepHistorySnapshotCount,
      'compactTransitions': _compactHistoryTransitionCount,
      'compactMutations': _compactHistoryMutationCount,
      'pendingBurstMutations':
          _textHistoryBurst?.transaction.mutations.length ?? 0,
      'transitions': history?.transitionCount ?? 0,
      'cursor': history?.cursor ?? 0,
      'restorerDeltaCount': history?.currentRestorerDeltaCount ?? 0,
      'retainedDeltaCallbacks':
          history?.currentRestorerRetainedCallbackCount ?? 0,
      'checkpointReplayOperations':
          history?.currentCheckpointReplayOperationCount ?? 0,
      'checkpointPayloadUnits': history?.currentCheckpointPayloadUnits ?? 0,
      'retainedWindowPayloadUnits':
          history?.currentRetainedWindowPayloadUnits ?? 0,
      'checkpointBarriers': history?.currentCheckpointBarrierCount ?? 0,
    };
  }

  void resetHistoryDiagnostics() {
    _deepHistorySnapshotCount = 0;
    _compactHistoryTransitionCount = 0;
    _compactHistoryMutationCount = 0;
  }

  /// Coalesces model-restoration renders into one final layout/paint.
  ///
  /// An absolute history endpoint may restore a baseline and replay compact
  /// deltas. Those steps must not each run layout. Adjacent delta undo/redo
  /// still ends with its original fast render because it queues only once.
  void runHistoryReplay(void Function() action) {
    _historyReplayDepth += 1;
    try {
      action();
    } finally {
      _historyReplayDepth -= 1;
      if (_historyReplayDepth == 0) {
        final IDrawOption? queued = _historyReplayRenderOption;
        final int queuedCount = _historyReplayRenderCount;
        _historyReplayRenderOption = null;
        _historyReplayRenderCount = 0;
        if (queued != null) {
          if (queuedCount == 1) {
            render(queued);
          } else {
            _pendingInvalidation = null;
            render(
              IDrawOption(
                curIndex: queued.curIndex,
                isSetCursor: queued.isSetCursor,
                isSubmitHistory: false,
                isSourceHistory: true,
                notifyContentChange: true,
                isCompute: true,
              ),
            );
          }
        }
      }
    }
  }

  /// True apenas enquanto um tick progressivo está rodando/agendado. Quando há
  /// mais documento pendente, mas a paginação está pausada esperando rolagem,
  /// consumidores async podem redesenhar as páginas conhecidas normalmente.
  bool isProgressiveLayoutActive() => _layoutScheduler.isActive;

  /// True enquanto ainda existem linhas do documento a paginar, inclusive
  /// quando o processamento está pausado aguardando uma nova demanda.
  bool isProgressiveLayoutPending() => _layoutScheduler.hasJob;

  /// Garante que a paginação progressiva descubra páginas até [pageNo] +
  /// uma folga. Chamado pelo ScrollObserver quando o usuário se aproxima do
  /// fim conhecido, no mesmo espírito do Google Docs: o total cresce conforme
  /// a rolagem, em vez de ser calculado inteiro na abertura.
  void ensureProgressiveLayoutForPage(int pageNo) {
    if (!_layoutScheduler.hasJob) {
      return;
    }
    if (pageNo < _pageRowList.length - _progressiveNearEndPages) {
      return;
    }
    final int targetPage = pageNo + _progressiveAheadPages;
    final int? currentTarget = _layoutScheduler.target;
    if (currentTarget == null || targetPage > currentTarget) {
      _layoutScheduler.requestTarget(targetPage);
    } else if (_layoutScheduler.isPaused) {
      _layoutScheduler.resume();
    }
  }

  /// Conclui SINCRONAMENTE a paginação progressiva pendente (F5.5). Usado
  /// quando um consumidor precisa de posições além da fronteira materializada:
  /// navegação para bookmark/título, Ctrl+End, benchmarks. No fluxo normal a
  /// paginação continua crescendo sob demanda pela rolagem.
  void finishProgressiveLayout() {
    final _ProgressiveLayoutContinuation? continuation =
        _layoutScheduler.continuation;
    if (continuation == null) {
      return;
    }
    _layoutScheduler.cancel();
    final _RowLayoutState state = continuation.state;
    final IComputeRowListPayload payload = continuation.payload;
    while (!state.done) {
      state.budgetRows = 1 << 20;
      state.shouldYield = null;
      final List<IRow> rows = computeRowList(payload, resume: state);
      _rowList
        ..clear()
        ..addAll(rows);
    }
    final List<List<IRow>> pageRows = _computePageList();
    _pageRowList
      ..clear()
      ..addAll(pageRows);
    _computedElementCount = _elementList.length;
    (_position as Position?)?.computePositionList();
    _syncPageCanvases();
    if (getIsPagingMode()) {
      _lazyRender();
    } else {
      _immediateRender();
    }
    _listener?.pageSizeChange?.call(_pageRowList.length);
    if (_eventBus?.isSubscribe?.call('pageSizeChange') == true) {
      _eventBus.emit('pageSizeChange', _pageRowList.length);
    }
    (_area as Area?)?.compute();
    if (_mode != EditorMode.print) {
      final Search? search = _search as Search?;
      final String? keyword = search?.getSearchKeyword();
      if (keyword != null && keyword.isNotEmpty) {
        search?.compute(keyword);
      }
      (_control as Control?)?.computeHighlightList();
    }
  }

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
    final List<IElement> mainFiltered = _filterAssistElementList(snapshot.main);
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
    return _mode == EditorMode.readonly ||
        _mode == EditorMode.print ||
        _mode == EditorMode.graffiti;
  }

  bool isDisabled() {
    return isReadonly();
  }

  bool isDesignMode() => _mode == EditorMode.design;

  bool isPrintMode() => _mode == EditorMode.print;

  bool isGraffitiMode() => _mode == EditorMode.graffiti;

  Zone getZone() {
    _zone ??= Zone(this);
    return _zone!;
  }

  bool getIsPagingMode() {
    final PageMode pageMode = _options.pageMode ?? PageMode.paging;
    return pageMode == PageMode.paging;
  }

  void setDefaultRange() {
    if (_elementList.isEmpty) {
      return;
    }
    Timer.run(() {
      final int curIndex = _elementList.length - 1;
      final RangeManager? rangeManager = _rangeManager as RangeManager?;
      rangeManager?.setRange(curIndex, curIndex);
      rangeManager?.setRangeStyle();
    });
  }

  void setPageMode(PageMode payload) {
    if (_options.pageMode == payload) {
      return;
    }
    _options.pageMode = payload;
    if (payload == PageMode.paging) {
      final double height =
          (_options.height ?? _defaultOriginalHeight).toDouble();
      if (_pageList.isNotEmpty) {
        _pageCanvasManager.setPageHeight(
          0,
          height,
          truncateBackingStore: true,
        );
      }
    } else {
      _disconnectLazyRender();
      _header.recovery();
      _footer.recovery();
      getZone().setZone(EditorZone.main);
    }

    final RangeManager? rangeManager = _rangeManager as RangeManager?;
    final int? startIndex = rangeManager?.getRange().startIndex;
    final bool isCollapsed = rangeManager?.getIsCollapsed() ?? true;
    render(
      IDrawOption(
        isSetCursor: true,
        curIndex: startIndex,
        isSubmitHistory: false,
      ),
    );
    if (!isCollapsed) {
      (_cursor as Cursor?)?.drawCursor(IDrawCursorOption(isShow: false));
    }
    Timer.run(() {
      _listener?.pageModeChange?.call(payload);
      _emitEvent('pageModeChange', payload);
    });
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
  // Element list accessors (zone/table aware)
  // ---------------------------------------------------------------------------

  List<IRow> getTableRowList(List<IElement> sourceElementList) {
    final Position? position = _position as Position?;
    if (position == null) {
      return <IRow>[];
    }
    final IPositionContext positionContext = position.getPositionContext();
    final int? index = positionContext.index;
    final int? trIndex = positionContext.trIndex;
    final int? tdIndex = positionContext.tdIndex;
    if (index == null || trIndex == null || tdIndex == null) {
      return <IRow>[];
    }
    if (index < 0 || index >= sourceElementList.length) {
      return <IRow>[];
    }
    final List<ITr>? trList = sourceElementList[index].trList;
    if (trList == null || trIndex < 0 || trIndex >= trList.length) {
      return <IRow>[];
    }
    final ITr tr = trList[trIndex];
    if (tdIndex < 0 || tdIndex >= tr.tdList.length) {
      return <IRow>[];
    }
    final ITd td = tr.tdList[tdIndex];
    return td.rowList ?? <IRow>[];
  }

  List<IRow> getOriginalRowList() {
    final Zone zoneManager = getZone();
    if (zoneManager.isHeaderActive()) {
      return _header.getRowList();
    }
    if (zoneManager.isFooterActive()) {
      return _footer.getRowList();
    }
    return _rowList;
  }

  List<IRow> getRowList() {
    final Position? position = _position as Position?;
    if (position == null) {
      return _rowList;
    }
    final IPositionContext positionContext = position.getPositionContext();
    return positionContext.isTable == true
        ? getTableRowList(getOriginalElementList())
        : getOriginalRowList();
  }

  List<List<IRow>> getPageRowList() => _pageRowList;

  List<IElement> getHeaderElementList() => _header.getElementList();

  List<IElement> getFooterElementList() => _footer.getElementList();

  List<IElement> getTableElementList(List<IElement> sourceElementList) {
    final Position? position = _position as Position?;
    if (position == null) {
      return <IElement>[];
    }
    final IPositionContext positionContext = position.getPositionContext();
    final int? index = positionContext.index;
    final int? trIndex = positionContext.trIndex;
    final int? tdIndex = positionContext.tdIndex;
    if (index == null || trIndex == null || tdIndex == null) {
      return <IElement>[];
    }
    if (index < 0 || index >= sourceElementList.length) {
      return <IElement>[];
    }
    final List<ITr>? trList = sourceElementList[index].trList;
    if (trList == null || trIndex < 0 || trIndex >= trList.length) {
      return <IElement>[];
    }
    final ITr tr = trList[trIndex];
    if (tdIndex < 0 || tdIndex >= tr.tdList.length) {
      return <IElement>[];
    }
    return tr.tdList[tdIndex].value;
  }

  List<IElement> getElementList() {
    final Position? position = _position as Position?;
    if (position == null) {
      return getOriginalElementList();
    }
    final IPositionContext positionContext = position.getPositionContext();
    final List<IElement> elementList = getOriginalElementList();
    return positionContext.isTable == true
        ? getTableElementList(elementList)
        : elementList;
  }

  List<IElement> getMainElementList() {
    final Position? position = _position as Position?;
    if (position == null) {
      return _elementList;
    }
    final IPositionContext positionContext = position.getPositionContext();
    return positionContext.isTable == true
        ? getTableElementList(_elementList)
        : _elementList;
  }

  List<IElement> getOriginalElementList() {
    final Zone zoneManager = getZone();
    if (zoneManager.isHeaderActive()) {
      return getHeaderElementList();
    }
    if (zoneManager.isFooterActive()) {
      return getFooterElementList();
    }
    return _elementList;
  }

  List<IElement> getOriginalMainElementList() => _elementList;

  /// Canonical, UI-independent document owner used by commands and indexes.
  DocumentModel getDocumentModel() => _documentModel;

  Map<DocumentRegion, List<IElement>> _documentRegionRoots() =>
      <DocumentRegion, List<IElement>>{
        DocumentRegion.main: _elementList,
        DocumentRegion.headerDefault: _header.getDefaultElementList(),
        DocumentRegion.headerFirst: _header.getFirstElementList(),
        DocumentRegion.headerEven: _header.getEvenElementList(),
        DocumentRegion.footerDefault: _footer.getDefaultElementList(),
        DocumentRegion.footerFirst: _footer.getFirstElementList(),
        DocumentRegion.footerEven: _footer.getEvenElementList(),
      };

  DocumentRegion _activeDocumentRegion() {
    if (getZone().isHeaderActive()) {
      return switch (_header.getActiveVariant()) {
        'first' => DocumentRegion.headerFirst,
        'even' => DocumentRegion.headerEven,
        _ => DocumentRegion.headerDefault,
      };
    }
    if (getZone().isFooterActive()) {
      return switch (_footer.getActiveVariant()) {
        'first' => DocumentRegion.footerFirst,
        'even' => DocumentRegion.footerEven,
        _ => DocumentRegion.footerDefault,
      };
    }
    return DocumentRegion.main;
  }

  DocumentRegion? _rootDocumentRegion(List<IElement> elements) {
    if (identical(elements, _elementList)) return DocumentRegion.main;
    if (identical(elements, _header.getDefaultElementList())) {
      return DocumentRegion.headerDefault;
    }
    if (identical(elements, _header.getFirstElementList())) {
      return DocumentRegion.headerFirst;
    }
    if (identical(elements, _header.getEvenElementList())) {
      return DocumentRegion.headerEven;
    }
    if (identical(elements, _footer.getDefaultElementList())) {
      return DocumentRegion.footerDefault;
    }
    if (identical(elements, _footer.getFirstElementList())) {
      return DocumentRegion.footerFirst;
    }
    if (identical(elements, _footer.getEvenElementList())) {
      return DocumentRegion.footerEven;
    }
    return null;
  }

  DocumentLocatorIndex getDocumentLocatorIndex() {
    _documentLocatorIndex.rebindRoots(_documentRegionRoots());
    return _documentLocatorIndex;
  }

  /// Captures the real active list (root or nested cell) in O(1) after the
  /// active region's lazy locator index has been built once.
  DocumentListLocator? captureElementListLocator(List<IElement> elements) {
    final DocumentLocatorIndex index = getDocumentLocatorIndex();
    return index.captureList(elements, regionHint: _activeDocumentRegion()) ??
        index.captureList(elements);
  }

  List<IElement>? resolveElementListLocator(DocumentListLocator locator) {
    return getDocumentLocatorIndex().resolveList(locator);
  }

  DocumentElementLocator? captureElementLocator(
    List<IElement> elements,
    int elementIndex,
  ) {
    final DocumentLocatorIndex index = getDocumentLocatorIndex();
    return index.captureElement(
          elements,
          elementIndex,
          regionHint: _activeDocumentRegion(),
        ) ??
        index.captureElement(elements, elementIndex);
  }

  ResolvedDocumentElement? resolveElementLocator(
    DocumentElementLocator locator,
  ) {
    return getDocumentLocatorIndex().resolveElement(locator);
  }

  void invalidateDocumentLocatorRegion(DocumentRegion region) {
    _documentLocatorIndex.invalidateRegion(region);
  }

  void invalidateDocumentLocators() {
    _documentLocatorIndex.invalidateAll();
  }

  bool _isCanonicalDocumentList(List<IElement> elementList) =>
      identical(elementList, _elementList) ||
      identical(elementList, _headerElementList) ||
      identical(elementList, _footerElementList);

  void didChangeElementStyles(List<IElement> elementList) {
    if (identical(elementList, _elementList)) {
      _documentModel.onStyleChange();
    } else if (identical(elementList, _headerElementList)) {
      _documentModel.onStyleChange(section: DocumentSection.header);
    } else if (identical(elementList, _footerElementList)) {
      _documentModel.onStyleChange(section: DocumentSection.footer);
    }
  }

  void didChangeElementStructure(List<IElement> elementList) {
    // Capture the real owner instead of assuming the currently active zone.
    // Commands may mutate an inactive header/footer variant or a nested cell.
    // If the mutation already detached that cell, invalidate all lazy indexes:
    // this path is structural and rare, while choosing the wrong region would
    // let history replay write into an orphan list.
    final DocumentRegion? rootRegion = _rootDocumentRegion(elementList);
    final DocumentRegion? ownerRegion =
        rootRegion ?? captureElementListLocator(elementList)?.region;
    _recordComplexStructureChange(ownerRegion);
  }

  void _recordComplexStructureChange(DocumentRegion? ownerRegion) {
    if (ownerRegion == null) {
      _documentLocatorIndex.invalidateAll();
      _documentModel.didComplexStructureChangeAll();
      return;
    }
    _documentLocatorIndex.invalidateRegion(ownerRegion);
    final DocumentSection section = switch (ownerRegion) {
      DocumentRegion.main => DocumentSection.main,
      DocumentRegion.headerDefault ||
      DocumentRegion.headerFirst ||
      DocumentRegion.headerEven =>
        DocumentSection.header,
      DocumentRegion.footerDefault ||
      DocumentRegion.footerFirst ||
      DocumentRegion.footerEven =>
        DocumentSection.footer,
    };
    _documentModel.didComplexStructureChange(section: section);
  }

  ITd? getTd() {
    final Position? position = _position as Position?;
    if (position == null) {
      return null;
    }
    final IPositionContext positionContext = position.getPositionContext();
    if (positionContext.isTable != true) {
      return null;
    }
    final int? index = positionContext.index;
    final int? trIndex = positionContext.trIndex;
    final int? tdIndex = positionContext.tdIndex;
    final List<IElement> elementList = getOriginalElementList();
    if (index == null ||
        trIndex == null ||
        tdIndex == null ||
        index < 0 ||
        index >= elementList.length) {
      return null;
    }
    final List<ITr>? trList = elementList[index].trList;
    if (trList == null || trIndex < 0 || trIndex >= trList.length) {
      return null;
    }
    final ITr tr = trList[trIndex];
    if (tdIndex < 0 || tdIndex >= tr.tdList.length) {
      return null;
    }
    return tr.tdList[tdIndex];
  }

  Header getHeader() => _header;

  Footer getFooter() => _footer;

  Graffiti? getGraffiti() => _graffiti as Graffiti?;

  int getRowCount() => getRowList().length;

  IEditorData getOriginValue([dynamic options]) {
    final int? pageNo = options is IGetOriginValueOption
        ? options.pageNo
        : options is IGetValueOption
            ? options.pageNo
            : null;
    List<IElement> mainElementList = getOriginalMainElementList();
    if (pageNo != null && pageNo >= 0 && pageNo < _pageRowList.length) {
      final List<IElement> pageMainElementList = <IElement>[];
      for (final IRow row in _pageRowList[pageNo]) {
        pageMainElementList.addAll(row.elementList);
      }
      mainElementList = pageMainElementList;
    }
    return IEditorData(
      header: List<IElement>.from(getHeaderElementList()),
      main: List<IElement>.from(mainElementList),
      footer: List<IElement>.from(getFooterElementList()),
      graffiti: getGraffiti()?.getValue(),
    );
  }

  /// Reproduz `getValue().data.main` do estado de ABERTURA a partir da saída
  /// crua do conversor (F5): clona + formata + zipa, exatamente o mesmo
  /// pipeline que `setValue`+`getValue` fizeram ao abrir. Assim a abertura NÃO
  /// paga clone/format/zip da referência de save (~250ms de clone de 122k
  /// elementos no TR) — isso é adiado para o 1º save (ação do usuário, com
  /// spinner). `convertedMain` não é mutado por `setValue` (que clona a
  /// entrada), então guardá-lo por referência é seguro.
  List<IElement> buildSaveReferenceFromConverted(List<IElement> convertedMain) {
    final List<IElement> main = element_utils.cloneElementList(convertedMain);
    element_utils.formatElementList(
      main,
      element_utils.FormatElementListOption(
        editorOptions: _options,
        isForceCompensation: true,
      ),
    );
    return element_utils.zipElementList(
      List<IElement>.from(main),
      options: const element_utils.ZipElementListOption(isClassifyArea: true),
    );
  }

  IEditorResult getValue([IGetValueOption? options]) {
    final IEditorData originData = getOriginValue(options);
    final List<String> extraPickAttrs =
        options?.extraPickAttrs ?? const <String>[];
    final element_utils.ZipElementListOption commonOption =
        element_utils.ZipElementListOption(
      extraPickAttrs: extraPickAttrs,
    );
    final element_utils.ZipElementListOption mainOption =
        commonOption.copyWith(isClassifyArea: true);
    final IEditorData data = IEditorData(
      header: element_utils.zipElementList(
        List<IElement>.from(originData.header ?? const <IElement>[]),
        options: commonOption,
      ),
      main: element_utils.zipElementList(
        List<IElement>.from(originData.main),
        options: mainOption,
      ),
      footer: element_utils.zipElementList(
        List<IElement>.from(originData.footer ?? const <IElement>[]),
        options: commonOption,
      ),
      graffiti: originData.graffiti,
    );
    return IEditorResult(
      version: _packageVersion,
      data: data,
      options: option_utils.mergeOption(_options),
    );
  }

  Future<List<String>> getDataURL([IGetImageOption? payload]) async {
    final double? pixelRatio = payload?.pixelRatio;
    final EditorMode? mode = payload?.mode;
    final String mimeType = payload?.mimeType ?? 'image/png';
    final num? quality = payload?.quality;
    if (pixelRatio != null) {
      setPagePixelRatio(pixelRatio);
    }
    final EditorMode currentMode = _mode;
    final bool isSwitchMode = mode != null && currentMode != mode;
    if (isSwitchMode) {
      setMode(mode);
    }
    render(
      IDrawOption(
        isLazy: false,
        isCompute: false,
        isSetCursor: false,
        isSubmitHistory: false,
      ),
    );
    final ImageObserver? imageObserver = _imageObserver as ImageObserver?;
    if (imageObserver != null) {
      await imageObserver.allSettled();
    }
    final List<String> dataUrlList = _pageList
        .map((CanvasElement canvas) =>
            canvas.toDataUrl(mimeType, quality?.toDouble()))
        .toList();
    if (pixelRatio != null) {
      setPagePixelRatio(null);
    }
    if (isSwitchMode) {
      setMode(currentMode);
    }
    return dataUrlList;
  }

  void setValue(dynamic payload, [ISetValueOption? options]) {
    List<IElement>? header;
    List<IElement>? main;
    List<IElement>? footer;
    if (payload is IEditorData) {
      header = element_utils.cloneElementList(
        payload.header ?? const <IElement>[],
      );
      main = element_utils.cloneElementList(payload.main);
      footer = element_utils.cloneElementList(
        payload.footer ?? const <IElement>[],
      );
    } else {
      final dynamic rawHeader =
          payload is Map ? payload['header'] : payload?.header;
      final dynamic rawMain = payload is Map ? payload['main'] : payload?.main;
      final dynamic rawFooter =
          payload is Map ? payload['footer'] : payload?.footer;
      header = _castElementListFromDynamic(rawHeader);
      main = _castElementListFromDynamic(rawMain);
      footer = _castElementListFromDynamic(rawFooter);
    }
    if (header == null && main == null && footer == null) {
      return;
    }

    final bool isSetCursor = options?.isSetCursor ?? false;
    if (header != null) {
      element_utils.formatElementList(
        header,
        element_utils.FormatElementListOption(
          editorOptions: _options,
          isForceCompensation: true,
        ),
      );
    }
    final double tFmt = debugRenderTiming ? window.performance.now() : 0;
    if (main != null) {
      element_utils.formatElementList(
        main,
        element_utils.FormatElementListOption(
          editorOptions: _options,
          isForceCompensation: true,
        ),
      );
    }
    if (debugRenderTiming) {
      window.console.log('[render] formatElementList(main): '
          '${(window.performance.now() - tFmt).toStringAsFixed(0)}ms '
          'elems=${main?.length}');
    }
    if (footer != null) {
      element_utils.formatElementList(
        footer,
        element_utils.FormatElementListOption(
          editorOptions: _options,
          isForceCompensation: true,
        ),
      );
    }

    _documentModel.replace(header: header, main: main, footer: footer);
    if (main != null) {
      _documentLocatorIndex.invalidateRegion(DocumentRegion.main);
    }
    if (header != null) {
      _documentLocatorIndex.invalidateRegion(DocumentRegion.headerDefault);
    }
    if (footer != null) {
      _documentLocatorIndex.invalidateRegion(DocumentRegion.footerDefault);
    }
    if (header != null) {
      _header.setElementList(_headerElementList);
    }
    if (footer != null) {
      _footer.setElementList(_footerElementList);
    }
    if (payload is IEditorData) {
      getGraffiti()?.setValue(payload.graffiti);
    } else {
      final dynamic rawGraffiti =
          payload is Map ? payload['graffiti'] : payload?.graffiti;
      if (rawGraffiti is List<IGraffitiData>) {
        getGraffiti()?.setValue(rawGraffiti);
      }
    }

    (_historyManager as HistoryManager?)?.recovery();
    int? curIndex;
    if (isSetCursor) {
      curIndex = main != null && main.isNotEmpty ? main.length - 1 : 0;
      (_rangeManager as RangeManager?)?.setRange(curIndex, curIndex);
    }
    render(
      IDrawOption(
        curIndex: curIndex,
        isSetCursor: isSetCursor,
        isFirstRender: true,
      ),
    );
  }

  void setEditorData(IEditorData payload) {
    _documentModel.replace(
      main: payload.main,
      header: payload.header ?? const <IElement>[],
      footer: payload.footer ?? const <IElement>[],
    );
    _documentLocatorIndex
      ..invalidateRegion(DocumentRegion.main)
      ..invalidateRegion(DocumentRegion.headerDefault)
      ..invalidateRegion(DocumentRegion.footerDefault);
    if (payload.graffiti != null) {
      getGraffiti()?.setValue(payload.graffiti);
    }
    _header.setElementList(_headerElementList);
    _footer.setElementList(_footerElementList);
  }

  void insertElementList(
    List<IElement> payload, [
    IInsertElementListOption? options,
  ]) {
    final RangeManager? rangeManager = _rangeManager as RangeManager?;
    if (payload.isEmpty ||
        rangeManager == null ||
        !rangeManager.getIsCanInput()) {
      return;
    }
    final IRange range = rangeManager.getRange();
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex < 0 && endIndex < 0) {
      return;
    }
    final bool isSubmitHistory = options?.isSubmitHistory ?? true;
    final bool isSubmitHistoryDeferred =
        options?.isSubmitHistoryDeferred ?? false;
    final bool isFastLayout = options?.isFastLayout == true;
    final bool isDeltaHistory =
        isSubmitHistory && options?.isDeltaHistory == true;
    element_utils.formatElementList(
      payload,
      element_utils.FormatElementListOption(
        editorOptions: _options,
        isHandleFirstElement: false,
      ),
    );
    final _InsertDeltaHistory? deltaHistory = isDeltaHistory
        ? _prepareInsertDeltaHistory(
            payload: payload,
            startIndex: startIndex,
            endIndex: endIndex,
            isFastLayout: isFastLayout,
          )
        : null;
    if (!isDeltaHistory) {
      _prepareHistoryForMutation(
        isSubmitHistory: isSubmitHistory,
        isDeferred: isSubmitHistoryDeferred,
        curIndex: startIndex,
      );
    }
    int curIndex = -1;

    final Control? control = _control as Control?;
    final bool isRangeWithinControl =
        control?.getIsRangeWithinControl() == true;
    final dynamic activeControl =
        isRangeWithinControl ? control?.ensureActiveControl() : null;
    if (activeControl != null && control?.getIsRangeWithinControl() == true) {
      try {
        final int? controlIndex = control?.setValue(payload);
        if (controlIndex != null) {
          curIndex = controlIndex;
        }
        control?.emitControlContentChange();
      } catch (_) {}
    }

    if (curIndex == -1) {
      final List<IElement> elementList = getElementList();
      final bool isCollapsed = startIndex == endIndex;
      final int start = startIndex + 1;
      if (!isCollapsed) {
        spliceElementList(elementList, start, endIndex - startIndex);
      }
      spliceElementList(elementList, start, 0, payload);
      curIndex = startIndex + payload.length;

      final IElement? preElement =
          start - 1 >= 0 && start - 1 < elementList.length
              ? elementList[start - 1]
              : null;
      if (payload.first.listId != null &&
          preElement != null &&
          preElement.listId == null &&
          preElement.value == ZERO &&
          (preElement.type == null || preElement.type == ElementType.text)) {
        if (startIndex >= 0 && startIndex < elementList.length) {
          spliceElementList(
            elementList,
            startIndex,
            1,
            null,
            ISpliceElementListOption(isIgnoreDeletedRule: true),
          );
          curIndex -= 1;
        }
      }
    }

    if (curIndex >= 0) {
      rangeManager.setRange(curIndex, curIndex);
      if (deltaHistory != null) {
        _recordInsertDeltaHistoryAfter(deltaHistory, curIndex);
      }
      render(
        IDrawOption(
          curIndex: curIndex,
          isSubmitHistory: isSubmitHistory && deltaHistory == null,
          isSubmitHistoryDeferred: isSubmitHistoryDeferred,
          notifyContentChange: deltaHistory != null,
          fastLayoutIndex: isFastLayout ? curIndex : null,
        ),
      );
    }
  }

  void appendElementList(
    List<IElement> elementList, [
    IAppendElementListOption? options,
  ]) {
    if (elementList.isEmpty) {
      return;
    }
    element_utils.formatElementList(
      elementList,
      element_utils.FormatElementListOption(
        editorOptions: _options,
        isHandleFirstElement: false,
      ),
    );
    final bool isPrepend = options?.isPrepend == true;
    final bool isSubmitHistory = options?.isSubmitHistory ?? true;
    int curIndex;
    if (isPrepend) {
      spliceElementList(_elementList, 1, 0, elementList);
      curIndex = elementList.length;
    } else {
      spliceElementList(_elementList, _elementList.length, 0, elementList);
      curIndex = _elementList.length - 1;
    }
    (_rangeManager as RangeManager?)?.setRange(curIndex, curIndex);
    render(
      IDrawOption(
        curIndex: curIndex,
        isSubmitHistory: isSubmitHistory,
      ),
    );
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
    if (_compactMutationDepth == 0) {
      _closeTextHistoryBurst();
      if (_deferredHistoryTimer != null) {
        flushDeferredHistory();
      }
    }
    final bool isIgnoreDeletedRule = options?.isIgnoreDeletedRule ?? false;
    final DocumentRegion? locatorRootRegion = _rootDocumentRegion(elementList);
    final DocumentSection? documentSection =
        identical(elementList, _elementList)
            ? DocumentSection.main
            : identical(elementList, _headerElementList)
                ? DocumentSection.header
                : identical(elementList, _footerElementList)
                    ? DocumentSection.footer
                    : null;
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
    final bool changesNestedTableTopology =
        (insertList?.any((IElement item) => item.type == ElementType.table) ??
                false) ||
            (normalizedDeleteCount > 0 &&
                elementList
                    .getRange(
                      normalizedStart,
                      normalizedStart + normalizedDeleteCount,
                    )
                    .any((IElement item) => item.type == ElementType.table));
    // Capture before the splice: removing the table may detach [elementList]
    // from the document and make its owner impossible to discover afterwards.
    final DocumentRegion? nestedTopologyRegion =
        locatorRootRegion == null && changesNestedTableTopology
            ? captureElementListLocator(elementList)?.region
            : null;
    bool usedSelectiveDelete = false;
    if (normalizedDeleteCount > 0) {
      final int endIndex = normalizedStart + normalizedDeleteCount;
      final IElement? endElement =
          endIndex >= 0 && endIndex < elementList.length
              ? elementList[endIndex]
              : null;
      final String? endElementListId = endElement?.listId;
      if (endElementListId != null &&
          (normalizedStart == 0 ||
              elementList[normalizedStart - 1].listId != endElementListId)) {
        int startIndex = endIndex;
        while (startIndex < elementList.length) {
          final IElement curElement = elementList[startIndex];
          if (curElement.listId != endElementListId ||
              curElement.value == ZERO) {
            break;
          }
          curElement
            ..listId = null
            ..listType = null
            ..listStyle = null;
          startIndex += 1;
        }
      }

      final bool isRangeWithinControl =
          (_control as Control?)?.getIsRangeWithinControl() == true;
      if (!isIgnoreDeletedRule && !isDesignMode() && !isRangeWithinControl) {
        usedSelectiveDelete = true;
        final bool? tdDeletable = getTd()?.deletable;
        final bool controlDeletableDisabled =
            _options.modeRule?.form?.controlDeletableDisabled == true;
        final bool groupDeletable = _options.group?.deletable != false;
        final List<IElement> preserved = <IElement>[];
        for (int deleteIndex = normalizedStart;
            deleteIndex < endIndex;
            deleteIndex++) {
          final IElement deleteElement = elementList[deleteIndex];
          final bool canDeleteByRule = tdDeletable != false &&
              deleteElement.control?.deletable != false &&
              (deleteElement.controlId == null ||
                  _mode != EditorMode.form ||
                  !controlDeletableDisabled) &&
              deleteElement.title?.deletable != false &&
              (groupDeletable ||
                  !(deleteElement.groupIds?.isNotEmpty ?? false)) &&
              (deleteElement.area?.deletable != false ||
                  deleteElement.areaIndex != 0);
          if (deleteElement.hide == true ||
              deleteElement.control?.hide == true ||
              deleteElement.area?.hide == true ||
              canDeleteByRule) {
            continue;
          }
          preserved.add(deleteElement);
        }
        // Uma única movimentação da cauda. O removeAt descendente anterior
        // deslocava ~N elementos para cada item selecionado (O(faixa×cauda)),
        // chegando a segundos em seleções perto do início de DOCX grandes.
        elementList.replaceRange(normalizedStart, endIndex, preserved);
      } else {
        elementList.removeRange(normalizedStart, endIndex);
      }
    }

    if (insertList != null && insertList.isNotEmpty) {
      // `insert` por item também deslocava a cauda repetidamente em paste ou
      // substituição grande. insertAll preserva a ordem com um único splice.
      elementList.insertAll(normalizedStart, insertList);
    }
    if (documentSection != null) {
      final int insertCount = insertList?.length ?? 0;
      final int actualDeleteCount = length + insertCount - elementList.length;
      if (actualDeleteCount > 0 || insertCount > 0) {
        if (usedSelectiveDelete && actualDeleteCount != normalizedDeleteCount) {
          _documentModel.didComplexStructureChange(section: documentSection);
        } else {
          _documentModel.didSplice(
            section: documentSection,
            start: normalizedStart,
            deleteCount: actualDeleteCount,
            insertCount: insertCount,
          );
        }
      }
    }
    if (locatorRootRegion != null) {
      // Mesmo preservando a identidade da lista raiz, índices/path fallbacks
      // de tabelas podem mudar com qualquer splice anterior à tabela.
      _documentLocatorIndex.invalidateRegion(locatorRootRegion);
    } else if (changesNestedTableTopology) {
      _recordComplexStructureChange(nestedTopologyRegion);
    }
  }

  void deleteElementRangeWithDeltaHistory(
    int start,
    int deleteCount, {
    int? curIndex,
  }) {
    if (deleteCount <= 0) {
      return;
    }
    final List<IElement> elementList = getElementList();
    if (start < 0 || start >= elementList.length) {
      return;
    }
    final int safeDeleteCount = deleteCount > elementList.length - start
        ? elementList.length - start
        : deleteCount;
    final _ElementRangeDeltaHistory? delta = _prepareElementRangeDeleteDelta(
      start,
      safeDeleteCount,
      curIndex: curIndex,
    );
    spliceElementList(
      elementList,
      start,
      safeDeleteCount,
      null,
      ISpliceElementListOption(isIgnoreDeletedRule: true),
    );
    if (curIndex != null) {
      (_rangeManager as RangeManager?)?.setRange(curIndex, curIndex);
    }
    if (delta != null) {
      _applyElementRangeRowDelta(delta, isAfter: true);
      _recordElementRangeDeleteDeltaAfter(delta);
      render(
        IDrawOption(
          curIndex: curIndex,
          isSubmitHistory: false,
          notifyContentChange: true,
          isRowListPrecomputed: true,
        ),
      );
    } else {
      render(IDrawOption(curIndex: curIndex));
    }
  }

  void deleteTextRangeWithDeltaHistory(
    int start,
    int deleteCount, {
    int? curIndex,
    bool isFastLayout = true,
  }) {
    if (deleteCount <= 0) {
      return;
    }
    final List<IElement> elementList = getElementList();
    if (start < 0 || start >= elementList.length) {
      return;
    }
    final int safeDeleteCount = deleteCount > elementList.length - start
        ? elementList.length - start
        : deleteCount;
    final _InsertDeltaHistory? delta = _prepareTextDeleteDeltaHistory(
      start: start,
      deleteCount: safeDeleteCount,
      isFastLayout: isFastLayout,
    );
    spliceElementList(
      elementList,
      start,
      safeDeleteCount,
      null,
      ISpliceElementListOption(isIgnoreDeletedRule: true),
    );
    if (curIndex != null) {
      (_rangeManager as RangeManager?)?.setRange(curIndex, curIndex);
    }
    if (delta != null) {
      _recordInsertDeltaHistoryAfter(delta, curIndex ?? start);
    }
    render(
      IDrawOption(
        curIndex: curIndex,
        isSubmitHistory: delta == null,
        isSubmitHistoryDeferred: delta == null,
        notifyContentChange: true,
        fastLayoutIndex: isFastLayout ? curIndex : null,
      ),
    );
  }

  // Compatibilidade do histórico legado + agrupamento da digitação tipada.
  // O timer de texto apenas fecha a transação reversível da rajada; não clona
  // o documento. `_deferredHistoryTimer` permanece somente para rotas legadas
  // que ainda pedem snapshot adiado explicitamente.
  int? _deferredHistoryIndex;
  Timer? _deferredHistoryTimer;
  _TextHistoryBurst? _textHistoryBurst;
  Timer? _textHistoryTimer;
  bool _renewTextHistoryTimerAfterRender = false;
  int _compactMutationDepth = 0;
  static const Duration _deferredHistoryDelay = Duration(milliseconds: 300);

  /// Materializa o snapshot pendente da rajada de digitação (se houver).
  /// Chamado antes de undo/redo e em pontos de entrada de eventos que mudam
  /// o documento fora da rajada.
  void flushDeferredHistory() {
    _closeTextHistoryBurst();
    if (_deferredHistoryTimer == null) {
      return;
    }
    final int? curIndex = _deferredHistoryIndex;
    cancelDeferredHistory();
    submitHistory(curIndex);
  }

  /// Descarta o snapshot pendente (o estado da rajada foi englobado por um
  /// submit imediato posterior ou o documento foi substituído).
  void cancelDeferredHistory() {
    _closeTextHistoryBurst();
    _deferredHistoryTimer?.cancel();
    _deferredHistoryTimer = null;
    _deferredHistoryIndex = null;
  }

  void _closeTextHistoryBurst() {
    _textHistoryTimer?.cancel();
    _textHistoryTimer = null;
    _renewTextHistoryTimerAfterRender = false;
    _textHistoryBurst = null;
  }

  /// Aplica uma edicao textual e registra imediatamente um delta reversivel.
  ///
  /// Mutations adjacentes com o mesmo [mergeKey] compartilham uma unica
  /// transicao de undo durante 300 ms. Os callbacks da transicao capturam a
  /// transaction mutavel, portanto acrescentar a proxima tecla nao clona o
  /// documento e nao cria outro registro.
  LayoutInvalidation? applyTextMutation({
    required List<IElement> elementList,
    required int start,
    required int deleteCount,
    required List<IElement> replacement,
    required int curIndex,
    required String mergeKey,
    bool recordHistory = true,
    bool forceSnapshotHistory = false,
    DocumentMutationImpact impact = DocumentMutationImpact.paragraphLayout,
  }) {
    final double mutationStartedAt =
        debugRenderTiming ? window.performance.now() : 0;
    if (start < 0 ||
        start > elementList.length ||
        deleteCount < 0 ||
        start + deleteCount > elementList.length) {
      throw RangeError('invalid text mutation range');
    }
    final RangeManager? rangeManager = _rangeManager as RangeManager?;
    if (rangeManager == null) {
      return null;
    }
    final HistoryViewState beforeViewState = captureHistoryViewState();
    final IRange beforeRange = beforeViewState.range;
    final HistoryManager? historyManager = _historyManager as HistoryManager?;
    final bool listMetadataSideEffect = deleteCount > 0 &&
        _spliceClearsFollowingListMetadata(
          elementList,
          start,
          deleteCount,
        );
    final DocumentListLocator? listLocator =
        !forceSnapshotHistory && !listMetadataSideEffect
            ? captureElementListLocator(elementList)
            : null;
    final bool supportsStableReplay =
        !forceSnapshotHistory && !listMetadataSideEffect && listLocator != null;
    final bool shouldRecord = recordHistory &&
        supportsStableReplay &&
        _options.historyDisabled != true &&
        historyManager != null;

    // Only genuinely unaddressable lists fall back to a deep snapshot. Main,
    // header/footer variants and arbitrarily nested table cells replay through
    // a stable locator, even after an absolute endpoint replaced their roots.
    final bool useSnapshotHistory = recordHistory &&
        !supportsStableReplay &&
        _options.historyDisabled != true &&
        historyManager != null;
    final double mutationPreparedAt =
        debugRenderTiming ? window.performance.now() : 0;
    if (useSnapshotHistory) {
      flushDeferredHistory();
      if (historyManager.isStackEmpty()) {
        submitHistory(beforeRange.endIndex);
      }
    }

    // Um snapshot legado pendente representa outra unidade logica e precisa
    // ser fechado antes de capturarmos o before deste delta.
    if (shouldRecord && _deferredHistoryTimer != null) {
      flushDeferredHistory();
    }
    if (shouldRecord && historyManager.isStackEmpty()) {
      submitHistory(beforeRange.endIndex);
    }

    final List<IElement> removed = deleteCount == 0
        ? const <IElement>[]
        : elementList.sublist(start, start + deleteCount);
    final int beforeLength = elementList.length;
    _compactMutationDepth += 1;
    try {
      spliceElementList(
        elementList,
        start,
        deleteCount,
        replacement,
      );
    } finally {
      _compactMutationDepth -= 1;
    }
    final double mutationSplicedAt =
        debugRenderTiming ? window.performance.now() : 0;
    // Regras de modo/formulario podem preservar itens protegidos dentro da
    // faixa solicitada. Capturamos o segmento REAL resultante, mantendo o
    // replay exato sem mudar as regras do splice original.
    final int afterSegmentLength =
        elementList.length - (beforeLength - deleteCount);
    final int safeAfterSegmentLength = afterSegmentLength < 0
        ? 0
        : afterSegmentLength.clamp(0, elementList.length - start);
    final List<IElement> actualReplacement = safeAfterSegmentLength == 0
        ? const <IElement>[]
        : elementList.sublist(start, start + safeAfterSegmentLength);
    final ElementSpliceMutation mutation = ElementSpliceMutation(
      start: start,
      removed: removed,
      inserted: actualReplacement,
      impact: impact,
      replayDomain: listLocator,
      cloneElements: (Iterable<IElement> source) =>
          element_utils.cloneElementList(source.toList()),
      splice: (
        int mutationStart,
        int mutationDeleteCount,
        List<IElement> mutationReplacement,
      ) {
        final List<IElement> replayElementList;
        if (listLocator == null) {
          // This mutation is used only to derive layout invalidation; its
          // history endpoint follows the snapshot path above.
          replayElementList = elementList;
        } else {
          replayElementList = resolveElementListLocator(listLocator) ??
              (throw StateError(
                'document list locator could not be resolved during history replay',
              ));
        }
        spliceElementList(
          replayElementList,
          mutationStart,
          mutationDeleteCount,
          mutationReplacement,
          ISpliceElementListOption(isIgnoreDeletedRule: true),
        );
      },
    );
    final double mutationDeltaBuiltAt =
        debugRenderTiming ? window.performance.now() : 0;

    rangeManager.setRange(curIndex, curIndex);

    final DocumentTransaction candidate = DocumentTransaction(
      mergeKey: mergeKey,
    )..add(mutation);
    final LayoutInvalidation mutationInvalidation =
        LayoutInvalidation.fromTransaction(candidate);

    if (!shouldRecord) {
      if (useSnapshotHistory) {
        return null;
      }
      return mutationInvalidation;
    }

    _compactHistoryMutationCount += 1;

    _TextHistoryBurst? burst = _textHistoryBurst;
    final bool merge = burst != null &&
        identical(burst.elementList, elementList) &&
        burst.transaction.canMergeWith(candidate);
    if (!merge) {
      _closeTextHistoryBurst();
      burst = _TextHistoryBurst(
        elementList: elementList,
        transaction: candidate,
        beforeViewState: beforeViewState,
        afterViewState: captureHistoryViewState(),
        curIndex: curIndex,
      );
      _textHistoryBurst = burst;
      _compactHistoryTransitionCount += 1;
      final _TextHistoryBurst recordedBurst = burst;
      historyManager.executeDelta(
        revert: () {
          _restoreTextHistoryBurst(recordedBurst, isAfter: false);
        },
        apply: () {
          _restoreTextHistoryBurst(recordedBurst, isAfter: true);
        },
        checkpointDelta: mutation,
      );
    } else {
      burst.transaction.merge(candidate);
      burst
        ..afterViewState = captureHistoryViewState()
        ..curIndex = curIndex;
    }
    _textHistoryTimer?.cancel();
    _textHistoryTimer = Timer(_deferredHistoryDelay, _closeTextHistoryBurst);
    // Timers cannot run during the synchronous canvas render. Mark this one
    // for renewal at the end of render so a slow frame does not consume the
    // entire coalescing window before the next keyboard event is dispatched.
    _renewTextHistoryTimerAfterRender = true;
    if (debugRenderTiming) {
      window.console.log(
        '[mutation] prepare='
        '${(mutationPreparedAt - mutationStartedAt).toStringAsFixed(0)}ms '
        'splice=${(mutationSplicedAt - mutationPreparedAt).toStringAsFixed(0)}ms '
        'delta=${(mutationDeltaBuiltAt - mutationSplicedAt).toStringAsFixed(0)}ms '
        'history=${(window.performance.now() - mutationDeltaBuiltAt).toStringAsFixed(0)}ms',
      );
    }
    return mutationInvalidation;
  }

  bool _spliceClearsFollowingListMetadata(
    List<IElement> elementList,
    int start,
    int deleteCount,
  ) {
    final int end = start + deleteCount;
    if (end < 0 || end >= elementList.length) {
      return false;
    }
    final String? followingListId = elementList[end].listId;
    return followingListId != null &&
        (start == 0 || elementList[start - 1].listId != followingListId);
  }

  void _restoreTextHistoryBurst(
    _TextHistoryBurst burst, {
    required bool isAfter,
  }) {
    _closeTextHistoryBurst();
    if (isAfter) {
      burst.transaction.apply();
    } else {
      burst.transaction.revert();
    }
    restoreHistoryViewState(
      isAfter ? burst.afterViewState : burst.beforeViewState,
    );
    final LayoutInvalidation invalidation =
        LayoutInvalidation.fromTransaction(burst.transaction);
    renderUpdate(
      LayoutRequest(
        invalidation: invalidation,
        curIndex:
            isAfter ? burst.curIndex : burst.beforeViewState.range.endIndex,
        notifyContentChange: true,
      ),
    );
  }

  void _prepareHistoryForMutation({
    required bool isSubmitHistory,
    required bool isDeferred,
    int? curIndex,
  }) {
    if (!isSubmitHistory || _options.historyDisabled == true) {
      return;
    }
    final HistoryManager? historyManager = _historyManager as HistoryManager?;
    if (historyManager == null) {
      return;
    }
    if (!isDeferred) {
      flushDeferredHistory();
    }
    if (historyManager.isStackEmpty()) {
      submitHistory(curIndex);
    }
  }

  _InsertDeltaHistory? _prepareInsertDeltaHistory({
    required List<IElement> payload,
    required int startIndex,
    required int endIndex,
    required bool isFastLayout,
  }) {
    final HistoryManager? historyManager = _historyManager as HistoryManager?;
    final RangeManager? rangeManager = _rangeManager as RangeManager?;
    if (historyManager == null || rangeManager == null) {
      return null;
    }
    cancelDeferredHistory();
    final List<IElement> elementList = getElementList();
    if (!_isCanonicalDocumentList(elementList)) {
      if (historyManager.isStackEmpty()) {
        submitHistory(rangeManager.getRange().endIndex);
      }
      return null;
    }
    final bool removesLeadingListZero = payload.first.listId != null &&
        startIndex >= 0 &&
        startIndex < elementList.length &&
        elementList[startIndex].listId == null &&
        elementList[startIndex].value == ZERO &&
        (elementList[startIndex].type == null ||
            elementList[startIndex].type == ElementType.text);
    final int insertStart =
        removesLeadingListZero ? startIndex : startIndex + 1;
    if (insertStart < 0 || insertStart > elementList.length) {
      return null;
    }
    final int selectedCount =
        startIndex == endIndex ? 0 : endIndex - startIndex;
    final int deleteCount = (selectedCount + (removesLeadingListZero ? 1 : 0))
        .clamp(0, elementList.length - insertStart);
    final List<IElement> removedSnapshot = deleteCount > 0
        ? element_utils.cloneElementList(
            elementList.sublist(insertStart, insertStart + deleteCount),
          )
        : <IElement>[];
    final List<IElement> insertedSnapshot =
        element_utils.cloneElementList(payload);
    final HistoryViewState beforeViewState = captureHistoryViewState();
    final IRange beforeRange = beforeViewState.range;
    if (historyManager.isStackEmpty()) {
      submitHistory(beforeRange.endIndex);
    }
    final _InsertDeltaHistory delta = _InsertDeltaHistory(
      insertStart: insertStart,
      elementList: elementList,
      removedSnapshot: removedSnapshot,
      insertedSnapshot: insertedSnapshot,
      beforeViewState: beforeViewState,
      isFastLayout: isFastLayout,
    );
    return delta;
  }

  _InsertDeltaHistory? _prepareTextDeleteDeltaHistory({
    required int start,
    required int deleteCount,
    required bool isFastLayout,
  }) {
    final HistoryManager? historyManager = _historyManager as HistoryManager?;
    final RangeManager? rangeManager = _rangeManager as RangeManager?;
    if (historyManager == null || rangeManager == null) {
      return null;
    }
    cancelDeferredHistory();
    final List<IElement> elementList = getElementList();
    if (!_isCanonicalDocumentList(elementList)) {
      if (historyManager.isStackEmpty()) {
        submitHistory(rangeManager.getRange().endIndex);
      }
      return null;
    }
    if (start < 0 || start + deleteCount > elementList.length) {
      return null;
    }
    final HistoryViewState beforeViewState = captureHistoryViewState();
    final IRange beforeRange = beforeViewState.range;
    if (historyManager.isStackEmpty()) {
      submitHistory(beforeRange.endIndex);
    }
    final _InsertDeltaHistory delta = _InsertDeltaHistory(
      insertStart: start,
      elementList: elementList,
      removedSnapshot: element_utils.cloneElementList(
        elementList.sublist(start, start + deleteCount),
      ),
      insertedSnapshot: const <IElement>[],
      beforeViewState: beforeViewState,
      isFastLayout: isFastLayout,
    );
    return delta;
  }

  void _recordInsertDeltaHistoryAfter(
    _InsertDeltaHistory delta,
    int curIndex,
  ) {
    final HistoryManager? historyManager = _historyManager as HistoryManager?;
    final RangeManager? rangeManager = _rangeManager as RangeManager?;
    if (historyManager == null || rangeManager == null) {
      return;
    }
    delta.afterViewState = captureHistoryViewState();
    delta.afterCurIndex = curIndex;
    historyManager.executeDelta(
      revert: () {
        _restoreInsertDeltaHistory(delta, isAfter: false);
      },
      apply: () {
        _restoreInsertDeltaHistory(delta, isAfter: true);
      },
    );
  }

  void _restoreInsertDeltaHistory(
    _InsertDeltaHistory delta, {
    required bool isAfter,
  }) {
    final List<IElement> elementList = delta.elementList;
    final int replaceCount =
        isAfter ? delta.removedSnapshot.length : delta.insertedSnapshot.length;
    final List<IElement> replacement = element_utils.cloneElementList(
      isAfter ? delta.insertedSnapshot : delta.removedSnapshot,
    );
    spliceElementList(
      elementList,
      delta.insertStart,
      replaceCount,
      replacement,
      ISpliceElementListOption(isIgnoreDeletedRule: true),
    );
    final HistoryViewState? nextViewState =
        isAfter ? delta.afterViewState : delta.beforeViewState;
    if (nextViewState != null) {
      restoreHistoryViewState(nextViewState);
    }
    final int curIndex = isAfter
        ? (delta.afterCurIndex ?? delta.insertStart + replacement.length - 1)
        : delta.beforeViewState.range.endIndex;
    render(
      IDrawOption(
        curIndex: curIndex,
        isSubmitHistory: false,
        notifyContentChange: true,
        fastLayoutIndex: delta.isFastLayout ? curIndex : null,
      ),
    );
  }

  _ElementRangeDeltaHistory? _prepareElementRangeDeleteDelta(
    int start,
    int deleteCount, {
    int? curIndex,
  }) {
    final HistoryManager? historyManager = _historyManager as HistoryManager?;
    final RangeManager? rangeManager = _rangeManager as RangeManager?;
    if (historyManager == null || rangeManager == null) {
      return null;
    }
    cancelDeferredHistory();
    final List<IElement> elementList = getElementList();
    if (!identical(elementList, _elementList)) {
      if (historyManager.isStackEmpty()) {
        submitHistory(rangeManager.getRange().endIndex);
      }
      return null;
    }
    if (start < 0 || start + deleteCount > elementList.length) {
      return null;
    }
    final int rowStart = _lowerBoundRowByStartIndex(start);
    final int rowEnd = _lowerBoundRowByStartIndex(start + deleteCount);
    if (rowStart < 0 ||
        rowStart > rowEnd ||
        rowEnd > _rowList.length ||
        elementList.length != _computedElementCount) {
      return null;
    }
    final HistoryViewState beforeViewState = captureHistoryViewState();
    final IRange beforeRange = beforeViewState.range;
    if (historyManager.isStackEmpty()) {
      submitHistory(beforeRange.endIndex);
    }
    final _ElementRangeDeltaHistory delta = _ElementRangeDeltaHistory(
      start: start,
      deleteCount: deleteCount,
      elementList: elementList,
      removedSnapshot: element_utils.cloneElementList(
        elementList.sublist(start, start + deleteCount),
      ),
      removedRows: _cloneRows(_rowList.sublist(rowStart, rowEnd)),
      rowStart: rowStart,
      beforeViewState: beforeViewState,
      beforeCurIndex: rangeManager.getRange().endIndex,
      afterCurIndex: curIndex,
    );
    return delta;
  }

  void _recordElementRangeDeleteDeltaAfter(_ElementRangeDeltaHistory delta) {
    final HistoryManager? historyManager = _historyManager as HistoryManager?;
    final RangeManager? rangeManager = _rangeManager as RangeManager?;
    if (historyManager == null || rangeManager == null) {
      return;
    }
    delta.afterViewState = captureHistoryViewState();
    historyManager.executeDelta(
      revert: () {
        _restoreElementRangeDeleteDelta(delta, isAfter: false);
      },
      apply: () {
        _restoreElementRangeDeleteDelta(delta, isAfter: true);
      },
    );
  }

  void _restoreElementRangeDeleteDelta(
    _ElementRangeDeltaHistory delta, {
    required bool isAfter,
  }) {
    final List<IElement> elementList = delta.elementList;
    if (isAfter) {
      spliceElementList(
        elementList,
        delta.start,
        delta.deleteCount,
        null,
        ISpliceElementListOption(isIgnoreDeletedRule: true),
      );
    } else {
      spliceElementList(
        elementList,
        delta.start,
        0,
        element_utils.cloneElementList(delta.removedSnapshot),
        ISpliceElementListOption(isIgnoreDeletedRule: true),
      );
    }
    _applyElementRangeRowDelta(delta, isAfter: isAfter);
    final HistoryViewState? nextViewState =
        isAfter ? delta.afterViewState : delta.beforeViewState;
    if (nextViewState != null) {
      restoreHistoryViewState(nextViewState);
    }
    render(
      IDrawOption(
        curIndex: isAfter ? delta.afterCurIndex : delta.beforeCurIndex,
        isSubmitHistory: false,
        notifyContentChange: true,
        isRowListPrecomputed: true,
      ),
    );
  }

  void _applyElementRangeRowDelta(
    _ElementRangeDeltaHistory delta, {
    required bool isAfter,
  }) {
    if (delta.removedRows.isEmpty) {
      _computedElementCount = getElementList().length;
      return;
    }
    final int rowCount = delta.removedRows.length;
    if (isAfter) {
      final int removeEnd = delta.rowStart + rowCount;
      if (delta.rowStart <= _rowList.length && removeEnd <= _rowList.length) {
        _rowList.removeRange(delta.rowStart, removeEnd);
      }
      for (int i = delta.rowStart; i < _rowList.length; i++) {
        _rowList[i].startIndex -= delta.deleteCount;
        _rowList[i].rowIndex -= rowCount;
      }
    } else {
      for (int i = delta.rowStart; i < _rowList.length; i++) {
        _rowList[i].startIndex += delta.deleteCount;
        _rowList[i].rowIndex += rowCount;
      }
      _rowList.insertAll(delta.rowStart, _cloneRows(delta.removedRows));
    }
    _computedElementCount = getElementList().length;
  }

  List<IRow> _cloneRows(List<IRow> rows) {
    return rows
        .map(
          (IRow row) => IRow(
            width: row.width,
            height: row.height,
            ascent: row.ascent,
            rowFlex: row.rowFlex,
            startIndex: row.startIndex,
            isPageBreak: row.isPageBreak,
            isList: row.isList,
            listIndex: row.listIndex,
            offsetX: row.offsetX,
            offsetY: row.offsetY,
            elementList: List<IRowElement>.from(row.elementList),
            isWidthNotEnough: row.isWidthNotEnough,
            rowIndex: row.rowIndex,
            isSurround: row.isSurround,
          ),
        )
        .toList(growable: false);
  }

  void submitHistory([int? curIndex, bool defer = false]) {
    // Flag de teste: histórico desligado => nenhum snapshot (zero deep-clone do
    // documento por edição, que é a fonte da tempestade de alocação/OOM em docs
    // grandes). Retornamos antes de agendar o timer adiado.
    if (_options.historyDisabled == true) {
      return;
    }
    if (defer) {
      _closeTextHistoryBurst();
      _deferredHistoryIndex = curIndex;
      _deferredHistoryTimer?.cancel();
      _deferredHistoryTimer =
          Timer(_deferredHistoryDelay, flushDeferredHistory);
      return;
    }
    // Um submit imediato captura o estado corrente, que já inclui a rajada
    // pendente — o snapshot adiado viraria uma duplicata na pilha de undo.
    cancelDeferredHistory();
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
    final List<IElement> headerFirstSnapshot =
        element_utils.cloneElementList(_header.getFirstElementList());
    final List<IElement> headerEvenSnapshot =
        element_utils.cloneElementList(_header.getEvenElementList());
    final bool headerTitlePageSnapshot = _header.getIsTitlePage();
    final bool headerEvenAndOddSnapshot = _header.getIsEvenAndOdd();
    final List<IElement> footerFirstSnapshot =
        element_utils.cloneElementList(_footer.getFirstElementList());
    final List<IElement> footerEvenSnapshot =
        element_utils.cloneElementList(_footer.getEvenElementList());
    final bool footerTitlePageSnapshot = _footer.getIsTitlePage();
    final bool footerEvenAndOddSnapshot = _footer.getIsEvenAndOdd();
    _deepHistorySnapshotCount += 1;
    final HistoryViewState viewStateSnapshot = captureHistoryViewState();

    historyManager.execute(() {
      _documentModel.replace(
        header: element_utils.cloneElementList(headerSnapshot),
        main: element_utils.cloneElementList(elementSnapshot),
        footer: element_utils.cloneElementList(footerSnapshot),
      );
      _header.setElementList(_headerElementList);
      _footer.setElementList(_footerElementList);
      _header.setVariants(
        first: element_utils.cloneElementList(headerFirstSnapshot),
        even: element_utils.cloneElementList(headerEvenSnapshot),
        titlePage: headerTitlePageSnapshot,
        evenAndOdd: headerEvenAndOddSnapshot,
      );
      _footer.setVariants(
        first: element_utils.cloneElementList(footerFirstSnapshot),
        even: element_utils.cloneElementList(footerEvenSnapshot),
        titlePage: footerTitlePageSnapshot,
        evenAndOdd: footerEvenAndOddSnapshot,
      );
      // DocumentModel preserves canonical default-list identities, while
      // nested table lists and first/even roots are cloned above. Rebuild each
      // region lazily before the flat restorer replays its next delta.
      _documentLocatorIndex.invalidateAll();
      restoreHistoryViewState(viewStateSnapshot);
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
    final double height =
        (_options.height ?? _defaultOriginalHeight).toDouble();
    return _options.paperDirection == PaperDirection.horizontal
        ? height
        : width;
  }

  double getOriginalHeight() {
    final double width = (_options.width ?? _defaultOriginalWidth).toDouble();
    final double height =
        (_options.height ?? _defaultOriginalHeight).toDouble();
    return _options.paperDirection == PaperDirection.horizontal
        ? width
        : height;
  }

  double getWidth() => (getOriginalWidth() * _resolveScale()).floorToDouble();

  double getHeight() => (getOriginalHeight() * _resolveScale()).floorToDouble();

  double getPageGap() =>
      (_options.pageGap ?? _defaultPageGap).toDouble() * _resolveScale();

  double getCanvasWidth(int pageNo) {
    ensureContainerMounted();
    return _pageCanvasManager.getCanvasWidth(pageNo, fallback: getWidth());
  }

  double getCanvasHeight(int pageNo) {
    ensureContainerMounted();
    return _pageCanvasManager.getCanvasHeight(pageNo, fallback: getHeight());
  }

  double getOriginalPageGap() =>
      (_options.pageGap ?? _defaultPageGap).toDouble();

  double getDefaultBasicRowMarginHeight() {
    final double base = (_options.defaultBasicRowMarginHeight ?? 0).toDouble();
    return base * _resolveScale();
  }

  double getMarginIndicatorSize() {
    final double base =
        (_options.marginIndicatorSize ?? _defaultMarginIndicatorSize)
            .toDouble();
    return base * _resolveScale();
  }

  List<double> getMargins() {
    final List<double> margins = getOriginalMargins();
    final double scale = _resolveScale();
    return margins.map((double value) => value * scale).toList();
  }

  List<double> getOriginalMargins() {
    final List<double> defaultMargins =
        List<double>.from(_options.margins ?? _defaultMargins);
    if (_options.paperDirection == PaperDirection.horizontal) {
      return <double>[
        defaultMargins[1],
        defaultMargins[2],
        defaultMargins[3],
        defaultMargins[0]
      ];
    }
    return defaultMargins;
  }

  String getElementFont(IElement element, [double scale = 1]) {
    final bool isItalic = element.italic == true;
    final bool isBold = element.bold == true;
    final String fontFamily =
        element.font ?? _options.defaultFont ?? 'sans-serif';
    final num baseSize =
        element.actualSize ?? element.size ?? _options.defaultSize ?? 16;
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
    final double baseMargin =
        (_options.defaultBasicRowMarginHeight ?? 0).toDouble();
    final double defaultRowMargin = (_options.defaultRowMargin ?? 1).toDouble();
    return baseMargin *
        (element.rowMargin ?? defaultRowMargin) *
        _resolveScale();
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
    return margins[0] +
        margins[2] +
        _resolveHeaderExtraHeight() +
        _resolveFooterExtraHeight();
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
    return _pageCanvasManager.pagePixelRatio;
  }

  void setPagePixelRatio(double? value) {
    if (!_pageCanvasManager.setPagePixelRatio(value)) {
      return;
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

  /// Layout fatiado (F5.5, modelo OnlyOffice): com [resume] fornecido, RETOMA
  /// de onde parou (mesmo elementList) e cede o thread ao produzir
  /// `resume.budgetRows` rows, num limite de parágrafo, salvando o cursor.
  /// Com [resume] == null o comportamento é idêntico ao layout completo.
  List<IRow> computeRowList(
    IComputeRowListPayload payload, {
    // ignore: library_private_types_in_public_api
    _RowLayoutState? resume,
  }) {
    final double innerWidth = payload.innerWidth;
    final List<IElement> elementList = payload.elementList;
    if (innerWidth <= 0 || elementList.isEmpty) {
      resume?.done = true;
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
    final double defaultTabWidth =
        (_options.defaultTabWidth ?? defaultSize).toDouble();
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
    final List<IRow> rowList = resume?.rowList ?? <IRow>[];
    if (rowList.isEmpty && elementList.isNotEmpty) {
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
    final bool isResuming = resume?.started ?? false;
    double x = isResuming ? resume!.x : startX;
    double y = isResuming ? resume!.y : startY;
    int pageNo = isResuming ? resume!.pageNo : 0;
    int listIndex = isResuming ? resume!.listIndex : 0;
    String? listId = isResuming ? resume!.listId : null;
    double controlRealWidth = isResuming ? resume!.controlRealWidth : 0;
    // Corte de fatia (F5.5): produz até `budgetRows` rows por chamada.
    final int chunkStartRowCount = rowList.length;
    final int budgetRows = resume?.budgetRows ?? (1 << 30);
    // Hoisted do loop (plano de otimização A3): regex e fonte por elemento
    // eram recriados dezenas de milhares de vezes por render.
    final RegExp effectiveLetterReg = getLetterReg() ?? _defaultLetterReg;
    for (int i = resume?.i ?? 0; i < elementList.length; i++) {
      final IRow curRow = rowList.last;
      final IElement element = elementList[i];
      final IElement? preElement = i > 0 ? elementList[i - 1] : null;
      // Fonte resolvida no branch de texto e reutilizada no rowElement (A3).
      String? resolvedFontStyle;
      // Dentro de tabela o default é 0 (não `defaultRowMargin`): o Word não
      // aplica o "basic row margin" do editor em células, e o ZERO que o editor
      // injeta no início de cada célula vem com rowMargin=null — sem isto cada
      // linha de célula ganhava ~16px (2×8), inflando as tabelas (~2,6× numa
      // linha simples) e o total de páginas.
      final double rowMarginFactor =
          element.rowMargin ?? (isFromTable ? 0 : defaultRowMargin);
      final double rowMargin = defaultBasicRowMarginHeight * rowMarginFactor;
      final IElementMetrics metrics = IElementMetrics(
        width: 0,
        height: 0,
        boundingBoxAscent: 0,
        boundingBoxDescent: 0,
      );
      final double computedOffsetX = curRow.offsetX ??
          (element.listId != null ? (listStyleMap[element.listId!] ?? 0) : 0);
      // `w:ind@right`: reduz a largura útil da linha; clamp para nunca
      // deixar a linha estreita demais (evita loop de wrap degenerado).
      double paraRightIndent = (element.paraIndentRight ?? 0) * scale;
      if (paraRightIndent > 0 &&
          innerWidth - computedOffsetX - paraRightIndent < 50) {
        final double clamped = innerWidth - computedOffsetX - 50;
        paraRightIndent = clamped > 0 ? clamped : 0;
      }
      final double availableWidth =
          innerWidth - computedOffsetX - paraRightIndent;
      final bool isStartElement = curRow.elementList.length == 1;
      if (isStartElement) {
        x += computedOffsetX;
        y += curRow.offsetY ?? 0;
      }
      if (curRow.elementList.isEmpty) {
        curRow.startIndex = i;
      }
      // F4.3: espaçamento antes do 1º parágrafo (doc inteiro ou recorte do
      // fast path — o ZERO inicial não passa pelo force-break do isWrap).
      if (i == 0 && element.value == ZERO) {
        final double paraSpacingBefore =
            (element.paraSpacingBefore ?? 0) * scale;
        if (paraSpacingBefore > 0) {
          curRow.offsetY = (curRow.offsetY ?? 0) + paraSpacingBefore;
        }
        // F4.2: indent da 1ª linha do parágrafo inicial do recorte/doc.
        if (element.listId == null) {
          final double indent = ((element.paraIndentLeft ?? 0) +
                  (element.paraIndentFirstLine ?? 0)) *
              scale;
          if (indent > 0) {
            curRow.offsetX = indent;
          }
        }
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
        metrics.boundingBoxAscent = 0;
        if (element.imgDisplay == ImageDisplay.surround ||
            element.imgDisplay == ImageDisplay.floatTop ||
            element.imgDisplay == ImageDisplay.floatBottom) {
          metrics.width = 0;
          metrics.height = 0;
          metrics.boundingBoxDescent = 0;
        } else {
          final double rawWidth = element.width != null
              ? element.width!.toDouble()
              : availableWidth / scale;
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
          if (element.imgCaption?.value.isNotEmpty == true) {
            final IImgCaptionOption imgCaptionOption =
                _options.imgCaption ?? const IImgCaptionOption();
            final double captionSize =
                (element.imgCaption?.size ?? imgCaptionOption.size ?? 12)
                    .toDouble();
            final double captionTop =
                (element.imgCaption?.top ?? imgCaptionOption.top ?? 5)
                    .toDouble();
            metrics.boundingBoxAscent = (captionSize + captionTop) * scale;
          }
        }
      } else if (element.type == ElementType.label) {
        final IPadding padding = _options.label?.defaultPadding ??
            IPadding(top: 4, right: 4, bottom: 4, left: 4);
        final String labelFont = getElementFont(element);
        final ITextMetrics fontMetrics =
            textParticle!.measureTextWithFont(ctx, element, labelFont);
        metrics.width =
            fontMetrics.width + (padding.right + padding.left) * scale;
        metrics.height = ((element.size ?? defaultSize).toDouble()) * scale;
        metrics.boundingBoxDescent = 0;
        metrics.boundingBoxAscent =
            (padding.top + fontMetrics.actualBoundingBoxAscent) * scale;
      } else if (element.type == ElementType.table &&
          element.tablePartRenderId == _renderCount) {
        // Parte de tabela já particionada NESTE render (F4.5/F5): o setup
        // completo (computeRowColInfo, layout de célula, redução, split) já
        // rodou uma vez sobre a tabela inteira; aqui só emitimos a geometria
        // desta parte, evitando o custo O(partes×linhas).
        final double partHeight =
            element.tablePartHeight ?? element.height ?? 0;
        element.height = partHeight;
        metrics.width = (element.width ?? 0) * scale;
        metrics.height = partHeight * scale;
        metrics.boundingBoxDescent = metrics.height;
        metrics.boundingBoxAscent = -rowMargin;
        if (i + 1 < elementList.length &&
            elementList[i + 1].type == ElementType.table) {
          metrics.boundingBoxAscent -= rowMargin;
        }
      } else if (element.type == ElementType.table) {
        if (element.pagingId != null) {
          int tableIndex = i + 1;
          int combineCount = 0;
          bool restoredPagingTopology = false;
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
            restoredPagingTopology = true;
          }
          // Reconstitui a tabela original: remove as células-continuação
          // sintéticas e restaura os rowspans truncados pela divisão anterior
          // (F4.5) — sem isso o merge-back devolveria uma tabela corrompida.
          final List<ITr>? merged = element.trList;
          if (merged != null) {
            for (final ITr tr in merged) {
              final int originalCellCount = tr.tdList.length;
              tr.tdList.removeWhere((ITd td) => td.pagingContinuation == true);
              if (tr.tdList.length != originalCellCount) {
                restoredPagingTopology = true;
              }
              for (final ITd td in tr.tdList) {
                if (td.originalRowspan != null) {
                  td.rowspan = td.originalRowspan!;
                  td.originalRowspan = null;
                  restoredPagingTopology = true;
                }
              }
            }
          }
          if (restoredPagingTopology) {
            // Merge-back mutates both the root and nested cell ownership
            // without going through spliceElementList. Keep revisioned indexes
            // and stable history locators aligned with the canonical tree.
            didChangeElementStructure(elementList);
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
              final double effectiveInnerWidth =
                  tdInnerWidth <= 0 ? innerWidth : tdInnerWidth;
              // Reusa o layout da célula quando ela já foi medida NESTE render
              // com a mesma largura (F4.5/F5): o table paging move as mesmas
              // células para as partes seguintes — sem isso o split fica
              // O(n²) numa tabela de milhares de linhas.
              final List<IRow> tdRowList;
              if (td.rowList != null &&
                  td.layoutRenderId == _renderCount &&
                  td.layoutInnerWidth == effectiveInnerWidth) {
                tdRowList = td.rowList!;
              } else {
                tdRowList = computeRowList(
                  IComputeRowListPayload(
                    innerWidth: effectiveInnerWidth,
                    elementList: td.value,
                    isFromTable: true,
                    isPagingMode: isPagingMode,
                  ),
                );
                td.layoutRenderId = _renderCount;
                td.layoutInnerWidth = effectiveInnerWidth;
              }
              // offsetY carrega o before/after dos parágrafos da célula
              // (F4.3) — sem ele a altura do TD ignora o espaçamento.
              final double rowHeight = tdRowList.fold<double>(
                0,
                (double prev, IRow cur) =>
                    prev + cur.height + (cur.offsetY ?? 0),
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
        // Table paging (F4.5/roteiro F4.7): tabela que cruza o limite da
        // página é DIVIDIDA em partes com o mesmo pagingId (o merge no início
        // deste branch reconstitui antes de re-dividir), repetindo os tr com
        // pagingRepeat como cabeçalho. Port do Draw.ts original (~1618-1737).
        if (isPagingMode && !isFromTable) {
          // Table paging em PASSO ÚNICO (F4.5/F5): particiona a tabela
          // inteira de uma vez em vez de cortar uma parte por iteração do
          // laço externo (que re-executava o setup O(linhas) por parte →
          // O(partes×linhas) numa tabela de milhares de linhas).
          _partitionTableAcrossPages(
            element: element,
            rowList: rowList,
            elementList: elementList,
            index: i,
            metrics: metrics,
            pageContentHeight: pageHeight,
            marginHeight: mainOuterHeight,
            scale: scale,
            rowMargin: rowMargin,
            position: position,
          );
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
        resolvedFontStyle = fontStyle;
        final double scaledSize = resolvedSize * scale;
        final bool isZero = element.value == ZERO;
        // F4.10 (D4): métricas TTF determinísticas quando a família está no
        // registry (Arial e substitutas cobrem ~100% dos DOCX de resources/).
        // Largura e altura de linha deixam de depender do que o browser tem
        // instalado e passam a bater com o Word. Sem métricas → fallback
        // canvas (measureText), como antes.
        final ce_fonts.FontMetrics? ttf = ce_fonts.FontRegistry.instance
            .lookup(element.font ?? _options.defaultFont);
        // ascent/descent do glifo (bounding box) e da linha (com lineGap).
        double glyphAscent;
        double glyphDescent;
        double fontAscent;
        double fontDescent;
        if (ttf != null) {
          metrics.width =
              isZero ? 0 : ttf.measureWidth(element.value, scaledSize);
          glyphAscent = isZero ? scaledSize : ttf.ascentPx(scaledSize);
          glyphDescent = ttf.descentPx(scaledSize);
          // lineGap todo acima (baseline ancorada pelo descent embaixo).
          fontAscent = ttf.ascentPx(scaledSize) + ttf.lineGapPx(scaledSize);
          fontDescent = ttf.descentPx(scaledSize);
        } else {
          final ITextMetrics? fontMetrics =
              textParticle?.measureTextWithFont(ctx, element, fontStyle);
          metrics.width = (fontMetrics?.width ?? 0) * scale;
          glyphAscent = (isZero
                  ? (element.size ?? defaultSize).toDouble()
                  : fontMetrics?.actualBoundingBoxAscent ?? resolvedSize) *
              scale;
          glyphDescent = (fontMetrics?.actualBoundingBoxDescent ?? 0) * scale;
          fontAscent = (fontMetrics?.fontBoundingBoxAscent ?? 0) * scale;
          fontDescent = (fontMetrics?.fontBoundingBoxDescent ?? 0) * scale;
          if (fontAscent <= 0) {
            final double? knownFactor = _singleLineFactorByFont[
                (element.font ?? _options.defaultFont ?? '').toLowerCase()];
            if (knownFactor != null) {
              final double single0 = resolvedSize * knownFactor * scale;
              fontDescent = single0 * 0.19;
              fontAscent = single0 - fontDescent;
            } else {
              fontAscent = resolvedSize * 0.9 * scale;
              fontDescent = resolvedSize * 0.25 * scale;
            }
          }
        }
        if (element.letterSpacing != null) {
          metrics.width += element.letterSpacing! * scale;
        }
        metrics.boundingBoxAscent = glyphAscent;
        metrics.boundingBoxDescent = glyphDescent;
        // F4.3 (spacing Word-fiel): parágrafos vindos de DOCX trazem
        // lineSpacingRule e rowMargin=0; a altura da linha passa a ser a da
        // FONTE (ascent+descent+lineGap do Word), não o bounding box do glifo
        // + padding fixo do editor. O extra de espaçamento entra acima da
        // linha (baseline no fundo, como o Word).
        final String? lineRule = element.lineSpacingRule;
        if (lineRule != null) {
          final double single = fontAscent + fontDescent;
          final double value = element.lineSpacingValue ?? 1.0;
          double target;
          if (lineRule == 'exact') {
            target = value * scale;
          } else if (lineRule == 'atLeast') {
            final double minPx = value * scale;
            target = single > minPx ? single : minPx;
          } else {
            target = single * value;
          }
          if (target > 0) {
            metrics.boundingBoxDescent = fontDescent;
            metrics.boundingBoxAscent = target - fontDescent;
          }
        }
        if (element.type == ElementType.superscript) {
          metrics.boundingBoxAscent += metrics.height / 2;
        } else if (element.type == ElementType.subscript) {
          metrics.boundingBoxDescent += metrics.height / 2;
        }
      }
      final double ascent = !(element.hide == true ||
                  element.control?.hide == true ||
                  element.area?.hide == true) &&
              ((element.imgDisplay != ImageDisplay.inline &&
                      element.type == ElementType.image) ||
                  element.type == ElementType.latex)
          ? metrics.height + rowMargin
          : metrics.boundingBoxAscent + rowMargin;
      final double height = rowMargin +
          metrics.boundingBoxAscent +
          metrics.boundingBoxDescent +
          rowMargin;
      final String fontStyle =
          resolvedFontStyle ?? getElementFont(element, scale);
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
          // Só olha à frente no INÍCIO de uma palavra (atual é letra e o
          // anterior NÃO é) — senão a quebra cairia no meio da palavra
          // ("Migração / I" | "mplantação"). No começo da palavra, se ela
          // inteira não couber no restante da linha, a decisão de wrap a joga
          // inteira para a próxima linha (comportamento do Word).
          final bool curIsLetter = effectiveLetterReg.hasMatch(element.value);
          final bool preIsLetter = preElement != null &&
              effectiveLetterReg.hasMatch(preElement.value);
          if (curIsLetter && !preIsLetter) {
            final IMeasureWordResult measureResult = textParticle.measureWord(
                ctx, elementList, i, resolvedFontStyle);
            final IElement? endElement = measureResult.endElement;
            final double wordWidth = measureResult.width * scale;
            // NÃO exigir endElement != null: a última palavra da célula não
            // tem caractere não-letra depois dela (endElement=null), mas ainda
            // precisa ser mantida inteira ("Treinam|ento", "M|ês").
            if (wordWidth <= availableWidth) {
              if (endElement != null) {
                nextElement = endElement;
              }
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
      final bool isForceBreak = element.type == ElementType.separator ||
          element.type == ElementType.table ||
          preElement?.type == ElementType.table ||
          preElement?.type == ElementType.block ||
          element.type == ElementType.block ||
          preElement?.imgDisplay == ImageDisplay.inline ||
          element.imgDisplay == ImageDisplay.inline ||
          preElement?.listId != element.listId ||
          (preElement?.areaId != element.areaId &&
              element.area?.hide != true) ||
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
              (i + 1 < elementList.length ? elementList[i + 1].rowFlex : null),
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
        } else if (element.paraIndentLeft != null ||
            element.paraIndentFirstLine != null) {
          // F4.2 (w:ind): 1ª linha do parágrafo = left + firstLine (hanging
          // entra negativo); linhas de continuação (wrap) = left.
          final bool isParagraphStart = element.value == ZERO;
          final double indent = ((element.paraIndentLeft ?? 0) +
                  (isParagraphStart ? (element.paraIndentFirstLine ?? 0) : 0)) *
              scale;
          if (indent > 0) {
            newRow.offsetX = indent;
          }
        }
        if (!isFromTable &&
            element.area?.top != null &&
            element.areaId != preElement?.areaId) {
          newRow.offsetY = (element.area!.top ?? 0) * scale;
        }
        // F4.3: `w:spacing` before/after — o espaço entre parágrafos é o
        // MÁXIMO de (after do anterior, before do atual), como o Word
        // renderiza os DOCX do corpus (medido no PDF golden: gap de 6pt
        // entre Nivel2 before=120/after=120 — a soma daria 12pt e inflava
        // a paginação: TR 150 vs 140 do Word).
        if (element.value == ZERO) {
          final double before = (element.paraSpacingBefore ?? 0) * scale;
          final double prevAfter = (preElement?.paraSpacingAfter ?? 0) * scale;
          final double paraSpacing = before > prevAfter ? before : prevAfter;
          if (paraSpacing > 0) {
            newRow.offsetY = (newRow.offsetY ?? 0) + paraSpacing;
          }
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
            final double totalGap = availableWidth - curRow.width;
            // Justificação estilo Word (F4.3): distribui o espaço extra apenas
            // nos ESPAÇOS (limites de palavra), não entre cada caractere —
            // senão células estreitas viram "u s o  p o r  p r a z o".
            // Estica só espaço normal (U+0020) e ideográfico (U+3000); nbsp
            // (U+00A0) e narrow nbsp (U+202F) NÃO esticam, por definição.
            final List<int> spaceIndexes = <int>[];
            for (int e = 0; e < rowElementList.length; e++) {
              final String v = rowElementList[e].value;
              if (v.length == 1) {
                final int cu = v.codeUnitAt(0);
                if (cu == 0x20 || cu == 0x3000) {
                  spaceIndexes.add(e);
                }
              }
            }
            if (spaceIndexes.isNotEmpty && totalGap > 0) {
              final double gap = totalGap / spaceIndexes.length;
              for (final int e in spaceIndexes) {
                rowElementList[e].metrics.width += gap;
              }
              curRow.width = availableWidth;
            }
            // Sem espaços (palavra única) → não estica (como o Word).
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
        final Map<String, double> nextSurround = position?.setSurroundPosition(
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
      // Corte de fatia (F5.5): cedeu o orçamento de rows E estamos num limite
      // de parágrafo (próximo elemento inicia parágrafo) → salva o cursor de
      // continuação e devolve as rows acumuladas até aqui.
      if (resume != null &&
          ((rowList.length - chunkStartRowCount) >= budgetRows ||
              (resume.shouldYield?.call() ?? false)) &&
          i + 1 < elementList.length &&
          elementList[i + 1].value == ZERO) {
        resume
          ..i = i + 1
          ..x = x
          ..y = y
          ..pageNo = pageNo
          ..listIndex = listIndex
          ..listId = listId
          ..controlRealWidth = controlRealWidth
          ..started = true
          ..done = false;
        return _finalizeRowList(rowList);
      }
    }
    resume?.done = true;
    return _finalizeRowList(rowList);
  }

  /// Filtra rows vazias e reindexa (compartilhado entre o retorno completo e
  /// cada fatia do layout progressivo).
  List<IRow> _finalizeRowList(List<IRow> rowList) {
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
      imgCrop: source.imgCrop,
      imgCaption: source.imgCaption,
      imgToolDisabled: source.imgToolDisabled,
      labelId: source.labelId,
      label: source.label,
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
        final double targetHeight = pageHeight > height ? pageHeight : height;
        _pageCanvasManager.setPageHeight(0, targetHeight);
      }
      return pageRowList;
    }
    final List<List<IRow>> pageRowList = <List<IRow>>[<IRow>[]];
    double pageHeight = marginHeight;
    int pageNo = 0;
    for (int i = 0; i < rowList.length; i++) {
      final IRow row = rowList[i];
      final double rowOffsetY = row.offsetY ?? 0;
      final bool shouldBreak = row.height + rowOffsetY + pageHeight > height ||
          (i > 0 && rowList[i - 1].isPageBreak == true);
      if (shouldBreak) {
        if (maxPageNo != null && pageNo >= maxPageNo) {
          if (row.startIndex >= 0 && row.startIndex <= _elementList.length) {
            _documentModel.replace(
              main: _elementList.take(row.startIndex),
            );
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

  /// Nº de elementos de `_elementList` no momento do último compute — usado
  /// pelo fast path para mapear índices novos → antigos nas rows cacheadas.
  int _computedElementCount = 0;

  static double _sumTrHeight(List<ITr> rows) {
    double h = 0;
    for (final ITr tr in rows) {
      h += tr.height;
    }
    return h;
  }

  /// Trata `rowspan` cruzando a fronteira entre [prevRows] e [nextRows]
  /// (F4.5): trunca o span das células que ultrapassam [prevRows] e insere a
  /// célula-continuação correspondente na 1ª linha de [nextRows], como o
  /// `vMerge continue` do Word. Chamado da esquerda p/ direita, então uma
  /// continuação pode ela mesma cruzar a próxima fronteira.
  void _bridgeRowspanAcrossCut(
      List<ITr> prevRows, List<ITr> nextRows, int gridCols) {
    if (gridCols <= 0 || prevRows.isEmpty || nextRows.isEmpty) {
      return;
    }
    final int prevCount = prevRows.length;
    final List<List<ITd?>> owners = List<List<ITd?>>.generate(
      prevCount,
      (_) => List<ITd?>.filled(gridCols, null),
    );
    // (coluna, td, linhas restantes) das células que cruzam a fronteira.
    final List<List<Object>> crossing = <List<Object>>[];
    for (int r0 = 0; r0 < prevCount; r0++) {
      int col = 0;
      for (final ITd td in prevRows[r0].tdList) {
        while (col < gridCols && owners[r0][col] != null) {
          col += 1;
        }
        if (col >= gridCols) {
          break;
        }
        final int spanEnd = r0 + td.rowspan;
        for (int rr = r0;
            rr < (spanEnd < prevCount ? spanEnd : prevCount);
            rr++) {
          for (int cc = col; cc < col + td.colspan && cc < gridCols; cc++) {
            owners[rr][cc] = td;
          }
        }
        if (spanEnd > prevCount) {
          crossing.add(<Object>[col, td, spanEnd - prevCount]);
          td.originalRowspan ??= td.rowspan;
          td.rowspan = prevCount - r0;
        }
        col += td.colspan;
      }
    }
    if (crossing.isEmpty) {
      return;
    }
    crossing.sort((a, b) => (a[0] as int).compareTo(b[0] as int));
    final ITr firstNextTr = nextRows.first;
    final Set<int> phantomCols = <int>{};
    for (final List<Object> cross in crossing) {
      final ITd td = cross[1] as ITd;
      for (int k = cross[0] as int; k < (cross[0] as int) + td.colspan; k++) {
        phantomCols.add(k);
      }
    }
    final List<int> realCols = <int>[];
    int col = 0;
    for (final ITd td in firstNextTr.tdList) {
      while (phantomCols.contains(col)) {
        col += 1;
      }
      realCols.add(col);
      col += td.colspan;
    }
    int inserted = 0;
    for (final List<Object> cross in crossing) {
      final int crossCol = cross[0] as int;
      final ITd ownerTd = cross[1] as ITd;
      final int remaining = cross[2] as int;
      int insertAt = inserted;
      for (final int realCol in realCols) {
        if (realCol < crossCol) {
          insertAt += 1;
        }
      }
      firstNextTr.tdList.insert(
        insertAt,
        ITd(
          id: utils.getUUID(),
          colspan: ownerTd.colspan,
          rowspan: remaining,
          value: <IElement>[IElement(value: '')],
          backgroundColor: ownerTd.backgroundColor,
          borderTypes: ownerTd.borderTypes?.toList(),
          verticalAlign: ownerTd.verticalAlign,
          pagingContinuation: true,
        ),
      );
      inserted += 1;
    }
  }

  /// Table paging em passo único (F4.5/F5): particiona a tabela inteira (já
  /// medida) em partes ≤ altura de página, criando todas as continuações de
  /// uma vez e marcando-as para o laço externo não re-executar o setup por
  /// parte. Substitui o algoritmo O(partes×linhas) do port original.
  void _partitionTableAcrossPages({
    required IElement element,
    required List<IRow> rowList,
    required List<IElement> elementList,
    required int index,
    required IElementMetrics metrics,
    required double pageContentHeight,
    required double marginHeight,
    required double scale,
    required double rowMargin,
    required Position? position,
  }) {
    final List<ITr> fullTrList = element.trList ?? <ITr>[];
    if (fullTrList.isEmpty) {
      return;
    }
    final double rowMarginHeight = rowMargin * 2 * scale;
    final int gridCols = element.colgroup?.length ?? 0;

    // 1) Fill da página corrente (uma varredura de rowList).
    double curPagePreHeight = marginHeight;
    for (int r = 0; r < rowList.length; r++) {
      final IRow row = rowList[r];
      final double oy = row.offsetY ?? 0;
      if (row.height + curPagePreHeight + oy > pageContentHeight ||
          (r > 0 && rowList[r - 1].isPageBreak == true)) {
        curPagePreHeight = marginHeight + row.height + oy;
      } else {
        curPagePreHeight += row.height + oy;
      }
    }
    final double firstTrHeight = fullTrList.first.height * scale;
    if (curPagePreHeight + firstTrHeight + rowMarginHeight >
            pageContentHeight ||
        (index > 0 && elementList[index - 1].type == ElementType.pageBreak)) {
      curPagePreHeight = marginHeight;
    }

    // 2) Fronteiras de corte em um passo (altura acumulada, sem re-varrer).
    final List<ITr> repeatHeaders =
        fullTrList.where((ITr t) => t.pagingRepeat == true).toList();
    final double repeatHeadersHeight = _sumTrHeight(repeatHeaders) * scale;
    final List<int> cutIndices = <int>[];
    int partStart = 0;
    double pageFill = curPagePreHeight;
    for (int r = 0; r < fullTrList.length; r++) {
      final double trH = fullTrList[r].height * scale;
      if (r > partStart &&
          pageFill + rowMarginHeight + trH > pageContentHeight) {
        cutIndices.add(r);
        partStart = r;
        pageFill = marginHeight + repeatHeadersHeight + trH;
      } else {
        pageFill += trH;
      }
    }
    if (cutIndices.isEmpty) {
      return; // cabe inteira; métricas já setadas pelo chamador.
    }

    // 3) Constrói as partes (fronteiras [0, cut0, ..., N]).
    final String pagingId = element.pagingId ?? utils.getUUID();
    element.pagingId = pagingId;
    element.pagingIndex = element.pagingIndex ?? 0;
    final List<List<ITr>> partRows = <List<ITr>>[];
    int prevCut = 0;
    for (final int cut in cutIndices) {
      partRows.add(fullTrList.sublist(prevCut, cut));
      prevCut = cut;
    }
    partRows.add(fullTrList.sublist(prevCut));

    // Parte 0 permanece em element.
    List<ITr> prevPartRows = partRows[0];
    element.trList = prevPartRows;
    element.height = _sumTrHeight(prevPartRows);

    final List<IElement> clones = <IElement>[];
    for (int k = 1; k < partRows.length; k++) {
      List<ITr> nextRows = partRows[k];
      if (gridCols > 0) {
        _bridgeRowspanAcrossCut(prevPartRows, nextRows, gridCols);
      }
      if (repeatHeaders.isNotEmpty) {
        final List<ITr> clonedHeaders =
            element_utils.cloneTrList(repeatHeaders);
        for (final ITr t in clonedHeaders) {
          t.id = utils.getUUID();
        }
        nextRows = <ITr>[...clonedHeaders, ...nextRows];
      }
      final IElement clone = element_utils.cloneElement(element);
      clone.trList = nextRows;
      // Rebaseia a geometria (td.x/td.y) ao TOPO desta parte. Os ITd reusados
      // guardam o `y` acumulado da tabela INTEIRA (ex.: ~300px para a 3ª linha),
      // e como o fast-path de render (tablePartRenderId) não re-roda o layout,
      // a parte de continuação renderizaria ~N px abaixo do header (gap enorme
      // no topo da página, inflando a contagem de páginas). Recalcular aqui —
      // uma vez por parte, O(linhas_da_parte) — zera esse offset e posiciona
      // headers repetidos corretamente no topo.
      (_tableParticle as TableParticle?)?.computeRowColInfo(clone);
      clone.pagingId = pagingId;
      clone.pagingIndex = (element.pagingIndex ?? 0) + k;
      clone.id = utils.getUUID();
      clone.height = _sumTrHeight(nextRows);
      clone.tablePartRenderId = _renderCount;
      clone.tablePartHeight = clone.height;
      clones.add(clone);
      prevPartRows = nextRows;
    }

    // 4) Emenda todas as partes de uma vez.
    spliceElementList(elementList, index + 1, 0, clones);

    // 5) Métricas da parte 0.
    final double part0Height = element.height ?? 0;
    metrics.height = part0Height * scale;
    metrics.boundingBoxDescent = metrics.height;
    metrics.boundingBoxAscent = -rowMargin;
    if (index + 1 < elementList.length &&
        elementList[index + 1].type == ElementType.table) {
      metrics.boundingBoxAscent -= rowMargin;
    }

    // 6) Fixup do positionContext (cursor em tabela dividida).
    if (position != null) {
      final IPositionContext positionContext = position.getPositionContext();
      if (positionContext.isTable) {
        int newIndex = -1;
        int newTrIndex = -1;
        int tableIndex = index;
        while (tableIndex < elementList.length) {
          final IElement curElement = elementList[tableIndex];
          if (curElement.pagingId != pagingId) {
            break;
          }
          final int trIndex = curElement.trList?.indexWhere(
                (ITr r) => r.id == positionContext.trId,
              ) ??
              -1;
          if (trIndex >= 0) {
            newIndex = tableIndex;
            newTrIndex = trIndex;
            break;
          }
          tableIndex += 1;
        }
        if (newIndex >= 0) {
          positionContext.index = newIndex;
          positionContext.trIndex = newTrIndex;
          position.setPositionContext(positionContext);
        }
      }
    }
  }

  /// Fast path de layout para edição textual (P2 do plano de otimização;
  /// análogo ao `Recalculate_FastWholeParagraph` do OnlyOffice).
  ///
  /// Para uma tecla comum, recomputa o parágrafo do cursor. Quando [range]
  /// descreve um splice (Enter ou exclusão/substituição de uma seleção), o
  /// recorte cresce até fronteiras de parágrafo estáveis nos dois lados. Isso
  /// é importante porque o ZERO inserido por Enter não existia no layout
  /// anterior e uma exclusão pode fundir vários parágrafos; procurar apenas a
  /// row do novo cursor fazia ambos caírem no relayout global.
  ///
  /// As rows fora do recorte são reutilizadas e apenas seus índices são
  /// deslocados. Páginas e posições ainda são agregadas pelo chamador. Retorna
  /// `false` (cai no relayout completo) em qualquer situação fora do caso
  /// textual seguro:
  /// zona ≠ main, cursor em tabela, floats/surround no documento, parágrafo
  /// com lista/área/controle/título de lista/elemento não-inline, rowFlex
  /// não nulo conflitante no parágrafo, ou fronteiras de rows desalinhadas.
  bool _tryFastParagraphLayout(
    int anchorIndex, {
    DocumentRange? range,
  }) {
    final Position? position = _position as Position?;
    if (position == null || _rowList.isEmpty || _computedElementCount == 0) {
      return false;
    }
    if (position.getPositionContext().isTable == true) {
      return false;
    }
    if (!getZone().isMainActive()) {
      return false;
    }
    // O deslocamento vertical de um parágrafo pode alterar a ancoragem e o
    // contorno de qualquer objeto flutuante nas páginas seguintes. Até haver
    // uma invalidação incremental específica para floats, preserve a
    // correção fazendo o layout completo nesse caso.
    if (position.getFloatPositionList().isNotEmpty) {
      return false;
    }
    final List<IElement> elementList = _elementList;
    if (anchorIndex < 0 || anchorIndex >= elementList.length) {
      return false;
    }
    final int delta = elementList.length - _computedElementCount;

    // O intervalo da invalidation usa max(removidos, inseridos). Junto com o
    // delta total ele permite recuperar os dois comprimentos sem carregar
    // objetos de mutation para dentro do layout.
    int mutationStart = anchorIndex;
    int insertedCount = 0;
    if (range != null) {
      mutationStart = range.start;
      final int span = range.length;
      insertedCount = delta >= 0 ? span : span + delta;
      final int removedCount = delta >= 0 ? span - delta : span;
      if (insertedCount < 0 || removedCount < 0) {
        return false;
      }
      if (mutationStart < 0 ||
          mutationStart > elementList.length ||
          mutationStart + insertedCount > elementList.length) {
        return false;
      }
    }

    int pStart;
    int pEnd;
    if (range == null) {
      // Chamadas legadas não informam o splice: mantém exatamente o recorte
      // histórico de um parágrafo.
      pStart = anchorIndex;
      while (pStart > 0 && elementList[pStart].value != ZERO) {
        pStart -= 1;
      }
      pEnd = anchorIndex + 1;
      while (pEnd < elementList.length && elementList[pEnd].value != ZERO) {
        pEnd += 1;
      }
    } else {
      // Começa ANTES do splice para incluir o parágrafo que é dividido por
      // Enter ou fundido por Backspace/Delete. Depois avança do fim real dos
      // itens inseridos até o próximo ZERO, incluindo todos os novos
      // parágrafos produzidos pelo splice.
      pStart = mutationStart > 0 ? mutationStart - 1 : 0;
      if (pStart >= elementList.length) {
        pStart = elementList.length - 1;
      }
      while (pStart > 0 && elementList[pStart].value != ZERO) {
        pStart -= 1;
      }
      pEnd = mutationStart + insertedCount;
      if (pEnd <= pStart) {
        pEnd = pStart + 1;
      }
      while (pEnd < elementList.length && elementList[pEnd].value != ZERO) {
        pEnd += 1;
      }
      // Inclui também o parágrafo estável seguinte. O offsetY da primeira row
      // dele depende de max(paraSpacingAfter anterior, paraSpacingBefore
      // atual); reutilizá-lo depois de uma fusão de parágrafos preservaria um
      // espaçamento calculado com a borda antiga.
      if (pEnd < elementList.length) {
        pEnd += 1;
        while (pEnd < elementList.length && elementList[pEnd].value != ZERO) {
          pEnd += 1;
        }
      }
    }

    bool isSafeTextElement(IElement el) {
      final ElementType? type = el.type;
      return (type == null ||
              type == ElementType.text ||
              type == ElementType.superscript ||
              type == ElementType.subscript) &&
          el.listId == null &&
          el.areaId == null &&
          el.controlId == null &&
          el.imgDisplay == null &&
          el.pagingId == null;
    }

    // Guardas por elemento do recorte novo.
    RowFlex? sliceRowFlex;
    for (int i = pStart; i < pEnd; i++) {
      final IElement el = elementList[i];
      if (!isSafeTextElement(el)) {
        return false;
      }
      // DOCX formatado pode carregar o alinhamento somente no ZERO ou somente
      // nos runs do parágrafo; `null` significa herdar e não é conflito. O
      // teste antigo comparava null literalmente e mandava títulos textuais
      // comuns para um relayout global de 3–4 s ao alternar bold/italic.
      // Preserve o fallback apenas para dois valores NÃO nulos realmente
      // incompatíveis dentro do mesmo parágrafo.
      if (i == pStart || (i > pStart && el.value == ZERO)) {
        sliceRowFlex = null;
      }
      final RowFlex? elementRowFlex = el.rowFlex;
      if (elementRowFlex != null) {
        if (sliceRowFlex == null) {
          sliceRowFlex = elementRowFlex;
        } else if (elementRowFlex != sliceRowFlex) {
          return false;
        }
      }
    }

    // Fronteira equivalente na lista ANTIGA. Tudo após o splice desloca por
    // [delta], logo o ZERO estável à direita tinha índice pEnd-delta.
    final int pEndOld = pEnd - delta;
    if (pEndOld < pStart || pEndOld > _computedElementCount) {
      return false;
    }

    // Rows antigas do parágrafo: [rowStart, rowEnd) com fronteiras exatas.
    int rowStart = _lowerBoundRowByStartIndex(pStart);
    if (rowStart >= _rowList.length ||
        _rowList[rowStart].startIndex != pStart) {
      // Parágrafo 0 começa na row 0 sem ZERO próprio.
      if (!(pStart == 0 && rowStart == 0)) {
        return false;
      }
    }
    int rowEnd = _lowerBoundRowByStartIndex(pEndOld);
    if (rowEnd < _rowList.length && _rowList[rowEnd].startIndex != pEndOld) {
      return false;
    }
    if (rowEnd < rowStart) {
      return false;
    }

    // O recorte antigo pode conter estruturas que acabaram de ser removidas
    // e, portanto, não aparecem mais em elementList. Não reutilize layout ao
    // excluir tabela/lista/controle/float: esses casos mantêm o caminho global
    // até possuírem invalidation estrutural própria.
    for (int r = rowStart; r < rowEnd; r++) {
      for (final IElement oldElement in _rowList[r].elementList) {
        if (!isSafeTextElement(oldElement)) {
          return false;
        }
      }
    }

    // Conserva a caixa que estava efetivamente pintada antes de substituir as
    // rows. O repaint parcial só será aceito depois que Position produzir a
    // nova caixa e ambas forem comprovadas na mesma página. Sem essa evidência
    // (por exemplo, durante uma paginação ainda incompleta), o chamador faz o
    // repaint integral da página.
    if (rowStart < rowEnd) {
      final List<IElementPosition> oldPositions =
          position.getOriginalMainPositionList();
      final IRow firstOldRow = _rowList[rowStart];
      final IRow lastOldRow = _rowList[rowEnd - 1];
      final int firstOldIndex = firstOldRow.startIndex;
      final int lastOldIndex =
          lastOldRow.startIndex + lastOldRow.elementList.length - 1;
      if (firstOldIndex >= 0 &&
          lastOldIndex >= firstOldIndex &&
          lastOldIndex < oldPositions.length) {
        final IElementPosition firstOldPosition = oldPositions[firstOldIndex];
        final IElementPosition lastOldPosition = oldPositions[lastOldIndex];
        if (firstOldPosition.pageNo == lastOldPosition.pageNo) {
          _fastLayoutOldDirtyPage = firstOldPosition.pageNo;
          _fastLayoutOldDirtyTop = firstOldPosition.coordY;
          _fastLayoutOldDirtyBottom =
              lastOldPosition.coordY + lastOldPosition.lineHeight;
        }
      }
    }

    // Recomputa as rows apenas do recorte do parágrafo.
    final List<double> margins = getMargins();
    final List<IRow> sliceRows = computeRowList(
      IComputeRowListPayload(
        startX: margins[3],
        startY: 0,
        pageHeight: getHeight(),
        mainOuterHeight: getMainOuterHeight(),
        isPagingMode: getIsPagingMode(),
        innerWidth: getInnerWidth(),
        surroundElementList: const <IElement>[],
        elementList: elementList.sublist(pStart, pEnd),
      ),
    );

    // No recorte o ZERO do parágrafo é i==0 (sem preElement): o i==0 já
    // aplicou o `before`; repõe só o EXCESSO do `after` do parágrafo
    // anterior quando ele é maior (regra max(after, before) — F4.3).
    if (sliceRows.isNotEmpty && pStart > 0) {
      final double scale = _resolveScale();
      final double prevAfter =
          (elementList[pStart - 1].paraSpacingAfter ?? 0) * scale;
      final double before =
          (elementList[pStart].paraSpacingBefore ?? 0) * scale;
      if (prevAfter > before) {
        sliceRows.first.offsetY =
            (sliceRows.first.offsetY ?? 0) + (prevAfter - before);
      }
    }
    // Reindexa o recorte e desloca as rows seguintes.
    final int baseRowIndex =
        rowStart > 0 ? _rowList[rowStart - 1].rowIndex + 1 : 0;
    for (int j = 0; j < sliceRows.length; j++) {
      sliceRows[j].startIndex += pStart;
      sliceRows[j].rowIndex = baseRowIndex + j;
    }
    final int rowDelta = sliceRows.length - (rowEnd - rowStart);
    // Repintura dirigida (modelo OnlyOffice OnRecalculatePage): se o nº de
    // rows e a altura total do parágrafo não mudaram, nada abaixo dele se
    // move — só a(s) página(s) que contêm o parágrafo precisam redesenhar.
    double oldSliceHeight = 0;
    for (int j = rowStart; j < rowEnd; j++) {
      oldSliceHeight += _rowList[j].height + (_rowList[j].offsetY ?? 0);
    }
    double newSliceHeight = 0;
    for (final IRow row in sliceRows) {
      newSliceHeight += row.height + (row.offsetY ?? 0);
    }
    _fastLayoutDirtyRowIndexStart = baseRowIndex;
    _fastLayoutDirtyRowIndexEnd = baseRowIndex + sliceRows.length;
    _fastLayoutHeightUnchanged =
        rowDelta == 0 && (oldSliceHeight - newSliceHeight).abs() < 0.005;
    for (int j = rowEnd; j < _rowList.length; j++) {
      final IRow row = _rowList[j];
      row.startIndex += delta;
      row.rowIndex += rowDelta;
    }
    _rowList.replaceRange(rowStart, rowEnd, sliceRows);
    return true;
  }

  /// Menor índice de row com `startIndex >= target` (rows têm startIndex
  /// estritamente crescente).
  int _lowerBoundRowByStartIndex(int target) {
    int lo = 0;
    int hi = _rowList.length;
    while (lo < hi) {
      final int mid = (lo + hi) >> 1;
      if (_rowList[mid].startIndex < target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void _syncCachedRowElementsForFastRender() {
    final List<IElement> sourceElementList = getElementList();
    final List<IRow> rowList = getRowList();
    if (sourceElementList.isEmpty || rowList.isEmpty) {
      return;
    }

    int from = 0;
    int to = sourceElementList.length - 1;
    final RangeManager? rangeManager = _rangeManager as RangeManager?;
    final IRange? currentRange = rangeManager?.getRange();
    if (currentRange != null) {
      if (currentRange.startIndex != currentRange.endIndex) {
        from = currentRange.startIndex + 1;
        to = currentRange.endIndex;
      } else if (currentRange.endIndex >= 0) {
        from = currentRange.endIndex;
        to = currentRange.endIndex;
      }
    }

    if (from < 0) {
      from = 0;
    }
    if (to >= sourceElementList.length) {
      to = sourceElementList.length - 1;
    }
    if (from > to) {
      from = 0;
      to = sourceElementList.length - 1;
    }

    final double scale = _resolveScale();
    for (final IRow row in rowList) {
      final int rowStart = row.startIndex;
      final int rowEnd = rowStart + row.elementList.length - 1;
      if (rowEnd < from) {
        continue;
      }
      if (rowStart > to) {
        break;
      }
      for (int index = 0; index < row.elementList.length; index++) {
        final int sourceIndex = rowStart + index;
        if (sourceIndex < from || sourceIndex > to) {
          continue;
        }
        if (sourceIndex < 0 || sourceIndex >= sourceElementList.length) {
          continue;
        }
        final IRowElement currentRowElement = row.elementList[index];
        final IElement sourceElement = sourceElementList[sourceIndex];
        final IRowElement syncedRowElement = _buildRowElement(
          sourceElement,
          currentRowElement.metrics,
          getElementFont(sourceElement, scale),
        )..left = currentRowElement.left;
        row.elementList[index] = syncedRowElement;
      }
    }
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
        final IRowElement? preElement =
            j > 0 ? curRow.elementList[j - 1] : null;
        final int elementIndex = curRow.startIndex + j;
        if (elementIndex < 0 || elementIndex >= positionList.length) {
          continue;
        }
        final IElementPosition position = positionList[elementIndex];
        final List<double> leftTop =
            position.coordinate['leftTop'] ?? <double>[0, 0];
        final double x = leftTop.isNotEmpty ? leftTop[0] : 0;
        final double y = leftTop.length > 1 ? leftTop[1] : 0;
        final double offsetX = element.left ?? 0;
        final String? highlightColor = element.highlight ??
            control?.getControlHighlight(elementList, elementIndex);
        if (highlightColor != null && highlightColor.isNotEmpty) {
          if (preElement?.highlight != null &&
              preElement?.highlight != highlightColor) {
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
    final bool isDrawLineBreak =
        payload.isDrawLineBreak ?? (_options.lineBreak?.disabled != true);
    final bool isDrawWhiteSpace =
        payload.isDrawWhiteSpace ?? (_options.whiteSpace?.disabled != true);
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
    final LabelParticle? labelParticle = _labelParticle as LabelParticle?;
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
    final WhiteSpaceParticle? whiteSpaceParticle =
        _whiteSpaceParticle as WhiteSpaceParticle?;
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
        final IRowElement? preElement =
            j > 0 ? curRow.elementList[j - 1] : null;
        final int elementIndex = curRow.startIndex + j;
        if (elementIndex < 0 || elementIndex >= positionList.length) {
          index += 1;
          continue;
        }
        final IElementPosition pos = positionList[elementIndex];
        final List<double> leftTop =
            pos.coordinate['leftTop'] ?? <double>[0, 0];
        final double x = leftTop.isNotEmpty ? leftTop[0] : 0;
        final double y = leftTop.length > 1 ? leftTop[1] : 0;
        final double baselineOffset = pos.ascent;
        final IRowElement? nextElement = j + 1 < curRow.elementList.length
            ? curRow.elementList[j + 1]
            : null;
        final bool isHiddenElement = (element.hide == true ||
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
        } else if (element.type == ElementType.label) {
          textParticle?.complete();
          labelParticle?.render(ctx, element, x, y + baselineOffset);
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
          if (element.width != null ||
              element.letterSpacing != null ||
              regular.punctuationReg.hasMatch(element.value)) {
            textParticle?.complete();
          }
        }

        if (isDrawLineBreak &&
            !isPrintMode &&
            _mode != EditorMode.clean &&
            curRow.isWidthNotEnough != true &&
            j == curRow.elementList.length - 1) {
          lineBreakParticle?.render(ctx, element, x, y + curRow.height / 2);
        }

        if (isDrawWhiteSpace && regular.whiteSpaceReg.hasMatch(element.value)) {
          whiteSpaceParticle?.render(ctx, element, x, y + curRow.height / 2);
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
          if (element.type == ElementType.subscript &&
              subscriptParticle != null) {
            underlineOffset = subscriptParticle.getOffsetY(element);
          }
          final String? underlineColor = element.control?.underline == true
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
                  element_constants.textlikeElementType
                      .contains(element.type!));
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
            double adjustY = y +
                baselineOffset +
                basisMetrics.actualBoundingBoxDescent * scale -
                element.metrics.height / 2;
            if (element.type == ElementType.subscript &&
                subscriptParticle != null) {
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
          final bool isSameTableContext = (!isTableContext && tdId == null) ||
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

        if (!groupDisabled &&
            element.groupIds != null &&
            element.groupIds!.isNotEmpty) {
          group?.recordFillInfo(
              element, x, y, element.metrics.width, curRow.height);
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
          rangeManager?.render(ctx, rangeRecord.x, rangeRecord.y,
              rangeRecord.width, rangeRecord.height);
        }
        if (isCrossRowCol &&
            tableRangeElement != null &&
            tableId != null &&
            tableRangeElement.id != null &&
            tableRangeElement.id == tableId &&
            curRow.startIndex >= 0 &&
            curRow.startIndex < positionList.length) {
          final IElementPosition startPosition =
              positionList[curRow.startIndex];
          final List<double> leftTop =
              startPosition.coordinate['leftTop'] ?? <double>[0, 0];
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

  _PartialPageRepaint? _buildFastPartialPageRepaint(
    int pageNo,
    List<IElementPosition> positionList,
  ) {
    final int? dirtyStart = _fastLayoutDirtyRowIndexStart;
    final int? dirtyEnd = _fastLayoutDirtyRowIndexEnd;
    final int? oldPage = _fastLayoutOldDirtyPage;
    final double? oldTop = _fastLayoutOldDirtyTop;
    final double? oldBottom = _fastLayoutOldDirtyBottom;
    if (!_fastLayoutHeightUnchanged ||
        dirtyStart == null ||
        dirtyEnd == null ||
        dirtyEnd <= dirtyStart ||
        oldPage != pageNo ||
        oldTop == null ||
        oldBottom == null ||
        !oldTop.isFinite ||
        !oldBottom.isFinite ||
        oldBottom <= oldTop ||
        pageNo < 0 ||
        pageNo >= _pageRowList.length ||
        !getZone().isMainActive() ||
        !getIsPagingMode() ||
        _elementList.length <= 1) {
      return null;
    }

    // Elementos que desenham fora das rows (ou cujo visual cruza a página)
    // tornam um clip local ambíguo. O fast path continua correto nesses casos,
    // mas mantém o repaint integral.
    final Position? position = _position as Position?;
    final Area? area = _area as Area?;
    final Search? search = _search as Search?;
    final Control? control = _control as Control?;
    final Graffiti? graffiti = getGraffiti();
    final ImageObserver? imageObserver = _imageObserver as ImageObserver?;
    final String? backgroundImage = _options.background?.image;
    final bool hasWatermark = _options.watermark?.data.isNotEmpty == true &&
        _options.watermark?.opacity != 0;
    if (position == null ||
        position.getFloatPositionList().isNotEmpty ||
        area?.getAreaInfo().isNotEmpty == true ||
        search?.getSearchKeyword()?.isNotEmpty == true ||
        control?.getActiveControl() != null ||
        imageObserver?.hasPending == true ||
        isGraffitiMode() ||
        graffiti?.getValue().isNotEmpty == true ||
        hasWatermark ||
        (backgroundImage != null && backgroundImage.isNotEmpty) ||
        _options.lineNumber?.disabled == false ||
        _options.pageBorder?.disabled == false) {
      return null;
    }

    final List<IRow> pageRows = _pageRowList[pageNo];
    final int firstOffset =
        pageRows.indexWhere((IRow row) => row.rowIndex == dirtyStart);
    if (firstOffset < 0) {
      return null;
    }
    int lastOffset = firstOffset;
    while (lastOffset + 1 < pageRows.length &&
        pageRows[lastOffset + 1].rowIndex < dirtyEnd) {
      lastOffset += 1;
    }
    if (pageRows[lastOffset].rowIndex != dirtyEnd - 1 ||
        lastOffset - firstOffset + 1 != dirtyEnd - dirtyStart) {
      return null;
    }
    final List<IRow> dirtyRows = pageRows.sublist(firstOffset, lastOffset + 1);
    final IRow firstRow = dirtyRows.first;
    final IRow lastRow = dirtyRows.last;
    if (firstRow.elementList.isEmpty || lastRow.elementList.isEmpty) {
      return null;
    }
    final int firstIndex = firstRow.startIndex;
    final int lastIndex = lastRow.startIndex + lastRow.elementList.length - 1;
    if (firstIndex < 0 ||
        lastIndex < firstIndex ||
        lastIndex >= positionList.length) {
      return null;
    }
    final IElementPosition firstPosition = positionList[firstIndex];
    final IElementPosition lastPosition = positionList[lastIndex];
    if (firstPosition.pageNo != pageNo || lastPosition.pageNo != pageNo) {
      return null;
    }
    final double newTop = firstPosition.coordY;
    final double newBottom = lastPosition.coordY + lastPosition.lineHeight;
    if (!newTop.isFinite || !newBottom.isFinite || newBottom <= newTop) {
      return null;
    }

    // Limpa a união das caixas antiga/nova. Horizontalmente o clip cobre toda
    // a largura útil do texto, portanto alinhamento/justificação e overhang de
    // itálico não deixam pixels antigos para trás.
    final double scale = (_options.scale ?? 1).toDouble();
    final double padding = 3 * scale + 1;
    final List<double> margins = getMargins();
    final double canvasWidth = getCanvasWidth(pageNo);
    final double canvasHeight = getCanvasHeight(pageNo);
    final double left = (margins[3] - padding).clamp(0, canvasWidth).toDouble();
    final double right = (margins[3] + getInnerWidth() + padding)
        .clamp(0, canvasWidth)
        .toDouble();
    final double top = (oldTop < newTop ? oldTop : newTop) - padding;
    final double bottom =
        (oldBottom > newBottom ? oldBottom : newBottom) + padding;
    final double clippedTop = top.clamp(0, canvasHeight).toDouble();
    final double clippedBottom = bottom.clamp(0, canvasHeight).toDouble();
    if (right <= left || clippedBottom <= clippedTop) {
      return null;
    }
    return _PartialPageRepaint(
      rowList: dirtyRows,
      clipRect: Rectangle<double>(
        left,
        clippedTop,
        right - left,
        clippedBottom - clippedTop,
      ),
    );
  }

  void _clearPage(int pageNo, {bool clearBlockState = true}) {
    if (pageNo < 0 || pageNo >= _ctxList.length || pageNo >= _pageList.length) {
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
    if (clearBlockState) {
      final BlockParticle? blockParticle = _blockParticle as BlockParticle?;
      blockParticle?.clear();
    }
  }

  void _drawPartialPage(
    IDrawPagePayload payload,
    _PartialPageRepaint repaint,
  ) {
    final int pageNo = payload.pageNo;
    if (pageNo < 0 || pageNo >= _ctxList.length) {
      return;
    }
    final CanvasRenderingContext2D ctx = _ctxList[pageNo];
    final Rectangle<double> clip = repaint.clipRect;
    final Background? background = _background as Background?;
    final Margin? margin = _margin as Margin?;
    final Badge? badge = _badge as Badge?;
    final Zone zone = getZone();
    final double inactiveAlpha = (_options.inactiveAlpha ?? 1).toDouble();

    ctx.save();
    try {
      ctx
        ..beginPath()
        ..rect(clip.left, clip.top, clip.width, clip.height)
        ..clip()
        ..globalAlpha = zone.isMainActive() ? 1 : inactiveAlpha;
      // clearRect respeita o clip. Não limpe BlockParticle: os blocks ficam
      // fora deste fast path textual e seu estado DOM é global ao documento.
      _clearPage(pageNo, clearBlockState: false);
      background?.render(ctx, pageNo);
      // Recompõe uma eventual marca de margem tocada pelo pequeno padding do
      // clip (normalmente as rows ficam inteiramente dentro dela).
      margin?.render(ctx, pageNo);
      drawRow(
        ctx,
        IDrawRowPayload(
          elementList: payload.elementList,
          positionList: payload.positionList,
          rowList: repaint.rowList,
          pageNo: pageNo,
          startIndex: repaint.rowList.first.startIndex,
          innerWidth: getInnerWidth(),
          zone: EditorZone.main,
        ),
      );
      // Main badge pode ser posicionado sobre o corpo; renderizá-lo sob o clip
      // preserva esse caso sem percorrer header/footer e o restante da página.
      badge?.render(ctx, pageNo);
    } finally {
      ctx.restore();
    }
    _partialPageRepaintCount += 1;
    _lastPartialPageRepaintRowCount = repaint.rowList.length;
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
    if (!isPrintMode || _options.modeRule?.print?.backgroundDisabled != true) {
      background?.render(ctx, pageNo);
    }

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
    if (isGraffitiMode()) {
      getGraffiti()?.render(ctx, pageNo);
    }
    ctx.globalAlpha = 1;
  }

  void _disconnectLazyRender() {
    _lazyRenderObserver?.disconnect();
    _lazyRenderObserver = null;
    _observedPageCount = -1;
    _livePages.clear();
    _scrollDrawQueue.clear();
  }

  bool _shouldDrawQueuedScrollPage(int pageIndex) =>
      pageIndex >= 0 &&
      pageIndex < _pageRowList.length &&
      _livePages.contains(pageIndex);

  void _drawQueuedScrollPage(int pageIndex) {
    final Position? position = _position as Position?;
    if (position == null) {
      return;
    }
    final List<IElementPosition> positionList =
        position.getOriginalMainPositionList();
    final List<IElement> elementList = getOriginalMainElementList();
    _drawPage(
      IDrawPagePayload(
        elementList: elementList,
        positionList: positionList,
        rowList: _pageRowList[pageIndex],
        pageNo: pageIndex,
      ),
    );
  }

  /// Mantém/libera o backing store do canvas da página [i] (F5.4a —
  /// virtualização de memória). Um canvas dormente fica 1×1 (bitmap liberado),
  /// mas o tamanho CSS é preservado pelo `_applyPageMetrics`, então a posição
  /// e a barra de rolagem não mudam. Ao voltar a ficar vivo, redimensiona o
  /// backing store e reaplica a transformação de DPR (o resize limpa o canvas,
  /// então quem chama precisa redesenhar).
  void _setPageCanvasLive(int i, bool live) {
    _pageCanvasManager.setPageLive(i, live);
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
    // Caminho LEVE de redraw (perf de digitação): se o observer já existe e a
    // paginação não mudou, não recomputa visibilidade (evita N×
    // getBoundingClientRect, que força reflow do DOM) nem recria o observer —
    // só redesenha as páginas já vivas (a página editada está visível). O
    // scroll continua tratado pelo observer persistente.
    if (_lazyRenderObserver != null &&
        _observedPageCount == _pageList.length &&
        _livePages.isNotEmpty) {
      // Repintura dirigida (P2+): quando o fast path delimitou a mudança,
      // pula as páginas vivas fora da faixa suja (consume-once).
      final int? repaintFrom = _fastRepaintFromPage;
      final int? repaintTo = _fastRepaintToPage;
      _fastRepaintFromPage = null;
      _fastRepaintToPage = null;
      for (final int i in _livePages.toList(growable: false)) {
        if (i >= 0 && i < _pageRowList.length) {
          if (repaintFrom != null && i < repaintFrom) continue;
          if (repaintTo != null && i > repaintTo) continue;
          _setPageCanvasLive(i, true);
          final IDrawPagePayload pagePayload = IDrawPagePayload(
            elementList: elementList,
            positionList: positionList,
            rowList: _pageRowList[i],
            pageNo: i,
          );
          final _PartialPageRepaint? partialRepaint =
              repaintFrom == i && repaintTo == i
                  ? _buildFastPartialPageRepaint(i, positionList)
                  : null;
          if (partialRepaint != null) {
            _drawPartialPage(pagePayload, partialRepaint);
          } else {
            _drawPage(pagePayload);
          }
        }
      }
      return;
    }
    _fastRepaintFromPage = null;
    _fastRepaintToPage = null;
    _disconnectLazyRender();
    // Buffer (~1 viewport) para materializar as páginas um pouco antes de
    // entrarem na tela e só liberar quando já saíram com folga — evita
    // piscar branco em rolagem rápida.
    final int bufferPx = (window.innerHeight ?? 800);
    void handlePage(int pageIndex, bool isIntersecting) {
      if (pageIndex < 0 || pageIndex >= _pageRowList.length) {
        return;
      }
      if (isIntersecting) {
        _livePages.add(pageIndex);
        _setPageCanvasLive(pageIndex, true);
        _drawPage(
          IDrawPagePayload(
            elementList: elementList,
            positionList: positionList,
            rowList: _pageRowList[pageIndex],
            pageNo: pageIndex,
          ),
        );
      } else {
        _livePages.remove(pageIndex);
        _setPageCanvasLive(pageIndex, false);
      }
    }

    final IntersectionObserver observer = IntersectionObserver(
      (entries, observer) {
        for (final IntersectionObserverEntry entry in entries) {
          final double ratio = (entry.intersectionRatio ?? 0).toDouble();
          final bool isIntersecting =
              (entry as dynamic).isIntersecting == true || ratio > 0;
          final Element? target = entry.target;
          if (target == null) {
            continue;
          }
          final String? indexAttr = target.dataset['index'];
          final int? pageIndex =
              indexAttr != null ? int.tryParse(indexAttr) : null;
          if (pageIndex == null) {
            continue;
          }
          // Scroll: enfileira o desenho (fatiado em frames) em vez de desenhar
          // sincronamente — evita travar ao rolar rápido por várias páginas.
          if (isIntersecting) {
            _livePages.add(pageIndex);
            _setPageCanvasLive(pageIndex, true);
            _scrollDrawQueue.enqueue(pageIndex);
          } else {
            _livePages.remove(pageIndex);
            _scrollDrawQueue.remove(pageIndex);
            _setPageCanvasLive(pageIndex, false);
          }
        }
      },
      <String, dynamic>{'rootMargin': '${bufferPx}px 0px ${bufferPx}px 0px'},
    );
    _lazyRenderObserver = observer;
    // Estado inicial síncrono (F5.4a): desenha as páginas atualmente no
    // viewport (± buffer) e libera as demais, para a memória já nascer plana
    // e a 1ª página visível ficar pronta antes de qualquer assert de teste.
    final double viewportBottom =
        (window.innerHeight ?? 800) + bufferPx.toDouble();
    final double viewportTop = -bufferPx.toDouble();
    _livePages.clear();
    for (int i = 0; i < _pageList.length; i++) {
      final CanvasElement page = _pageList[i];
      final Rectangle<num> rect = page.getBoundingClientRect();
      final bool visible =
          rect.bottom > viewportTop && rect.top < viewportBottom;
      handlePage(i, visible);
      observer.observe(page);
    }
    _observedPageCount = _pageList.length;
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
      // Caminho não-lazy (impressão/export/contínuo): todas as páginas vivas.
      _setPageCanvasLive(i, true);
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

  /// Entrada nova para comandos transacionais. O comando declara a mutacao;
  /// Draw apenas traduz a invalidacao para o menor pipeline seguro.
  void renderUpdate(LayoutRequest request) {
    final LayoutInvalidation invalidation = request.invalidation;
    _pendingInvalidation = invalidation;
    render(
      IDrawOption(
        curIndex: request.curIndex,
        isSetCursor: request.setCursor,
        isSubmitHistory: request.submitHistory,
        isSourceHistory: request.sourceHistory,
        notifyContentChange: request.notifyContentChange,
        isCompute: invalidation.needsLayout,
        fastLayoutIndex: invalidation.kind == LayoutInvalidationKind.paragraph
            ? (invalidation.range?.start ?? request.curIndex)
            : null,
      ),
    );
  }

  void render([IDrawOption? option]) {
    if (_historyReplayDepth > 0) {
      _historyReplayRenderOption = option ?? IDrawOption();
      _historyReplayRenderCount += 1;
      return;
    }
    ensureContainerMounted();
    _renderCount += 1;
    final IDrawOption renderOption = option ?? IDrawOption();
    final bool isCompute = renderOption.isCompute ?? true;
    final LayoutInvalidation? invalidation = _pendingInvalidation;
    _pendingInvalidation = null;
    // Um repaint/caret nao muda a verdade do layout e portanto NAO pode
    // cancelar a paginacao pendente. Antes, qualquer clique durante a abertura
    // descartava a continuacao e a edicao seguinte fazia relayout global.
    if (isCompute) {
      _layoutScheduler.cancel();
    }
    // Faixa de repintura dirigida vale só para o render que a produziu.
    _fastRepaintFromPage = null;
    _fastRepaintToPage = null;
    if (invalidation?.isRepaintOnly == true) {
      _setRepaintPagesForElementRange(invalidation?.range);
    }
    final bool isLazy = renderOption.isLazy ?? true;
    final bool isInit = renderOption.isInit ?? false;
    final bool isSubmitHistory = renderOption.isSubmitHistory ?? true;
    final bool isSourceHistory = renderOption.isSourceHistory ?? false;
    final bool notifyContentChange =
        renderOption.notifyContentChange ?? isSubmitHistory || isSourceHistory;
    final bool isSetCursor = renderOption.isSetCursor ?? true;
    final bool isFirstRender = renderOption.isFirstRender ?? false;
    final bool isRowListPrecomputed = renderOption.isRowListPrecomputed == true;
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

    if (debugRenderTiming) {
      _tPhase = window.performance.now();
    }
    if (isCompute) {
      // Fast path de digitação (P2 do plano de otimização, inspirado no
      // Recalculate_FastWholeParagraph do OnlyOffice): recomputa só as rows do
      // parágrafo editado e reusa todas as outras. Precisa rodar ANTES do
      // reset de floatPositionList (usa a lista como guarda).
      bool fastLayoutDone = isRowListPrecomputed;
      _fastLayoutDirtyRowIndexStart = null;
      _fastLayoutDirtyRowIndexEnd = null;
      _fastLayoutHeightUnchanged = false;
      _fastLayoutOldDirtyPage = null;
      _fastLayoutOldDirtyTop = null;
      _fastLayoutOldDirtyBottom = null;
      if (!fastLayoutDone &&
          renderOption.fastLayoutIndex != null &&
          !isSourceHistory) {
        fastLayoutDone = _tryFastParagraphLayout(
          renderOption.fastLayoutIndex!,
          range: invalidation?.kind == LayoutInvalidationKind.paragraph
              ? invalidation?.range
              : null,
        );
      }
      if (fastLayoutDone) {
        _lastLayoutMode = isRowListPrecomputed ? 'precomputed' : 'text-range';
        if (!isRowListPrecomputed) {
          _fastTextLayoutCount += 1;
        }
      } else {
        _lastLayoutMode = 'full';
        _fullLayoutCount += 1;
      }
      position?.setFloatPositionList(<IFloatPosition>[]);
      if (!fastLayoutDone) {
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
        final IComputeRowListPayload rowPayload = IComputeRowListPayload(
          startX: margins[3],
          startY: margins[0] + extraHeight,
          pageHeight: pageHeight,
          mainOuterHeight: mainOuterHeight,
          isPagingMode: isPagingMode,
          innerWidth: innerWidth,
          surroundElementList: surroundElementList,
          elementList: _elementList,
        );
        // Layout fatiado (F5.5): na abertura de docs grandes, a 1ª fatia é
        // síncrona (viewport + folga) e o resto pagina em ticks de Timer, para
        // a UI não travar. Edições usam o fast path; demais renders são
        // completos como antes.
        final bool useProgressive = isFirstRender &&
            isPagingMode &&
            _mode != EditorMode.print &&
            _elementList.length > _progressiveMinElements;
        if (useProgressive) {
          final _RowLayoutState state = _RowLayoutState()
            ..budgetRows = _progressiveFirstChunkRows;
          final List<IRow> firstChunk =
              computeRowList(rowPayload, resume: state);
          _rowList
            ..clear()
            ..addAll(firstChunk);
          if (!state.done) {
            _startProgressiveLayout(state, rowPayload);
          }
        } else {
          final List<IRow> computedRows = computeRowList(rowPayload);
          _rowList
            ..clear()
            ..addAll(computedRows);
        }
      }
      if (debugRenderTiming && !fastLayoutDone) {
        window.console.log('[render] computeRowList: '
            '${(window.performance.now() - _tPhase).toStringAsFixed(0)}ms '
            'rows=${_rowList.length}');
        _tPhase = window.performance.now();
      }
      final int? paginationDirtyRowStart =
          fastLayoutDone ? _fastLayoutDirtyRowIndexStart : null;
      final bool canRepaginateLocally = paginationDirtyRowStart != null &&
          isPagingMode &&
          (_options.pageMode ?? PageMode.paging) == PageMode.paging &&
          _options.pageNumber?.maxPageNo == null &&
          _pageRowList.isNotEmpty;
      final List<List<IRow>> pageRows;
      if (canRepaginateLocally) {
        final PageRowAggregation aggregation = PageRowIndex.repaginateFromRow(
          rows: _rowList,
          previousPages: _pageRowList,
          dirtyRowIndex: paginationDirtyRowStart,
          pageHeight: getHeight(),
          marginHeight: getMainOuterHeight(),
        );
        pageRows = aggregation.pages;
        _lastPaginationInspectedRowCount = aggregation.inspectedRowCount;
        _lastPaginationReusedPageCount = aggregation.reusedPrefixPageCount +
            aggregation.reusedSuffixPageCount;
      } else {
        pageRows = _computePageList();
        _lastPaginationInspectedRowCount = _rowList.length;
        _lastPaginationReusedPageCount = 0;
      }
      _pageRowList
        ..clear()
        ..addAll(pageRows);
      // Repintura dirigida (P2+): mapeia a faixa de rows recomputadas pelo
      // fast path para páginas. Altura idêntica → só as páginas da faixa;
      // altura mudou → da 1ª página da faixa em diante (nada ACIMA muda).
      _fastRepaintFromPage = null;
      _fastRepaintToPage = null;
      final int? dirtyRowStart = paginationDirtyRowStart;
      final int? dirtyRowEnd = _fastLayoutDirtyRowIndexEnd;
      // Busca ativa: highlights de outras páginas podem mudar com a edição —
      // sem repintura dirigida nesse caso.
      final bool searchActive = search?.getSearchKeyword()?.isNotEmpty == true;
      if (fastLayoutDone &&
          !searchActive &&
          dirtyRowStart != null &&
          dirtyRowEnd != null) {
        int? fromPage;
        int? toPage;
        for (int p = 0; p < _pageRowList.length; p++) {
          final List<IRow> rowsOfPage = _pageRowList[p];
          if (rowsOfPage.isEmpty) continue;
          final int first = rowsOfPage.first.rowIndex;
          final int last = rowsOfPage.last.rowIndex;
          if (last >= dirtyRowStart && fromPage == null) fromPage = p;
          if (first < dirtyRowEnd) toPage = p;
          if (first >= dirtyRowEnd) break;
        }
        if (fromPage != null) {
          _fastRepaintFromPage = fromPage;
          if (_fastLayoutHeightUnchanged && toPage != null) {
            _fastRepaintToPage = toPage;
          }
        }
      }
      // Enquanto a paginação progressiva não termina, `_rowList` é parcial —
      // 0 desabilita o fast path de edição (que assume o layout completo);
      // uma edição durante a paginação cai no relayout completo (correto).
      _computedElementCount = _layoutScheduler.hasJob ? 0 : _elementList.length;
      if (debugRenderTiming) {
        window.console.log('[render] computePageList: '
            '${(window.performance.now() - _tPhase).toStringAsFixed(0)}ms '
            'pages=${_pageRowList.length}');
        _tPhase = window.performance.now();
      }
      position?.computePositionList();
      if (debugRenderTiming) {
        window.console.log('[render] computePositionList: '
            '${(window.performance.now() - _tPhase).toStringAsFixed(0)}ms');
        _tPhase = window.performance.now();
      }
      // Se o mapa ficou vazio após o último layout completo, uma mutação que
      // passou pelo fast path textual não pode ter criado uma Area (a guarda
      // do slice rejeita areaId). Evita scan global de todos os elementos por
      // tecla nos DOCX comuns sem áreas.
      if (!fastLayoutDone || area?.getAreaInfo().isNotEmpty == true) {
        area?.compute();
      }
      if (isGraffitiMode()) {
        getGraffiti()?.compute();
      }
      if (_mode != EditorMode.print) {
        final String? keyword = search?.getSearchKeyword();
        if (keyword != null && keyword.isNotEmpty) {
          search?.compute(keyword);
        }
        control?.computeHighlightList();
      }
    } else {
      _syncCachedRowElementsForFastRender();
    }

    final ImageObserver? imageObserver = _imageObserver as ImageObserver?;
    imageObserver?.clearAll();
    final Cursor? cursor = _cursor as Cursor?;
    cursor?.recoveryCursor();

    if (debugRenderTiming) {
      window.console.log('[render] compute-tail(area/search/etc): '
          '${(window.performance.now() - _tPhase).toStringAsFixed(0)}ms');
      _tPhase = window.performance.now();
    }
    _syncPageCanvases();
    if (debugRenderTiming) {
      window.console.log('[render] syncPageCanvases: '
          '${(window.performance.now() - _tPhase).toStringAsFixed(0)}ms');
      _tPhase = window.performance.now();
    }

    if (isLazy && isPagingMode) {
      _lazyRender();
    } else {
      _disconnectLazyRender();
      _immediateRender();
    }
    if (debugRenderTiming) {
      window.console.log('[render] draw(lazy/immediate): '
          '${(window.performance.now() - _tPhase).toStringAsFixed(0)}ms');
      _tPhase = window.performance.now();
    }

    if (isSetCursor) {
      curIndex = setCursor(curIndex);
    } else if (rangeManager?.getIsSelection() == true) {
      cursor?.focus();
    }

    final HistoryManager? historyManager = _historyManager as HistoryManager?;
    final bool isHistoryStackEmpty = historyManager?.isStackEmpty() ?? false;
    // O baseline absoluto precisa existir antes da primeira interação. Em docs
    // grandes, adiá-lo até o primeiro clique fazia `submitHistory` clonar todo
    // o documento dentro do caminho de foco/cursor (uma pausa visível de ~1 s).
    // `isFirstRender` só é usado pelo construtor e por `setValue`; este último
    // limpa a timeline antes de renderizar. O clone passa, portanto, a fazer
    // parte deterministicamente da abertura/troca do documento. A condição de
    // `curIndex` continua como fallback caso um primeiro render sem largura
    // tenha retornado antes de chegar aqui.
    final bool needsInitialHistoryBaseline =
        isFirstRender && isHistoryStackEmpty;
    if (needsInitialHistoryBaseline ||
        (isSubmitHistory && !isFirstRender) ||
        (curIndex != null && isHistoryStackEmpty)) {
      final bool deferHistory =
          (renderOption.isSubmitHistoryDeferred ?? false) &&
              !isHistoryStackEmpty;
      submitHistory(curIndex, deferHistory);
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
      // Moldura tracejada + label "Cabeçalho"/"Rodapé": mantida viva em
      // QUALQUER render enquanto a zona não-main está ativa (as edições da
      // caixa de texto renderizam com isCompute:false).
      if (_mode != EditorMode.print && !getZone().isMainActive()) {
        getZone().drawZoneIndicator();
      }
      if (oldPageSize != _pageRowList.length) {
        _listener?.pageSizeChange?.call(_pageRowList.length);
        if (_eventBus?.isSubscribe?.call('pageSizeChange') == true) {
          _eventBus.emit('pageSizeChange', _pageRowList.length);
        }
      }
      if (notifyContentChange && !isInit) {
        _listener?.contentChange?.call();
        if (_eventBus?.isSubscribe?.call('contentChange') == true) {
          _eventBus.emit('contentChange');
        }
      }
    });

    if (debugRenderTiming) {
      window.console.log('[render] post(cursor/história): '
          '${(window.performance.now() - _tPhase).toStringAsFixed(0)}ms');
    }

    if (_renewTextHistoryTimerAfterRender && _textHistoryBurst != null) {
      _renewTextHistoryTimerAfterRender = false;
      _textHistoryTimer?.cancel();
      _textHistoryTimer = Timer(_deferredHistoryDelay, _closeTextHistoryBurst);
    }

    // F5.5/Kix: se a 1ª fatia não cobriu o documento inteiro, fica pendente.
    // O ScrollObserver chamará ensureProgressiveLayoutForPage ao se aproximar
    // do fim conhecido, fazendo o total de páginas crescer sob demanda.
    // O scheduler nasce pausado sem alvo; ScrollObserver o retoma quando a
    // viewport chega perto do fim conhecido.
  }

  void _setRepaintPagesForElementRange(DocumentRange? range) {
    if (range == null) {
      return;
    }
    final Position? position = _position as Position?;
    final List<IElementPosition>? positions =
        position?.getOriginalMainPositionList();
    if (positions == null || positions.isEmpty) {
      return;
    }

    IElementPosition? atOrAfter(int index) {
      int low = 0;
      int high = positions.length;
      while (low < high) {
        final int mid = low + ((high - low) >> 1);
        if (positions[mid].index < index) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      return low < positions.length ? positions[low] : null;
    }

    IElementPosition? atOrBefore(int index) {
      int low = 0;
      int high = positions.length;
      while (low < high) {
        final int mid = low + ((high - low) >> 1);
        if (positions[mid].index <= index) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      return low > 0 ? positions[low - 1] : null;
    }

    final IElementPosition? first = atOrAfter(range.start);
    final IElementPosition? last = atOrBefore(range.end);
    if (first == null || last == null || first.pageNo > last.pageNo) {
      return;
    }
    _fastRepaintFromPage = first.pageNo;
    _fastRepaintToPage = last.pageNo;
  }

  void _startProgressiveLayout(
    _RowLayoutState state,
    IComputeRowListPayload payload,
  ) {
    state.publishedRowCount = _rowList.length;
    _layoutScheduler.start(
      continuation: _ProgressiveLayoutContinuation(
        state: state,
        payload: payload,
      ),
      step: _runProgressiveLayoutSlice,
      onComplete: _completeProgressiveLayout,
      onError: (Object error, StackTrace stackTrace) {
        window.console.error(
          '[layout] progressive job failed: $error\n$stackTrace',
        );
      },
    );
  }

  LayoutStepResult<_ProgressiveLayoutContinuation> _runProgressiveLayoutSlice(
    LayoutSlice<_ProgressiveLayoutContinuation, int> slice,
  ) {
    final _ProgressiveLayoutContinuation? continuation = slice.continuation;
    if (continuation == null) {
      return const LayoutStepResult<_ProgressiveLayoutContinuation>.complete();
    }
    final int? targetPage = slice.target;
    if (targetPage == null) {
      return LayoutStepResult<_ProgressiveLayoutContinuation>(
        continuation: continuation,
        targetReached: true,
      );
    }
    if (_pageRowList.length > targetPage) {
      return LayoutStepResult<_ProgressiveLayoutContinuation>(
        continuation: continuation,
        targetReached: true,
      );
    }

    final _RowLayoutState state = continuation.state;
    state
      ..budgetRows = 1 << 30
      ..shouldYield = () => slice.shouldYield;
    final List<IRow> rows = computeRowList(
      continuation.payload,
      resume: state,
    );
    state.shouldYield = null;
    final bool complete = state.done;
    final bool targetReached = !complete && state.pageNo >= targetPage;
    final int fromRowIndex = state.publishedRowCount;
    void commit() {
      _publishProgressiveRows(
        rows,
        fromRowIndex: fromRowIndex,
        complete: complete,
      );
      state.publishedRowCount = rows.length;
    }

    if (complete) {
      return LayoutStepResult<_ProgressiveLayoutContinuation>.complete(
        commit: commit,
      );
    }
    return LayoutStepResult<_ProgressiveLayoutContinuation>(
      continuation: continuation,
      commit: commit,
      targetReached: targetReached,
    );
  }

  void _publishProgressiveRows(
    List<IRow> rows, {
    required int fromRowIndex,
    required bool complete,
  }) {
    final int oldPageCount = _pageRowList.length;
    if (fromRowIndex < 0 ||
        fromRowIndex > rows.length ||
        fromRowIndex > _rowList.length) {
      _rowList
        ..clear()
        ..addAll(rows);
      fromRowIndex = 0;
    } else {
      if (_rowList.length > fromRowIndex) {
        _rowList.removeRange(fromRowIndex, _rowList.length);
      }
      _rowList.addAll(rows.getRange(fromRowIndex, rows.length));
    }

    final bool canAppendPages = fromRowIndex > 0 &&
        getIsPagingMode() &&
        (_options.pageMode ?? PageMode.paging) == PageMode.paging &&
        _options.pageNumber?.maxPageNo == null;
    final List<List<IRow>> pageRows;
    if (canAppendPages) {
      final PageRowAggregation aggregation = PageRowIndex.append(
        rows: _rowList,
        previousPages: _pageRowList,
        pageHeight: getHeight(),
        marginHeight: getMainOuterHeight(),
      );
      pageRows = aggregation.pages;
      _lastPaginationInspectedRowCount = aggregation.inspectedRowCount;
      _lastPaginationReusedPageCount = aggregation.reusedPrefixPageCount;
    } else {
      pageRows = _computePageList();
      _lastPaginationInspectedRowCount = _rowList.length;
      _lastPaginationReusedPageCount = 0;
    }
    _pageRowList
      ..clear()
      ..addAll(pageRows);
    _computedElementCount = complete ? _elementList.length : 0;
    (_position as Position?)?.computePositionList();
    _syncPageCanvases();
    if (getIsPagingMode()) {
      _lazyRender();
    } else {
      _immediateRender();
    }
    if (oldPageCount != _pageRowList.length) {
      _listener?.pageSizeChange?.call(_pageRowList.length);
      if (_eventBus?.isSubscribe?.call('pageSizeChange') == true) {
        _eventBus.emit('pageSizeChange', _pageRowList.length);
      }
    }
  }

  void _completeProgressiveLayout() {
    (_area as Area?)?.compute();
    if (_mode != EditorMode.print) {
      final Search? search = _search as Search?;
      final String? keyword = search?.getSearchKeyword();
      if (keyword != null && keyword.isNotEmpty) {
        search?.compute(keyword);
      }
      (_control as Control?)?.computeHighlightList();
    }
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
          if (tdIndex != null && tdIndex >= 0 && tdIndex < tdList.length) {
            final ITd td = tdList[tdIndex];
            final List<IElementPosition>? tablePositionList = td.positionList;
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
      if (curIndex != null && curIndex >= 0 && curIndex < positionList.length) {
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
          final IElementPosition? cursorPosition = position.getCursorPosition();
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

  /// Aplica tamanho de página e margens SEM disparar render (plano de
  /// otimização A5). Usado pelo fluxo de abertura de DOCX para configurar a
  /// geometria antes do `setValue`, que faz o único render da abertura —
  /// `setPaperSize` + `setPaperMargin` custariam dois relayouts completos
  /// do documento anterior.
  void setPaperOptionsSilently({
    double? width,
    double? height,
    IMargin? margins,
  }) {
    if (width != null && height != null && width > 0 && height > 0) {
      _options.width = width;
      _options.height = height;
      _formatContainer();
      _applyPageMetrics();
    }
    if (margins != null) {
      _options.margins = List<double>.from(margins);
    }
  }

  // ---------------------------------------------------------------------------
  // Object graph setters for yet-to-be-ported modules
  // ---------------------------------------------------------------------------

  void attachHistoryManager(dynamic historyManager) =>
      _historyManager = historyManager;

  void attachRangeManager(dynamic rangeManager) => _rangeManager = rangeManager;

  void attachPosition(dynamic position) => _position = position;

  void attachCursor(dynamic cursor) => _cursor = cursor;

  void attachCanvasEvent(dynamic canvasEvent) => _canvasEvent = canvasEvent;

  void attachGlobalEvent(dynamic globalEvent) => _globalEvent = globalEvent;

  void attachPreviewer(dynamic previewer) => _previewer = previewer;

  void attachTableTool(dynamic tableTool) => _tableTool = tableTool;

  void attachTableParticle(dynamic tableParticle) =>
      _tableParticle = tableParticle;

  void attachTableOperate(dynamic tableOperate) => _tableOperate = tableOperate;

  void attachHyperlinkParticle(dynamic hyperlinkParticle) =>
      _hyperlinkParticle = hyperlinkParticle;

  void attachSearch(dynamic search) => _search = search;

  void attachControl(dynamic control) => _control = control;

  void attachDateParticle(dynamic dateParticle) => _dateParticle = dateParticle;

  void attachImageObserver(dynamic imageObserver) =>
      _imageObserver = imageObserver;

  void attachImageParticle(dynamic imageParticle) =>
      _imageParticle = imageParticle;

  void attachCheckboxParticle(dynamic checkboxParticle) =>
      _checkboxParticle = checkboxParticle;

  void attachListParticle(dynamic listParticle) => _listParticle = listParticle;

  void attachRadioParticle(dynamic radioParticle) =>
      _radioParticle = radioParticle;

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

  dynamic getWhiteSpaceParticle() => _whiteSpaceParticle;
  dynamic getLabelParticle() => _labelParticle;
  dynamic getLineBreakParticle() => _lineBreakParticle;
  dynamic getHyperlinkParticle() => _hyperlinkParticle;
  TextBoxTool? getTextBoxTool() => _textBoxTool;
  dynamic getSearch() => _search;
  dynamic getGroup() => _group;
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
    _textBoxTool?.clear();
    (_dateParticle as DateParticle?)?.clearDatePicker();
  }

  /// Navega até um bookmark interno (alvo `#nome` de hyperlink interno/TOC):
  /// procura o elemento marcado na conversão DOCX com
  /// `extension['bookmarks']` contendo [name], posiciona o cursor nele e
  /// rola a viewport (mesma mecânica do locationCatalog). Retorna `false`
  /// quando o bookmark não existe no documento.
  bool locationBookmark(String name) {
    // O alvo pode estar além da fronteira da paginação sob demanda.
    finishProgressiveLayout();
    final List<IElement> elementList =
        (getOriginalElementList() as List).cast<IElement>();

    bool hasBookmark(IElement element) {
      final dynamic extension = element.extension;
      if (extension is! Map) return false;
      final dynamic bookmarks = extension['bookmarks'];
      return bookmarks is List && bookmarks.contains(name);
    }

    Map<String, dynamic>? locate(List<IElement> list) {
      for (var e = 0; e < list.length; e++) {
        final IElement element = list[e];
        if (element.type == ElementType.table) {
          final List<ITr>? trList = element.trList;
          if (trList != null) {
            for (var r = 0; r < trList.length; r++) {
              final tdList = trList[r].tdList;
              for (var d = 0; d < tdList.length; d++) {
                final Map<String, dynamic>? inner = locate(tdList[d].value);
                if (inner != null) {
                  inner['isTable'] = true;
                  inner['index'] = e;
                  inner['trIndex'] = r;
                  inner['tdIndex'] = d;
                  inner['tdId'] = tdList[d].id;
                  inner['trId'] = trList[r].id;
                  inner['tableId'] = element.id;
                  return inner;
                }
              }
            }
          }
        }
        if (hasBookmark(element)) {
          return <String, dynamic>{'isTable': false, 'endIndex': e};
        }
      }
      return null;
    }

    final Map<String, dynamic>? context = locate(elementList);
    if (context == null) return false;
    final Position? position = _position as Position?;
    final RangeManager? rangeManager = _rangeManager as RangeManager?;
    if (position == null || rangeManager == null) return false;
    final bool isTable = context['isTable'] == true;
    final int endIndex = context['endIndex'] as int;
    position.setPositionContext(IPositionContext(
      isTable: isTable,
      index: context['index'] as int?,
      trIndex: context['trIndex'] as int?,
      tdIndex: context['tdIndex'] as int?,
      tdId: context['tdId'] as String?,
      trId: context['trId'] as String?,
      tableId: context['tableId'] as String?,
    ));
    rangeManager.setRange(endIndex, endIndex, context['tableId'] as String?,
        null, null, null, null);
    render(IDrawOption(
      curIndex: endIndex,
      isSetCursor: true,
      isCompute: false,
      isSubmitHistory: false,
    ));
    final List<dynamic> positionList =
        position.getPositionList() as List<dynamic>;
    if (endIndex >= 0 && endIndex < positionList.length) {
      final dynamic cursorPosition = positionList[endIndex];
      if (cursorPosition is IElementPosition) {
        position.setCursorPosition(cursorPosition);
        final dynamic cursor = _cursor;
        try {
          cursor?.moveCursorToVisible(IMoveCursorToVisibleOption(
            cursorPosition: cursorPosition,
            direction: MoveDirection.down,
          ));
        } catch (_) {}
      }
    }
    return true;
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

  void _applyPageMetrics({bool updateStyles = true}) {
    _pageCanvasManager.applyPageMetrics(updateStyles: updateStyles);
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

  List<IElement>? _castElementListFromDynamic(dynamic source) {
    if (source == null) {
      return null;
    }
    if (source is List<IElement>) {
      return element_utils.cloneElementList(source);
    }
    if (source is List) {
      final List<IElement> list = source.whereType<IElement>().toList();
      return element_utils.cloneElementList(list);
    }
    return null;
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
    _pageCanvasManager.createPage(index);
  }

  HistoryViewState captureHistoryViewState() {
    final Position position = _position as Position;
    final RangeManager rangeManager = _rangeManager as RangeManager;
    return HistoryViewState(
      zone: getZone().getZone(),
      positionContext: _clonePositionContext(position.getPositionContext()),
      range: _cloneRange(rangeManager.getRange()),
      pageNo: _pageNo,
    );
  }

  void restoreHistoryViewState(HistoryViewState state) {
    getZone().setZone(state.zone);
    setPageNo(state.pageNo);
    (_position as Position).setPositionContext(
      _clonePositionContext(state.positionContext),
    );
    (_rangeManager as RangeManager).replaceRange(_cloneRange(state.range));
  }

  void _syncPageCanvases() {
    final int desiredPageCount = _pageRowList.isEmpty ? 1 : _pageRowList.length;
    _pageNo = _pageCanvasManager.syncPageCount(desiredPageCount, _pageNo);
  }

  static RegExp? _buildLetterReg(List<String>? letterClass) {
    if (letterClass == null || letterClass.isEmpty) {
      return null;
    }
    final String joined = letterClass.join();
    return RegExp('[$joined]');
  }

  /// Altura de linha "single" do Word em `em` por família (ascent+descent do
  /// TTF). Interino até o ce_fonts medir as tabelas hhea/OS2 (F4.10).
  static const Map<String, double> _singleLineFactorByFont = <String, double>{
    'times new roman': 1.15,
    'arial': 1.15,
    'calibri': 1.22,
    'cambria': 1.17,
    'courier new': 1.13,
    'verdana': 1.21,
    'tahoma': 1.21,
  };

  /// Classe de "letra" para word-break (F4.3): inclui A-Z, a-z E os acentos
  /// latinos (0xC0-0x24F: à á â ã ç é ê í ó ô õ ú etc.). Sem os acentos, o
  /// `[A-Za-z]` quebrava palavras em português no meio ("Implanta|ção"),
  /// porque a medição de palavra parava no 1º caractere acentuado.
  static final RegExp _defaultLetterReg = RegExp('[A-Za-zÀ-ɏ]');

  static const double _defaultOriginalWidth = 794; // px ~ A4 portrait (210mm)
  static const double _defaultOriginalHeight = 1123; // px ~ A4 portrait (297mm)
  static const double _defaultPageGap = 20;
  static const List<double> _defaultMargins = <double>[96, 96, 96, 96];
  static const double _defaultMarginIndicatorSize = 35;
  static const double _defaultPageNumberBottom = 60;
}

/// Cursor de continuação do layout fatiado (F5.5, modelo OnlyOffice). Guarda o
/// estado do laço de `computeRowList` para retomar de onde parou entre ticks:
/// índice do elemento, x/y (relativos à página), página, estado de lista e a
/// lista de rows acumulada. `budgetRows` limita quantas rows uma fatia produz
/// antes de ceder o thread.
class _RowLayoutState {
  final List<IRow> rowList = <IRow>[];
  int i = 0;
  double x = 0;
  double y = 0;
  int pageNo = 0;
  int listIndex = 0;
  String? listId;
  double controlRealWidth = 0;
  int budgetRows = 1 << 30;
  int publishedRowCount = 0;
  bool Function()? shouldYield;
  bool started = false;
  bool done = false;
}

class _ProgressiveLayoutContinuation {
  const _ProgressiveLayoutContinuation({
    required this.state,
    required this.payload,
  });

  final _RowLayoutState state;
  final IComputeRowListPayload payload;
}

class _PartialPageRepaint {
  const _PartialPageRepaint({
    required this.rowList,
    required this.clipRect,
  });

  final List<IRow> rowList;
  final Rectangle<double> clipRect;
}

class _InsertDeltaHistory {
  _InsertDeltaHistory({
    required this.insertStart,
    required this.elementList,
    required this.removedSnapshot,
    required this.insertedSnapshot,
    required this.beforeViewState,
    required this.isFastLayout,
  });

  final int insertStart;
  final List<IElement> elementList;
  final List<IElement> removedSnapshot;
  final List<IElement> insertedSnapshot;
  final HistoryViewState beforeViewState;
  final bool isFastLayout;
  HistoryViewState? afterViewState;
  int? afterCurIndex;
}

class _ElementRangeDeltaHistory {
  _ElementRangeDeltaHistory({
    required this.start,
    required this.deleteCount,
    required this.elementList,
    required this.removedSnapshot,
    required this.removedRows,
    required this.rowStart,
    required this.beforeViewState,
    required this.beforeCurIndex,
    this.afterCurIndex,
  });

  final int start;
  final int deleteCount;
  final List<IElement> elementList;
  final List<IElement> removedSnapshot;
  final List<IRow> removedRows;
  final int rowStart;
  final HistoryViewState beforeViewState;
  final int beforeCurIndex;
  int? afterCurIndex;
  HistoryViewState? afterViewState;
}

class _TextHistoryBurst {
  _TextHistoryBurst({
    required this.elementList,
    required this.transaction,
    required this.beforeViewState,
    required this.afterViewState,
    required this.curIndex,
  });

  final List<IElement> elementList;
  final DocumentTransaction transaction;
  final HistoryViewState beforeViewState;
  HistoryViewState afterViewState;
  int curIndex;
}
