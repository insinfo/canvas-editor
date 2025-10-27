import './common.dart';

class IPageBorderOption {
	String? color;
	double? lineWidth;
	IPadding? padding;
	bool? disabled;

	IPageBorderOption({
		this.color,
		this.lineWidth,
		this.padding,
		this.disabled,
	});
}