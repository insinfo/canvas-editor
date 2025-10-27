import '../dataset/constant/background.dart';
import '../dataset/constant/badge.dart';
import '../dataset/constant/checkbox.dart';
import '../dataset/constant/common.dart';
import '../dataset/constant/control.dart';
import '../dataset/constant/cursor.dart';
import '../dataset/constant/editor.dart';
import '../dataset/constant/footer.dart';
import '../dataset/constant/group.dart';
import '../dataset/constant/header.dart';
import '../dataset/constant/line_break.dart';
import '../dataset/constant/line_number.dart';
import '../dataset/constant/page_border.dart';
import '../dataset/constant/page_break.dart';
import '../dataset/constant/page_number.dart';
import '../dataset/constant/placeholder.dart';
import '../dataset/constant/radio.dart';
import '../dataset/constant/separator.dart';
import '../dataset/constant/table.dart';
import '../dataset/constant/title.dart';
import '../dataset/constant/watermark.dart';
import '../dataset/constant/zone.dart';
import '../dataset/enum/editor.dart';
import '../interface/background.dart';
import '../interface/badge.dart';
import '../interface/checkbox.dart';
import '../interface/common.dart';
import '../interface/control.dart';
import '../interface/cursor.dart';
import '../interface/editor.dart';
import '../interface/footer.dart';
import '../interface/group.dart';
import '../interface/header.dart';
import '../interface/line_break.dart';
import '../interface/line_number.dart';
import '../interface/page_border.dart';
import '../interface/page_break.dart';
import '../interface/page_number.dart';
import '../interface/placeholder.dart';
import '../interface/radio.dart';
import '../interface/separator.dart';
import '../interface/table/table.dart';
import '../interface/title.dart';
import '../interface/watermark.dart';
import '../interface/zone.dart';

