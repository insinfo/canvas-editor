import 'dart:collection';

import '../../dataset/enum/element.dart';
import '../../interface/element.dart';
import '../../interface/table/td.dart';

/// Independent roots that can own an editable element list.
///
/// Header/footer variants intentionally do not collapse into one `header` or
/// `footer` value: replacing a DOCX root must restore the exact variant that
/// was active when a transaction was captured.
enum DocumentRegion {
  main,
  headerDefault,
  headerFirst,
  headerEven,
  footerDefault,
  footerFirst,
  footerEven,
}

/// Stable identity of one table cell in a possibly nested table path.
class TableCellLocatorStep {
  const TableCellLocatorStep({
    required this.tableId,
    required this.pagingId,
    required this.rowId,
    required this.cellId,
    required this.tableIndex,
    required this.rowIndex,
    required this.cellIndex,
  });

  /// Concrete table-part id. It is diagnostic/fallback information; a table
  /// split may replace it while preserving [pagingId], row and cell ids.
  final String? tableId;
  final String? pagingId;
  final String? rowId;
  final String? cellId;
  final int tableIndex;
  final int rowIndex;
  final int cellIndex;

  String get _stableKey {
    final String tableKey = pagingId ?? tableId ?? '#$tableIndex';
    final String rowKey = rowId ?? '#$rowIndex';
    final String cellKey = cellId ?? '#$cellIndex';
    return '${_part(tableKey)}${_part(rowKey)}${_part(cellKey)}';
  }

  String get _exactKey {
    final String tableKey = tableId ?? pagingId ?? '#$tableIndex';
    final String rowKey = rowId ?? '#$rowIndex';
    final String cellKey = cellId ?? '#$cellIndex';
    return '${_part(tableKey)}${_part(rowKey)}${_part(cellKey)}';
  }

  static String _part(String value) => '${value.length}:$value;';

  @override
  bool operator ==(Object other) =>
      other is TableCellLocatorStep &&
      tableId == other.tableId &&
      pagingId == other.pagingId &&
      rowId == other.rowId &&
      cellId == other.cellId &&
      tableIndex == other.tableIndex &&
      rowIndex == other.rowIndex &&
      cellIndex == other.cellIndex;

  @override
  int get hashCode => Object.hash(
        tableId,
        pagingId,
        rowId,
        cellId,
        tableIndex,
        rowIndex,
        cellIndex,
      );
}

/// Stable address of an editable `List<IElement>`.
///
/// [path] is empty for a region root and contains one step per nested cell.
/// The locator never retains the mutable list itself, so it remains valid
/// after root objects are replaced by snapshot restore/import.
class DocumentListLocator {
  DocumentListLocator({
    required this.region,
    Iterable<TableCellLocatorStep> path = const <TableCellLocatorStep>[],
  }) : path = List<TableCellLocatorStep>.unmodifiable(path);

  final DocumentRegion region;
  final List<TableCellLocatorStep> path;

  String get _stableKey => '${region.index}|'
      '${path.map((TableCellLocatorStep step) => step._stableKey).join()}';

  String get _exactKey => '${region.index}|'
      '${path.map((TableCellLocatorStep step) => step._exactKey).join()}';

  @override
  bool operator ==(Object other) =>
      other is DocumentListLocator &&
      region == other.region &&
      _listEquals(path, other.path);

  @override
  int get hashCode => Object.hash(region, Object.hashAll(path));
}

/// Element endpoint carried on top of a stable list locator.
class DocumentElementLocator {
  const DocumentElementLocator({
    required this.list,
    required this.index,
    this.elementId,
  });

  final DocumentListLocator list;
  final int index;
  final String? elementId;
}

class ResolvedDocumentElement {
  const ResolvedDocumentElement({
    required this.elements,
    required this.index,
  });

  final List<IElement> elements;
  final int index;

  IElement get element => elements[index];
}

/// Lazy recursive index for stable document-list locators.
///
/// Building one region is O(elements + tables/cells) once. Capturing a list is
/// O(1) through an identity map, and resolving a previously captured locator
/// is O(1) through its stable path key. A root replacement invalidates only
/// that region; ordinary character splices do not invalidate the table path.
class DocumentLocatorIndex {
  DocumentLocatorIndex(Map<DocumentRegion, List<IElement>> roots) {
    rebindRoots(roots);
  }

  final Map<DocumentRegion, _RegionLocatorIndex> _regions =
      <DocumentRegion, _RegionLocatorIndex>{};

  int _rebuildCount = 0;
  int get rebuildCount => _rebuildCount;

  /// Updates region roots. A different list identity invalidates only the
  /// corresponding region and is rebuilt lazily on first capture/resolve.
  void rebindRoots(Map<DocumentRegion, List<IElement>> roots) {
    for (final DocumentRegion region in DocumentRegion.values) {
      final List<IElement>? root = roots[region];
      final _RegionLocatorIndex? current = _regions[region];
      if (root == null) {
        _regions.remove(region);
      } else if (current == null || !identical(current.root, root)) {
        _regions[region] = _RegionLocatorIndex(root);
      }
    }
  }

  void invalidateRegion(DocumentRegion region) {
    _regions[region]?.invalidate();
  }

  void invalidateAll() {
    for (final _RegionLocatorIndex region in _regions.values) {
      region.invalidate();
    }
  }

