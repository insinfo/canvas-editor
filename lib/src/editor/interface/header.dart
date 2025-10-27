import '../dataset/enum/common.dart';

class IHeader {
  double? top;
  double? inactiveAlpha;
  MaxHeightRatio? maxHeightRadio;
  bool? disabled;
  bool? editable;

  IHeader({
    this.top,
    this.inactiveAlpha,
    this.maxHeightRadio,
    this.disabled,
    this.editable,
  });
}
