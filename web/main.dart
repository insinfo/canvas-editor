import 'dart:html';

import 'package:canvas_text_editor/src/editor.dart';

// window.onLoad.listen não funciona com dart DDC ou seja  webdev serve so funciona sem o window.onLoad.listen
// ja para webdev build ai sim o window.onLoad.listen funciona
// executar com webdev serve --auto refresh
void main() {
  void startEditor() {
    final userAgent = window.navigator.userAgent;
    final isApple = userAgent.contains('Mac OS X');
    EditorApp(isApple: isApple).initialize();
  }

  if (document.readyState == 'loading') {
    document.onReadyStateChange
        .firstWhere((_) => document.readyState != 'loading')
        .then((_) => startEditor());
    return;
  }

  startEditor();
}
