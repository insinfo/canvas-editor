import '../dataset/enum/editor.dart';
import './element.dart';
import './range.dart';

class ISearchResultRestArgs {
	String? tableId;
	int? tableIndex;
	int? trIndex;
	int? tdIndex;
	String? tdId;
	int? startIndex;

	ISearchResultRestArgs({
		this.tableId,
		this.tableIndex,
		this.trIndex,
		this.tdIndex,
		this.tdId,
		this.startIndex,
	});
}

class ISearchResult extends ISearchResultRestArgs {
	EditorContext type;
	int index;
	String groupId;

	ISearchResult({
		required this.type,
		required this.index,
		required this.groupId,
		String? tableId,
		int? tableIndex,
		int? trIndex,
		int? tdIndex,
		String? tdId,
		int? startIndex,
	}) : super(
			tableId: tableId,
			tableIndex: tableIndex,
			trIndex: trIndex,
			tdIndex: tdIndex,
			tdId: tdId,
			startIndex: startIndex,
		);
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

class INavigateInfo {
	int index;
	int count;

	INavigateInfo({required this.index, required this.count});
}