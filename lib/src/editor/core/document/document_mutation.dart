import '../../interface/element.dart';
import 'document_replay_delta.dart';
import 'document_range.dart';

/// Custo minimo necessario para refletir uma mutacao na tela.
enum DocumentMutationImpact {
  repaintOnly,
  paragraphLayout,
  tableLayout,
  fullLayout,
}

/// Unidade reversivel de alteracao do documento.
///
/// Mutations nao desenham e nao conhecem canvas. Elas descrevem o intervalo e
/// o impacto, permitindo que historico e layout tomem a mesma decisao.
abstract class DocumentMutation {
  DocumentRange get affectedRange;

  DocumentMutationImpact get impact;

  void apply();

  void revert();

  bool canMergeWith(DocumentMutation next) => false;
}

typedef ElementSpliceCallback = void Function(
  int start,
  int deleteCount,
  List<IElement> replacement,
);

typedef ElementCloneList = List<IElement> Function(Iterable<IElement> source);

/// Delta estrutural compacto para digitacao, delete, backspace e paste.
///
/// Somente os elementos removidos/inseridos sao clonados; o documento inteiro
/// nunca entra no registro de historico.
class ElementSpliceMutation extends DocumentMutation
    implements DocumentReplayDelta {
  ElementSpliceMutation({
    required this.start,
    required List<IElement> removed,
    required List<IElement> inserted,
    required ElementSpliceCallback splice,
    required ElementCloneList cloneElements,
    this.replayDomain,
    this.impact = DocumentMutationImpact.paragraphLayout,
  })  : _removed = cloneElements(removed),
        _inserted = cloneElements(inserted),
        _splice = splice,
        _cloneElements = cloneElements;

  int start;
  final List<IElement> _removed;
  final List<IElement> _inserted;
  final ElementSpliceCallback _splice;
  final ElementCloneList _cloneElements;

  /// Stable identity of the addressed list (normally a DocumentListLocator).
  /// Checkpoint compaction never merges splices from different domains.
  final Object? replayDomain;

  @override
  final DocumentMutationImpact impact;

  List<IElement> get removed => _cloneElements(_removed);

  List<IElement> get inserted => _cloneElements(_inserted);

  @override
  DocumentRange get affectedRange {
    final int span =
        _removed.length > _inserted.length ? _removed.length : _inserted.length;
    return DocumentRange(start, start + (span > 0 ? span - 1 : 0));
  }

  @override
  void apply() {
    _splice(
      start,
      _removed.length,
      _cloneElements(_inserted),
    );
  }

  @override
  void replay() => apply();

  @override
  void revert() {
    _splice(
      start,
      _inserted.length,
      _cloneElements(_removed),
    );
  }

  @override
  bool canMergeWith(DocumentMutation next) {
    if (next is! ElementSpliceMutation || next.impact != impact) {
      return false;
    }
    final int thisAfter = start + _inserted.length;
    final int nextAfter = next.start + next._inserted.length;
    final int thisRemovedAfter = start + _removed.length;
    final int nextRemovedAfter = next.start + next._removed.length;
    return next.start == thisAfter ||
        nextAfter == start ||
        next.start == start ||
        nextRemovedAfter == start ||
        thisRemovedAfter == next.start;
  }

  /// Coalesces the common text-edit sequences into this single splice.
  ///
  /// Both mutations have already been applied to the live document. This only
  /// compacts their retained before/after payload so history replay performs
  /// one splice instead of one splice per key.
  bool tryMergeWith(ElementSpliceMutation next) {
    if (next.impact != impact || !_sameReplayDomain(next.replayDomain)) {
      return false;
    }

    // Typing (including typing after replacing a selection): the next pure
    // insertion lands somewhere in the segment inserted by this mutation.
    if (next._removed.isEmpty &&
        next._inserted.isNotEmpty &&
        next.start >= start &&
        next.start <= start + _inserted.length) {
      _inserted.insertAll(next.start - start, next._inserted);
      return true;
    }

    // Delete keeps removing at the same index in the post-mutation document.
    if (_inserted.isEmpty && next._inserted.isEmpty && next.start == start) {
      _removed.addAll(next._removed);
      return true;
    }

    // Backspace removes the element immediately before the retained range.
    if (_inserted.isEmpty &&
        next._inserted.isEmpty &&
        next.start + next._removed.length == start) {
      start = next.start;
      _removed.insertAll(0, next._removed);
      return true;
    }

    return false;
  }

  @override
  DocumentReplayDelta copyForCheckpoint() => _ElementSpliceCheckpointDelta(
        start: start,
        deleteCount: _removed.length,
        inserted: List<IElement>.of(_inserted),
        splice: _splice,
        cloneElements: _cloneElements,
        replayDomain: replayDomain,
      );

  @override
  bool tryMergeCheckpoint(DocumentReplayDelta next) => false;

  @override
  int get replayOperationCount => 1;

  @override
  int get retainedPayloadUnits => _removed.length + _inserted.length;

  bool _sameReplayDomain(Object? other) {
    if (replayDomain == null || other == null) {
      return replayDomain == null && other == null;
    }
    return replayDomain == other;
  }
}

