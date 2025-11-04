import 'dart:html';

import '../../../interface/editor.dart';
import '../../../interface/common.dart';
import '../../../interface/page_border.dart';
import '../draw.dart';

class PageBorder {
	PageBorder(this._draw)
			: _options = _draw.getOptions();

	final Draw _draw;
	final IEditorOption _options;

	double _getHeaderExtraHeight() {
		try {
			final dynamic header = (_draw as dynamic).getHeader();
			final dynamic extra = header?.getExtraHeight();
			if (extra is num) {
				return extra.toDouble();
			}
		} catch (_) {}
		return 0;
	}

	double _getFooterExtraHeight() {
		try {
			final dynamic footer = (_draw as dynamic).getFooter();
			final dynamic extra = footer?.getExtraHeight();
			if (extra is num) {
				return extra.toDouble();
			}
		} catch (_) {}
		return 0;
	}

	void render(CanvasRenderingContext2D ctx) {
		final IPageBorderOption? pageBorder = _options.pageBorder;
		if (pageBorder == null || pageBorder.disabled == true) {
			return;
		}

		final double scale = (_options.scale ?? 1).toDouble();
		final double lineWidth = (pageBorder.lineWidth ?? 1).toDouble() * scale;
		final String strokeColor = pageBorder.color ?? '#DCDFE6';
		final IPadding padding = pageBorder.padding ??
				IPadding(top: 0, right: 0, bottom: 0, left: 0);

		final List<double> margins = _draw.getMargins();
		final double headerExtraHeight = _getHeaderExtraHeight();
		final double footerExtraHeight = _getFooterExtraHeight();
		final double innerWidth = _draw.getInnerWidth();
		final double height = _draw.getHeight();

		final double x = margins[3] - padding.left * scale;
		final double y = margins[0] + headerExtraHeight - padding.top * scale;
		final double width = innerWidth + (padding.right + padding.left) * scale;
		final double rectHeight = height -
				y -
				footerExtraHeight -
				margins[2] +
				padding.bottom * scale;

		ctx.save();
		ctx.translate(0.5, 0.5);
		ctx.strokeStyle = strokeColor;
		ctx.lineWidth = lineWidth;
		ctx.rect(x, y, width, rectHeight);
		ctx.stroke();
		ctx.restore();
	}
}
