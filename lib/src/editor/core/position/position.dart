import 'dart:collection';

import '../../dataset/constant/common.dart';
import '../../dataset/enum/common.dart';
import '../../dataset/enum/control.dart';
import '../../dataset/enum/editor.dart';
import '../../dataset/enum/element.dart';
import '../../dataset/enum/list.dart';
import '../../dataset/enum/row.dart';
import '../../dataset/enum/vertical_align.dart';
import '../../interface/editor.dart';
import '../../interface/element.dart';
import '../../interface/position.dart';
import '../../interface/range.dart';
import '../../interface/row.dart';
import '../../interface/table/td.dart';
import '../../utils/element.dart' as element_utils;
import '../../utils/index.dart' show isRectIntersect;
import 'page_position_index.dart';

class Position {
  Position(dynamic drawInstance)
      : draw = drawInstance,
        eventBus = drawInstance.getEventBus(),
        options = drawInstance.getOptions() as IEditorOption,
        positionList = <IElementPosition>[],
        floatPositionList = <IFloatPosition>[],
        cursorPosition = null,
        positionContext = IPositionContext(isTable: false);

  final dynamic draw;
  final dynamic eventBus;
  final IEditorOption options;

  IElementPosition? cursorPosition;
  IPositionContext positionContext;
  List<IElementPosition> positionList;
  List<IFloatPosition> floatPositionList;

  // Indice derivado sobre positionList. A lista global continua sendo a fonte
  // de verdade para preservar todos os consumidores/indexes existentes.
  final PagePositionIndex _pagePositionIndex = PagePositionIndex();
  Map<int, List<IFloatPosition>> _floatPositionsByPage =
      <int, List<IFloatPosition>>{};
  List<IFloatPosition>? _indexedFloatPositionSource;
  int _indexedFloatPositionLength = 0;

  // Diagnosticos baratos para testes/regressoes de performance.
  bool _lastHitTestUsedPageIndex = false;
  int _lastHitTestCandidateCount = 0;
  int _lastHitTestInspectedPositionCount = 0;
  bool _lastFloatHitTestUsedPageIndex = false;
  int _lastFloatHitTestCandidateCount = 0;

  bool get lastHitTestUsedPageIndex => _lastHitTestUsedPageIndex;
  int get lastHitTestCandidateCount => _lastHitTestCandidateCount;
  int get lastHitTestInspectedPositionCount =>
      _lastHitTestInspectedPositionCount;
  bool get lastFloatHitTestUsedPageIndex => _lastFloatHitTestUsedPageIndex;
  int get lastFloatHitTestCandidateCount => _lastFloatHitTestCandidateCount;

  // Cache de posições POR PÁGINA (perf de digitação): guarda, do último
  // computePositionList, as rows e as posições de cada página. Como cada página
  // começa sempre no mesmo startY, uma página cujas rows são as MESMAS (por
  // referência — o fast path de edição reusa os objetos de row) tem posições
  // idênticas; só o campo `index` (índice do elemento) desloca ao inserir/
  // remover char. Reusa as posições e corrige só o index (barato) em vez de
  // recomputar coordenadas (caro). Páginas com float não entram no cache.
  List<List<IRow>> _cachedPageRows = <List<IRow>>[];
  List<List<IElementPosition>> _cachedPagePositions =
      <List<IElementPosition>>[];
  List<bool> _cachedPageReusable = <bool>[];
  List<IElementPositionAnchor?> _cachedPageAnchors =
      <IElementPositionAnchor?>[];
  double _cachedStartY = double.nan;
  double _cachedInnerWidth = double.nan;

  int _lastRecomputedPageCount = 0;
  int _lastRebasedPageCount = 0;
  int _lastFlattenedPositionCount = 0;

  int get lastRecomputedPageCount => _lastRecomputedPageCount;
  int get lastRebasedPageCount => _lastRebasedPageCount;
  int get lastFlattenedPositionCount => _lastFlattenedPositionCount;

  /// Invalida o cache de posições por página (chamar quando o layout muda de
  /// forma não incremental — ex.: relayout completo, novo documento).
  void invalidatePositionCache() {
    _cachedPageRows = <List<IRow>>[];
    _cachedPagePositions = <List<IElementPosition>>[];
    _cachedPageReusable = <bool>[];
    _cachedPageAnchors = <IElementPositionAnchor?>[];
  }

  List<IFloatPosition> getFloatPositionList() {
    return floatPositionList;
  }

  List<IElementPosition> getTablePositionList(
      List<IElement> sourceElementList) {
    final int? index = positionContext.index;
    final int? trIndex = positionContext.trIndex;
    final int? tdIndex = positionContext.tdIndex;
    if (index == null || trIndex == null || tdIndex == null) {
      return <IElementPosition>[];
    }
    if (index < 0 || index >= sourceElementList.length) {
      return <IElementPosition>[];
    }
    final IElement tableElement = sourceElementList[index];
    final List<ITr>? trList = tableElement.trList;
    if (trList == null || trIndex < 0 || trIndex >= trList.length) {
      return <IElementPosition>[];
    }
    final ITr tr = trList[trIndex];
    final List<ITd> tdList = tr.tdList;
    if (tdIndex < 0 || tdIndex >= tdList.length) {
      return <IElementPosition>[];
    }
    return tdList[tdIndex].positionList ?? <IElementPosition>[];
  }

  List<IElementPosition> getPositionList() {
    if (positionContext.isTable) {
      return getTablePositionList(draw.getOriginalElementList());
    }
    return getOriginalPositionList();
  }

  List<IElementPosition> getMainPositionList() {
    if (positionContext.isTable) {
      return getTablePositionList(draw.getOriginalMainElementList());
    }
    return positionList;
  }

  List<IElementPosition> getOriginalPositionList() {
    final dynamic zoneManager = draw.getZone();
    if (zoneManager.isHeaderActive() == true) {
      final dynamic header = draw.getHeader();
      return (header.getPositionList() as List<dynamic>)
          .whereType<IElementPosition>()
          .toList();
    }
    if (zoneManager.isFooterActive() == true) {
      final dynamic footer = draw.getFooter();
      return (footer.getPositionList() as List<dynamic>)
          .whereType<IElementPosition>()
          .toList();
    }
    return positionList;
  }

