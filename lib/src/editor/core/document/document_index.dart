import 'dart:collection';

import '../../dataset/constant/common.dart' show ZERO;
import '../../interface/element.dart';
import 'document_range.dart';

/// Lazy, UI-independent indexes over one document element list.
///
/// Structural maps are invalidated in O(1) after a splice and rebuilt only on
/// the next structural lookup. Paragraph starts use an ordered tree with lazy
/// tail shifts, so inserting one character does not renumber every later
/// paragraph boundary.
class DocumentIndex {
  DocumentIndex(this._elements);

  final List<IElement> _elements;

  Map<String, int>? _idToIndex;
  Map<String, List<int>>? _tableIdToIndexes;
  Map<String, List<int>>? _pagingIdToIndexes;
  int _structuralRebuildCount = 0;

  _ParagraphBoundaryNode? _paragraphStarts;
  bool _paragraphStartsBuilt = false;
  int _priorityState = 0x13579bdf;

  /// Diagnostic counter useful for asserting that mutations stay lazy.
  int get structuralRebuildCount => _structuralRebuildCount;

  /// Returns the first element index with [id], or `null` when absent.
  int? lookupById(String id) {
    _ensureStructuralMaps();
    return _idToIndex![id];
  }

  /// Returns all flat-list indexes whose `tableId` equals [tableId].
  List<int> lookupByTableId(String tableId) {
    _ensureStructuralMaps();
    final List<int>? indexes = _tableIdToIndexes![tableId];
    return indexes == null ? const <int>[] : UnmodifiableListView<int>(indexes);
  }

  /// Returns all flat-list indexes whose `pagingId` equals [pagingId].
  List<int> lookupByPagingId(String pagingId) {
    _ensureStructuralMaps();
    final List<int>? indexes = _pagingIdToIndexes![pagingId];
    return indexes == null ? const <int>[] : UnmodifiableListView<int>(indexes);
  }

  /// Returns the inclusive paragraph range containing [index].
  ///
  /// Index zero always starts the first paragraph. Every later element whose
  /// value is [ZERO] starts another paragraph.
  DocumentRange paragraphRangeAt(int index) {
    if (index < 0 || index >= _elements.length) {
      throw RangeError.index(index, _elements, 'index');
    }
    _ensureParagraphStarts();
    final int start = _predecessor(_paragraphStarts, index) ?? 0;
    final int? nextStart = _successor(_paragraphStarts, index);
    return DocumentRange(start, (nextStart ?? _elements.length) - 1);
  }

  /// Updates this index after the backing list has already been spliced.
  void onSplice({
    required int start,
    required int deleteCount,
    required int insertCount,
  }) {
    if (start < 0 || deleteCount < 0 || insertCount < 0) {
      throw RangeError('splice values must be non-negative');
    }
    final int oldLength = _elements.length - insertCount + deleteCount;
    if (start > oldLength || start + deleteCount > oldLength) {
      throw RangeError('splice exceeds the previous element list');
    }
    if (start + insertCount > _elements.length) {
      throw RangeError('inserted range exceeds the current element list');
    }

    invalidateStructuralMaps();
    if (!_paragraphStartsBuilt) {
      return;
    }

    final int deletedEnd = start + deleteCount;
    final bool shiftedSyntheticFirstBoundary = start == 0 &&
        deleteCount == 0 &&
        oldLength > 0 &&
        _elements[insertCount].value != ZERO;
    final _BoundarySplit beforeDeleted =
        _splitParagraphStarts(_paragraphStarts, start);
    final _BoundarySplit afterDeleted =
        _splitParagraphStarts(beforeDeleted.right, deletedEnd);
    final int shift = insertCount - deleteCount;
    _shiftSubtree(afterDeleted.right, shift);
    _paragraphStarts =
        _mergeParagraphStarts(beforeDeleted.left, afterDeleted.right);
    if (shiftedSyntheticFirstBoundary) {
      _paragraphStarts = _removeParagraphStart(_paragraphStarts, insertCount);
    }

    for (int i = 0; i < insertCount; i++) {
      final int index = start + i;
      if (_elements[index].value == ZERO) {
        _paragraphStarts = _insertParagraphStart(_paragraphStarts, index);
      }
    }

    if (_elements.isEmpty) {
      _paragraphStarts = null;
    } else {
      _paragraphStarts = _insertParagraphStart(_paragraphStarts, 0);
    }
  }

  /// Invalidates only maps that depend on structural identifiers.
  void invalidateStructuralMaps() {
    _idToIndex = null;
    _tableIdToIndexes = null;
    _pagingIdToIndexes = null;
  }

  /// Resets all cached data after the backing list is replaced wholesale.
  void reset() {
    invalidateStructuralMaps();
    _paragraphStarts = null;
    _paragraphStartsBuilt = false;
  }

