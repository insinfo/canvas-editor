import '../common.dart';

class ITableOption {
	IPadding? tdPadding;
	double? defaultTrMinHeight;
	double? defaultColMinWidth;
	String? defaultBorderColor;
	bool? overflow;

	ITableOption({
		this.tdPadding,
		this.defaultTrMinHeight,
		this.defaultColMinWidth,
		this.defaultBorderColor,
		this.overflow,
	});
}