  List<IElementPosition> getOriginalMainPositionList() {
    return positionList;
  }

  List<IElementPosition>? getSelectionPositionList() {
    final IRange range = draw.getRange().getRange();
    if (range.startIndex == range.endIndex) {
      return null;
    }
    final List<IElementPosition> list = getPositionList();
    final int from = range.startIndex + 1;
    final int to = range.endIndex + 1;
    if (from < 0 || to > list.length) {
      return null;
    }
    return list.sublist(from, to);
  }

  void setPositionList(List<IElementPosition> payload) {
    positionList = payload;
    invalidatePositionCache();
    _pagePositionIndex.rebuild(positionList);
  }

  void setFloatPositionList(List<IFloatPosition> payload) {
    floatPositionList = payload;
    _rebuildFloatPositionIndex();
  }

  void _rebuildFloatPositionIndex() {
    final Map<int, List<IFloatPosition>> next = <int, List<IFloatPosition>>{};
    for (final IFloatPosition floatPosition in floatPositionList) {
      next
          .putIfAbsent(floatPosition.pageNo, () => <IFloatPosition>[])
          .add(floatPosition);
    }
    _floatPositionsByPage = next;
    _indexedFloatPositionSource = floatPositionList;
    _indexedFloatPositionLength = floatPositionList.length;
  }

  List<IFloatPosition> _getFloatPositionsForPage(int pageNo) {
    final bool canUseIndex =
        identical(floatPositionList, _indexedFloatPositionSource) &&
            floatPositionList.length == _indexedFloatPositionLength;
    _lastFloatHitTestUsedPageIndex = canUseIndex;
    if (canUseIndex) {
      return _floatPositionsByPage[pageNo] ?? const <IFloatPosition>[];
    }
    return floatPositionList;
  }

  IComputePageRowPositionResult computePageRowPosition(
      IComputePageRowPositionPayload payload) {
    final List<IElementPosition> targetPositionList = payload.positionList;
    final List<IRow> rowList = payload.rowList;
    final int pageNo = payload.pageNo;
    final double innerWidth = payload.innerWidth;
    final double startX = payload.startX;
    final double startY = payload.startY;
    final int startRowIndex = payload.startRowIndex;
    final int startIndex = payload.startIndex;
    final double scale = _getScale();
    final List<double> tdPadding = _getTdPadding();

    double x = startX;
    double y = startY;
    var index = startIndex;

    for (var i = 0; i < rowList.length; i++) {
      final IRow curRow = rowList[i];

      if (curRow.isSurround != true) {
        final double curRowWidth = curRow.width + (curRow.offsetX ?? 0);
        if (curRow.rowFlex == RowFlex.center) {
          x += (innerWidth - curRowWidth) / 2;
        } else if (curRow.rowFlex == RowFlex.right) {
          x += innerWidth - curRowWidth;
        }
      }

      x += curRow.offsetX ?? 0;
      y += curRow.offsetY ?? 0;

      final double tablePreX = x;
      final double tablePreY = y;

      final List<IRowElement> elementList = curRow.elementList;
      for (var j = 0; j < elementList.length; j++) {
        final IRowElement element = elementList[j];
        final IElementMetrics metrics = element.metrics;
        // Imagens (inline ou não) e látex descem da baseline: o topo fica em
        // `ascent - altura` para o RODAPÉ da imagem repousar na baseline. Antes
        // as inline eram excluídas e usavam `offsetY = ascent`, o que empurrava
        // a imagem ~altura px para baixo (o brasão do cabeçalho "descia" ~87px e
        // sobrepunha o conteúdo nas páginas de continuação).
        final bool isImageLike = element.type == ElementType.image ||
            element.type == ElementType.latex;
        final double offsetY = element.hide != true && isImageLike
            ? curRow.ascent - metrics.height
            : curRow.ascent;

        if (element.left != null) {
          x += element.left!;
        }
        if (element.translateX != null) {
          x += element.translateX! * scale;
        }

        // Cantos derivados de coordX/coordY + metrics/lineHeight; o Map só é
        // materializado se algum consumidor ler `coordinate` (A4).
        final IElementPosition positionItem = IElementPosition(
          pageNo: pageNo,
          index: index,
          value: element.value,
          rowIndex: startRowIndex + i,
          rowNo: i,
          metrics: metrics,
          left: element.left ?? 0,
          ascent: offsetY,
          lineHeight: curRow.height,
          isFirstLetter: j == 0,
          isLastLetter: j == elementList.length - 1,
          coordX: x,
          coordY: y,
          anchor: payload.positionAnchor,
        );

        if (element.imgDisplay == ImageDisplay.surround ||
            element.imgDisplay == ImageDisplay.floatTop ||
            element.imgDisplay == ImageDisplay.floatBottom) {
          if (targetPositionList.isNotEmpty) {
            final IElementPosition prePosition =
                targetPositionList[targetPositionList.length - 1];
            positionItem.metrics = prePosition.metrics;
            positionItem.coordinate = Map<String, List<double>>.from(
              prePosition.coordinate.map(
                (String key, List<double> value) =>
                    MapEntry<String, List<double>>(
                        key, List<double>.from(value)),
              ),
            );
          }
          element.imgFloatPosition ??= <String, num>{
            'x': x,
            'y': y,
            'pageNo': pageNo,
          };
          floatPositionList.add(
            IFloatPosition(
              pageNo: pageNo,
              element: element,
              position: positionItem,
              isTable: payload.isTable,
              index: payload.index,
              tdIndex: payload.tdIndex,
              trIndex: payload.trIndex,
              tdValueIndex: index,
              zone: payload.zone,
            ),
          );
        }

        targetPositionList.add(positionItem);
        index += 1;
        x += metrics.width;

        if (element.type == ElementType.table && element.hide != true) {
          final List<ITr>? trList = element.trList;
          final IElementPositionAnchor? tablePositionAnchor =
              payload.positionAnchor == null
                  ? null
                  : IElementPositionAnchor(
                      pageParent: payload.positionAnchor,
                    );
          // Cache de posições de célula (perf): se esta parte de tabela não se
          // moveu desde o último cálculo (mesmo tablePreY e pageNo), as posições
          // absolutas das células são idênticas — reusa as td.positionList
          // existentes e pula todo o loop. Grande ganho ao digitar no corpo
          // (a tabela gigante do TR não precisa ser reposicionada por tecla).
          final bool tableCached = trList != null &&
              element.lastPositionedTablePreY == tablePreY &&
              element.lastPositionedPageNo == pageNo &&
              trList.isNotEmpty &&
              trList.first.tdList.isNotEmpty &&
              identical(
                element.lastPositionedFirstCellRowList,
                trList.first.tdList.first.rowList,
              ) &&
              (trList.first.tdList.first.positionList?.isNotEmpty ?? false);
          if (trList != null && !tableCached) {
            final double tdPaddingWidth = (tdPadding[1] + tdPadding[3]);
            final double tdPaddingHeight = (tdPadding[0] + tdPadding[2]);
            for (var t = 0; t < trList.length; t++) {
              final ITr tr = trList[t];
              for (var d = 0; d < tr.tdList.length; d++) {
                final ITd td = tr.tdList[d];
                td.positionList = <IElementPosition>[];
                final List<IRow> tdRowList = td.rowList ?? <IRow>[];
                final double tdStartX = ((td.x ?? 0) + tdPadding[3]) * scale +
                    tablePreX +
                    (element.translateX ?? 0) * scale;
                final double tdStartY =
                    ((td.y ?? 0) + tdPadding[0]) * scale + tablePreY;
                final double tdInnerWidth =
                    ((td.width ?? 0) - tdPaddingWidth) * scale;
                final IComputePageRowPositionResult drawRowResult =
                    computePageRowPosition(
                  IComputePageRowPositionPayload(
                    positionList: td.positionList!,
                    rowList: tdRowList,
                    pageNo: pageNo,
                    startRowIndex: 0,
                    startIndex: 0,
                    startX: tdStartX,
                    startY: tdStartY,
                    innerWidth: tdInnerWidth,
                    isTable: true,
                    index: index - 1,
                    tdIndex: d,
                    trIndex: t,
                    zone: payload.zone,
                    positionAnchor: tablePositionAnchor,
                  ),
                );

                if (td.verticalAlign == VerticalAlign.middle ||
                    td.verticalAlign == VerticalAlign.bottom) {
                  final double rowsHeight = tdRowList.fold<double>(
                    0,
                    (double previousValue, IRow current) =>
                        previousValue + current.height,
                  );
                  final double blankHeight =
                      ((td.height ?? 0) - tdPaddingHeight) * scale - rowsHeight;
                  final double offsetHeight =
                      td.verticalAlign == VerticalAlign.middle
                          ? blankHeight / 2
                          : blankHeight;
                  if (offsetHeight.floor() > 0) {
                    for (final IElementPosition tdPosition
                        in td.positionList!) {
                      final List<double>? leftTop =
                          tdPosition.coordinate['leftTop'];
                      final List<double>? leftBottom =
                          tdPosition.coordinate['leftBottom'];
                      final List<double>? rightBottom =
                          tdPosition.coordinate['rightBottom'];
                      final List<double>? rightTop =
                          tdPosition.coordinate['rightTop'];
                      if (leftTop != null && leftTop.length >= 2) {
                        leftTop[1] += offsetHeight;
                      }
                      if (leftBottom != null && leftBottom.length >= 2) {
                        leftBottom[1] += offsetHeight;
                      }
                      if (rightBottom != null && rightBottom.length >= 2) {
                        rightBottom[1] += offsetHeight;
                      }
                      if (rightTop != null && rightTop.length >= 2) {
                        rightTop[1] += offsetHeight;
                      }
                    }
                  }
                }
                x = drawRowResult.x;
                y = drawRowResult.y;
              }
            }
            element.lastPositionedTablePreY = tablePreY;
            element.lastPositionedPageNo = pageNo;
            element.lastPositionedFirstCellRowList =
                trList.first.tdList.first.rowList;
          }
          x = tablePreX;
          y = tablePreY;
        }
      }

      x = startX;
      y += curRow.height;
    }

    return IComputePageRowPositionResult(x: x, y: y, index: index);
  }

