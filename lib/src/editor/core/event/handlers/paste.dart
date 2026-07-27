import 'dart:async';
import 'package:canvas_text_editor/src/dom/dom.dart';

import '../../../dataset/constant/common.dart';
import '../../../dataset/constant/element.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/event.dart';
import '../../../interface/range.dart';
import '../../../utils/clipboard.dart';
import '../../../utils/element.dart';
import '../../../utils/index.dart';

void pasteElement(dynamic canvasEvent, List<IElement> elementList) {
  final dynamic draw = canvasEvent.getDraw();
  if (draw.isReadonly() == true ||
      draw.isDisabled() == true ||
      draw.getControl()?.getIsDisabledPasteControl() == true) {
    return;
  }
  final dynamic rangeManager = draw.getRange();
  final IRange range = rangeManager.getRange() as IRange;
  final int startIndex = range.startIndex;
  final bool isCollapsed = range.startIndex == range.endIndex;
  final List<IElement> originalElementList =
      (draw.getElementList() as List).cast<IElement>();
  if (startIndex != -1 && rangeManager.getIsSelectAll() != true) {
    final IElement? anchorElement =
        startIndex >= 0 && startIndex < originalElementList.length
            ? originalElementList[startIndex]
            : null;
    if (anchorElement != null &&
        (anchorElement.titleId != null || anchorElement.listId != null)) {
      var index = 0;
      while (index < elementList.length) {
        final IElement pasteElement = elementList[index];
        if (anchorElement.titleId != null &&
            RegExp(r'^\n').hasMatch(pasteElement.value)) {
          break;
        }
        if (virtualElementType.contains(pasteElement.type)) {
          elementList.removeAt(index);
          final List<IElement>? valueList = pasteElement.valueList;
          if (valueList != null) {
            for (var v = 0; v < valueList.length; v++) {
              final IElement element = valueList[v];
              if (element.value == ZERO || element.value == '\n') {
                continue;
              }
              elementList.insert(index, element);
              index++;
            }
          }
          index--;
        }
        index++;
      }
    }
    formatElementContext(
      originalElementList,
      elementList,
      startIndex,
      options: const FormatElementContextOption(isBreakWhenWrap: true)
          .copyWith(editorOptions: draw.getOptions() as IEditorOption?),
    );
  }
  draw.insertElementList(
    elementList,
    IInsertElementListOption(
      isDeltaHistory: true,
      isFastLayout: isCollapsed && _isInlineFastPastePayload(elementList),
    ),
  );
}

bool _isInlineFastPastePayload(List<IElement> elementList) {
  if (elementList.isEmpty) {
    return false;
  }
  for (final IElement element in elementList) {
    if (element.value == ZERO) {
      return false;
    }
    final ElementType? type = element.type;
    if (type != null && type != ElementType.text) {
      return false;
    }
    if (element.listId != null ||
        element.areaId != null ||
        element.controlId != null ||
        element.imgDisplay != null ||
        element.pagingId != null ||
        element.valueList != null ||
        element.trList != null ||
        element.colgroup != null) {
      return false;
    }
  }
  return true;
}

void pasteHTML(dynamic canvasEvent, String htmlText) {
  final dynamic draw = canvasEvent.getDraw();
  if (draw.isReadonly() == true || draw.isDisabled() == true) {
    return;
  }
  final List<IElement> elementList = getElementListByHTML(
    htmlText,
    GetElementListByHtmlOption(
      innerWidth: (draw.getOriginalInnerWidth() as num).toDouble(),
    ),
  );
  pasteElement(canvasEvent, elementList);
}

void pasteImage(dynamic canvasEvent, Blob file) {
  final dynamic draw = canvasEvent.getDraw();
  if (draw.isReadonly() == true || draw.isDisabled() == true) {
    return;
  }
  final dynamic rangeManager = draw.getRange();
  final IRange range = rangeManager.getRange() as IRange;
  final int startIndex = range.startIndex;
  final List<IElement> originalElementList =
      (draw.getElementList() as List).cast<IElement>();
  final FileReader fileReader = FileReader();
  fileReader.readAsDataURL(file);
  fileReader.onLoad.first.then((_) {
    final String? value = readerResultAsString(fileReader);
    if (value == null) {
      return;
    }
    final HTMLImageElement image = HTMLImageElement()..src = value;
    image.onLoad.first.then((_) {
      final num widthValue =
          image.naturalWidth != 0 ? image.naturalWidth : image.width;
      final num heightValue =
          image.naturalHeight != 0 ? image.naturalHeight : image.height;
      final IElement imageElement = IElement(
        value: value,
        type: ElementType.image,
        width: widthValue.toDouble(),
        height: heightValue.toDouble(),
      );
      if (startIndex != -1) {
        formatElementContext(
          originalElementList,
          <IElement>[imageElement],
          startIndex,
          options: FormatElementContextOption(
            editorOptions: draw.getOptions() as IEditorOption?,
          ),
        );
      }
      draw.insertElementList(<IElement>[imageElement]);
    });
  });
}

