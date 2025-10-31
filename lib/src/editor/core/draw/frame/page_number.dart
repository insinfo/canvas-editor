import 'dart:html';

import '../../../dataset/constant/page_number.dart';
import '../../../dataset/enum/common.dart';
import '../../../dataset/enum/row.dart';
import '../../../interface/editor.dart';
import '../../../interface/page_number.dart';
import '../../../utils/index.dart' show convertNumberToChinese;
import '../draw.dart';

class PageNumber {
	PageNumber(this._draw) : _options = _draw.getOptions();

	final Draw _draw;
	final IEditorOption _options;

	static String formatNumberPlaceholder(
		String text,
		int pageNo,
		RegExp replaceReg,
		NumberType? numberType,
	) {
		final String pageText = numberType == NumberType.chinese
				? convertNumberToChinese(pageNo)
				: pageNo.toString();
		return text.replaceAll(replaceReg, pageText);
	}

	void render(CanvasRenderingContext2D ctx, int pageNo) {
		final IPageNumber? pageNumberOption = _options.pageNumber;
		if (pageNumberOption == null || pageNumberOption.disabled == true) {
			return;
		}

		final double scale = (_options.scale ?? 1).toDouble();
		final double fontSize = (pageNumberOption.size ?? 12).toDouble() * scale;
		final String fontFamily = pageNumberOption.font ?? 'sans-serif';
		final String color = pageNumberOption.color ?? '#000000';
		final RowFlex alignment = pageNumberOption.rowFlex ?? RowFlex.center;
		final NumberType? numberType = pageNumberOption.numberType;
		final int fromPageNo = pageNumberOption.fromPageNo ?? 0;
		final int startPageNo = pageNumberOption.startPageNo ?? 1;
		final int? maxPageNo = pageNumberOption.maxPageNo;
		if (pageNo < fromPageNo || (maxPageNo != null && pageNo >= maxPageNo)) {
			return;
		}

		String text = pageNumberOption.format ?? PageNumberFormatPlaceholder.pageNo;
		final RegExp pageNoReg =
				RegExp(PageNumberFormatPlaceholder.pageNo, caseSensitive: false);
		if (pageNoReg.hasMatch(text)) {
			text = PageNumber.formatNumberPlaceholder(
				text,
				pageNo + startPageNo - fromPageNo,
				pageNoReg,
				numberType,
			);
		}
		final RegExp pageCountReg =
				RegExp(PageNumberFormatPlaceholder.pageCount, caseSensitive: false);
		if (pageCountReg.hasMatch(text)) {
			text = PageNumber.formatNumberPlaceholder(
				text,
				_draw.getPageCount() - fromPageNo,
				pageCountReg,
				numberType,
			);
		}

		final double width = _draw.getWidth();
		final double height = _draw.getHeight();
		final double pageNumberBottom = _draw.getPageNumberBottom();
		final double y = height - pageNumberBottom;

		ctx.save();
		ctx
			..fillStyle = color
			..font = '${fontSize}px ${fontFamily}';

		final List<double> margins = _draw.getMargins();
		final TextMetrics metrics = ctx.measureText(text);
		final double textWidth = (metrics.width as num).toDouble();
		double x;
		switch (alignment) {
			case RowFlex.right:
				x = width - textWidth - margins[1];
				break;
			case RowFlex.center:
				x = (width - textWidth) / 2;
				break;
			case RowFlex.left:
			case RowFlex.alignment:
			case RowFlex.justify:
				x = margins[3];
				break;
		}

		ctx.fillText(text, x, y);
		ctx.restore();
	}
}