  void computePositionList() {
    floatPositionList = <IFloatPosition>[];
    _lastRecomputedPageCount = 0;
    _lastRebasedPageCount = 0;
    _lastFlattenedPositionCount = 0;
    final double innerWidth = draw.getInnerWidth();
    final List<List<IRow>> pageRowList =
        (draw.getPageRowList() as List<dynamic>).map<List<IRow>>(
      (dynamic entry) {
        if (entry is List<IRow>) {
          return entry;
        }
        if (entry is List) {
          return entry.whereType<IRow>().toList();
        }
        return <IRow>[];
      },
    ).toList();
    final List<double> margins = _getMargins();
    final dynamic header = draw.getHeader();
    final double extraHeight = (header.getExtraHeight() as num).toDouble();
    final double startX = margins[3];
    final double startY = margins[0] + extraHeight;
    // startY (altura do header) ou innerWidth mudou → coordenadas cacheadas não
    // valem mais (as rows do corpo podem ser as mesmas, mas deslocadas).
    if (startY != _cachedStartY || innerWidth != _cachedInnerWidth) {
      _cachedPageRows = <List<IRow>>[];
      _cachedPagePositions = <List<IElementPosition>>[];
      _cachedPageReusable = <bool>[];
      _cachedPageAnchors = <IElementPositionAnchor?>[];
      _cachedStartY = startY;
      _cachedInnerWidth = innerWidth;
    }
    var startRowIndex = 0;
    final List<List<IElementPosition>> previousPagePositions =
        _cachedPagePositions;
    final List<List<IRow>> newCachedRows = <List<IRow>>[];
    final List<List<IElementPosition>> newCachedPositions =
        <List<IElementPosition>>[];
    final List<bool> newCachedReusable = <bool>[];
    final List<IElementPositionAnchor?> newCachedAnchors =
        <IElementPositionAnchor?>[];
    final Map<IRow, int> previousPageByFirstRow = HashMap<IRow, int>.identity();
    for (int page = 0; page < _cachedPageRows.length; page++) {
      final List<IRow> rows = _cachedPageRows[page];
      if (rows.isNotEmpty) {
        previousPageByFirstRow[rows.first] = page;
      }
    }
    final Set<int> reusedPreviousPages = <int>{};
    for (var i = 0; i < pageRowList.length; i++) {
      final List<IRow> rowList = pageRowList[i];
      final int startIndex = rowList.isNotEmpty ? rowList[0].startIndex : 0;
      int? cachedPageIndex;
      if (!reusedPreviousPages.contains(i) &&
          _canReusePagePositions(i, rowList)) {
        cachedPageIndex = i;
      } else if (rowList.isNotEmpty) {
        final int? candidate = previousPageByFirstRow[rowList.first];
        if (candidate != null &&
            !reusedPreviousPages.contains(candidate) &&
            _canReusePagePositions(candidate, rowList)) {
          cachedPageIndex = candidate;
        }
      }
      final List<IElementPosition>? reuse = cachedPageIndex == null
          ? null
          : _cachedPagePositions[cachedPageIndex];
      if (reuse != null) {
        // Todas as posições da página compartilham a mesma âncora. Um splice
        // anterior desloca índice/row/page em O(1), sem visitar os caracteres.
        reusedPreviousPages.add(cachedPageIndex!);
        final IElementPositionAnchor anchor =
            _cachedPageAnchors[cachedPageIndex]!;
        final int pageDelta = i - reuse.first.pageNo;
        final int indexDelta = startIndex - reuse.first.index;
        final int rowDelta = startRowIndex - reuse.first.rowIndex;
        if (pageDelta != 0 || indexDelta != 0 || rowDelta != 0) {
          anchor.shift(
            pageDelta: pageDelta,
            indexDelta: indexDelta,
            rowIndexDelta: rowDelta,
          );
          _lastRebasedPageCount += 1;
        }
        newCachedRows.add(List<IRow>.of(rowList));
        newCachedPositions.add(reuse);
        newCachedReusable.add(true);
        newCachedAnchors.add(anchor);
      } else {
        final List<IElementPosition> pagePositions = <IElementPosition>[];
        final IElementPositionAnchor anchor = IElementPositionAnchor();
        final int floatsBefore = floatPositionList.length;
        computePageRowPosition(
          IComputePageRowPositionPayload(
            positionList: pagePositions,
            rowList: rowList,
            pageNo: i,
            startRowIndex: startRowIndex,
            startIndex: startIndex,
            startX: startX,
            startY: startY,
            innerWidth: innerWidth,
            positionAnchor: anchor,
          ),
        );
        _lastRecomputedPageCount += 1;
        newCachedRows.add(List<IRow>.of(rowList));
        newCachedPositions.add(pagePositions);
        // Uma página com float precisa recomputar para repopular a lista de
        // floats; a geometria plana ainda participa da agregação incremental.
        newCachedReusable.add(floatPositionList.length == floatsBefore);
        newCachedAnchors.add(anchor);
      }
      startRowIndex += rowList.length;
    }
    _replaceFlattenedPagePositions(
      previousPagePositions,
      newCachedPositions,
    );
    _cachedPageRows = newCachedRows;
    _cachedPagePositions = newCachedPositions;
    _cachedPageReusable = newCachedReusable;
    _cachedPageAnchors = newCachedAnchors;
    _pagePositionIndex.rebuildFromPageLengths(
      positionList,
      newCachedPositions.map((List<IElementPosition> page) => page.length),
    );
    _rebuildFloatPositionIndex();
  }