void pasteByEvent(dynamic canvasEvent, ClipboardEvent event) {
  final dynamic draw = canvasEvent.getDraw();
  if (draw.isReadonly() == true || draw.isDisabled() == true) {
    return;
  }
  final DataTransfer? clipboardData = event.clipboardData;
  if (clipboardData == null) {
    return;
  }
  final dynamic override = draw.getOverride();
  final dynamic overridePaste = override?.paste;
  if (overridePaste is Function) {
    final dynamic overrideResult = overridePaste(event);
    if (_shouldPreventDefault(overrideResult)) {
      return;
    }
  }
  if (!getIsClipboardContainFile(clipboardData)) {
    final String clipboardText = clipboardData.getData('text');
    final ClipboardDataPayload? editorClipboardData = getClipboardData();
    if (editorClipboardData != null &&
        normalizeLineBreak(clipboardText) ==
            normalizeLineBreak(editorClipboardData.text)) {
      pasteElement(canvasEvent, editorClipboardData.elementList);
      return;
    }
  }
  removeClipboardData();
  final String htmlData = clipboardData.getData('text/html');
  if (htmlData.isNotEmpty) {
    pasteHTML(canvasEvent, htmlData);
    return;
  }
  final String plainText = clipboardData.getData('text/plain');
  if (plainText.isNotEmpty) {
    canvasEvent.input(plainText);
    return;
  }
  for (final File file in filesOf(clipboardData.files)) {
    if (file.type.startsWith('image')) {
      pasteImage(canvasEvent, file);
    }
  }
}

Future<void> pasteByApi(dynamic canvasEvent, [IPasteOption? option]) async {
  final dynamic draw = canvasEvent.getDraw();
  if (draw.isReadonly() == true || draw.isDisabled() == true) {
    return;
  }
  final dynamic override = draw.getOverride();
  final dynamic overridePaste = override?.paste;
  if (overridePaste is Function) {
    final dynamic overrideResult = overridePaste();
    if (_shouldPreventDefault(overrideResult)) {
      return;
    }
  }
  final Clipboard clipboard = window.navigator.clipboard;
  String clipboardText = '';
  try {
    clipboardText = (await clipboard.readText().toDart).toDart;
  } catch (_) {
    clipboardText = '';
  }
  final ClipboardDataPayload? editorClipboardData = getClipboardData();
  if (editorClipboardData != null &&
      normalizeLineBreak(clipboardText) ==
          normalizeLineBreak(editorClipboardData.text)) {
    pasteElement(canvasEvent, editorClipboardData.elementList);
    return;
  }
  removeClipboardData();
  if (option?.isPlainText == true) {
    if (clipboardText.isNotEmpty) {
      canvasEvent.input(clipboardText);
    }
    return;
  }
  List<ClipboardItem> items;
  try {
    final JSArray<ClipboardItem> raw = await clipboard.read().toDart;
    items = raw.toDart;
  } catch (_) {
    if (clipboardText.isNotEmpty) {
      canvasEvent.input(clipboardText);
    }
    return;
  }
  final bool isHTML = items.any(
    (ClipboardItem item) => _extractTypes(item).contains('text/html'),
  );
  for (final ClipboardItem item in items) {
    final List<String> types = _extractTypes(item);
    if (types.contains('text/plain') && !isHTML) {
      final Blob? textBlob = await _getItemBlob(item, 'text/plain');
      if (textBlob != null) {
        final String text = await _blobToString(textBlob);
        if (text.isNotEmpty) {
          canvasEvent.input(text);
        }
      }
    } else if (types.contains('text/html') && isHTML) {
      final Blob? htmlBlob = await _getItemBlob(item, 'text/html');
      if (htmlBlob != null) {
        final String htmlText = await _blobToString(htmlBlob);
        if (htmlText.isNotEmpty) {
          pasteHTML(canvasEvent, htmlText);
        }
      }
    } else {
      final String imageType = types.firstWhere(
        (String type) => type.startsWith('image/'),
        orElse: () => '',
      );
      if (imageType.isNotEmpty) {
        final Blob? imageBlob = await _getItemBlob(item, imageType);
        if (imageBlob != null) {
          pasteImage(canvasEvent, imageBlob);
        }
      }
    }
  }
}

List<String> _extractTypes(ClipboardItem item) {
  try {
    return item.types.toDart.map((JSString value) => value.toDart).toList();
  } catch (_) {
    return <String>[];
  }
}

Future<Blob?> _getItemBlob(ClipboardItem item, String type) async {
  if (type.isEmpty) {
    return null;
  }
  try {
    return await item.getType(type).toDart;
  } catch (_) {
    return null;
  }
}

Future<String> _blobToString(Blob blob) {
  final Completer<String> completer = Completer<String>();
  final FileReader reader = FileReader();
  reader.readAsText(blob);
  StreamSubscription<Event>? loadSub;
  StreamSubscription<Event>? errorSub;
  loadSub = reader.onLoad.listen((_) {
    loadSub?.cancel();
    errorSub?.cancel();
    completer.complete(readerResultAsString(reader) ?? '');
  });
  errorSub = reader.onError.listen((_) {
    loadSub?.cancel();
    errorSub?.cancel();
    completer.complete('');
  });
  return completer.future;
}

bool _shouldPreventDefault(dynamic overrideResult) {
  if (overrideResult == null) {
    return false;
  }
  if (overrideResult is Map) {
    final dynamic value = overrideResult['preventDefault'];
    return value != null && value != false;
  }
  if (jsIsJSObject(overrideResult)) {
    final JSObject jsResult = overrideResult as JSObject;
    if (jsResult.hasProperty('preventDefault'.toJS).toDart) {
      final JSAny? value = jsResult.getProperty('preventDefault'.toJS);
      return value != null && value != false.toJS;
    }
    return false;
  }
  try {
    final dynamic value = overrideResult.preventDefault;
    return value != null && value != false;
  } catch (_) {
    // ignore missing field
  }
  return false;
}
