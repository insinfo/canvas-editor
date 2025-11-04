import 'dart:html';
import 'dart:js_util' as js_util;

import '../../../interface/editor.dart';
import '../../../interface/page_break.dart';
import '../../../interface/row.dart';
import '../../i18n/i18n.dart';
import '../draw.dart';

class PageBreakParticle {
	PageBreakParticle(Draw draw)
			: _draw = draw,
				_options = draw.getOptions(),
				_i18n = draw.getI18n();

	final Draw _draw;
	final IEditorOption _options;
	final I18n _i18n;

	void render(
		CanvasRenderingContext2D ctx,
		IRowElement element,
		double x,
		double y,
	) {
		final IPageBreak? pageBreak = _options.pageBreak;
		if (pageBreak == null) {
			return;
		}
		final double scale = _options.scale?.toDouble() ?? 1;
		final double fontSize = (pageBreak.fontSize ?? 12).toDouble();
		final String fontFamily = pageBreak.font ?? 'sans-serif';
		final List<double> lineDash = pageBreak.lineDash ?? const <double>[6, 3];
		final String displayName = _i18n.t('pageBreak.displayName');
		final double rowMargin = (_options.defaultRowMargin ?? 1).toDouble();
		final double size = fontSize * scale;
		final double elementWidth = (element.width ?? element.metrics.width) * scale;
		final double offsetY = _draw.getDefaultBasicRowMarginHeight() * rowMargin;
		ctx.save();
		ctx.font = '${size}px $fontFamily';
		final TextMetrics metrics = ctx.measureText(displayName);
		final double textWidth = (metrics.width ?? 0).toDouble();
		final double halfX = (elementWidth - textWidth) / 2;
		if (lineDash.isNotEmpty) {
			ctx.setLineDash(lineDash);
		}
		ctx.translate(0, 0.5 + offsetY);
		ctx.beginPath();
		ctx.moveTo(x, y);
		ctx.lineTo(x + halfX, y);
		ctx.moveTo(x + halfX + textWidth, y);
		ctx.lineTo(x + elementWidth, y);
		ctx.stroke();
		final num ascentValue =
				js_util.getProperty(metrics, 'actualBoundingBoxAscent') as num? ?? size;
		final double ascent = ascentValue.toDouble();
		ctx.fillText(displayName, x + halfX, y + ascent - size / 2);
		ctx.restore();
	}
}