  /// Reconciles only the changed middle of the flattened canonical list.
  /// Identical page lists at the prefix/suffix remain untouched, so a local
  /// edit does not concatenate every position in the document again.
  void _replaceFlattenedPagePositions(
    List<List<IElementPosition>> previous,
    List<List<IElementPosition>> next,
  ) {
    int prefix = 0;
    final int commonLength =
        previous.length < next.length ? previous.length : next.length;
    while (prefix < commonLength && identical(previous[prefix], next[prefix])) {
      prefix += 1;
    }

    int suffix = 0;
    while (suffix < commonLength - prefix &&
        identical(
          previous[previous.length - 1 - suffix],
          next[next.length - 1 - suffix],
        )) {
      suffix += 1;
    }

    int replaceStart = 0;
    for (int i = 0; i < prefix; i++) {
      replaceStart += previous[i].length;
    }
    int replaceEnd = positionList.length;
    for (int i = 0; i < suffix; i++) {
      replaceEnd -= previous[previous.length - 1 - i].length;
    }

    final List<IElementPosition> replacement = <IElementPosition>[];
    final int nextEnd = next.length - suffix;
    for (int i = prefix; i < nextEnd; i++) {
      replacement.addAll(next[i]);
    }
    _lastFlattenedPositionCount = replacement.length;
    if (replaceStart == replaceEnd && replacement.isEmpty) {
      return;
    }
    positionList.replaceRange(replaceStart, replaceEnd, replacement);
  }

  /// Retorna as posições cacheadas da página [i] se as suas rows são as MESMAS
  /// (por referência) do último cálculo e a página foi cacheada (sem float);
  /// senão null (recomputa).
  bool _canReusePagePositions(int i, List<IRow> rowList) {
    if (i >= _cachedPageRows.length ||
        i >= _cachedPagePositions.length ||
        i >= _cachedPageReusable.length ||
        i >= _cachedPageAnchors.length ||
        !_cachedPageReusable[i] ||
        _cachedPageAnchors[i] == null) {
      return false;
    }
    final List<IRow> cachedRows = _cachedPageRows[i];
    if (cachedRows.length != rowList.length || rowList.isEmpty) {
      return false;
    }
    for (var k = 0; k < rowList.length; k++) {
      if (!identical(cachedRows[k], rowList[k])) {
        return false;
      }
    }
    final List<IElementPosition> cached = _cachedPagePositions[i];
    return cached.isNotEmpty;
  }

  List<IElementPosition> computeRowPosition(
      IComputeRowPositionPayload payload) {
    final IRow rowClone = _cloneRow(payload.row);
    final List<IElementPosition> tempPositionList = <IElementPosition>[];
    computePageRowPosition(
      IComputePageRowPositionPayload(
        positionList: tempPositionList,
        rowList: <IRow>[rowClone],
        pageNo: 0,
        startRowIndex: 0,
        startIndex: 0,
        startX: 0,
        startY: 0,
        innerWidth: payload.innerWidth,
      ),
    );
    return tempPositionList;
  }