IEditorOption mergeOption([IEditorOption? options]) {
  final ITableOption tableOptions = _mergeTableOption(options?.table);
  final IHeader headerOptions = _mergeHeaderOption(options?.header);
  final IFooter footerOptions = _mergeFooterOption(options?.footer);
  final IPageNumber pageNumberOptions =
      _mergePageNumberOption(options?.pageNumber);
  final IWatermark waterMarkOptions = _mergeWatermarkOption(options?.watermark);
  final IControlOption controlOptions = _mergeControlOption(options?.control);
  final ICheckboxOption checkboxOptions =
      _mergeCheckboxOption(options?.checkbox);
  final IRadioOption radioOptions = _mergeRadioOption(options?.radio);
  final ICursorOption cursorOptions = _mergeCursorOption(options?.cursor);
  final ITitleOption titleOptions = _mergeTitleOption(options?.title);
  final IPlaceholder placeholderOptions =
      _mergePlaceholderOption(options?.placeholder);
  final IGroup groupOptions = _mergeGroupOption(options?.group);
  final IPageBreak pageBreakOptions = _mergePageBreakOption(options?.pageBreak);
  final IZoneOption zoneOptions = _mergeZoneOption(options?.zone);
  final IBackgroundOption backgroundOptions =
      _mergeBackgroundOption(options?.background);
  final ILineBreakOption lineBreakOptions =
      _mergeLineBreakOption(options?.lineBreak);
  final ISeparatorOption separatorOptions =
      _mergeSeparatorOption(options?.separator);
  final ILineNumberOption lineNumberOptions =
      _mergeLineNumberOption(options?.lineNumber);
  final IPageBorderOption pageBorderOptions =
      _mergePageBorderOption(options?.pageBorder);
  final IBadgeOption badgeOptions = _mergeBadgeOption(options?.badge);
  final IModeRule modeRuleOption = _mergeModeRule(options?.modeRule);

  return IEditorOption(
    mode: options?.mode ?? EditorMode.edit,
    locale: options?.locale ?? 'zhCN',
    defaultType: options?.defaultType ?? 'TEXT',
    defaultColor: options?.defaultColor ?? '#000000',
    defaultFont: options?.defaultFont ?? 'Microsoft YaHei',
    defaultSize: options?.defaultSize ?? 16,
    minSize: options?.minSize ?? 5,
    maxSize: options?.maxSize ?? 72,
    defaultRowMargin: options?.defaultRowMargin ?? 1,
    defaultBasicRowMarginHeight: options?.defaultBasicRowMarginHeight ?? 8,
    defaultTabWidth: options?.defaultTabWidth ?? 32,
    width: options?.width ?? 794,
    height: options?.height ?? 1123,
    scale: options?.scale ?? 1,
    pageGap: options?.pageGap ?? 20,
    underlineColor: options?.underlineColor ?? '#000000',
    strikeoutColor: options?.strikeoutColor ?? '#FF0000',
    rangeColor: options?.rangeColor ?? '#AECBFA',
    rangeAlpha: options?.rangeAlpha ?? 0.6,
    rangeMinWidth: options?.rangeMinWidth ?? 5,
    searchMatchColor: options?.searchMatchColor ?? '#FFFF00',
    searchNavigateMatchColor: options?.searchNavigateMatchColor ?? '#AAD280',
    searchMatchAlpha: options?.searchMatchAlpha ?? 0.6,
    highlightAlpha: options?.highlightAlpha ?? 0.6,
    highlightMarginHeight: options?.highlightMarginHeight ?? 8,
    resizerColor: options?.resizerColor ?? '#4182D9',
    resizerSize: options?.resizerSize ?? 5,
    marginIndicatorSize: options?.marginIndicatorSize ?? 35,
    marginIndicatorColor: options?.marginIndicatorColor ?? '#BABABA',
    margins: _resolveList(options?.margins, const <double>[100, 120, 100, 120]),
    pageMode: options?.pageMode ?? PageMode.paging,
    renderMode: options?.renderMode ?? RenderMode.speed,
    defaultHyperlinkColor: options?.defaultHyperlinkColor ?? '#0000FF',
    paperDirection: options?.paperDirection ?? PaperDirection.vertical,
    inactiveAlpha: options?.inactiveAlpha ?? 0.6,
    historyMaxRecordCount: options?.historyMaxRecordCount ?? 100,
    printPixelRatio: options?.printPixelRatio ?? 3,
    maskMargin: _resolveList(options?.maskMargin, const <double>[0, 0, 0, 0]),
    letterClass: _resolveStringList(
        options?.letterClass, const <String>[LetterClass.ENGLISH]),
    contextMenuDisableKeys:
        _resolveStringList(options?.contextMenuDisableKeys, const <String>[]),
    shortcutDisableKeys:
        _resolveStringList(options?.shortcutDisableKeys, const <String>[]),
    scrollContainerSelector: options?.scrollContainerSelector ?? '',
    pageOuterSelectionDisable: options?.pageOuterSelectionDisable ?? false,
    wordBreak: options?.wordBreak ?? WordBreak.breakWord,
    table: tableOptions,
    header: headerOptions,
    footer: footerOptions,
    pageNumber: pageNumberOptions,
    watermark: waterMarkOptions,
    control: controlOptions,
    checkbox: checkboxOptions,
    radio: radioOptions,
    cursor: cursorOptions,
    title: titleOptions,
    placeholder: placeholderOptions,
    group: groupOptions,
    pageBreak: pageBreakOptions,
    zone: zoneOptions,
    background: backgroundOptions,
    lineBreak: lineBreakOptions,
    separator: separatorOptions,
    lineNumber: lineNumberOptions,
    pageBorder: pageBorderOptions,
    badge: badgeOptions,
    modeRule: modeRuleOption,
  );
}

ITableOption _mergeTableOption(ITableOption? option) {
  return ITableOption(
    tdPadding: _resolvePadding(option?.tdPadding, defaultTableOption.tdPadding),
    defaultTrMinHeight:
        option?.defaultTrMinHeight ?? defaultTableOption.defaultTrMinHeight,
    defaultColMinWidth:
        option?.defaultColMinWidth ?? defaultTableOption.defaultColMinWidth,
    defaultBorderColor:
        option?.defaultBorderColor ?? defaultTableOption.defaultBorderColor,
    overflow: option?.overflow ?? defaultTableOption.overflow,
  );
}

