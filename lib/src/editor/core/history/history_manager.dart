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

	void undo() {
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
		_draw.flushDeferredHistory();
		if (_redoStack.isNotEmpty) {
			final HistoryCallback pop = _redoStack.removeLast();
			_undoStack.add(pop);
			pop();
		}
	}

	void execute(HistoryCallback callback) {
		_undoStack.add(callback);
		if (_redoStack.isNotEmpty) {
			_redoStack.clear();
		}
		while (_undoStack.length > _maxRecordCount) {
			_undoStack.removeAt(0);
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