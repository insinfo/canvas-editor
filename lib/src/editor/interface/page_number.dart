import '../dataset/enum/common.dart';
import '../dataset/enum/row.dart';

class IPageNumber {
	double? bottom;
	double? size;
	String? font;
	String? color;
	RowFlex? rowFlex;
	String? format;
	NumberType? numberType;
	bool? disabled;
	int? startPageNo;
	int? fromPageNo;
	int? maxPageNo;

	IPageNumber({
		this.bottom,
		this.size,
		this.font,
		this.color,
		this.rowFlex,
		this.format,
		this.numberType,
		this.disabled,
		this.startPageNo,
		this.fromPageNo,
		this.maxPageNo,
	});
}