IHeader _mergeHeaderOption(IHeader? option) {
  return IHeader(
    top: option?.top ?? defaultHeaderOption.top,
    inactiveAlpha: option?.inactiveAlpha ?? defaultHeaderOption.inactiveAlpha,
    maxHeightRadio:
        option?.maxHeightRadio ?? defaultHeaderOption.maxHeightRadio,
    disabled: option?.disabled ?? defaultHeaderOption.disabled,
    editable: option?.editable ?? defaultHeaderOption.editable,
  );
}

IFooter _mergeFooterOption(IFooter? option) {
  return IFooter(
    bottom: option?.bottom ?? defaultFooterOption.bottom,
    inactiveAlpha: option?.inactiveAlpha ?? defaultFooterOption.inactiveAlpha,
    maxHeightRadio:
        option?.maxHeightRadio ?? defaultFooterOption.maxHeightRadio,
    disabled: option?.disabled ?? defaultFooterOption.disabled,
    editable: option?.editable ?? defaultFooterOption.editable,
  );
}

IPageNumber _mergePageNumberOption(IPageNumber? option) {
  return IPageNumber(
    bottom: option?.bottom ?? defaultPageNumberOption.bottom,
    size: option?.size ?? defaultPageNumberOption.size,
    font: option?.font ?? defaultPageNumberOption.font,
    color: option?.color ?? defaultPageNumberOption.color,
    rowFlex: option?.rowFlex ?? defaultPageNumberOption.rowFlex,
    format: option?.format ?? defaultPageNumberOption.format,
    numberType: option?.numberType ?? defaultPageNumberOption.numberType,
    disabled: option?.disabled ?? defaultPageNumberOption.disabled,
    startPageNo: option?.startPageNo ?? defaultPageNumberOption.startPageNo,
    fromPageNo: option?.fromPageNo ?? defaultPageNumberOption.fromPageNo,
    maxPageNo: option?.maxPageNo ?? defaultPageNumberOption.maxPageNo,
  );
}

IWatermark _mergeWatermarkOption(IWatermark? option) {
  return IWatermark(
    data: option?.data ?? defaultWatermarkOption.data,
    type: option?.type ?? defaultWatermarkOption.type,
    width: option?.width ?? defaultWatermarkOption.width,
    height: option?.height ?? defaultWatermarkOption.height,
    color: option?.color ?? defaultWatermarkOption.color,
    opacity: option?.opacity ?? defaultWatermarkOption.opacity,
    size: option?.size ?? defaultWatermarkOption.size,
    font: option?.font ?? defaultWatermarkOption.font,
    repeat: option?.repeat ?? defaultWatermarkOption.repeat,
    numberType: option?.numberType ?? defaultWatermarkOption.numberType,
    gap: _resolveNullableList(option?.gap, defaultWatermarkOption.gap),
  );
}

IControlOption _mergeControlOption(IControlOption? option) {
  return IControlOption(
    placeholderColor:
        option?.placeholderColor ?? defaultControlOption.placeholderColor,
    bracketColor: option?.bracketColor ?? defaultControlOption.bracketColor,
    prefix: option?.prefix ?? defaultControlOption.prefix,
    postfix: option?.postfix ?? defaultControlOption.postfix,
    borderWidth: option?.borderWidth ?? defaultControlOption.borderWidth,
    borderColor: option?.borderColor ?? defaultControlOption.borderColor,
    activeBackgroundColor: option?.activeBackgroundColor ??
        defaultControlOption.activeBackgroundColor,
    disabledBackgroundColor: option?.disabledBackgroundColor ??
        defaultControlOption.disabledBackgroundColor,
    existValueBackgroundColor: option?.existValueBackgroundColor ??
        defaultControlOption.existValueBackgroundColor,
    noValueBackgroundColor: option?.noValueBackgroundColor ??
        defaultControlOption.noValueBackgroundColor,
  );
}

