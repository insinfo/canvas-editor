# canvas_text_editor

DOCX canvas editor and viewer for pure Dart Web and AngularDart 8. The package
manages its own scrolling and can be embedded in cards, grids, pages and modals
without relying on `body` scrolling.

## Dart Web

```dart
import 'dart:html';
import 'package:canvas_text_editor/canvas_text_editor.dart';

void main() {
  CanvasEditorWidget(
    document.querySelector('#editor-host') as HtmlElement,
    config: CanvasEditorConfig(
      height: '600px',
      mode: CanvasEditorWidgetMode.editor,
      appearance: CanvasEditorAppearance.word,
      data: IEditorData(main: <IElement>[IElement(value: 'Document')]),
    ),
  );
}
```

The consumer HTML only needs the host element:

```html
<div id="editor-host"></div>
```

## Read-only Viewer

```dart
final viewer = CanvasEditorWidget(
  host,
  config: CanvasEditorConfig(
    mode: CanvasEditorWidgetMode.viewer,
    showToolbar: false,
    height: '70vh',
  ),
);
viewer.loadDocx(bytes);
```

The `viewer` mode uses `EditorMode.readonly`, does not create the formatting
toolbar and hides the cursor and input area. `setMode(...)` allows switching
the same document at runtime.

## Interface Appearance

- `CanvasEditorAppearance.compact`: small toolbar for cards and modals.
- `CanvasEditorAppearance.word`: title bar, File/Home/Insert/Layout/View tabs
  and grouped ribbon, inspired by Microsoft Word.

Both interfaces are built dynamically by the component. To open a file via the
UI use `editor.openFilePicker()`; the input remains attached to the DOM and
`onDocumentLoaded`/`onError` report the result.

## AngularDart

Create the widget in `ngAfterViewInit` and release listeners in `ngOnDestroy`:

```dart
@ViewChild('editorHost')
DivElement? editorHost;

CanvasEditorWidget? editor;

void ngAfterViewInit() {
  editor = CanvasEditorWidget(
    editorHost!,
    config: CanvasEditorConfig(height: '560px'),
  );
}

void ngOnDestroy() => editor?.destroy();
```

See the full integration with `ngdart: 8.0.0-dev.4`, `limitless_ui` and
Limitless CSS in [example2](example2/README.md).

## Assets

The controls use the official Tabler Icons 3.44.0 webfont, included in
`lib/assets/icons/tabler`. The CSS classes are stable (`ti ti-bold`,
`ti ti-printer`, etc.) and there is no dependency on SVG icon files.

## Known Regressions (v2.0.0-dev)

> **Warning**: This version is a complete restructuring of the codebase.
> Several Word-mode UI features are currently broken and will be restored in
> upcoming commits. See the [CHANGELOG](CHANGELOG.md) for a detailed list.
