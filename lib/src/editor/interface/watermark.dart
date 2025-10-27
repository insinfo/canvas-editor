import '../dataset/enum/common.dart';
import '../dataset/enum/watermark.dart';

class IWatermark {
	String data;
	WatermarkType? type;
	double? width;
	double? height;
	String? color;
	double? opacity;
	double? size;
	String? font;
	bool? repeat;
	NumberType? numberType;
	List<double>? gap;

	IWatermark({
		required this.data,
		this.type,
		this.width,
		this.height,
		this.color,
		this.opacity,
		this.size,
		this.font,
		this.repeat,
		this.numberType,
		this.gap,
	});
}