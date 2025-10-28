import 'dart:js_util' as js_util;

import '../../../dataset/constant/common.dart';
import '../../../dataset/constant/element.dart' as element_constants;
import '../../../dataset/constant/regular.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/draw.dart';
import '../../../interface/element.dart';
import '../../../interface/position.dart';
import '../../../interface/range.dart';

IRange? _getWordRangeBySegmenter(dynamic host) {
	final dynamic draw = host.getDraw();
	final dynamic position = draw.getPosition();
	final IElementPosition? cursorPosition =
			position.getCursorPosition() as IElementPosition?;
	if (cursorPosition == null) {
		return null;
	}

	final dynamic rangeManager = draw.getRange();
	final IRangeParagraphInfo? paragraphInfo =
			rangeManager.getRangeParagraphInfo() as IRangeParagraphInfo?;
	if (paragraphInfo == null) {
		return null;
	}

	final List<IElement> paragraphElements =
			(paragraphInfo.elementList as List?)?.cast<IElement>() ?? <IElement>[];
	if (paragraphElements.isEmpty) {
		return null;
	}

	final StringBuffer buffer = StringBuffer();
	for (final IElement element in paragraphElements) {
		final ElementType? type = element.type;
		final bool isTextLike = type == null ||
				(type != ElementType.control &&
						element_constants.textlikeElementType.contains(type));
		buffer.write(isTextLike ? element.value : ZERO);
	}
	final String paragraphText = buffer.toString();
	if (paragraphText.isEmpty) {
		return null;
	}

	final Iterable<_SegmentData> segments = _segmentText(paragraphText);
	if (segments.isEmpty) {
		return null;
	}

	final int cursorStartIndex =
			_computeCursorStartIndex(draw, cursorPosition);
	final int offset = paragraphInfo.startIndex;

	for (final _SegmentData segment in segments) {
		if (!segment.isWordLike) {
			continue;
		}
		final int realSegmentStartIndex = segment.index + offset;
		if (cursorStartIndex >= realSegmentStartIndex &&
				cursorStartIndex < realSegmentStartIndex + segment.length) {
			final int startIndex = realSegmentStartIndex - 1;
			final int endIndex = startIndex + segment.length;
			if (startIndex >= 0) {
				return IRange(startIndex: startIndex, endIndex: endIndex);
			}
			break;
		}
	}

	return null;
}

int _computeCursorStartIndex(dynamic draw, IElementPosition cursorPosition) {
	final int index = cursorPosition.index;
	if (cursorPosition.isFirstLetter) {
		return index + 1;
	}
	final dynamic cursor = draw.getCursor();
	final int? hitLineStartIndex = cursor?.getHitLineStartIndex() as int?;
	if (hitLineStartIndex != null && hitLineStartIndex != 0) {
		return index + 1;
	}
	return index;
}

Iterable<_SegmentData> _segmentText(String text) sync* {
	if (!js_util.hasProperty(js_util.globalThis, 'Intl')) {
		return;
	}
	final dynamic intl = js_util.getProperty(js_util.globalThis, 'Intl');
	if (intl == null || !js_util.hasProperty(intl, 'Segmenter')) {
		return;
	}

	final dynamic constructor = js_util.getProperty(intl, 'Segmenter');
	final dynamic options = js_util.jsify(<String, Object?>{
		'granularity': 'word',
	});
	final dynamic segmenter = js_util.callConstructor(
		constructor,
		<Object?>[js_util.jsify(const <Object?>[]), options],
	);
	final dynamic segments =
			js_util.callMethod(segmenter, 'segment', <Object?>[text]);

	final dynamic dartified = js_util.dartify(segments);
	if (dartified is Iterable) {
		for (final dynamic entry in dartified) {
			final _SegmentData? data = _segmentFromEntry(entry);
			if (data != null) {
				yield data;
			}
		}
		return;
	}

	if (js_util.hasProperty(segments, 'values')) {
		final dynamic iterator =
				js_util.callMethod(segments, 'values', const <Object?>[]);
		while (true) {
			final dynamic result =
					js_util.callMethod(iterator, 'next', const <Object?>[]);
			if (result == null || js_util.getProperty(result, 'done') == true) {
				break;
			}
			final dynamic value = js_util.getProperty(result, 'value');
			final _SegmentData? data = _segmentFromEntry(value);
			if (data != null) {
				yield data;
			}
		}
	}
}

_SegmentData? _segmentFromEntry(dynamic entry) {
	if (entry == null) {
		return null;
	}
	try {
		final String? segment = js_util.getProperty(entry, 'segment') as String?;
		final int? index =
				(js_util.getProperty(entry, 'index') as num?)?.toInt();
		final bool isWordLike = js_util.getProperty(entry, 'isWordLike') == true;
		if (segment == null || index == null) {
			return null;
		}
		return _SegmentData(segment: segment, index: index, isWordLike: isWordLike);
	} catch (_) {
		final dynamic dartified = js_util.dartify(entry);
		if (dartified is Map) {
			final String? segment = dartified['segment'] as String?;
			final int? index = (dartified['index'] as num?)?.toInt();
			final bool isWordLike = dartified['isWordLike'] == true;
			if (segment == null || index == null) {
				return null;
			}
			return _SegmentData(segment: segment, index: index, isWordLike: isWordLike);
		}
	}
	return null;
}

