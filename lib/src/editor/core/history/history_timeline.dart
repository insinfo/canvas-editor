/// One reversible transition in a [HistoryTimeline].
///
/// [before] and [after] are kept independently. In particular, preparing the
/// `before` endpoint of a later transition must not overwrite the `after`
/// endpoint used to redo an earlier transition.
class HistoryTransition<T> {
  const HistoryTransition({
    required this.before,
    required this.after,
    this.undoAction,
    this.redoAction,
  });

  final T before;
  final T after;
  final T? undoAction;
  final T? redoAction;
}

/// A UI-independent undo/redo timeline.
///
/// The first value recorded with [execute] establishes the baseline. Every
/// later value creates a transition from the current endpoint to the new one.
/// [replaceCurrent] changes only the endpoint that will become `before` in the
/// next transition; already-recorded transitions remain immutable.
///
/// The timeline only selects endpoints. It deliberately does not invoke them,
/// which keeps this class usable with callbacks, values, or command objects.
class HistoryTimeline<T> {
  final List<HistoryTransition<T>> _transitions = <HistoryTransition<T>>[];

  late T _current;
  bool _hasCurrent = false;
  int _cursor = 0;

  bool get canUndo => _cursor > 0;

  bool get canRedo => _cursor < _transitions.length;

  bool get isEmpty => !_hasCurrent && _transitions.isEmpty;

  int get transitionCount => _transitions.length;

  int get cursor => _cursor;

  /// Visits absolute endpoints still retained by the undo/redo window.
  ///
  /// Direct undo/redo actions are intentionally excluded. Consumers use this
  /// to find the oldest endpoint sharing a compact-restorer log without
  /// allocating a temporary collection on every edit.
  void visitRetainedEndpoints(void Function(T endpoint) visitor) {
    if (_hasCurrent) {
      visitor(_current);
    }
    for (final HistoryTransition<T> transition in _transitions) {
      visitor(transition.before);
      visitor(transition.after);
    }
  }

  /// Endpoint that restores the currently applied state.
  T? get current => _hasCurrent ? _current : null;

  /// Establishes the baseline or records a transition to [after].
  ///
  /// Recording after an undo discards the abandoned redo branch. When
  /// [maxTransitions] is supplied, the oldest transitions are evicted while
  /// the current endpoint is retained as the new baseline.
  void execute(
    T after, {
    T? undoAction,
    T? redoAction,
    int? maxTransitions,
  }) {
    _truncateRedoBranch();
    if (!_hasCurrent) {
      _current = after;
      _hasCurrent = true;
      return;
    }

    _transitions.add(
      HistoryTransition<T>(
        before: _current,
        after: after,
        undoAction: undoAction,
        redoAction: redoAction,
      ),
    );
    _cursor++;
    _current = after;
    _enforceLimit(maxTransitions);
  }

  /// Replaces the current boundary for the next transition.
  ///
  /// This is the operation used by delta producers to register their undo
  /// callback immediately before registering the corresponding redo callback
  /// with [execute]. It also starts a new branch when called after an undo.
  void replaceCurrent(T current) {
    _truncateRedoBranch();
    _current = current;
    _hasCurrent = true;
  }

  /// Moves one transition backwards and returns its `before` endpoint.
  T? undo() {
    if (!canUndo) {
      return null;
    }
    final HistoryTransition<T> transition = _transitions[_cursor - 1];
    _cursor--;
    _current = transition.before;
    _hasCurrent = true;
    return transition.undoAction ?? transition.before;
  }

  /// Moves one transition forwards and returns its `after` endpoint.
  T? redo() {
    if (!canRedo) {
      return null;
    }
    final HistoryTransition<T> transition = _transitions[_cursor];
    _cursor++;
    _current = transition.after;
    _hasCurrent = true;
    return transition.redoAction ?? transition.after;
  }

  /// Removes the latest applied endpoint without invoking it.
  ///
  /// A following [execute] then records a replacement transition from the
  /// removed transition's `before` endpoint, effectively squashing/replacing
  /// the last history record. If only a baseline exists, it is removed.
  T? popUndo() {
    if (_cursor > 0) {
      final HistoryTransition<T> removed = _transitions.removeAt(_cursor - 1);
      _cursor--;
      _current = removed.before;
      _hasCurrent = true;
      return removed.after;
    }
    if (!_hasCurrent) {
      return null;
    }
    final T removed = _current;
    _hasCurrent = false;
    return removed;
  }

  void clear() {
    _transitions.clear();
    _cursor = 0;
    _hasCurrent = false;
  }

  void _truncateRedoBranch() {
    if (_cursor < _transitions.length) {
      _transitions.removeRange(_cursor, _transitions.length);
    }
  }

  void _enforceLimit(int? maxTransitions) {
    if (maxTransitions == null) {
      return;
    }
    final int limit = maxTransitions < 0 ? 0 : maxTransitions;
    final int overflow = _transitions.length - limit;
    if (overflow <= 0) {
      return;
    }
    _transitions.removeRange(0, overflow);
    _cursor -= overflow;
  }
}
