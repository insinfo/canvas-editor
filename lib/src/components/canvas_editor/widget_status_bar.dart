import 'package:canvas_text_editor/src/dom/dom.dart';

import '../../editor/index.dart';
import '../core/ui_component.dart';

/// Barra de status estilo Word na base do widget: página atual/total,
/// contagem de palavras, alternância paginado/contínuo e controles de zoom.
///
/// A barra é passiva: o [CanvasEditorWidget] alimenta os valores a partir dos
/// listeners do editor (`intersectionPageNoChange`, `pageSizeChange`,
/// `pageScaleChange`, `pageModeChange`, `contentChange`).
class WidgetStatusBar extends UiComponent {
  WidgetStatusBar(this._command) {
    root = _build();
  }

  final Command _command;

  @override
  late final HTMLDivElement root;

  late final HTMLSpanElement _pageLabel;
  late final HTMLSpanElement _wordLabel;
  late final HTMLButtonElement _zoomLabel;
  late final HTMLInputElement _zoomSlider;
  late final HTMLButtonElement _pagingButton;
  late final HTMLButtonElement _continuousButton;

  int _currentPage = 1;
  int _pageCount = 1;

  /// Índice 0-based da página visível — usado pela exportação de imagem.
  int get currentPageIndex => _currentPage - 1;

  HTMLDivElement _build() {
    _pageLabel = HTMLSpanElement()
      ..classList.add('ce-statusbar__pages')
      ..text = 'Página 1 de 1';
    _wordLabel = HTMLSpanElement()
      ..classList.add('ce-statusbar__words')
      ..text = '0 palavras';

    _pagingButton = _iconButton('ti-file', 'Modo paginado',
        () => _command.executePageMode(PageMode.paging))
      ..classList.add('active');
    _continuousButton = _iconButton('ti-arrows-vertical', 'Modo contínuo',
        () => _command.executePageMode(PageMode.continuity));

    _zoomSlider = (HTMLInputElement()..type = 'range')
      ..classList.add('ce-statusbar__zoom-slider')
      ..min = '50'
      ..max = '300'
      ..step = '10'
      ..value = '100'
      ..title = 'Zoom';
    _zoomSlider.onInput.listen((_) {
      final int? percent = int.tryParse(_zoomSlider.value);
      if (percent != null) {
        _command.executePageScale(percent / 100);
      }
    });
    _zoomLabel = HTMLButtonElement()
      ..type = 'button'
      ..classList.add('ce-statusbar__zoom-label')
      ..title = 'Restaurar zoom para 100%'
      ..text = '100%'
      ..onClick.listen((_) => _command.executePageScaleRecovery());

    return HTMLDivElement()
      ..classList.add('ce-statusbar')
      ..appendAll(<Element>[
        HTMLDivElement()
          ..classList.add('ce-statusbar__left')
          ..appendAll(<Element>[_pageLabel, _wordLabel]),
        HTMLDivElement()
          ..classList.add('ce-statusbar__right')
          ..appendAll(<Element>[
            _pagingButton,
            _continuousButton,
            _iconButton('ti-zoom-out', 'Reduzir zoom',
                () => _command.executePageScaleMinus()),
            _zoomSlider,
            _iconButton('ti-zoom-in', 'Ampliar zoom',
                () => _command.executePageScaleAdd()),
            _zoomLabel,
          ]),
      ]);
  }

  HTMLButtonElement _iconButton(
      String iconClass, String label, void Function() action) {
    return HTMLButtonElement()
      ..type = 'button'
      ..title = label
      ..setAttribute('aria-label', label)
      ..append(HTMLSpanElement()..classList.addAll(<String>['ti', iconClass]))
      ..onClick.listen((_) => action());
  }

  void setCurrentPage(int pageNo) {
    _currentPage = pageNo;
    _syncPageLabel();
  }

  void setPageCount(int count) {
    _pageCount = count;
    _syncPageLabel();
  }

  void _syncPageLabel() {
    _pageLabel.text = 'Página $_currentPage de $_pageCount';
  }

  void setWordCount(int count) {
    _wordLabel.text = count == 1 ? '1 palavra' : '$count palavras';
  }

  /// Esconde o contador de palavras (config.showWordCount = false — a
  /// contagem é O(doc) por mudança e pode ser desligada em docs grandes).
  void hideWordCount() {
    _wordLabel.style.display = 'none';
  }

  void setScale(double scale) {
    final int percent = (scale * 100).floor();
    _zoomLabel.text = '$percent%';
    _zoomSlider.value = '${percent.clamp(50, 300)}';
  }

  void setPageMode(PageMode mode) {
    _pagingButton.classList.toggle('active', mode == PageMode.paging);
    _continuousButton.classList.toggle('active', mode == PageMode.continuity);
  }

  void setVisible(bool visible) {
    root.style.display = visible ? '' : 'none';
  }
}