  /// Captures [elements] using [regionHint] without inspecting other regions.
  /// Without a hint, regions are tried lazily until the identity is found.
  DocumentListLocator? captureList(
    List<IElement> elements, {
    DocumentRegion? regionHint,
  }) {
    if (regionHint != null) {
      final _RegionLocatorIndex? region = _regions[regionHint];
      if (region == null) return null;
      if (identical(region.root, elements)) {
        return DocumentListLocator(region: regionHint);
      }
      _ensureBuilt(regionHint, region);
      return region.locatorByList[elements];
    }
    for (final MapEntry<DocumentRegion, _RegionLocatorIndex> entry
        in _regions.entries) {
      if (identical(entry.value.root, elements)) {
        return DocumentListLocator(region: entry.key);
      }
    }
    for (final MapEntry<DocumentRegion, _RegionLocatorIndex> entry
        in _regions.entries) {
      _ensureBuilt(entry.key, entry.value);
      final DocumentListLocator? locator = entry.value.locatorByList[elements];
      if (locator != null) return locator;
    }
    return null;
  }

  DocumentElementLocator? captureElement(
    List<IElement> elements,
    int index, {
    DocumentRegion? regionHint,
  }) {
    if (index < 0 || index >= elements.length) return null;
    final DocumentListLocator? list =
        captureList(elements, regionHint: regionHint);
    if (list == null) return null;
    return DocumentElementLocator(
      list: list,
      index: index,
      elementId: elements[index].id,
    );
  }

  List<IElement>? resolveList(DocumentListLocator locator) {
    final _RegionLocatorIndex? region = _regions[locator.region];
    if (region == null) return null;
    if (locator.path.isEmpty) return region.root;
    _ensureBuilt(locator.region, region);
    final List<List<IElement>>? exactCandidates =
        region.listsByExactPath[locator._exactKey];
    if (exactCandidates?.length == 1) return exactCandidates!.single;

    // A paginacao pode recriar o id concreto de uma parte de tabela. O
    // fallback por pagingId e aceito somente se continuar inequivoco; headers
    // repetidos com os mesmos row/cell ids nunca escolhem uma parte ao acaso.
    final List<List<IElement>>? stableCandidates =
        region.listsByStablePath[locator._stableKey];
    if (stableCandidates == null || stableCandidates.length != 1) return null;
    return stableCandidates.single;
  }

  ResolvedDocumentElement? resolveElement(DocumentElementLocator locator) {
    final List<IElement>? elements = resolveList(locator.list);
    if (elements == null || elements.isEmpty) return null;

    final String? elementId = locator.elementId;
    if (elementId != null) {
      if (locator.index >= 0 &&
          locator.index < elements.length &&
          elements[locator.index].id == elementId) {
        return ResolvedDocumentElement(
          elements: elements,
          index: locator.index,
        );
      }
      final int byId =
          elements.indexWhere((IElement item) => item.id == elementId);
      if (byId >= 0) {
        return ResolvedDocumentElement(elements: elements, index: byId);
      }
    }
    if (locator.index < 0 || locator.index >= elements.length) return null;
    return ResolvedDocumentElement(
      elements: elements,
      index: locator.index,
    );
  }

  void _ensureBuilt(DocumentRegion region, _RegionLocatorIndex index) {
    if (index.isBuilt) return;
    index.build(region);
    _rebuildCount += 1;
  }
}

class _RegionLocatorIndex {
  _RegionLocatorIndex(this.root);

  final List<IElement> root;
  bool isBuilt = false;
  HashMap<List<IElement>, DocumentListLocator> locatorByList =
      HashMap<List<IElement>, DocumentListLocator>.identity();
  Map<String, List<List<IElement>>> listsByStablePath =
      <String, List<List<IElement>>>{};
  Map<String, List<List<IElement>>> listsByExactPath =
      <String, List<List<IElement>>>{};

  void invalidate() {
    isBuilt = false;
    locatorByList = HashMap<List<IElement>, DocumentListLocator>.identity();
    listsByStablePath = <String, List<List<IElement>>>{};
    listsByExactPath = <String, List<List<IElement>>>{};
  }

  void build(DocumentRegion region) {
    invalidate();
    _visitList(region, root, const <TableCellLocatorStep>[]);
    isBuilt = true;
  }

  void _visitList(
    DocumentRegion region,
    List<IElement> elements,
    List<TableCellLocatorStep> path,
  ) {
    final DocumentListLocator locator =
        DocumentListLocator(region: region, path: path);
    locatorByList[elements] = locator;
    (listsByStablePath[locator._stableKey] ??= <List<IElement>>[])
        .add(elements);
    (listsByExactPath[locator._exactKey] ??= <List<IElement>>[]).add(elements);

    for (int tableIndex = 0; tableIndex < elements.length; tableIndex++) {
      final IElement table = elements[tableIndex];
      if (table.type != ElementType.table || table.trList == null) continue;
      for (int rowIndex = 0; rowIndex < table.trList!.length; rowIndex++) {
        final ITr row = table.trList![rowIndex];
        for (int cellIndex = 0; cellIndex < row.tdList.length; cellIndex++) {
          final ITd cell = row.tdList[cellIndex];
          final TableCellLocatorStep step = TableCellLocatorStep(
            tableId: table.id,
            pagingId: table.pagingId,
            rowId: row.id,
            cellId: cell.id,
            tableIndex: tableIndex,
            rowIndex: rowIndex,
            cellIndex: cellIndex,
          );
          _visitList(
            region,
            cell.value,
            <TableCellLocatorStep>[...path, step],
          );
        }
      }
    }
  }
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (int index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