  void _ensureStructuralMaps() {
    if (_idToIndex != null) {
      return;
    }
    final Map<String, int> ids = <String, int>{};
    final Map<String, List<int>> tableIds = <String, List<int>>{};
    final Map<String, List<int>> pagingIds = <String, List<int>>{};
    for (int index = 0; index < _elements.length; index++) {
      final IElement element = _elements[index];
      final String? id = element.id;
      if (id != null) {
        ids.putIfAbsent(id, () => index);
      }
      final String? tableId = element.tableId;
      if (tableId != null) {
        (tableIds[tableId] ??= <int>[]).add(index);
      }
      final String? pagingId = element.pagingId;
      if (pagingId != null) {
        (pagingIds[pagingId] ??= <int>[]).add(index);
      }
    }
    _idToIndex = ids;
    _tableIdToIndexes = tableIds;
    _pagingIdToIndexes = pagingIds;
    _structuralRebuildCount++;
  }

  void _ensureParagraphStarts() {
    if (_paragraphStartsBuilt) {
      return;
    }
    _paragraphStarts = null;
    if (_elements.isNotEmpty) {
      _paragraphStarts = _insertParagraphStart(_paragraphStarts, 0);
      for (int index = 1; index < _elements.length; index++) {
        if (_elements[index].value == ZERO) {
          _paragraphStarts = _insertParagraphStart(_paragraphStarts, index);
        }
      }
    }
    _paragraphStartsBuilt = true;
  }

  _ParagraphBoundaryNode? _insertParagraphStart(
    _ParagraphBoundaryNode? root,
    int key,
  ) {
    if (_contains(root, key)) {
      return root;
    }
    final _BoundarySplit split = _splitParagraphStarts(root, key);
    final _ParagraphBoundaryNode inserted =
        _ParagraphBoundaryNode(key, _nextPriority());
    return _mergeParagraphStarts(
      _mergeParagraphStarts(split.left, inserted),
      split.right,
    );
  }

  _ParagraphBoundaryNode? _removeParagraphStart(
    _ParagraphBoundaryNode? root,
    int key,
  ) {
    final _BoundarySplit before = _splitParagraphStarts(root, key);
    final _BoundarySplit after = _splitParagraphStarts(before.right, key + 1);
    return _mergeParagraphStarts(before.left, after.right);
  }

  int _nextPriority() {
    _priorityState = (_priorityState * 1103515245 + 12345) & 0x7fffffff;
    return _priorityState;
  }
}

class _ParagraphBoundaryNode {
  _ParagraphBoundaryNode(this.key, this.priority);

  int key;
  final int priority;
  int pendingShift = 0;
  _ParagraphBoundaryNode? left;
  _ParagraphBoundaryNode? right;
}

class _BoundarySplit {
  const _BoundarySplit(this.left, this.right);

  final _ParagraphBoundaryNode? left;
  final _ParagraphBoundaryNode? right;
}

void _shiftSubtree(_ParagraphBoundaryNode? node, int shift) {
  if (node == null || shift == 0) {
    return;
  }
  node.key += shift;
  node.pendingShift += shift;
}

void _pushShift(_ParagraphBoundaryNode node) {
  final int shift = node.pendingShift;
  if (shift == 0) {
    return;
  }
  _shiftSubtree(node.left, shift);
  _shiftSubtree(node.right, shift);
  node.pendingShift = 0;
}

_BoundarySplit _splitParagraphStarts(
  _ParagraphBoundaryNode? root,
  int key,
) {
  if (root == null) {
    return const _BoundarySplit(null, null);
  }
  _pushShift(root);
  if (root.key < key) {
    final _BoundarySplit split = _splitParagraphStarts(root.right, key);
    root.right = split.left;
    return _BoundarySplit(root, split.right);
  }
  final _BoundarySplit split = _splitParagraphStarts(root.left, key);
  root.left = split.right;
  return _BoundarySplit(split.left, root);
}

_ParagraphBoundaryNode? _mergeParagraphStarts(
  _ParagraphBoundaryNode? left,
  _ParagraphBoundaryNode? right,
) {
  if (left == null) {
    return right;
  }
  if (right == null) {
    return left;
  }
  if (left.priority >= right.priority) {
    _pushShift(left);
    left.right = _mergeParagraphStarts(left.right, right);
    return left;
  }
  _pushShift(right);
  right.left = _mergeParagraphStarts(left, right.left);
  return right;
}

bool _contains(_ParagraphBoundaryNode? root, int key) {
  _ParagraphBoundaryNode? current = root;
  while (current != null) {
    _pushShift(current);
    if (key == current.key) {
      return true;
    }
    current = key < current.key ? current.left : current.right;
  }
  return false;
}

int? _predecessor(_ParagraphBoundaryNode? root, int key) {
  _ParagraphBoundaryNode? current = root;
  int? result;
  while (current != null) {
    _pushShift(current);
    if (current.key <= key) {
      result = current.key;
      current = current.right;
    } else {
      current = current.left;
    }
  }
  return result;
}

int? _successor(_ParagraphBoundaryNode? root, int key) {
  _ParagraphBoundaryNode? current = root;
  int? result;
  while (current != null) {
    _pushShift(current);
    if (current.key > key) {
      result = current.key;
      current = current.left;
    } else {
      current = current.right;
    }
  }
  return result;
}
