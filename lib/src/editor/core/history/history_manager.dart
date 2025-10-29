// TODO: Translate from C:\\MyTsProjects\\canvas-editor\\src\\editor\\core\\history\\HistoryManager.ts
typedef HistoryCallback = void Function();

class HistoryManager {
	HistoryManager(dynamic draw)
			: _maxRecordCount = (draw.getOptions()?.historyMaxRecordCount as int? ?? 0) + 1;

	final int _maxRecordCount;
	final List<HistoryCallback> _undoStack = <HistoryCallback>[];
	final List<HistoryCallback> _redoStack = <HistoryCallback>[];

	void undo() {
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
		_undoStack.clear();
		_redoStack.clear();
	}

	HistoryCallback? popUndo() => _undoStack.isNotEmpty ? _undoStack.removeLast() : null;
}