/// Forward-only splice used after its undo transition left the retained
/// history window. Removed element values are deliberately not kept.
class _ElementSpliceCheckpointDelta implements DocumentReplayDelta {
  _ElementSpliceCheckpointDelta({
    required this.start,
    required this.deleteCount,
    required List<IElement> inserted,
    required ElementSpliceCallback splice,
    required ElementCloneList cloneElements,
    required this.replayDomain,
  })  : _inserted = inserted,
        _splice = splice,
        _cloneElements = cloneElements;

  int start;
  int deleteCount;
  final List<IElement> _inserted;
  final ElementSpliceCallback _splice;
  final ElementCloneList _cloneElements;
  final Object? replayDomain;

  @override
  void replay() {
    _splice(start, deleteCount, _cloneElements(_inserted));
  }

  @override
  DocumentReplayDelta copyForCheckpoint() => _ElementSpliceCheckpointDelta(
        start: start,
        deleteCount: deleteCount,
        inserted: List<IElement>.of(_inserted),
        splice: _splice,
        cloneElements: _cloneElements,
        replayDomain: replayDomain,
      );

  @override
  bool tryMergeCheckpoint(DocumentReplayDelta next) {
    final _ForwardSpliceData? candidate = _forwardSpliceData(next);
    if (candidate == null || !_sameReplayDomain(candidate.replayDomain)) {
      return false;
    }

    // Sequential insertions, including insertion after replacing a selection.
    if (candidate.deleteCount == 0 &&
        candidate.inserted.isNotEmpty &&
        candidate.start >= start &&
        candidate.start <= start + _inserted.length) {
      _inserted.insertAll(candidate.start - start, candidate.inserted);
      return true;
    }

    // Repeated Delete at the same post-splice position.
    if (_inserted.isEmpty &&
        candidate.inserted.isEmpty &&
        candidate.start == start) {
      deleteCount += candidate.deleteCount;
      return true;
    }

    // Repeated Backspace extends the deleted interval to the left.
    if (_inserted.isEmpty &&
        candidate.inserted.isEmpty &&
        candidate.start + candidate.deleteCount == start) {
      start = candidate.start;
      deleteCount += candidate.deleteCount;
      return true;
    }

    return false;
  }

  @override
  int get replayOperationCount => 1;

  @override
  int get retainedPayloadUnits => _inserted.length;

  bool _sameReplayDomain(Object? other) {
    if (replayDomain == null || other == null) {
      return replayDomain == null && other == null;
    }
    return replayDomain == other;
  }
}

class _ForwardSpliceData {
  const _ForwardSpliceData({
    required this.start,
    required this.deleteCount,
    required this.inserted,
    required this.replayDomain,
  });

  final int start;
  final int deleteCount;
  final List<IElement> inserted;
  final Object? replayDomain;
}

_ForwardSpliceData? _forwardSpliceData(DocumentReplayDelta delta) {
  if (delta is ElementSpliceMutation) {
    return _ForwardSpliceData(
      start: delta.start,
      deleteCount: delta._removed.length,
      inserted: delta._inserted,
      replayDomain: delta.replayDomain,
    );
  }
  if (delta is _ElementSpliceCheckpointDelta) {
    return _ForwardSpliceData(
      start: delta.start,
      deleteCount: delta.deleteCount,
      inserted: delta._inserted,
      replayDomain: delta.replayDomain,
    );
  }
  return null;
}

/// Delta de propriedades para formatacao de uma selecao.
class ElementSnapshotMutation extends DocumentMutation {
  ElementSnapshotMutation.capture({
    required List<IElement> elements,
    required Iterable<int> indexes,
    required this.impact,
    required ElementCloneList cloneElements,
  })  : _elements = elements,
        _cloneElements = cloneElements,
        indexes = indexes.toSet().toList()..sort() {
    if (this.indexes.isEmpty) {
      throw ArgumentError.value(indexes, 'indexes', 'must not be empty');
    }
    _before = _snapshot();
  }

  final List<IElement> _elements;
  final ElementCloneList _cloneElements;
  final List<int> indexes;

  @override
  final DocumentMutationImpact impact;

  late final List<IElement> _before;
  List<IElement>? _after;

  bool get isCaptured => _after != null;

  void captureAfter() {
    _after = _snapshot();
  }

  @override
  DocumentRange get affectedRange => DocumentRange(indexes.first, indexes.last);

  @override
  void apply() {
    final List<IElement>? after = _after;
    if (after == null) {
      throw StateError('captureAfter must be called before apply');
    }
    _restore(after);
  }

  @override
  void revert() => _restore(_before);

  List<IElement> _snapshot() {
    final List<IElement> selected = <IElement>[];
    for (final int index in indexes) {
      if (index < 0 || index >= _elements.length) {
        throw RangeError.index(index, _elements, 'indexes');
      }
      selected.add(_elements[index]);
    }
    return _cloneElements(selected);
  }

  void _restore(List<IElement> snapshot) {
    if (snapshot.length != indexes.length) {
      throw StateError('snapshot/index length mismatch');
    }
    for (int i = 0; i < indexes.length; i++) {
      final int index = indexes[i];
      if (index < 0 || index >= _elements.length) {
        throw RangeError.index(index, _elements, 'indexes');
      }
      _elements[index] = _cloneElements(<IElement>[snapshot[i]]).first;
    }
  }
}
