import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../../dataset/constant/common.dart';
import '../../../dataset/constant/element.dart' as element_constants;
import '../../../dataset/constant/regular.dart';
import '../../../dataset/enum/element.dart';
import '../../../dataset/enum/editor.dart';
import '../../../interface/draw.dart';
import '../../../interface/element.dart';
import '../../../interface/position.dart';
import '../../../interface/range.dart';
import 'mouse_offset.dart';

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

  final int cursorStartIndex = _computeCursorStartIndex(draw, cursorPosition);
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
  // Intl.Segmenter via js_interop (indisponível em navegadores antigos).
  if (!globalContext.hasProperty('Intl'.toJS).toDart) {
    return;
  }
  final JSObject? intl = globalContext.getProperty('Intl'.toJS) as JSObject?;
  if (intl == null || !intl.hasProperty('Segmenter'.toJS).toDart) {
    return;
  }

  final JSFunction? constructor =
      intl.getProperty('Segmenter'.toJS) as JSFunction?;
  if (constructor == null) {
    return;
  }
  final JSObject options = JSObject()
    ..setProperty('granularity'.toJS, 'word'.toJS);
  final JSObject segmenter = constructor.callAsConstructor<JSObject>(
    <JSAny?>[].toJS,
    options,
  );
  final JSObject segments =
      segmenter.callMethod<JSObject>('segment'.toJS, text.toJS);

  if (!segments.hasProperty('values'.toJS).toDart) {
    return;
  }
  final JSObject iterator = segments.callMethod<JSObject>('values'.toJS);
  while (true) {
    final JSObject result = iterator.callMethod<JSObject>('next'.toJS);
    final JSAny? done = result.getProperty('done'.toJS);
    if (done != null && done.isA<JSBoolean>() && (done as JSBoolean).toDart) {
      break;
    }
    final JSAny? value = result.getProperty('value'.toJS);
    final _SegmentData? data = _segmentFromEntry(
        value != null && value.isA<JSObject>() ? value as JSObject : null);
    if (data != null) {
      yield data;
    }
  }
}

_SegmentData? _segmentFromEntry(JSObject? entry) {
  if (entry == null) {
    return null;
  }
  final JSAny? segment = entry.getProperty('segment'.toJS);
  final JSAny? index = entry.getProperty('index'.toJS);
  if (segment == null ||
      !segment.isA<JSString>() ||
      index == null ||
      !index.isA<JSNumber>()) {
    return null;
  }
  final JSAny? wordLike = entry.getProperty('isWordLike'.toJS);
  return _SegmentData(
    segment: (segment as JSString).toDart,
    index: (index as JSNumber).toDartInt,
    isWordLike: wordLike != null &&
        wordLike.isA<JSBoolean>() &&
        (wordLike as JSBoolean).toDart,
  );
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
  final offset = getMouseOffset(evt);
  final double offsetX = offset.x;
  final double offsetY = offset.y;

  final ICurrentPosition positionContext = position.getPositionByXY(
    IGetPositionByXYPayload(x: offsetX, y: offsetY),
  );
  if (draw.getMode() == EditorMode.readonly &&
      (positionContext.isImage == true ||
          (positionContext.zone != null &&
              positionContext.zone != EditorZone.main))) {
    return;
  }

  // Word: duplo-clique na faixa do cabeçalho/rodapé ATIVA a zona primeiro —
  // mesmo sobre imagem ou caixa de texto (a moldura tracejada + label
  // "Cabeçalho"/"Rodapé" aparecem). Só com a zona já ativa o duplo-clique
  // nos elementos internos abre previewer/editor da caixa.
  if (draw.getIsPagingMode() == true && positionContext.zone != null) {
    final dynamic zoneManager = draw.getZone();
    if (positionContext.zone != EditorZone.main &&
        zoneManager?.getZone() != positionContext.zone) {
      zoneManager?.setZone(positionContext.zone);
      draw.clearSideEffect();
      position.setPositionContext(IPositionContext(isTable: false));
      return;
    }
    if (positionContext.index < 0 &&
        positionContext.zone == EditorZone.main &&
        zoneManager?.getZone() != EditorZone.main) {
      zoneManager?.setZone(EditorZone.main);
      draw.clearSideEffect();
      position.setPositionContext(IPositionContext(isTable: false));
      return;
    }
  }

  if (positionContext.isImage == true && positionContext.isDirectHit == true) {
    // Word: duplo-clique na imagem NÃO abre visualizador — só mantém a imagem
    // selecionada (as alças + a aba contextual "Imagem" do ribbon é o que
    // aparece). O visualizador/recorte fica na UI de imagem, não aqui.
    return;
  }

  if ((positionContext.isCheckbox == true || positionContext.isRadio == true) &&
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
    final bool isDifferentList = element.listId != previous.listId ||
        element.titleId != previous.titleId;
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