  void setCursorPosition(IElementPosition? position) {
    cursorPosition = position;
  }

  IElementPosition? getCursorPosition() {
    return cursorPosition;
  }

  IPositionContext getPositionContext() {
    return positionContext;
  }

  void setPositionContext(IPositionContext payload) {
    try {
      eventBus.emit('positionContextChange', <String, dynamic>{
        'value': payload,
        'oldValue': positionContext,
      });
    } catch (_) {}
    positionContext = payload;
  }

  ICurrentPosition getPositionByXY(IGetPositionByXYPayload payload) {
    final double x = payload.x;
    final double y = payload.y;
    final bool isTable = payload.isTable == true;
    final List<IElement> elementList = _resolveElementList(payload.elementList);
    final List<IElementPosition> currentPositionList =
        payload.positionList ?? getOriginalPositionList();
    final dynamic zoneManager = draw.getZone();
    final int curPageNo = payload.pageNo ?? draw.getPageNo();
    final bool isMainActive = zoneManager.isMainActive() == true;
    final int positionNo = isMainActive ? curPageNo : 0;
    final List<double> margins = _getMargins();
    final PagePositionSlice? pageSlice =
        _pagePositionIndex.sliceFor(currentPositionList, positionNo);
    final int candidateStart = pageSlice?.startOffset ?? 0;
    final int candidateEnd = pageSlice?.endOffset ?? currentPositionList.length;
    _lastHitTestUsedPageIndex = pageSlice != null;
    _lastHitTestCandidateCount = candidateEnd - candidateStart;
    _lastHitTestInspectedPositionCount = 0;

    if (!isTable) {
      final ICurrentPosition? floatTopPosition = getFloatPositionByXY(
        IGetFloatPositionByXYPayload(
          imgDisplays: <ImageDisplay>[
            ImageDisplay.floatTop,
            ImageDisplay.surround
          ],
          x: x,
          y: y,
          pageNo: payload.pageNo,
          isTable: payload.isTable,
          td: payload.td,
          tablePosition: payload.tablePosition,
          elementList: payload.elementList,
          positionList: payload.positionList,
        ),
      );
      if (floatTopPosition != null) {
        return floatTopPosition;
      }
    }

    for (var j = candidateStart; j < candidateEnd; j++) {
      final IElementPosition positionItem = currentPositionList[j];
      final int index = positionItem.index;
      final int pageNo = positionItem.pageNo;
      // Se o indice estiver indisponivel (header/footer, tabela ou lista
      // externa), filtre a pagina antes de ler `coordinate`. Isso preserva o
      // fallback sem materializar a geometria lazy de paginas anteriores.
      if (positionNo != pageNo) {
        continue;
      }
      final double left = positionItem.left;
      final bool isFirstLetter = positionItem.isFirstLetter;
      _lastHitTestInspectedPositionCount += 1;
      final List<double> leftTop =
          positionItem.coordinate['leftTop'] ?? <double>[0, 0];
      final List<double> rightTop =
          positionItem.coordinate['rightTop'] ?? <double>[0, 0];
      final List<double> leftBottom =
          positionItem.coordinate['leftBottom'] ?? <double>[0, 0];
      if (leftTop.length < 2 || rightTop.length < 2 || leftBottom.length < 2) {
        continue;
      }
      if (leftTop[0] - left <= x &&
          rightTop[0] >= x &&
          leftTop[1] <= y &&
          leftBottom[1] >= y) {
        var curPositionIndex = j;
        final IElement element = elementList[j];
        if (element.type == ElementType.table) {
          final List<ITr>? trList = element.trList;
          if (trList != null) {
            for (var t = 0; t < trList.length; t++) {
              final ITr tr = trList[t];
              for (var d = 0; d < tr.tdList.length; d++) {
                final ITd td = tr.tdList[d];
                final ICurrentPosition tablePosition = getPositionByXY(
                  IGetPositionByXYPayload(
                    x: x,
                    y: y,
                    pageNo: curPageNo,
                    isTable: true,
                    td: td,
                    tablePosition: positionItem,
                    elementList: td.value,
                    positionList: td.positionList,
                  ),
                );
                if (tablePosition.index != -1) {
                  final int tdValueIndex = tablePosition.index;
                  final IElement tdValueElement = td.value[tdValueIndex];
                  return ICurrentPosition(
                    index: index,
                    isCheckbox: tablePosition.isCheckbox == true ||
                        tdValueElement.type == ElementType.checkbox ||
                        tdValueElement.controlComponent ==
                            ControlComponent.checkbox,
                    isRadio: tdValueElement.type == ElementType.radio ||
                        tdValueElement.controlComponent ==
                            ControlComponent.radio,
                    isControl: tdValueElement.controlId != null,
                    isImage: tablePosition.isImage,
                    isLabel: tablePosition.isLabel,
                    isDirectHit: tablePosition.isDirectHit,
                    isTable: true,
                    tdIndex: d,
                    trIndex: t,
                    tdValueIndex: tdValueIndex,
                    tdId: td.id,
                    trId: tr.id,
                    tableId: element.id,
                    hitLineStartIndex: tablePosition.hitLineStartIndex,
                  );
                }
              }
            }
          }
        }
        if (element.type == ElementType.image ||
            element.type == ElementType.latex) {
          return ICurrentPosition(
            index: curPositionIndex,
            isDirectHit: true,
            isImage: true,
          );
        }
        if (element.type == ElementType.checkbox ||
            element.controlComponent == ControlComponent.checkbox) {
          return ICurrentPosition(
            index: curPositionIndex,
            isDirectHit: true,
            isCheckbox: true,
          );
        }
        if (element.type == ElementType.label) {
          return ICurrentPosition(
            index: curPositionIndex,
            isDirectHit: true,
            isLabel: true,
          );
        }
        if (element.type == ElementType.tab &&
            element.listStyle == ListStyle.checkbox) {
          var indexPointer = curPositionIndex - 1;
          while (indexPointer > 0) {
            final IElement checkElement = elementList[indexPointer];
            if (checkElement.value == ZERO &&
                checkElement.listStyle == ListStyle.checkbox) {
              break;
            }
            indexPointer -= 1;
          }
          return ICurrentPosition(
            index: indexPointer,
            isDirectHit: true,
            isCheckbox: true,
          );
        }
        if (element.type == ElementType.radio ||
            element.controlComponent == ControlComponent.radio) {
          return ICurrentPosition(
            index: curPositionIndex,
            isDirectHit: true,
            isRadio: true,
          );
        }

        int? hitLineStartIndex;
        if (elementList[index].value != ZERO) {
          final double valueWidth = rightTop[0] - leftTop[0];
          if (x < leftTop[0] + valueWidth / 2) {
            curPositionIndex = j - 1;
            if (isFirstLetter) {
              hitLineStartIndex = j;
            }
          }
        }
        return ICurrentPosition(
          index: curPositionIndex,
          isDirectHit: true,
          isControl: element.controlId != null,
          hitLineStartIndex: hitLineStartIndex,
        );
      }
    }

    if (!isTable) {
      final ICurrentPosition? floatBottomPosition = getFloatPositionByXY(
        IGetFloatPositionByXYPayload(
          imgDisplays: <ImageDisplay>[ImageDisplay.floatBottom],
          x: x,
          y: y,
          pageNo: payload.pageNo,
          isTable: payload.isTable,
          td: payload.td,
          tablePosition: payload.tablePosition,
          elementList: payload.elementList,
          positionList: payload.positionList,
        ),
      );
      if (floatBottomPosition != null) {
        return floatBottomPosition;
      }
    }

    var curPositionIndex = -1;
    int? hitLineStartIndex;
    var isLastArea = false;

    if (isTable) {
      final double scale = _getScale();
      final ITd? td = payload.td;
      final IElementPosition? tablePosition = payload.tablePosition;
      if (td != null && tablePosition != null) {
        final List<double> leftTop =
            tablePosition.coordinate['leftTop'] ?? <double>[0, 0];
        final double tdX =
            (td.x ?? 0) * scale + (leftTop.isNotEmpty ? leftTop[0] : 0);
        final double tdY =
            (td.y ?? 0) * scale + (leftTop.length > 1 ? leftTop[1] : 0);
        final double tdWidth = (td.width ?? 0) * scale;
        final double tdHeight = (td.height ?? 0) * scale;
        final bool insideTd =
            tdX < x && x < tdX + tdWidth && tdY < y && y < tdY + tdHeight;
        if (!insideTd) {
          return ICurrentPosition(index: curPositionIndex);
        }
      }
    }

    final List<IElementPosition> lastLetterList = <IElementPosition>[];
    for (var p = candidateStart; p < candidateEnd; p++) {
      final IElementPosition position = currentPositionList[p];
      if (position.isLastLetter && position.pageNo == positionNo) {
        lastLetterList.add(position);
      }
    }
    for (var j = 0; j < lastLetterList.length; j++) {
      final IElementPosition lastLetter = lastLetterList[j];
      final int index = lastLetter.index;
      final int rowNo = lastLetter.rowNo;
      final List<double> rowLeftTop =
          lastLetter.coordinate['leftTop'] ?? <double>[0, 0];
      final List<double> rowLeftBottom =
          lastLetter.coordinate['leftBottom'] ?? <double>[0, 0];
      if (rowLeftTop.length < 2 || rowLeftBottom.length < 2) {
        continue;
      }
      if (y > rowLeftTop[1] && y <= rowLeftBottom[1]) {
        var headIndex = -1;
        for (var p = candidateStart; p < candidateEnd; p++) {
          final IElementPosition position = currentPositionList[p];
          if (position.pageNo == positionNo && position.rowNo == rowNo) {
            headIndex = p;
            break;
          }
        }
        if (headIndex >= 0) {
          final IElement headElement = elementList[headIndex];
          final IElementPosition headPosition = currentPositionList[headIndex];
          final List<double> headLeftTop =
              headPosition.coordinate['leftTop'] ?? <double>[0, 0];
          final double headStartX = headElement.listStyle == ListStyle.checkbox
              ? margins[3]
              : (headLeftTop.isNotEmpty ? headLeftTop[0] : 0);
          if (x < headStartX) {
            if (headPosition.value == ZERO) {
              curPositionIndex = headIndex;
            } else {
              curPositionIndex = headIndex - 1;
              hitLineStartIndex = headIndex;
            }
          } else {
            if (headElement.listStyle == ListStyle.checkbox &&
                headLeftTop.isNotEmpty &&
                x < headLeftTop[0]) {
              return ICurrentPosition(
                index: headIndex,
                isDirectHit: true,
                isCheckbox: true,
              );
            }
            curPositionIndex = index;
          }
        } else {
          curPositionIndex = index;
        }
        isLastArea = true;
        break;
      }
    }

    if (!isLastArea) {
      final dynamic header = draw.getHeader();
      final double headerHeight = (header.getHeight() as num).toDouble();
      final double headerTop = (header.getHeaderTop() as num).toDouble();
      final double headerBottomY = headerTop + headerHeight;
      final dynamic footer = draw.getFooter();
      final double pageHeight = (draw.getHeight() as num).toDouble();
      final double footerBottom = (footer.getFooterBottom() as num).toDouble();
      final double footerHeight = (footer.getHeight() as num).toDouble();
      final double footerTopY = pageHeight - (footerBottom + footerHeight);
      if (isMainActive) {
        if (y < headerBottomY) {
          return ICurrentPosition(index: -1, zone: EditorZone.header);
        }
        if (y > footerTopY) {
          return ICurrentPosition(index: -1, zone: EditorZone.footer);
        }
      } else {
        if (y <= footerTopY && y >= headerBottomY) {
          return ICurrentPosition(index: -1, zone: EditorZone.main);
        }
      }

      if (y <= margins[0]) {
        for (var p = candidateStart; p < candidateEnd; p++) {
          final IElementPosition position = currentPositionList[p];
          if (position.pageNo != positionNo || position.rowNo != 0) {
            continue;
          }
          final List<double> leftTop =
              position.coordinate['leftTop'] ?? <double>[0, 0];
          final List<double> rightTop =
              position.coordinate['rightTop'] ?? <double>[0, 0];
          final bool isLastElement = p + 1 >= currentPositionList.length ||
              currentPositionList[p + 1].rowNo != 0;
          if (x <= margins[3] ||
              (leftTop.isNotEmpty &&
                  rightTop.isNotEmpty &&
                  x >= leftTop[0] &&
                  x <= rightTop[0]) ||
              isLastElement) {
            return ICurrentPosition(index: position.index);
          }
        }
      } else {
        final IElementPosition? lastLetter = lastLetterList.isNotEmpty
            ? lastLetterList[lastLetterList.length - 1]
            : null;
        if (lastLetter != null) {
          final int lastRowNo = lastLetter.rowNo;
          for (var p = candidateStart; p < candidateEnd; p++) {
            final IElementPosition position = currentPositionList[p];
            if (position.pageNo != positionNo || position.rowNo != lastRowNo) {
              continue;
            }
            final List<double> leftTop =
                position.coordinate['leftTop'] ?? <double>[0, 0];
            final List<double> rightTop =
                position.coordinate['rightTop'] ?? <double>[0, 0];
            final bool isLastElement = p + 1 >= currentPositionList.length ||
                currentPositionList[p + 1].rowNo != lastRowNo;
            if (x <= margins[3] ||
                (leftTop.isNotEmpty &&
                    rightTop.isNotEmpty &&
                    x >= leftTop[0] &&
                    x <= rightTop[0]) ||
                isLastElement) {
              return ICurrentPosition(index: position.index);
            }
          }
        }
      }
      return ICurrentPosition(
        index: lastLetterList.isNotEmpty
            ? lastLetterList[lastLetterList.length - 1].index
            : currentPositionList.length - 1,
      );
    }

    final bool hasControl =
        curPositionIndex >= 0 && curPositionIndex < elementList.length
            ? elementList[curPositionIndex].controlId != null
            : false;
    return ICurrentPosition(
      index: curPositionIndex,
      hitLineStartIndex: hitLineStartIndex,
      isControl: hasControl,
    );
  }

