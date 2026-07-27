import 'package:canvas_text_editor/src/dom/dom.dart' as html;

import 'ua.dart';

bool isMod(html.Event evt) {
  // Acesso tipado obrigatório: dispatch dinâmico em objeto JS falha no dart2js.
  if (html.jsIsKeyboardEvent(evt)) {
    final html.KeyboardEvent event = evt as html.KeyboardEvent;
    return isApple ? event.metaKey : event.ctrlKey;
  }
  if (html.jsIsMouseEvent(evt)) {
    final html.MouseEvent event = evt as html.MouseEvent;
    return isApple ? event.metaKey : event.ctrlKey;
  }
  return false;
}
