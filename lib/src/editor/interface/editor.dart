import '../dataset/enum/Editor.dart';
import '../dataset/enum/Common.dart';
import './Element.dart';
import './Range.dart';

// Placeholders for missing imports
class IBackgroundOption {}
class ICheckboxOption {}
class IRadioOption {}
class IControlOption {}
class ICursorOption {}
class IFooter {}
class IGroup {}
class IHeader {}
class ILineBreakOption {}
class IMargin {}
class IPageBreak {}
class IPageNumber {}
class IPlaceholder {}
class ITitleOption {}
class IWatermark {}
class IZoneOption {}
class ISeparatorOption {}
class ITableOption {}
class ILineNumberOption {}
class IPageBorderOption {}
class IBadgeOption {}
class IRange {}

class IEditorData {
  List<IElement>? header;
  List<IElement> main;
  List<IElement>? footer;

  IEditorData({
    this.header,
    required this.main,
    this.footer,
  });
}

class IEditorOption {
  EditorMode? mode;
  String? locale;
  String? defaultType;
  String? defaultColor;
  String? defaultFont;
  int? defaultSize;
  int? minSize;
  int? maxSize;
  double? defaultBasicRowMarginHeight;
  double? defaultRowMargin;
  double? defaultTabWidth;
  double? width;
  double? height;
  double? scale;
  double? pageGap;
  String? underlineColor;
  String? strikeoutColor;
  String? rangeColor;
  double? rangeAlpha;
  double? rangeMinWidth;
  String? searchMatchColor;
  String? searchNavigateMatchColor;
  double? searchMatchAlpha;
  double? highlightAlpha;
  double? highlightMarginHeight;
  String? resizerColor;
  int? resizerSize;
  int? marginIndicatorSize;
  String? marginIndicatorColor;
  IMargin? margins;
  PageMode? pageMode;
  RenderMode? renderMode;
  String? defaultHyperlinkColor;
  PaperDirection? paperDirection;
  double? inactiveAlpha;
  int? historyMaxRecordCount;
  double? printPixelRatio;
  IMargin? maskMargin;
  List<String>? letterClass;
  List<String>? contextMenuDisableKeys;
  List<String>? shortcutDisableKeys;
  String? scrollContainerSelector;
  bool? pageOuterSelectionDisable;
  WordBreak? wordBreak;
  ITableOption? table;
  IHeader? header;
  IFooter? footer;
  IPageNumber? pageNumber;
  IWatermark? watermark;
  IControlOption? control;
  ICheckboxOption? checkbox;
  IRadioOption? radio;
  ICursorOption? cursor;
  ITitleOption? title;
  IPlaceholder? placeholder;
  IGroup? group;
  IPageBreak? pageBreak;
  IZoneOption? zone;
  IBackgroundOption? background;
  ILineBreakOption? lineBreak;
  ISeparatorOption? separator;
  ILineNumberOption? lineNumber;
  IPageBorderOption? pageBorder;
  IBadgeOption? badge;
  IModeRule? modeRule;

  IEditorOption({
    this.mode,
    this.locale,
    this.defaultType,
    this.defaultColor,
    this.defaultFont,
    this.defaultSize,
    this.minSize,
    this.maxSize,
    this.defaultBasicRowMarginHeight,
    this.defaultRowMargin,
    this.defaultTabWidth,
    this.width,
    this.height,
    this.scale,
    this.pageGap,
    this.underlineColor,
    this.strikeoutColor,
    this.rangeColor,
    this.rangeAlpha,
    this.rangeMinWidth,
    this.searchMatchColor,
    this.searchNavigateMatchColor,
    this.searchMatchAlpha,
    this.highlightAlpha,
    this.highlightMarginHeight,
    this.resizerColor,
    this.resizerSize,
    this.marginIndicatorSize,
    this.marginIndicatorColor,
    this.margins,
    this.pageMode,
    this.renderMode,
    this.defaultHyperlinkColor,
    this.paperDirection,
    this.inactiveAlpha,
    this.historyMaxRecordCount,
    this.printPixelRatio,
    this.maskMargin,
    this.letterClass,
    this.contextMenuDisableKeys,
    this.shortcutDisableKeys,
    this.scrollContainerSelector,
    this.pageOuterSelectionDisable,
    this.wordBreak,
    this.table,
    this.header,
    this.footer,
    this.pageNumber,
    this.watermark,
    this.control,
    this.checkbox,
    this.radio,
    this.cursor,
    this.title,
    this.placeholder,
    this.group,
    this.pageBreak,
    this.zone,
    this.background,
    this.lineBreak,
    this.separator,
    this.lineNumber,
    this.pageBorder,
    this.badge,
    this.modeRule,
  });
}