  ICurrentPosition? getFloatPositionByXY(IGetFloatPositionByXYPayload payload) {
    final double x = payload.x;
    final double y = payload.y;
    final int currentPageNo = payload.pageNo ?? draw.getPageNo();
    final EditorZone? currentZone = draw.getZone().getZone() as EditorZone?;
    final double scale = _getScale();
    final List<IFloatPosition> pageFloatPositions =
        _getFloatPositionsForPage(currentPageNo);
    _lastFloatHitTestCandidateCount = pageFloatPositions.length;

    for (final IFloatPosition floatPosition in pageFloatPositions) {
      final IElement element = floatPosition.element;
      final bool isTable = floatPosition.isTable == true;
      if (currentPageNo != floatPosition.pageNo) {
        continue;
      }
      if (element.type != ElementType.image) {
        continue;
      }
      final ImageDisplay? imgDisplay = element.imgDisplay;
      if (imgDisplay == null || !payload.imgDisplays.contains(imgDisplay)) {
        continue;
      }
      final EditorZone? floatZone = floatPosition.zone;
      if (floatZone != null &&
          currentZone != null &&
          floatZone != currentZone) {
        continue;
      }
      final Map<String, num>? imgFloatPosition =
          element.imgFloatPosition?.cast<String, num>();
      if (imgFloatPosition == null) {
        continue;
      }
      final double floatX = (imgFloatPosition['x'] ?? 0) * scale;
      final double floatY = (imgFloatPosition['y'] ?? 0) * scale;
      final double elementWidth = (element.width ?? 0) * scale;
      final double elementHeight = (element.height ?? 0) * scale;
      final bool isHit = x >= floatX &&
          x <= floatX + elementWidth &&
          y >= floatY &&
          y <= floatY + elementHeight;
      if (!isHit) {
        continue;
      }
      if (isTable) {
        return ICurrentPosition(
          index: floatPosition.index ?? -1,
          isDirectHit: true,
          isImage: true,
          isTable: true,
          trIndex: floatPosition.trIndex,
          tdIndex: floatPosition.tdIndex,
          tdValueIndex: floatPosition.tdValueIndex,
          tdId: element.tdId,
          trId: element.trId,
          tableId: element.tableId,
        );
      }
      return ICurrentPosition(
        index: floatPosition.position.index,
        isDirectHit: true,
        isImage: true,
      );
    }
    return null;
  }

