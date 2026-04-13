import 'dart:async';
import 'dart:html';
import 'dart:js_util' as js_util;

import '../dataset/enum/editor.dart';

class _PaperSize {
  const _PaperSize({
    required this.size,
    required this.width,
    required this.height,
  });

  final String size;
  final String width;
  final String height;
}

_PaperSize _convertPxToPaperSize(int width, int height) {
  if (width == 1125 && height == 1593) {
    return const _PaperSize(size: 'a3', width: '297mm', height: '420mm');
  }
  if (width == 794 && height == 1123) {
    return const _PaperSize(size: 'a4', width: '210mm', height: '297mm');
  }
  if (width == 565 && height == 796) {
    return const _PaperSize(size: 'a5', width: '148mm', height: '210mm');
  }
  return _PaperSize(
    size: '',
    width: '${width}px',
    height: '${height}px',
  );
}

void printImageBase64(
  List<String> base64List, {
  required int width,
  required int height,
  PaperDirection direction = PaperDirection.vertical,
}) {
  if (base64List.isEmpty) {
    return;
  }

  final IFrameElement iframe = IFrameElement()
    ..style.visibility = 'hidden'
    ..style.position = 'absolute'
    ..style.left = '0'
    ..style.top = '0'
    ..style.width = '0'
    ..style.height = '0'
    ..style.border = 'none';

  document.body?.append(iframe);
  final dynamic contentWindow = js_util.getProperty(iframe, 'contentWindow');
  if (contentWindow == null) {
    iframe.remove();
    return;
  }

  final dynamic doc = js_util.getProperty(contentWindow, 'document');
  if (doc == null) {
    iframe.remove();
    return;
  }

  final _PaperSize paperSize = _convertPxToPaperSize(width, height);
  final DivElement container = DivElement();
  for (final String base64 in base64List) {
    final ImageElement image = ImageElement()
      ..style.width = direction == PaperDirection.horizontal
          ? paperSize.height
          : paperSize.width
      ..style.height = direction == PaperDirection.horizontal
          ? paperSize.width
          : paperSize.height
      ..src = base64;
    container.append(image);
  }

  final StyleElement style = StyleElement()
    ..appendText('''
  * {
    margin: 0;
    padding: 0;
  }
  @page {
    margin: 0;
    size: ${paperSize.size} ${direction == PaperDirection.horizontal ? 'landscape' : 'portrait'};
  }
''');

  js_util.callMethod<void>(doc, 'open', const <dynamic>[]);

  scheduleMicrotask(() {
    js_util.callMethod<void>(
      doc,
      'write',
      <dynamic>['${style.outerHtml}${container.innerHtml}'],
    );
    Future<void>.delayed(Duration.zero, () {
      try {
        js_util.callMethod<void>(contentWindow, 'focus', const <dynamic>[]);
      } catch (_) {}
      js_util.callMethod<void>(contentWindow, 'print', const <dynamic>[]);
      js_util.callMethod<void>(doc, 'close', const <dynamic>[]);
      window.onMouseOver.first.then((_) => iframe.remove());
    });
  });
}
