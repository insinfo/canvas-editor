import '../draw/draw.dart';
import '../document/document_replay_delta.dart';
import 'history_restorer.dart';
import 'history_timeline.dart';

typedef HistoryCallback = void Function();

class HistoryManager {
  HistoryManager(Draw draw)
      : _draw = draw,
        _maxRecordCount = ((draw.getOptions().historyMaxRecordCount ?? 0) + 1);

  final Draw _draw;
  final int _maxRecordCount;
  final HistoryTimeline<HistoryRestorer> _timeline =
      HistoryTimeline<HistoryRestorer>();

  // Flag de teste (IEditorOption.historyDisabled): quando ligada, undo/redo
  // viram no-op e nada é empilhado. Ver submitHistory em draw.dart.
  bool get _isDisabled => _draw.getOptions().historyDisabled == true;

  void undo() {
    if (_isDisabled) {
      return;
    }
    // A rajada de digitação pendente precisa entrar na pilha antes do undo,
    // senão o estado corrente (fim da rajada) seria perdido para o redo.
    _draw.flushDeferredHistory();
    final HistoryRestorer? restorer = _timeline.undo();
    if (restorer != null) {
      _draw.runHistoryReplay(restorer.restore);
    }
  }

  void redo() {
    if (_isDisabled) {
      return;
    }
    _draw.flushDeferredHistory();
    final HistoryRestorer? restorer = _timeline.redo();
    if (restorer != null) {
      _draw.runHistoryReplay(restorer.restore);
    }
  }

  // Cada snapshot de undo é um deep-clone do documento inteiro (edições mutam
  // IElement in-place, então clone raso corromperia snapshots antigos). Num
  // DOCX de 150 páginas (~122k elementos) reter os 100 snapshots default
  // estourava a memória do navegador (~6 GB). Limitamos o total de elementos
  // retidos a um orçamento, mantendo pelo menos alguns níveis de undo.
  static const int _retainedElementBudget = 400000;
  static const int _minRecordCount = 4;

  int _effectiveMaxRecords() {
    final int docSize = _draw.getElementList().length;
    if (docSize <= 0) {
      return _maxRecordCount;
    }
    final int byBudget = _retainedElementBudget ~/ docSize;
    if (byBudget >= _maxRecordCount) {
      return _maxRecordCount;
    }
    return byBudget < _minRecordCount ? _minRecordCount : byBudget;
  }

  void execute(HistoryCallback callback) {
    if (_isDisabled) {
      return;
    }
    final int limit = _effectiveMaxRecords();
    _timeline.execute(
      HistoryRestorer.absolute(callback),
      maxTransitions: limit - 1,
    );
  }

  /// Records a compact change while keeping timeline endpoints absolute.
  ///
  /// Delta callbacks by themselves are relative ("insert these elements").
  /// Storing one directly as an endpoint corrupts mixed histories because the
  /// next snapshot-based transition may invoke it from an unrelated state.
  /// Appending it to the current flat restorer makes the new endpoint
  /// idempotent: restore the previous absolute state, then replay its deltas.
  /// The delta log is iterative and shared; this avoids the recursive closure
  /// chain previously built by every Enter/typing/delete transition.
  void executeDelta({
    required HistoryCallback revert,
    required HistoryCallback apply,
    DocumentReplayDelta? checkpointDelta,
  }) {
    if (_isDisabled) {
      return;
    }
    final HistoryRestorer? restoreBefore = _timeline.current;
    if (restoreBefore == null) {
      throw StateError('delta history requires an absolute baseline');
    }
    final HistoryRestorer restoreAfter = restoreBefore.appendDelta(
      apply,
      checkpointDelta: checkpointDelta,
    );

    final int limit = _effectiveMaxRecords();
    _timeline.execute(
      restoreAfter,
      undoAction: HistoryRestorer.action(revert),
      redoAction: HistoryRestorer.action(apply),
      maxTransitions: limit - 1,
    );
    _compactCurrentRestorer();
  }

  void _compactCurrentRestorer() {
    final HistoryRestorer? current = _timeline.current;
    if (current == null) {
      return;
    }
    HistoryRestorer oldest = current;
    _timeline.visitRetainedEndpoints((HistoryRestorer endpoint) {
      if (current.sharesDeltaStorageWith(endpoint) &&
          endpoint.deltaCount < oldest.deltaCount) {
        oldest = endpoint;
      }
    });
    current.compactBefore(oldest);
  }

  HistoryCallback? get currentRestorer {
    final HistoryRestorer? current = _timeline.current;
    return current?.restore;
  }

  /// Depth of the flat delta prefix after the latest absolute snapshot.
  int get currentRestorerDeltaCount => _timeline.current?.deltaCount ?? 0;

  /// Retained callbacks in the current restorer's shared delta storage.
  int get currentRestorerRetainedCallbackCount =>
      _timeline.current?.retainedDeltaCallbackCount ?? 0;

  int get currentCheckpointReplayOperationCount =>
      _timeline.current?.checkpointReplayOperationCount ?? 0;

  int get currentCheckpointPayloadUnits =>
      _timeline.current?.checkpointPayloadUnits ?? 0;

  int get currentRetainedWindowPayloadUnits =>
      _timeline.current?.retainedWindowPayloadUnits ?? 0;

  int get currentCheckpointBarrierCount =>
      _timeline.current?.checkpointBarrierCount ?? 0;

  void replaceCurrent(HistoryCallback callback) {
    if (_isDisabled) {
      return;
    }
    _timeline.replaceCurrent(HistoryRestorer.absolute(callback));
  }

  bool isCanUndo() => _timeline.canUndo;

  bool isCanRedo() => _timeline.canRedo;

  bool isStackEmpty() => _timeline.isEmpty;

  int get transitionCount => _timeline.transitionCount;

  int get cursor => _timeline.cursor;

  void recovery() {
    // O documento vai ser substituído: um snapshot adiado do doc antigo
    // não pode vazar para a pilha nova.
    _draw.cancelDeferredHistory();
    _timeline.clear();
  }

  HistoryCallback? popUndo() {
    final HistoryRestorer? removed = _timeline.popUndo();
    return removed?.restore;
  }
}