ICheckboxOption _mergeCheckboxOption(ICheckboxOption? option) {
  return ICheckboxOption(
    width: option?.width ?? defaultCheckboxOption.width,
    height: option?.height ?? defaultCheckboxOption.height,
    gap: option?.gap ?? defaultCheckboxOption.gap,
    lineWidth: option?.lineWidth ?? defaultCheckboxOption.lineWidth,
    fillStyle: option?.fillStyle ?? defaultCheckboxOption.fillStyle,
    strokeStyle: option?.strokeStyle ?? defaultCheckboxOption.strokeStyle,
    verticalAlign: option?.verticalAlign ?? defaultCheckboxOption.verticalAlign,
  );
}

IRadioOption _mergeRadioOption(IRadioOption? option) {
  return IRadioOption(
    width: option?.width ?? defaultRadioOption.width,
    height: option?.height ?? defaultRadioOption.height,
    gap: option?.gap ?? defaultRadioOption.gap,
    lineWidth: option?.lineWidth ?? defaultRadioOption.lineWidth,
    fillStyle: option?.fillStyle ?? defaultRadioOption.fillStyle,
    strokeStyle: option?.strokeStyle ?? defaultRadioOption.strokeStyle,
    verticalAlign: option?.verticalAlign ?? defaultRadioOption.verticalAlign,
  );
}

ICursorOption _mergeCursorOption(ICursorOption? option) {
  return ICursorOption(
    width: option?.width ?? defaultCursorOption.width,
    color: option?.color ?? defaultCursorOption.color,
    dragWidth: option?.dragWidth ?? defaultCursorOption.dragWidth,
    dragColor: option?.dragColor ?? defaultCursorOption.dragColor,
    dragFloatImageDisabled: option?.dragFloatImageDisabled ??
        defaultCursorOption.dragFloatImageDisabled,
  );
}

ITitleOption _mergeTitleOption(ITitleOption? option) {
  return ITitleOption(
    defaultFirstSize:
        option?.defaultFirstSize ?? defaultTitleOption.defaultFirstSize,
    defaultSecondSize:
        option?.defaultSecondSize ?? defaultTitleOption.defaultSecondSize,
    defaultThirdSize:
        option?.defaultThirdSize ?? defaultTitleOption.defaultThirdSize,
    defaultFourthSize:
        option?.defaultFourthSize ?? defaultTitleOption.defaultFourthSize,
    defaultFifthSize:
        option?.defaultFifthSize ?? defaultTitleOption.defaultFifthSize,
    defaultSixthSize:
        option?.defaultSixthSize ?? defaultTitleOption.defaultSixthSize,
  );
}

IPlaceholder _mergePlaceholderOption(IPlaceholder? option) {
  return IPlaceholder(
    data: option?.data ?? defaultPlaceholderOption.data,
    color: option?.color ?? defaultPlaceholderOption.color,
    opacity: option?.opacity ?? defaultPlaceholderOption.opacity,
    size: option?.size ?? defaultPlaceholderOption.size,
    font: option?.font ?? defaultPlaceholderOption.font,
  );
}

IGroup _mergeGroupOption(IGroup? option) {
  return IGroup(
    opacity: option?.opacity ?? defaultGroupOption.opacity,
    backgroundColor:
        option?.backgroundColor ?? defaultGroupOption.backgroundColor,
    activeOpacity: option?.activeOpacity ?? defaultGroupOption.activeOpacity,
    activeBackgroundColor: option?.activeBackgroundColor ??
        defaultGroupOption.activeBackgroundColor,
    disabled: option?.disabled ?? defaultGroupOption.disabled,
    deletable: option?.deletable ?? defaultGroupOption.deletable,
  );
}

IPageBreak _mergePageBreakOption(IPageBreak? option) {
  return IPageBreak(
    font: option?.font ?? defaultPageBreakOption.font,
    fontSize: option?.fontSize ?? defaultPageBreakOption.fontSize,
    lineDash:
        _resolveNullableList(option?.lineDash, defaultPageBreakOption.lineDash),
  );
}

