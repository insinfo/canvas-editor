import '../document/document_replay_delta.dart';

typedef HistoryRestoreCallback = void Function();

/// An absolute endpoint plus a bounded window of full replay callbacks.
///
/// Once a delta leaves the undo window, [compactBefore] folds its model-only
/// [DocumentReplayDelta] into a mutable forward checkpoint and releases the
/// full callback (and its undo payload/view state closure). The oldest
/// reachable endpoint itself is never folded, so at least one retained
/// callback still restores the exact range/view/render state.
///
/// For a linear history, append is O(1). Restore is one absolute baseline, the
/// compact checkpoint operations, and at most the retained undo window of full
/// callbacks. Branching after undo copies the checkpoint once; that uncommon
/// path is O(checkpoint payload) and isolates the abandoned redo branch.
class HistoryRestorer {
  HistoryRestorer.absolute(HistoryRestoreCallback restoreAbsolute)
      : _restoreAbsolute = restoreAbsolute,
        _log = _HistoryDeltaLog(),
        _sequence = 0;

  /// Direct undo/redo action; it owns no checkpoint or delta log.
  HistoryRestorer.action(HistoryRestoreCallback action)
      : _restoreAbsolute = action,
        _log = null,
        _sequence = 0;

  HistoryRestorer._(
    this._restoreAbsolute,
    this._log,
    this._sequence,
  );

  final HistoryRestoreCallback _restoreAbsolute;
  final _HistoryDeltaLog? _log;
  final int _sequence;

  /// Logical number of deltas since this absolute endpoint.
  int get deltaCount => _sequence;

  /// Full apply callbacks still retained after checkpoint compaction.
  int get retainedDeltaCallbackCount => _log?.entries.length ?? 0;

  /// Primitive model operations performed by the compact checkpoint.
  int get checkpointReplayOperationCount =>
      _log?.checkpoint.replayOperationCount ?? 0;

  /// Forward payload needed to recreate the net checkpoint state.
  int get checkpointPayloadUnits => _log?.checkpoint.retainedPayloadUnits ?? 0;

  /// Undo/redo payload retained by the callback window (not the checkpoint).
  int get retainedWindowPayloadUnits {
    final _HistoryDeltaLog? log = _log;
    if (log == null) return 0;
    var result = 0;
    for (final _HistoryDeltaEntry entry in log.entries) {
      result += entry.checkpointDelta?.retainedPayloadUnits ?? 0;
    }
    return result;
  }

  /// Number of opaque callbacks currently blocking further compaction.
  int get checkpointBarrierCount {
    final _HistoryDeltaLog? log = _log;
    if (log == null) return 0;
    return log.entries
        .where((_HistoryDeltaEntry entry) => entry.checkpointDelta == null)
        .length;
  }

  bool sharesDeltaStorageWith(HistoryRestorer other) =>
      _log != null && identical(_log, other._log);

  /// Appends one full history delta and its optional model-only checkpoint.
  ///
  /// [checkpointDelta] must represent the same model mutation as [apply], but
  /// without view restoration or rendering. A null value is an explicit
  /// compaction barrier and remains as a full callback while reachable.
  HistoryRestorer appendDelta(
    HistoryRestoreCallback apply, {
    DocumentReplayDelta? checkpointDelta,
  }) {
    final _HistoryDeltaLog? currentLog = _log;
    if (currentLog == null) {
      throw StateError('cannot append a delta to a direct history action');
    }
    final _HistoryDeltaLog targetLog;
    if (_sequence == currentLog.latestSequence) {
      targetLog = currentLog;
    } else {
      targetLog = currentLog.forkAt(_sequence);
    }
    final int sequence = targetLog.append(
      apply,
      checkpointDelta: checkpointDelta,
    );
    return HistoryRestorer._(_restoreAbsolute, targetLog, sequence);
  }

  /// Folds callbacks strictly older than [oldestReachable] into the checkpoint.
  ///
  /// Both endpoints must share the same log. The strict boundary preserves the
  /// callback that finalizes view state for the oldest undoable endpoint.
  void compactBefore(HistoryRestorer oldestReachable) {
    final _HistoryDeltaLog? log = _log;
    if (log == null || !identical(log, oldestReachable._log)) {
      return;
    }
    log.compactThrough(oldestReachable._sequence - 1);
  }

