import 'package:canvas_text_editor/canvas_text_editor.dart';
import 'package:canvas_text_editor/src/dom/dom.dart';

void main() {
  final HTMLDivElement host =
      document.querySelector('#editor-host') as HTMLDivElement;
  final HTMLButtonElement modeButton =
      document.querySelector('#mode-toggle') as HTMLButtonElement;
  final HTMLButtonElement settingsToggle =
      document.querySelector('#settings-toggle') as HTMLButtonElement;
  final HTMLButtonElement settingsClose =
      document.querySelector('#settings-close') as HTMLButtonElement;
  final Element settingsPanel =
      document.querySelector('#settings-panel') as Element;

  // ── Settings checkboxes ──
  final HTMLInputElement optWordMode =
      document.querySelector('#opt-word-mode') as HTMLInputElement;
  final HTMLInputElement optToolbar =
      document.querySelector('#opt-toolbar') as HTMLInputElement;
  final HTMLInputElement optTitlebar =
      document.querySelector('#opt-titlebar') as HTMLInputElement;
  final HTMLInputElement optCatalog =
      document.querySelector('#opt-catalog') as HTMLInputElement;
  final HTMLInputElement optStatusbar =
      document.querySelector('#opt-statusbar') as HTMLInputElement;
  final HTMLInputElement optPageMode =
      document.querySelector('#opt-page-mode') as HTMLInputElement;
  final HTMLInputElement optReadonly =
      document.querySelector('#opt-readonly') as HTMLInputElement;

  // ── Current state ──
  String currentHeight = 'calc(100vh - 230px)';
  bool isViewer = false;
  late CanvasEditorWidget widget;

  CanvasEditorWidget createWidget() {
    final CanvasEditorAppearance appearance = optWordMode.checked
        ? CanvasEditorAppearance.word
        : CanvasEditorAppearance.compact;

    final CanvasEditorWidgetMode mode = (optReadonly.checked || isViewer)
        ? CanvasEditorWidgetMode.viewer
        : CanvasEditorWidgetMode.editor;

    return CanvasEditorWidget(
      host,
      config: CanvasEditorConfig(
        height: currentHeight,
        mode: mode,
        appearance: appearance,
        showToolbar: optToolbar.checked,
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
    settingsPanel.classList.toggle('settings-panel--hidden');
  });
  settingsClose.onClick.listen((_) {
    settingsPanel.classList.add('settings-panel--hidden');
  });

  // ── Mode toggle ──
  modeButton.onClick.listen((_) {
    isViewer = !isViewer;
    widget.setMode(
      isViewer ? CanvasEditorWidgetMode.viewer : CanvasEditorWidgetMode.editor,
    );
    modeButton.textContent = isViewer ? 'Back to Editor' : 'Open as Viewer';
  });

  // ── Settings that require full rebuild ──
  optWordMode.onChange.listen((_) => rebuild());
  optToolbar.onChange.listen((_) => rebuild());

  // ── Settings that can be applied at runtime ──
  optTitlebar.onChange.listen((_) {
    _toggleTitlebar(widget, optTitlebar.checked);
  });

  optCatalog.onChange.listen((_) {
    final bool show = optCatalog.checked;
    if (show != widget.catalogPanel.isVisible) {
      widget.toggleCatalog();
    }
  });

  optStatusbar.onChange.listen((_) {
    _toggleStatusbar(widget, optStatusbar.checked);
  });

  optPageMode.onChange.listen((_) {
    _togglePageMode(widget, optPageMode.checked);
  });

  optReadonly.onChange.listen((_) {
    final bool ro = optReadonly.checked;
    widget.setMode(
      ro ? CanvasEditorWidgetMode.viewer : CanvasEditorWidgetMode.editor,
    );
  });

  // ── Height buttons ──
  for (final HTMLButtonElement btn in document
      .querySelectorAll('[data-height]')
      .toElements()
      .whereType<HTMLButtonElement>()) {
    btn.onClick.listen((_) {
      currentHeight = btn.data('height') ?? currentHeight;
      widget.root.querySelector('.ce-embed__scroll')?.style.height =
          currentHeight;
      // Update active state
      for (final Element sibling
          in document.querySelectorAll('[data-height]').toElements()) {
        sibling.classList.toggle(
            'demo-btn--active', sibling.data('height') == currentHeight);
      }
    });
  }

  // Apply initial runtime toggles
  _applyRuntimeToggles(widget, optTitlebar, optStatusbar, optPageMode);
}

void _applyRuntimeToggles(
  CanvasEditorWidget widget,
  HTMLInputElement optTitlebar,
  HTMLInputElement optStatusbar,
  HTMLInputElement optPageMode,
) {
  _toggleTitlebar(widget, optTitlebar.checked);
  _toggleStatusbar(widget, optStatusbar.checked);
  _togglePageMode(widget, optPageMode.checked);
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
