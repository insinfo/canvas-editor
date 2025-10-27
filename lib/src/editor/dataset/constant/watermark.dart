import '../../interface/watermark.dart';
import '../enum/common.dart';
import '../enum/watermark.dart';

/// Default configuration for document watermarks.
final IWatermark defaultWatermarkOption = IWatermark(
  data: '',
  type: WatermarkType.text,
  width: 0.0,
  height: 0.0,
  color: '#AEB5C0',
  opacity: 0.3,
  size: 200.0,
  font: 'Microsoft YaHei',
  repeat: false,
  gap: const [10.0, 10.0],
  numberType: NumberType.arabic,
);
