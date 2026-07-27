import 'package:canvas_text_editor/src/dom/dom.dart';

import '../../../interface/editor.dart';
import '../../../interface/row.dart';
import '../draw.dart';

class WhiteSpaceParticle {
  WhiteSpaceParticle(Draw draw) : _options = draw.getOptions();

  final IEditorOption _options;

  void render(
    CanvasRenderingContext2D ctx,
    IRowElement element,
    double x,
    double y,
  ) {
    final String color = _options.whiteSpace?.color ?? '#CCCCCC';
    final num radius = _options.whiteSpace?.radius ?? 1;
    final double scale = (_options.scale ?? 1).toDouble();
    final double width = element.metrics.width;
    ctx.save();
    ctx.fillColor = color;
    ctx.beginPath();
    ctx.arc(x + width / 2, y, radius.toDouble() * scale, 0, 3.141592653589793 * 2);
    ctx.fill();
    ctx.closePath();
    ctx.restore();
  }
}