  /// Restores this endpoint with bounded callback replay.
  void restore() {
    _restoreAbsolute();
    final _HistoryDeltaLog? log = _log;
    if (log == null) {
      return;
    }
    if (_sequence < log.compactedThrough) {
      throw StateError(
          'history endpoint was evicted from the compacted window');
    }
    log.checkpoint.replay();
    for (final _HistoryDeltaEntry entry in log.entries) {
      if (entry.sequence > _sequence) {
        break;
      }
      entry.apply();
    }
  }
}

class _HistoryDeltaEntry {
  const _HistoryDeltaEntry({
    required this.sequence,
    required this.apply,
    required this.checkpointDelta,
  });

  final int sequence;
  final HistoryRestoreCallback apply;
  final DocumentReplayDelta? checkpointDelta;
}

class _HistoryDeltaLog {
  _HistoryDeltaLog()
      : checkpoint = _HistoryCheckpoint(),
        entries = <_HistoryDeltaEntry>[];

  _HistoryDeltaLog._({
    required this.latestSequence,
    required this.compactedThrough,
    required this.checkpoint,
    required this.entries,
  });

  int latestSequence = 0;
  int compactedThrough = 0;
  final _HistoryCheckpoint checkpoint;
  final List<_HistoryDeltaEntry> entries;

  int append(
    HistoryRestoreCallback apply, {
    DocumentReplayDelta? checkpointDelta,
  }) {
    latestSequence += 1;
    entries.add(
      _HistoryDeltaEntry(
        sequence: latestSequence,
        apply: apply,
        checkpointDelta: checkpointDelta,
      ),
    );
    return latestSequence;
  }

  void compactThrough(int targetSequence) {
    if (targetSequence <= compactedThrough || entries.isEmpty) {
      return;
    }
    var compactCount = 0;
    for (final _HistoryDeltaEntry entry in entries) {
      if (entry.sequence > targetSequence) {
        break;
      }
      final DocumentReplayDelta? delta = entry.checkpointDelta;
      if (delta == null) {
        break;
      }
      checkpoint.append(delta);
      compactedThrough = entry.sequence;
      compactCount += 1;
    }
    if (compactCount > 0) {
      entries.removeRange(0, compactCount);
    }
  }

  _HistoryDeltaLog forkAt(int sequence) {
    if (sequence < compactedThrough || sequence > latestSequence) {
      throw StateError('cannot branch outside the retained history window');
    }
    return _HistoryDeltaLog._(
      latestSequence: sequence,
      compactedThrough: compactedThrough,
      checkpoint: checkpoint.copy(),
      entries: entries
          .where((_HistoryDeltaEntry entry) => entry.sequence <= sequence)
          .toList(growable: true),
    );
  }
}

class _HistoryCheckpoint {
  _HistoryCheckpoint() : _deltas = <DocumentReplayDelta>[];

  _HistoryCheckpoint._(this._deltas);

  final List<DocumentReplayDelta> _deltas;

  int get replayOperationCount {
    var result = 0;
    for (final DocumentReplayDelta delta in _deltas) {
      result += delta.replayOperationCount;
    }
    return result;
  }

  int get retainedPayloadUnits {
    var result = 0;
    for (final DocumentReplayDelta delta in _deltas) {
      result += delta.retainedPayloadUnits;
    }
    return result;
  }

  void append(DocumentReplayDelta delta) {
    if (_deltas.isNotEmpty && _deltas.last.tryMergeCheckpoint(delta)) {
      return;
    }
    _deltas.add(delta.copyForCheckpoint());
  }

  void replay() {
    for (final DocumentReplayDelta delta in _deltas) {
      delta.replay();
    }
  }

  _HistoryCheckpoint copy() => _HistoryCheckpoint._(
        _deltas
            .map((DocumentReplayDelta delta) => delta.copyForCheckpoint())
            .toList(growable: true),
      );
}
