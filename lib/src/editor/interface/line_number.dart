import '../dataset/enum/line_number.dart';

class ILineNumberOption {
  double? size;
  String? font;
  String? color;
  bool? disabled;
  double? right;
  LineNumberType? type;

  ILineNumberOption({
    this.size,
    this.font,
    this.color,
    this.disabled,
    this.right,
    this.type,
  });
}
