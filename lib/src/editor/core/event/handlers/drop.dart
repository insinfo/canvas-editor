import 'dart:html' as html;
import 'dart:js_util' as js_util;

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

  final html.Event? event = evt is html.Event ? evt : null;
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

  final List<html.File>? files = dataTransfer?.files;
  if (files == null) {
    return;
  }
  for (var i = 0; i < files.length; i++) {
    final html.File file = files[i];
    if (file.type.startsWith("image")) {
      pasteImage(host, file);
    }
  }
}

html.DataTransfer? _getDataTransfer(html.Event event) {
  try {
    final dynamic value = js_util.getProperty(event, 'dataTransfer');
    if (value is html.DataTransfer) {
      return value;
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
