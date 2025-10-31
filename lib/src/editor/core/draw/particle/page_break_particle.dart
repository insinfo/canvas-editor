// TODO: Translate from C:\\MyTsProjects\\canvas-editor\\src\\editor\\core\\draw\\particle\\PageBreakParticle.ts
import 'dart:html';

import '../../../interface/editor.dart';
import '../../../interface/page_break.dart';
import '../../../interface/row.dart';
import '../../i18n/i18n.dart';
import '../draw.dart';

class PageBreakParticle {
	PageBreakParticle(this._draw)
		: _options = _draw.getOptions(),
			_i18n = _draw.getI18n();

	final Draw _draw;
	final IEditorOption _options;
	final I18n _i18n;

	void render(
		CanvasRenderingContext2D ctx,
		IRowElement element,
		double x,
		double y,
	) {
		final IPageBreak? pageBreakOption = _options.pageBreak;
		final String fontFamily = pageBreakOption?.font ?? 'sans-serif';
		final double fontSize = (pageBreakOption?.fontSize ?? 12).toDouble();
		final List<double> lineDash = pageBreakOption?.lineDash ?? const <double>[6, 3];
		final String displayName = _i18n.t('pageBreak.displayName');
		final double scale = (_options.scale ?? 1).toDouble();
		final double defaultRowMargin = (_options.defaultRowMargin ?? 1).toDouble();
		final double size = fontSize * scale;
		final double elementWidth = (element.width ?? element.metrics.width) * scale;
		final double offsetY =
			_draw.getDefaultBasicRowMarginHeight() * defaultRowMargin;
		ctx.save();
		ctx.font = '${size}px $fontFamily';
		final TextMetrics metrics = ctx.measureText(displayName);
		final double textWidth = (metrics.width ?? 0).toDouble();
		final double halfX = (elementWidth - textWidth) / 2;
		ctx.setLineDash(lineDash);
		ctx.translate(0, 0.5 + offsetY);
		ctx.beginPath();
		ctx.moveTo(x, y);
		ctx.lineTo(x + halfX, y);
		ctx.moveTo(x + halfX + textWidth, y);
		ctx.lineTo(x + elementWidth, y);
		ctx.stroke();
		final double ascent = (metrics.actualBoundingBoxAscent ?? size).toDouble();
		ctx.fillText(displayName, x + halfX, y + ascent - size / 2);
		ctx.restore();
	}
}