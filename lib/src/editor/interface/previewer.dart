import 'dart:html';

enum PreviewerMime {
  png('png'),
  jpg('jpg'),
  jpeg('jpeg'),
  svg('svg');

  final String value;

  const PreviewerMime(this.value);
}

class IPreviewerCreateResult {
  DivElement resizerSelection;
  List<DivElement> resizerHandleList;
  DivElement resizerImageContainer;
  ImageElement resizerImage;
  SpanElement resizerSize;

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
