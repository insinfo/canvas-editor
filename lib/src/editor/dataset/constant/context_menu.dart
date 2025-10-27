class ContextMenuNamePlaceholder {
	ContextMenuNamePlaceholder._();

	static const String selectedText = '%s';
}

class InternalContextMenuKey {
	InternalContextMenuKey._();

	static const InternalContextMenuKeyGlobal global = InternalContextMenuKeyGlobal._();
	static const InternalContextMenuKeyControl control = InternalContextMenuKeyControl._();
	static const InternalContextMenuKeyHyperlink hyperlink = InternalContextMenuKeyHyperlink._();
	static const InternalContextMenuKeyImage image = InternalContextMenuKeyImage._();
	static const InternalContextMenuKeyTable table = InternalContextMenuKeyTable._();
}

class InternalContextMenuKeyGlobal {
	const InternalContextMenuKeyGlobal._();

	final String cut = 'globalCut';
	final String copy = 'globalCopy';
	final String paste = 'globalPaste';
	final String selectAll = 'globalSelectAll';
	final String print = 'globalPrint';
}

class InternalContextMenuKeyControl {
	const InternalContextMenuKeyControl._();

	final String delete = 'controlDelete';
}

class InternalContextMenuKeyHyperlink {
	const InternalContextMenuKeyHyperlink._();

	final String delete = 'hyperlinkDelete';
	final String cancel = 'hyperlinkCancel';
	final String edit = 'hyperlinkEdit';
}

class InternalContextMenuKeyImage {
	const InternalContextMenuKeyImage._();

	final String change = 'imageChange';
	final String saveAs = 'imageSaveAs';
	final String textWrap = 'imageTextWrap';
	final String textWrapEmbed = 'imageTextWrapEmbed';
	final String textWrapUpDown = 'imageTextWrapUpDown';
	final String textWrapSurround = 'imageTextWrapSurround';
	final String textWrapFloatTop = 'imageTextWrapFloatTop';
	final String textWrapFloatBottom = 'imageTextWrapFloatBottom';
}

class InternalContextMenuKeyTable {
	const InternalContextMenuKeyTable._();

	final String border = 'border';
	final String borderAll = 'tableBorderAll';
	final String borderEmpty = 'tableBorderEmpty';
	final String borderDash = 'tableBorderDash';
	final String borderExternal = 'tableBorderExternal';
	final String borderInternal = 'tableBorderInternal';
	final String borderTd = 'tableBorderTd';
	final String borderTdTop = 'tableBorderTdTop';
	final String borderTdRight = 'tableBorderTdRight';
	final String borderTdBottom = 'tableBorderTdBottom';
	final String borderTdLeft = 'tableBorderTdLeft';
	final String borderTdForward = 'tableBorderTdForward';
	final String borderTdBack = 'tableBorderTdBack';
	final String verticalAlign = 'tableVerticalAlign';
	final String verticalAlignTop = 'tableVerticalAlignTop';
	final String verticalAlignMiddle = 'tableVerticalAlignMiddle';
	final String verticalAlignBottom = 'tableVerticalAlignBottom';
	final String insertRowCol = 'tableInsertRowCol';
	final String insertTopRow = 'tableInsertTopRow';
	final String insertBottomRow = 'tableInsertBottomRow';
	final String insertLeftCol = 'tableInsertLeftCol';
	final String insertRightCol = 'tableInsertRightCol';
	final String deleteRowCol = 'tableDeleteRowCol';
	final String deleteRow = 'tableDeleteRow';
	final String deleteCol = 'tableDeleteCol';
	final String deleteTable = 'tableDeleteTable';
	final String mergeCell = 'tableMergeCell';
	final String cancelMergeCell = 'tableCancelMergeCell';
}