IRange? _getWordRangeByCursor(dynamic host) {
	final dynamic draw = host.getDraw();
	final dynamic position = draw.getPosition();
	final IElementPosition? cursorPosition =
			position.getCursorPosition() as IElementPosition?;
	if (cursorPosition == null) {
		return null;
	}

	final String value = cursorPosition.value;
	final int index = cursorPosition.index;
	final RegExp? letterReg = draw.getLetterReg() as RegExp?;
	final RegExp effectiveLetterReg = letterReg ?? RegExp(r'[A-Za-z]');

	int upCount = 0;
	int downCount = 0;
	final bool isNumber = numberLikeReg.hasMatch(value);
	final List<IElement> elementList =
			(draw.getElementList() as List).cast<IElement>();

	int upStartIndex = index - 1;
	while (upStartIndex > 0) {
		final IElement element = elementList[upStartIndex];
		final String elementValue = element.value;
		final bool matches = isNumber
				? numberLikeReg.hasMatch(elementValue)
				: effectiveLetterReg.hasMatch(elementValue);
		if (!matches) {
			break;
		}
		upCount++;
		upStartIndex--;
	}

	int downStartIndex = index + 1;
	while (downStartIndex < elementList.length) {
		final IElement element = elementList[downStartIndex];
		final String elementValue = element.value;
		final bool matches = isNumber
				? numberLikeReg.hasMatch(elementValue)
				: effectiveLetterReg.hasMatch(elementValue);
		if (!matches) {
			break;
		}
		downCount++;
		downStartIndex++;
	}

	final int startIndex = index - upCount - 1;
	if (startIndex < 0) {
		return null;
	}
	return IRange(startIndex: startIndex, endIndex: index + downCount);
}

void dblclick(dynamic host, dynamic evt) {
	final dynamic draw = host.getDraw();
	final dynamic position = draw.getPosition();
	final double offsetX = (evt?.offsetX as num?)?.toDouble() ?? 0;
	final double offsetY = (evt?.offsetY as num?)?.toDouble() ?? 0;

	final ICurrentPosition positionContext = position.getPositionByXY(
		IGetPositionByXYPayload(x: offsetX, y: offsetY),
	);

	if (positionContext.isImage == true &&
			positionContext.isDirectHit == true) {
		draw.getPreviewer()?.render();
		return;
	}

	if (draw.getIsPagingMode() == true) {
		final int ctxIndex = positionContext.index;
		if (ctxIndex < 0 && positionContext.zone != null) {
			final dynamic zoneManager = draw.getZone();
			zoneManager?.setZone(positionContext.zone);
			draw.clearSideEffect();
			position.setPositionContext(IPositionContext(isTable: false));
			return;
		}
	}

	if ((positionContext.isCheckbox == true ||
					positionContext.isRadio == true) &&
			positionContext.isDirectHit == true) {
		return;
	}

	final dynamic rangeManager = draw.getRange();
	final IRange? segmenterRange =
			_getWordRangeBySegmenter(host) ?? _getWordRangeByCursor(host);
	if (segmenterRange == null) {
		return;
	}

	rangeManager.setRange(segmenterRange.startIndex, segmenterRange.endIndex);
	draw.render(
		IDrawOption(
			isSubmitHistory: false,
			isSetCursor: false,
			isCompute: false,
		),
	);
	rangeManager.setRangeStyle();
}

void threeClick(dynamic host) {
	final dynamic draw = host.getDraw();
	final dynamic position = draw.getPosition();
	final IElementPosition? cursorPosition =
			position.getCursorPosition() as IElementPosition?;
	if (cursorPosition == null) {
		return;
	}

	final int index = cursorPosition.index;
	final List<IElement> elementList =
			(draw.getElementList() as List).cast<IElement>();
	if (index < 0 || index >= elementList.length) {
		return;
	}

	int upCount = 0;
	int downCount = 0;

	int upStartIndex = index - 1;
	while (upStartIndex > 0) {
		final IElement element = elementList[upStartIndex];
		final IElement previous = elementList[upStartIndex - 1];
		final bool isZeroWidth = element.value == ZERO && element.listWrap != true;
		final bool isDifferentList =
				element.listId != previous.listId || element.titleId != previous.titleId;
		if (isZeroWidth || isDifferentList) {
			break;
		}
		upCount++;
		upStartIndex--;
	}

	int downStartIndex = index + 1;
	while (downStartIndex < elementList.length) {
		final IElement element = elementList[downStartIndex];
		final IElement? next = downStartIndex + 1 < elementList.length
				? elementList[downStartIndex + 1]
				: null;
		final bool isZeroWidth = element.value == ZERO && element.listWrap != true;
		final bool isDifferentList =
				element.listId != next?.listId || element.titleId != next?.titleId;
		if (isZeroWidth || isDifferentList) {
			break;
		}
		downCount++;
		downStartIndex++;
	}

	int newStartIndex = index - upCount - 1;
	if (newStartIndex < 0) {
		return;
	}

	if (elementList[newStartIndex].value != ZERO) {
		newStartIndex -= 1;
	}
	if (newStartIndex < 0) {
		return;
	}

	int newEndIndex = index + downCount + 1;
	if (newEndIndex >= elementList.length ||
			elementList[newEndIndex].value == ZERO) {
		newEndIndex -= 1;
	}
	if (newEndIndex < newStartIndex) {
		return;
	}

	final dynamic rangeManager = draw.getRange();
	rangeManager.setRange(newStartIndex, newEndIndex);
	draw.render(
		IDrawOption(
			isSubmitHistory: false,
			isSetCursor: false,
			isCompute: false,
		),
	);
}

class _SegmentData {
	const _SegmentData({
		required this.segment,
		required this.index,
		required this.isWordLike,
	});

	final String segment;
	final int index;
	final bool isWordLike;

	int get length => segment.length;
}