import 'dart:html' as html;

import 'ua.dart';

bool isMod(html.Event evt) {
  if (evt is html.KeyboardEvent || evt is html.MouseEvent) {
    final dynamic event = evt;
    final bool metaKey = event.metaKey ?? false;
    final bool ctrlKey = event.ctrlKey ?? false;
    return isApple ? metaKey : ctrlKey;
  }
  return false;
}