  ICurrentPosition? adjustPositionContext(IGetPositionByXYPayload payload) {
    final ICurrentPosition positionResult = getPositionByXY(payload);
    if (positionResult.index == -1) {
      return null;
    }
    if (positionResult.isControl == true &&
        draw.getMode() != EditorMode.readonly) {
      final dynamic control = draw.getControl();
      final IMoveCursorResult moveResult = control.moveCursor(
        IControlInitOption(
          index: positionResult.index,
          isTable: positionResult.isTable,
          trIndex: positionResult.trIndex,
          tdIndex: positionResult.tdIndex,
          tdValueIndex: positionResult.tdValueIndex,
        ),
      ) as IMoveCursorResult;
      final int newIndex = moveResult.newIndex;
      if (positionResult.isTable == true) {
        positionResult.tdValueIndex = newIndex;
      } else {
        positionResult.index = newIndex;
      }
    }

    setPositionContext(
      IPositionContext(
        isTable: positionResult.isTable ?? false,
        isCheckbox: positionResult.isCheckbox ?? false,
        isRadio: positionResult.isRadio ?? false,
        isControl: positionResult.isControl ?? false,
        isImage: positionResult.isImage ?? false,
        isLabel: positionResult.isLabel ?? false,
        isDirectHit: positionResult.isDirectHit ?? false,
        index: positionResult.index,
        trIndex: positionResult.trIndex,
        tdIndex: positionResult.tdIndex,
        tdId: positionResult.tdId,
        trId: positionResult.trId,
        tableId: positionResult.tableId,
      ),
    );

    return positionResult;
  }

