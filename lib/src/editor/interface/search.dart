import '../dataset/enum/editor.dart';
import './element.dart';
import './range.dart';

class ISearchResult {
	EditorContext type;
	int index;
	String groupId;
	String? tableId;
	int? tableIndex;
	int? trIndex;
	int? tdIndex;
	String? tdId;
	int? startIndex;

	ISearchResult({
		required this.type,
		required this.index,
		required this.groupId,
		this.tableId,
		this.tableIndex,
		this.trIndex,
		this.tdIndex,
		this.tdId,
		this.startIndex,
	});
}

class ISearchResultContext {
	IRange range;
	IElementPosition startPosition;
	IElementPosition endPosition;

	ISearchResultContext({
		required this.range,
		required this.startPosition,
		required this.endPosition,
	});
}

class IReplaceOption {
	int? index;

	IReplaceOption({this.index});
}