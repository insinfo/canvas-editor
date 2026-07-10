import 'dart:html';

import '../core/ui_component.dart';

/// Overlay de carregamento do widget: feedback visual para operações
/// síncronas longas (abrir/salvar DOCX, exportar imagem). O `show` cede o
/// event loop (2× `window.animationFrame`) para o browser pintar o overlay
/// antes do trabalho pesado começar.
class WidgetLoadingOverlay extends UiComponent {
  WidgetLoadingOverlay(DivElement host) {
    root = DivElement()
      ..classes.add('ce-loading-overlay')
      ..style.display = 'none'
      ..append(DivElement()..classes.add('ce-loading-overlay__spinner'))
      ..append(_label = DivElement()..classes.add('ce-loading-overlay__label'));
    host.append(root);
  }

  @override
  late final DivElement root;
  late final DivElement _label;

  Future<void> show(String message) async {
    _label.text = message;
    root.style.display = 'flex';
    await window.animationFrame;
    await window.animationFrame;
  }

  void hide() {
    root.style.display = 'none';
  }
}
