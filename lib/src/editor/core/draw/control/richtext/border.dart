import 'dart:html';

import '../../../../interface/editor.dart';
import '../../../../interface/element.dart';
import '../../draw.dart';

class ControlBorder {
  ControlBorder(Draw draw)
      : _options = draw.getOptions(),
        _borderRect = IElementFillRect(x: 0, y: 0, width: 0, height: 0);

  final IEditorOption _options;
  IElementFillRect _borderRect;

  IElementFillRect clearBorderInfo() {
    _borderRect = IElementFillRect(x: 0, y: 0, width: 0, height: 0);
    return _borderRect;
  }

  void recordBorderInfo(num x, num y, num width, num height) {
    final bool isFirstRecord = _borderRect.width == 0;
    if (isFirstRecord) {
      _borderRect
        ..x = x.toDouble()
        ..y = y.toDouble()
        ..height = height.toDouble();
    }
    _borderRect.width += width.toDouble();
  }

  void render(CanvasRenderingContext2D ctx) {
    if (_borderRect.width == 0) {
      return;
    }
    final IControlOption? controlOption = _options.control;
    if (controlOption == null) {
      return;
    }
    final double scale = _options.scale ?? 1;
    ctx.save();
    ctx.translate(0, 1 * scale);
    ctx.lineWidth = (controlOption.borderWidth ?? 0) * scale;
    ctx.strokeStyle = controlOption.borderColor ?? '';
    ctx.beginPath();
    ctx.rect(
      _borderRect.x,
      _borderRect.y,
      _borderRect.width,
      _borderRect.height,
    );
    ctx.stroke();
    ctx.restore();
    clearBorderInfo();
  }
}