class IEditorResult {
  String version;
  IEditorData data;
  IEditorOption options;

  IEditorResult({
    required this.version,
    required this.data,
    required this.options,
  });
}

class IEditorHTML {
  String header;
  String main;
  String footer;

  IEditorHTML({
    required this.header,
    required this.main,
    required this.footer,
  });
}

typedef IEditorText = IEditorHTML;

class IUpdateOption {
  // Omitted properties from IEditorOption
  String? locale;
  String? defaultType;
  String? defaultColor;
  String? defaultFont;
  int? defaultSize;
  int? minSize;
  int? maxSize;
  double? defaultBasicRowMarginHeight;
  double? defaultRowMargin;
  double? defaultTabWidth;
  String? underlineColor;
  String? strikeoutColor;
  String? rangeColor;
  double? rangeAlpha;
  double? rangeMinWidth;
  String? searchMatchColor;
  String? searchNavigateMatchColor;
  double? searchMatchAlpha;
  double? highlightAlpha;
  double? highlightMarginHeight;
  String? resizerColor;
  int? resizerSize;
  int? marginIndicatorSize;
  String? marginIndicatorColor;
  IMargin? margins;
  RenderMode? renderMode;
  String? defaultHyperlinkColor;
  double? inactiveAlpha;
  double? printPixelRatio;
  IMargin? maskMargin;
  List<String>? letterClass;
  List<String>? contextMenuDisableKeys;
  List<String>? shortcutDisableKeys;
  bool? pageOuterSelectionDisable;
  WordBreak? wordBreak;
  ITableOption? table;
  IHeader? header;
  IFooter? footer;
  IPageNumber? pageNumber;
  IWatermark? watermark;
  IControlOption? control;
  ICheckboxOption? checkbox;
  IRadioOption? radio;
  ICursorOption? cursor;
  ITitleOption? title;
  IPlaceholder? placeholder;
  IGroup? group;
  IPageBreak? pageBreak;
  IZoneOption? zone;
  IBackgroundOption? background;
  ILineBreakOption? lineBreak;
  ISeparatorOption? separator;
  ILineNumberOption? lineNumber;
  IPageBorderOption? pageBorder;
  IBadgeOption? badge;
  IModeRule? modeRule;
}

class ISetValueOption {
  bool? isSetCursor;

  ISetValueOption({
    this.isSetCursor,
  });
}

class IFocusOption {
  int? rowNo;
  IRange? range;
  LocationPosition? position;
  bool? isMoveCursorToVisible;

  IFocusOption({
    this.rowNo,
    this.range,
    this.position,
    this.isMoveCursorToVisible,
  });
}

class IPrintModeRule {
  bool? imagePreviewerDisabled;

  IPrintModeRule({
    this.imagePreviewerDisabled,
  });
}

class IReadonlyModeRule {
  bool? imagePreviewerDisabled;

  IReadonlyModeRule({
    this.imagePreviewerDisabled,
  });
}

class IFormModeRule {
  bool? controlDeletableDisabled;

  IFormModeRule({
    this.controlDeletableDisabled,
  });
}

class IModeRule {
  IPrintModeRule? print;
  IReadonlyModeRule? readonly;
  IFormModeRule? form;

  IModeRule({
    this.print,
    this.readonly,
    this.form,
  });
}