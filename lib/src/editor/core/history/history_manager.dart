import '../draw/draw.dart';

typedef HistoryCallback = void Function();

class HistoryManager {
	HistoryManager(Draw draw)
			: _draw = draw,
			_maxRecordCount = ((draw.getOptions().historyMaxRecordCount ?? 0) + 1);

	final Draw _draw;
	final int _maxRecordCount;
	final List<HistoryCallback> _undoStack = <HistoryCallback>[];
	final List<HistoryCallback> _redoStack = <HistoryCallback>[];

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
		if (_undoStack.length > 1) {
			final HistoryCallback pop = _undoStack.removeLast();
			_redoStack.add(pop);
			if (_undoStack.isNotEmpty) {
				final HistoryCallback top = _undoStack.last;
				top();
			}
		}
	}

	void redo() {
		if (_isDisabled) {
			return;
		}
		_draw.flushDeferredHistory();
		if (_redoStack.isNotEmpty) {
			final HistoryCallback pop = _redoStack.removeLast();
			_undoStack.add(pop);
			pop();
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
		_undoStack.add(callback);
		if (_redoStack.isNotEmpty) {
			_redoStack.clear();
		}
		final int limit = _effectiveMaxRecords();
		while (_undoStack.length > limit) {
			_undoStack.removeAt(0);
		}
	}

	void replaceCurrent(HistoryCallback callback) {
		if (_isDisabled) {
			return;
		}
		if (_undoStack.isEmpty) {
			execute(callback);
			return;
		}
		_undoStack[_undoStack.length - 1] = callback;
		if (_redoStack.isNotEmpty) {
			_redoStack.clear();
		}
	}

	bool isCanUndo() => _undoStack.length > 1;

	bool isCanRedo() => _redoStack.isNotEmpty;

	bool isStackEmpty() => _undoStack.isEmpty && _redoStack.isEmpty;

	void recovery() {
		// O documento vai ser substituído: um snapshot adiado do doc antigo
		// não pode vazar para a pilha nova.
		_draw.cancelDeferredHistory();
		_undoStack.clear();
		_redoStack.clear();
	}

	HistoryCallback? popUndo() => _undoStack.isNotEmpty ? _undoStack.removeLast() : null;
}
