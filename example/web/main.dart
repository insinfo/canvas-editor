import 'dart:html';

import 'package:canvas_text_editor/canvas_text_editor.dart';

void main() {
  final DivElement host = document.querySelector('#editor-host') as DivElement;
  final ButtonElement modeButton =
      document.querySelector('#mode-toggle') as ButtonElement;
  final ButtonElement settingsToggle =
      document.querySelector('#settings-toggle') as ButtonElement;
  final ButtonElement settingsClose =
      document.querySelector('#settings-close') as ButtonElement;
  final Element settingsPanel =
      document.querySelector('#settings-panel') as Element;

  // ── Settings checkboxes ──
  final InputElement optWordMode =
      document.querySelector('#opt-word-mode') as InputElement;
  final InputElement optToolbar =
      document.querySelector('#opt-toolbar') as InputElement;
  final InputElement optTitlebar =
      document.querySelector('#opt-titlebar') as InputElement;
  final InputElement optCatalog =
      document.querySelector('#opt-catalog') as InputElement;
  final InputElement optStatusbar =
      document.querySelector('#opt-statusbar') as InputElement;
  final InputElement optPageMode =
      document.querySelector('#opt-page-mode') as InputElement;
  final InputElement optReadonly =
      document.querySelector('#opt-readonly') as InputElement;

  // ── Current state ──
  String currentHeight = 'calc(100vh - 230px)';
  bool isViewer = false;
  late CanvasEditorWidget widget;

  CanvasEditorWidget createWidget() {
    final CanvasEditorAppearance appearance = optWordMode.checked == true
        ? CanvasEditorAppearance.word
        : CanvasEditorAppearance.compact;

    final CanvasEditorWidgetMode mode =
        (optReadonly.checked == true || isViewer)
            ? CanvasEditorWidgetMode.viewer
            : CanvasEditorWidgetMode.editor;

    return CanvasEditorWidget(
      host,
      config: CanvasEditorConfig(
        height: currentHeight,
        mode: mode,
        appearance: appearance,
        showToolbar: optToolbar.checked ?? true,
        documentTitle: 'Document — Canvas Editor',
        data: IEditorData(main: _sampleDocument()),
        editorOptions: IEditorOption(
          margins: <double>[76, 82, 76, 82],
          placeholder: IPlaceholder(data: 'Start typing your document...'),
        ),
      ),
    );
  }

  widget = createWidget();

  // Rebuild the editor when any structural setting changes.
  void rebuild() {
    widget.destroy();
    widget = createWidget();
    _applyRuntimeToggles(widget, optTitlebar, optStatusbar, optPageMode);
  }

  // ── Settings panel toggle ──
  settingsToggle.onClick.listen((_) {
    settingsPanel.classes.toggle('settings-panel--hidden');
  });
  settingsClose.onClick.listen((_) {
    settingsPanel.classes.add('settings-panel--hidden');
  });

  // ── Mode toggle ──
  modeButton.onClick.listen((_) {
    isViewer = !isViewer;
    widget.setMode(
      isViewer ? CanvasEditorWidgetMode.viewer : CanvasEditorWidgetMode.editor,
    );
    modeButton.text = isViewer ? 'Back to Editor' : 'Open as Viewer';
  });

  // ── Settings that require full rebuild ──
  optWordMode.onChange.listen((_) => rebuild());
  optToolbar.onChange.listen((_) => rebuild());

  // ── Settings that can be applied at runtime ──
  optTitlebar.onChange.listen((_) {
    _toggleTitlebar(widget, optTitlebar.checked == true);
  });

  optCatalog.onChange.listen((_) {
    final bool show = optCatalog.checked == true;
    if (show != widget.catalogPanel.isVisible) {
      widget.toggleCatalog();
    }
  });

  optStatusbar.onChange.listen((_) {
    _toggleStatusbar(widget, optStatusbar.checked == true);
  });

  optPageMode.onChange.listen((_) {
    _togglePageMode(widget, optPageMode.checked == true);
  });

  optReadonly.onChange.listen((_) {
    final bool ro = optReadonly.checked == true;
    widget.setMode(
      ro ? CanvasEditorWidgetMode.viewer : CanvasEditorWidgetMode.editor,
    );
  });

  // ── Height buttons ──
  for (final ButtonElement btn
      in document.querySelectorAll('[data-height]').cast<ButtonElement>()) {
    btn.onClick.listen((_) {
      currentHeight = btn.dataset['height'] ?? currentHeight;
      widget.root.querySelector('.ce-embed__scroll')?.style.height =
          currentHeight;
      // Update active state
      for (final Element sibling
          in document.querySelectorAll('[data-height]')) {
        sibling.classes.toggle(
            'demo-btn--active', sibling.dataset['height'] == currentHeight);
      }
    });
  }

  // Apply initial runtime toggles
  _applyRuntimeToggles(widget, optTitlebar, optStatusbar, optPageMode);
}

void _applyRuntimeToggles(
  CanvasEditorWidget widget,
  InputElement optTitlebar,
  InputElement optStatusbar,
  InputElement optPageMode,
) {
  _toggleTitlebar(widget, optTitlebar.checked == true);
  _toggleStatusbar(widget, optStatusbar.checked == true);
  _togglePageMode(widget, optPageMode.checked == true);
}

void _toggleTitlebar(CanvasEditorWidget widget, bool show) {
  final Element? titlebar = widget.root.querySelector('.ce-word-titlebar');
  if (titlebar != null) {
    titlebar.style.display = show ? '' : 'none';
  }
}

void _toggleStatusbar(CanvasEditorWidget widget, bool show) {
  widget.setStatusBarVisible(show);
}

void _togglePageMode(CanvasEditorWidget widget, bool paginated) {
  try {
    widget.command.executePageMode(
      paginated ? PageMode.paging : PageMode.continuity,
    );
  } catch (_) {
    // Page mode command may not be available in all states.
  }
}

List<IElement> _sampleDocument() => <IElement>[
      IElement(
        value: '',
        type: ElementType.title,
        level: TitleLevel.first,
        valueList: <IElement>[
          IElement(value: 'Dart Web Document', size: 26, bold: true),
        ],
      ),
      IElement(
        value:
            '\nThis editor interface was built by the Dart component in lib/src/components. '
            'The index.html contains no ribbon, canvas, or editing controls.',
      ),
      IElement(
        value:
            '\nUse the settings panel (gear icon) above to toggle editor features '
            'like the title bar, toolbar, catalog, status bar, and page mode.',
      ),
      for (int index = 1; index <= 20; index++)
        IElement(
          value:
              '\nParagraph $index — scroll this area to verify the internal scrolling is '
              'independent of the body.',
        ),
    ];
