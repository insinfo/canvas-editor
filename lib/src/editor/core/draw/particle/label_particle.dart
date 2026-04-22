import 'dart:html';

import '../../../dataset/constant/label.dart';
import '../../../interface/common.dart';
import '../../../interface/editor.dart';
import '../../../interface/row.dart';
import '../draw.dart';

class LabelParticle {
  LabelParticle(Draw draw) : _options = draw.getOptions();

  final IEditorOption _options;

  void render(
    CanvasRenderingContext2D ctx,
    IRowElement element,
    double x,
    double y,
  ) {
    final double scale = (_options.scale ?? 1).toDouble();
    final String backgroundColor = element.label?.backgroundColor ??
        _options.label?.defaultBackgroundColor ??
        defaultLabelOption.defaultBackgroundColor ??
        '#e3f2fd';
    final String color = element.label?.color ??
        _options.label?.defaultColor ??
        defaultLabelOption.defaultColor ??
        '#1976d2';
    final double borderRadius = (element.label?.borderRadius ??
            _options.label?.defaultBorderRadius ??
            defaultLabelOption.defaultBorderRadius ??
            4)
        .toDouble();
    final IPadding padding = element.label?.padding ??
        _options.label?.defaultPadding ??
        defaultLabelOption.defaultPadding ??
        IPadding(top: 4, right: 4, bottom: 4, left: 4);

    ctx.save();
    ctx.font = element.style;

    final double width = element.metrics.width;
    final double height = element.metrics.height +
        (padding.top + padding.bottom) * scale;
    final double top = y - element.metrics.boundingBoxAscent;

    ctx.fillStyle = backgroundColor;
    _drawRoundedRect(ctx, x, top, width, height, borderRadius * scale);
    ctx.fill();

    ctx.fillStyle = color;
    ctx.fillText(element.value, x + padding.left * scale, y);
    ctx.restore();
  }

  void _drawRoundedRect(
    CanvasRenderingContext2D ctx,
    double x,
    double y,
    double width,
    double height,
    double radius,
  ) {
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + width - radius, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
    ctx.lineTo(x + width, y + height - radius);
    ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
    ctx.lineTo(x + radius, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
    ctx.lineTo(x, y + radius);
    ctx.quadraticCurveTo(x, y, x + radius, y);
    ctx.closePath();
  }
}