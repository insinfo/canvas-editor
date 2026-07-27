import 'package:canvas_text_editor/src/dom/dom.dart';

import '../core/ui_component.dart';

/// Overlay de carregamento do widget: feedback visual para operações
/// síncronas longas (abrir/salvar DOCX, exportar imagem). O `show` cede o
/// event loop (2× `window.animationFrame`) para o browser pintar o overlay
/// antes do trabalho pesado começar.
class WidgetLoadingOverlay extends UiComponent {
  WidgetLoadingOverlay(HTMLDivElement host) {
    root = HTMLDivElement()
      ..classList.add('ce-loading-overlay')
      ..style.display = 'none'
      ..append(HTMLDivElement()..classList.add('ce-loading-overlay__spinner'))
      ..append(_label = HTMLDivElement()..classList.add('ce-loading-overlay__label'));
    host.append(root);
  }

  @override
  late final HTMLDivElement root;
  late final HTMLDivElement _label;

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
