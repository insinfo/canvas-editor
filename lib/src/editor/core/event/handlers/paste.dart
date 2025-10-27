import 'dart:async';
import 'dart:html';
import 'dart:js_util' as js_util;

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
  draw.insertElementList(elementList);
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
  fileReader.readAsDataUrl(file);
  fileReader.onLoad.first.then((_) {
    final String? value = fileReader.result?.toString();
    if (value == null) {
      return;
    }
    final ImageElement image = ImageElement()..src = value;
    image.onLoad.first.then((_) {
      final num widthValue =
          js_util.getProperty(image, 'naturalWidth') as num? ??
              js_util.getProperty(image, 'width') as num? ??
              0;
      final num heightValue =
          js_util.getProperty(image, 'naturalHeight') as num? ??
              js_util.getProperty(image, 'height') as num? ??
              0;
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
  final dynamic files = clipboardData.files;
  if (files == null) {
    return;
  }
  final dynamic dartifiedFiles = js_util.dartify(files);
  if (dartifiedFiles is Iterable) {
    for (final dynamic file in dartifiedFiles) {
      if (file is File && file.type.startsWith('image')) {
        pasteImage(canvasEvent, file);
      }
    }
    return;
  }
  try {
    final int length = js_util.getProperty(files, 'length') as int? ?? 0;
    for (var i = 0; i < length; i++) {
      final dynamic file = js_util.hasProperty(files, 'item')
          ? js_util.callMethod(files, 'item', <dynamic>[i])
          : js_util.getProperty(files, i);
      if (file is File && file.type.startsWith('image')) {
        pasteImage(canvasEvent, file);
      }
    }
  } catch (_) {
    // Ignore failures from non-standard FileList implementations.
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
  final dynamic clipboard = js_util.getProperty(window.navigator, 'clipboard');
  if (clipboard == null) {
    return;
  }
  String clipboardText = '';
  try {
    clipboardText = await js_util.promiseToFuture<String>(
      js_util.callMethod(clipboard, 'readText', const <dynamic>[]),
    );
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
  dynamic clipboardItemsRaw;
  try {
    clipboardItemsRaw = await js_util.promiseToFuture(
      js_util.callMethod(clipboard, 'read', const <dynamic>[]),
    );
  } catch (_) {
    clipboardItemsRaw = null;
  }
  final dynamic clipboardItems = js_util.dartify(clipboardItemsRaw);
  if (clipboardItems is! Iterable) {
    if (clipboardText.isNotEmpty) {
      canvasEvent.input(clipboardText);
    }
    return;
  }
  final List<dynamic> items = clipboardItems.toList();
  final bool isHTML = items.any(
    (dynamic item) => _extractTypes(item).contains('text/html'),
  );
  for (final dynamic item in items) {
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

List<String> _extractTypes(dynamic item) {
  if (item == null) {
    return <String>[];
  }
  dynamic types;
  try {
    types = js_util.dartify(js_util.getProperty(item, 'types'));
  } catch (_) {
    types = null;
  }
  if (types is Iterable) {
    return types.map((dynamic value) => value.toString()).toList();
  }
  if (types is String) {
    return <String>[types];
  }
  return <String>[];
}

Future<Blob?> _getItemBlob(dynamic item, String type) async {
  if (item == null || type.isEmpty) {
    return null;
  }
  try {
    final dynamic result = js_util.callMethod(item, 'getType', <dynamic>[type]);
    final dynamic blob = await js_util.promiseToFuture(result);
    if (blob is Blob) {
      return blob;
    }
  } catch (_) {
    return null;
  }
  return null;
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
    completer.complete(reader.result?.toString() ?? '');
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
  try {
    if (js_util.hasProperty(overrideResult, 'preventDefault')) {
      final dynamic value =
          js_util.getProperty(overrideResult, 'preventDefault');
      if (value != null && value != false) {
        return true;
      }
    }
  } catch (_) {
    // ignore interop read failure
  }
  try {
    final dynamic value = overrideResult.preventDefault;
    return value != null && value != false;
  } catch (_) {
    // ignore missing field
  }
  return false;
}
