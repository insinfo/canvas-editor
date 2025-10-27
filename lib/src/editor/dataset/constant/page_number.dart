import '../../dataset/enum/common.dart';
import '../../dataset/enum/row.dart';
import '../../interface/page_number.dart';

class PageNumberFormatPlaceholder {
	static const String pageNo = '{pageNo}';
	static const String pageCount = '{pageCount}';
}

final IPageNumber defaultPageNumberOption = IPageNumber(
	bottom: 60,
	size: 12,
	font: 'Microsoft YaHei',
	color: '#000000',
	rowFlex: RowFlex.center,
	format: PageNumberFormatPlaceholder.pageNo,
	numberType: NumberType.arabic,
	disabled: false,
	startPageNo: 1,
	fromPageNo: 0,
	maxPageNo: null,
);