  Map<String, double> setSurroundPosition(ISetSurroundPositionPayload payload) {
    final double scale = _getScale();
    final int pageNo = payload.pageNo;
    final IRow row = payload.row;
    final IRowElement rowElement = payload.rowElement;
    final IElementFillRect rowElementRect = payload.rowElementRect;
    final List<IElement> surroundElementList = payload.surroundElementList;
    final double availableWidth = payload.availableWidth;

    double x = rowElementRect.x;
    double rowIncreaseWidth = 0;

    if (surroundElementList.isNotEmpty &&
        !element_utils.getIsBlockElement(rowElement) &&
        rowElement.control?.minWidth == null) {
      for (final IElement surroundElement in surroundElementList) {
        final Map<String, num>? floatPosition =
            surroundElement.imgFloatPosition?.cast<String, num>();
        if (floatPosition == null) {
          continue;
        }
        if ((floatPosition['pageNo'] ?? -1).toInt() != pageNo) {
          continue;
        }
        final IElementFillRect surroundRect = IElementFillRect(
          x: (floatPosition['x'] ?? 0) * scale,
          y: (floatPosition['y'] ?? 0) * scale,
          width: (surroundElement.width ?? 0) * scale,
          height: (surroundElement.height ?? 0) * scale,
        );
        if (isRectIntersect(rowElementRect, surroundRect)) {
          row.isSurround = true;
          final double translateX =
              surroundRect.width + surroundRect.x - rowElementRect.x;
          rowElement.left = translateX;
          row.width += translateX;
          rowIncreaseWidth += translateX;
          x = surroundRect.x + surroundRect.width;
          if (row.width + rowElement.metrics.width > availableWidth) {
            rowElement.left = 0;
            row.width -= rowIncreaseWidth;
            break;
          }
        }
      }
    }

    return <String, double>{
      'x': x,
      'rowIncreaseWidth': rowIncreaseWidth,
    };
  }

  double _getScale() {
    return options.scale?.toDouble() ?? 1;
  }

  List<double> _getTdPadding() {
    final IPadding? padding = options.table?.tdPadding;
    return <double>[
      (padding?.top ?? 0).toDouble(),
      (padding?.right ?? 0).toDouble(),
      (padding?.bottom ?? 0).toDouble(),
      (padding?.left ?? 0).toDouble(),
    ];
  }

  List<double> _getMargins() {
    final dynamic marginsRaw = draw.getMargins();
    if (marginsRaw is List) {
      final List<double> margins =
          marginsRaw.map((dynamic value) => (value as num).toDouble()).toList();
      if (margins.length < 4) {
        margins.addAll(List<double>.filled(4 - margins.length, 0));
      } else if (margins.length > 4) {
        return margins.sublist(0, 4);
      }
      return margins;
    }
    return <double>[0, 0, 0, 0];
  }

  List<IElement> _resolveElementList(List<IElement>? explicitList) {
    if (explicitList != null) {
      return explicitList;
    }
    final dynamic value = draw.getOriginalElementList();
    if (value is List<IElement>) {
      return value;
    }
    if (value is Iterable) {
      return value.whereType<IElement>().toList();
    }
    return <IElement>[];
  }

  IRow _cloneRow(IRow row) {
    return IRow(
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
      elementList:
          row.elementList.map(_cloneRowElement).toList(growable: false),
      isWidthNotEnough: row.isWidthNotEnough,
      rowIndex: row.rowIndex,
      isSurround: row.isSurround,
    );
  }

  IRowElement _cloneRowElement(IRowElement element) {
    final List<IElement> cloneList =
        element_utils.cloneElementList(<IElement>[element]);
    final IElement clone = cloneList.first;
    final IElementMetrics metrics = IElementMetrics(
      width: element.metrics.width,
      height: element.metrics.height,
      boundingBoxAscent: element.metrics.boundingBoxAscent,
      boundingBoxDescent: element.metrics.boundingBoxDescent,
    );

    return IRowElement(
      metrics: metrics,
      style: element.style,
      left: element.left,
      id: clone.id,
      type: clone.type,
      value: clone.value,
      extension: clone.extension,
      externalId: clone.externalId,
      font: clone.font,
      size: clone.size,
      width: clone.width,
      height: clone.height,
      bold: clone.bold,
      color: clone.color,
      highlight: clone.highlight,
      italic: clone.italic,
      underline: clone.underline,
      strikeout: clone.strikeout,
      rowFlex: clone.rowFlex,
      rowMargin: clone.rowMargin,
      letterSpacing: clone.letterSpacing,
      textDecoration: clone.textDecoration,
      hide: clone.hide,
      groupIds:
          clone.groupIds == null ? null : List<String>.from(clone.groupIds!),
      colgroup: clone.colgroup,
      trList: clone.trList,
      borderType: clone.borderType,
      borderColor: clone.borderColor,
      borderWidth: clone.borderWidth,
      borderExternalWidth: clone.borderExternalWidth,
      translateX: clone.translateX,
      tableToolDisabled: clone.tableToolDisabled,
      tdId: clone.tdId,
      trId: clone.trId,
      tableId: clone.tableId,
      conceptId: clone.conceptId,
      pagingId: clone.pagingId,
      pagingIndex: clone.pagingIndex,
      valueList: clone.valueList == null
          ? null
          : element_utils.cloneElementList(clone.valueList!),
      url: clone.url,
      hyperlinkId: clone.hyperlinkId,
      actualSize: clone.actualSize,
      dashArray:
          clone.dashArray == null ? null : List<double>.from(clone.dashArray!),
      control: clone.control,
      controlId: clone.controlId,
      controlComponent: clone.controlComponent,
      checkbox: clone.checkbox,
      radio: clone.radio,
      laTexSVG: clone.laTexSVG,
      dateFormat: clone.dateFormat,
      dateId: clone.dateId,
      imgDisplay: clone.imgDisplay,
      imgFloatPosition: clone.imgFloatPosition == null
          ? null
          : Map<String, num>.from(clone.imgFloatPosition!),
      imgToolDisabled: clone.imgToolDisabled,
      block: clone.block,
      level: clone.level,
      titleId: clone.titleId,
      title: clone.title,
      listType: clone.listType,
      listStyle: clone.listStyle,
      listId: clone.listId,
      listWrap: clone.listWrap,
      areaId: clone.areaId,
      areaIndex: clone.areaIndex,
      area: clone.area,
    );
  }
}
