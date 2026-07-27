import 'package:canvas_text_editor/src/dom/dom.dart' as html;

import "./paste.dart" show pasteImage;

void drop(dynamic evt, dynamic host) {
  final dynamic draw = host.getDraw();
  final dynamic override = draw.getOverride();
  final dynamic overrideDrop = override?.drop;
  if (overrideDrop is Function) {
    final dynamic overrideResult = overrideDrop(evt);
    if (_shouldPreventDefault(overrideResult)) {
      return;
    }
  }

  final html.Event? event =
      html.jsIsEvent(evt) ? evt as html.Event : null;
  if (event == null) {
    return;
  }
  event.preventDefault();

  final html.DataTransfer? dataTransfer = _getDataTransfer(event);
  final String? textData = dataTransfer?.getData('text');
  if (textData != null && textData.isNotEmpty) {
    host.input(textData);
    return;
  }

  final List<html.File> files = html.filesOf(dataTransfer?.files);
  for (var i = 0; i < files.length; i++) {
    final html.File file = files[i];
    if (file.type.startsWith("image")) {
      pasteImage(host, file);
    }
  }
}

html.DataTransfer? _getDataTransfer(html.Event event) {
  try {
    final html.JSAny? value =
        (event as html.JSObject).getProperty('dataTransfer'.toJS);
    if (value != null && value.isA<html.DataTransfer>()) {
      return value as html.DataTransfer;
    }
    return null;
  } catch (_) {
    return null;
  }
}

bool _shouldPreventDefault(dynamic overrideResult) {
  if (overrideResult == null) {
    return false;
  }
  if (overrideResult is Map) {
    final dynamic value = overrideResult['preventDefault'];
    return value != null && value != false;
  }
  if (html.jsIsJSObject(overrideResult)) {
    final html.JSObject jsResult = overrideResult as html.JSObject;
    if (jsResult.hasProperty('preventDefault'.toJS).toDart) {
      final html.JSAny? value = jsResult.getProperty('preventDefault'.toJS);
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
