import 'dart:html';

import '../core/ui_component.dart';

abstract class CanvasViewerActions {
  void viewerPreviousPage();
  void viewerNextPage();
  void viewerZoomOut();
  void viewerZoomIn();
  void viewerPrint();
  void viewerDownload();
}

/// Barra minimalista do modo visualizador, semelhante a um leitor de PDF.
class WidgetViewerToolbar extends UiComponent {
  WidgetViewerToolbar(this._actions) {
    root = DivElement()
      ..classes.add('ce-viewer-toolbar')
      ..setAttribute('role', 'toolbar')
      ..setAttribute('aria-label', 'Controles do visualizador')
      ..children.addAll(<Element>[
        _button(
            'ti-chevron-left', 'Página anterior', _actions.viewerPreviousPage),
        _button('ti-chevron-right', 'Próxima página', _actions.viewerNextPage),
        DivElement()..classes.add('ce-viewer-toolbar__separator'),
        _button('ti-zoom-out', 'Reduzir zoom', _actions.viewerZoomOut),
        _button('ti-zoom-in', 'Ampliar zoom', _actions.viewerZoomIn),
        DivElement()..classes.add('ce-viewer-toolbar__separator'),
        _button('ti-download', 'Baixar documento', _actions.viewerDownload),
        _button('ti-printer', 'Imprimir', _actions.viewerPrint),
      ]);
  }

  final CanvasViewerActions _actions;

  @override
  late final DivElement root;

  ButtonElement _button(String icon, String label, void Function() action) =>
      ButtonElement()
        ..type = 'button'
        ..title = label
        ..setAttribute('aria-label', label)
        ..append(SpanElement()..classes.addAll(<String>['ti', icon]))
        ..onClick.listen((_) => action());

  void setVisible(bool visible) {
    root.style.display = visible ? '' : 'none';
  }
}
