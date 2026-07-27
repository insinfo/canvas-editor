import 'package:canvas_text_editor/src/dom/dom.dart';

enum PreviewerMime {
  png('png'),
  jpg('jpg'),
  jpeg('jpeg'),
  svg('svg');

  final String value;

  const PreviewerMime(this.value);
}

class IPreviewerCreateResult {
  HTMLDivElement resizerSelection;
  List<HTMLDivElement> resizerHandleList;
  HTMLDivElement resizerImageContainer;
  HTMLImageElement resizerImage;
  HTMLSpanElement resizerSize;

  IPreviewerCreateResult({
    required this.resizerSelection,
    required this.resizerHandleList,
    required this.resizerImageContainer,
    required this.resizerImage,
    required this.resizerSize,
  });
}

class IPreviewerDrawOption {
  PreviewerMime? mime;
  String? srcKey;
  bool? dragDisable;

  IPreviewerDrawOption({
    this.mime,
    this.srcKey,
    this.dragDisable,
  });
}
