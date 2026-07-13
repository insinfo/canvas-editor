import 'dart:html';

import '../../../dataset/enum/editor.dart';
import '../../../interface/editor.dart';
import '../draw.dart';

class Margin {
  Margin(this._draw) : _options = _draw.getOptions();

  final Draw _draw;
  final IEditorOption _options;

  void render(CanvasRenderingContext2D ctx, int pageNo) {
    // Modo visualizador/impressão: sem as marcas "L" de margem — elas são
    // guia de edição (o Word/leitores de PDF não as mostram em leitura).
    final EditorMode mode = _draw.getMode();
    if (mode == EditorMode.readonly || mode == EditorMode.print) {
      return;
    }
    final String strokeColor = _options.marginIndicatorColor ?? '#BABABA';
    final PageMode pageMode = _options.pageMode ?? PageMode.paging;
    final double width = _draw.getWidth();
    final double height = pageMode == PageMode.continuity
        ? _draw.getCanvasHeight(pageNo)
        : _draw.getHeight();
    final List<double> margins = _draw.getMargins();
    final double indicatorSize = _draw.getMarginIndicatorSize();

    ctx.save();
    ctx.translate(0.5, 0.5);
    ctx.strokeStyle = strokeColor;
    ctx.beginPath();

    final double left = margins[3];
    final double right = width - margins[1];
    final double top = margins[0];
    final double bottom = height - margins[2];

    ctx.moveTo(left - indicatorSize, top);
    ctx.lineTo(left, top);
    ctx.lineTo(left, top - indicatorSize);

    ctx.moveTo(right + indicatorSize, top);
    ctx.lineTo(right, top);
    ctx.lineTo(right, top - indicatorSize);

    ctx.moveTo(left - indicatorSize, bottom);
    ctx.lineTo(left, bottom);
    ctx.lineTo(left, bottom + indicatorSize);

    ctx.moveTo(right + indicatorSize, bottom);
    ctx.lineTo(right, bottom);
    ctx.lineTo(right, bottom + indicatorSize);

    ctx.stroke();
    ctx.restore();
  }
}