IZoneOption _mergeZoneOption(IZoneOption? option) {
  return IZoneOption(
    tipDisabled: option?.tipDisabled ?? defaultZoneOption.tipDisabled,
  );
}

IBackgroundOption _mergeBackgroundOption(IBackgroundOption? option) {
  return IBackgroundOption(
    color: option?.color ?? defaultBackground.color,
    image: option?.image ?? defaultBackground.image,
    size: option?.size ?? defaultBackground.size,
    repeat: option?.repeat ?? defaultBackground.repeat,
    applyPageNumbers: _resolveNullableList(
        option?.applyPageNumbers, defaultBackground.applyPageNumbers),
  );
}

ILineBreakOption _mergeLineBreakOption(ILineBreakOption? option) {
  return ILineBreakOption(
    disabled: option?.disabled ?? defaultLineBreak.disabled,
    color: option?.color ?? defaultLineBreak.color,
    lineWidth: option?.lineWidth ?? defaultLineBreak.lineWidth,
  );
}

ISeparatorOption _mergeSeparatorOption(ISeparatorOption? option) {
  return ISeparatorOption(
    strokeStyle: option?.strokeStyle ?? defaultSeparatorOption.strokeStyle,
    lineWidth: option?.lineWidth ?? defaultSeparatorOption.lineWidth,
  );
}

ILineNumberOption _mergeLineNumberOption(ILineNumberOption? option) {
  return ILineNumberOption(
    size: option?.size ?? defaultLineNumberOption.size,
    font: option?.font ?? defaultLineNumberOption.font,
    color: option?.color ?? defaultLineNumberOption.color,
    disabled: option?.disabled ?? defaultLineNumberOption.disabled,
    right: option?.right ?? defaultLineNumberOption.right,
    type: option?.type ?? defaultLineNumberOption.type,
  );
}

IPageBorderOption _mergePageBorderOption(IPageBorderOption? option) {
  return IPageBorderOption(
    color: option?.color ?? defaultPageBorderOption.color,
    lineWidth: option?.lineWidth ?? defaultPageBorderOption.lineWidth,
    padding: _resolvePadding(option?.padding, defaultPageBorderOption.padding),
    disabled: option?.disabled ?? defaultPageBorderOption.disabled,
  );
}

IBadgeOption _mergeBadgeOption(IBadgeOption? option) {
  return IBadgeOption(
    top: option?.top ?? defaultBadgeOption.top,
    left: option?.left ?? defaultBadgeOption.left,
  );
}

IModeRule _mergeModeRule(IModeRule? option) {
  return IModeRule(
    print: IPrintModeRule(
      imagePreviewerDisabled: option?.print?.imagePreviewerDisabled ??
          defaultModeRuleOption.print?.imagePreviewerDisabled ??
          false,
    ),
    readonly: IReadonlyModeRule(
      imagePreviewerDisabled: option?.readonly?.imagePreviewerDisabled ??
          defaultModeRuleOption.readonly?.imagePreviewerDisabled ??
          false,
    ),
    form: IFormModeRule(
      controlDeletableDisabled: option?.form?.controlDeletableDisabled ??
          defaultModeRuleOption.form?.controlDeletableDisabled ??
          false,
    ),
  );
}

List<double> _resolveList(List<double>? override, List<double> fallback) {
  return List<double>.from(override ?? fallback);
}

List<String> _resolveStringList(List<String>? override, List<String> fallback) {
  return List<String>.from(override ?? fallback);
}

List<T>? _resolveNullableList<T>(List<T>? override, List<T>? fallback) {
  final List<T>? source = override ?? fallback;
  return source == null ? null : List<T>.from(source);
}

IPadding? _resolvePadding(IPadding? override, IPadding? fallback) {
  final IPadding? source = override ?? fallback;
  if (source == null) {
    return null;
  }
  return IPadding(
    top: source.top,
    right: source.right,
    bottom: source.bottom,
    left: source.left,
  );
}
