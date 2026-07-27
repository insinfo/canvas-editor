import 'dart:async';

import 'package:canvas_text_editor/src/dom/dom.dart';

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

  final HTMLIFrameElement iframe = HTMLIFrameElement()
    ..style.visibility = 'hidden'
    ..style.position = 'absolute'
    ..style.left = '0'
    ..style.top = '0'
    ..style.width = '0'
    ..style.height = '0'
    ..style.border = 'none';

  document.body?.append(iframe);
  // Objeto JS cru do frame (o wrapper tipado não expõe write/print cross-doc).
  final JSObject? contentWindow =
      (iframe as JSObject).getProperty('contentWindow'.toJS) as JSObject?;
  if (contentWindow == null) {
    iframe.remove();
    return;
  }

  final JSObject? doc =
      contentWindow.getProperty('document'.toJS) as JSObject?;
  if (doc == null) {
    iframe.remove();
    return;
  }

  final _PaperSize paperSize = _convertPxToPaperSize(width, height);
  final HTMLDivElement container = HTMLDivElement();
  for (final String base64 in base64List) {
    final HTMLImageElement image = HTMLImageElement()
      ..style.width = direction == PaperDirection.horizontal
          ? paperSize.height
          : paperSize.width
      ..style.height = direction == PaperDirection.horizontal
          ? paperSize.width
          : paperSize.height
      ..src = base64;
    container.append(image);
  }

  final HTMLStyleElement style = HTMLStyleElement()
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

  doc.callMethod('open'.toJS);

  scheduleMicrotask(() {
    doc.callMethod(
      'write'.toJS,
      '${style.outerHtml}${container.innerHtml}'.toJS,
    );
    Future<void>.delayed(Duration.zero, () {
      try {
        contentWindow.callMethod('focus'.toJS);
      } catch (_) {}
      contentWindow.callMethod('print'.toJS);
      doc.callMethod('close'.toJS);
      window.onMouseOver.first.then((_) => iframe.remove());
    });
  });
}
