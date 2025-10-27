import 'dart:html';

import '../dataset/constant/common.dart';
import '../dataset/constant/element.dart' as element_constants;
import '../dataset/constant/list.dart' as list_constants;
import '../dataset/constant/regular.dart';
import '../dataset/constant/title.dart';
import '../dataset/enum/block.dart';
import '../dataset/enum/common.dart';
import '../dataset/enum/control.dart';
import '../dataset/enum/editor.dart';
import '../dataset/enum/element.dart';
import '../dataset/enum/list.dart';
import '../dataset/enum/row.dart';
import '../dataset/enum/vertical_align.dart';
import '../dataset/enum/table/table.dart';
import '../dataset/enum/title.dart';
import '../interface/element.dart';
import '../interface/editor.dart';
import '../interface/placeholder.dart';
import '../interface/row.dart';
import '../interface/table/td.dart';
import './index.dart';
import './option.dart';

const List<String> _iframeSandboxAllowList = <String>[
  'allow-scripts',
  'allow-same-origin'
];

IElement _cloneElement(
  IElement source, {
  String? value,
}) {
  return IElement(
    id: source.id,
    type: source.type,
    value: value ?? source.value,
    extension: deepClone(source.extension),
    externalId: source.externalId,
    font: source.font,
    size: source.size,
    width: source.width,
    height: source.height,
    bold: source.bold,
    color: source.color,
    highlight: source.highlight,
    italic: source.italic,
    underline: source.underline,
    strikeout: source.strikeout,
    rowFlex: source.rowFlex,
    rowMargin: source.rowMargin,
    letterSpacing: source.letterSpacing,
    textDecoration: _cloneTextDecoration(source.textDecoration),
    hide: source.hide,
    groupIds: source.groupIds?.toList(),
    colgroup: _cloneColgroupList(source.colgroup),
    trList: _cloneTrList(source.trList),
    borderType: source.borderType,
    borderColor: source.borderColor,
    borderWidth: source.borderWidth,
    borderExternalWidth: source.borderExternalWidth,
    translateX: source.translateX,
    tableToolDisabled: source.tableToolDisabled,
    tdId: source.tdId,
    trId: source.trId,
    tableId: source.tableId,
    conceptId: source.conceptId,
    pagingId: source.pagingId,
    pagingIndex: source.pagingIndex,
    valueList: source.valueList?.map(_cloneElement).toList(),
    url: source.url,
    hyperlinkId: source.hyperlinkId,
    actualSize: source.actualSize,
    dashArray: source.dashArray?.toList(),
    control: _cloneControl(source.control),
    controlId: source.controlId,
    controlComponent: source.controlComponent,
    checkbox: _cloneCheckbox(source.checkbox),
    radio: _cloneRadio(source.radio),
    laTexSVG: source.laTexSVG,
    dateFormat: source.dateFormat,
    dateId: source.dateId,
    imgDisplay: source.imgDisplay,
    imgFloatPosition: source.imgFloatPosition == null
        ? null
        : Map<String, num>.from(source.imgFloatPosition!),
    imgToolDisabled: source.imgToolDisabled,
    block: _cloneBlock(source.block),
    level: source.level,
    titleId: source.titleId,
    title: _cloneTitle(source.title),
    listType: source.listType,
    listStyle: source.listStyle,
    listId: source.listId,
    listWrap: source.listWrap,
    areaId: source.areaId,
    areaIndex: source.areaIndex,
    area: _cloneArea(source.area),
  );
}

List<IElement> unzipElementList(List<IElement> elementList) {
  final result = <IElement>[];
  for (final valueItem in elementList) {
    final textList = splitText(valueItem.value);
    for (final text in textList) {
      result.add(_cloneElement(valueItem, value: text));
    }
  }
  return result;
}

List<IElement> cloneElementList(List<IElement> source) {
  return source.map((IElement element) => _cloneElement(element)).toList();
}

class FormatElementListOption {
  const FormatElementListOption({
    this.isHandleFirstElement = true,
    this.isForceCompensation = false,
    required this.editorOptions,
  });

  final bool isHandleFirstElement;
  final bool isForceCompensation;
  final IEditorOption editorOptions;

  FormatElementListOption copyWith({
    bool? isHandleFirstElement,
    bool? isForceCompensation,
  }) {
    return FormatElementListOption(
      editorOptions: editorOptions,
      isHandleFirstElement: isHandleFirstElement ?? this.isHandleFirstElement,
      isForceCompensation: isForceCompensation ?? this.isForceCompensation,
    );
  }
}

class GetElementListByHtmlOption {
  const GetElementListByHtmlOption({
    required this.innerWidth,
  });

  final double innerWidth;
}

class FormatElementContextOption {
  const FormatElementContextOption({
    this.isBreakWhenWrap = false,
    this.editorOptions,
  });

  final bool isBreakWhenWrap;
  final IEditorOption? editorOptions;

  FormatElementContextOption copyWith({
    bool? isBreakWhenWrap,
    IEditorOption? editorOptions,
  }) {
    return FormatElementContextOption(
      isBreakWhenWrap: isBreakWhenWrap ?? this.isBreakWhenWrap,
      editorOptions: editorOptions ?? this.editorOptions,
    );
  }
}

double? _resolveTitleSize(ITitleOption titleOption, TitleLevel level) {
  switch (level) {
    case TitleLevel.first:
      return titleOption.defaultFirstSize;
    case TitleLevel.second:
      return titleOption.defaultSecondSize;
    case TitleLevel.third:
      return titleOption.defaultThirdSize;
    case TitleLevel.fourth:
      return titleOption.defaultFourthSize;
    case TitleLevel.fifth:
      return titleOption.defaultFifthSize;
    case TitleLevel.sixth:
      return titleOption.defaultSixthSize;
  }
}

void _copyContextFromElement(IElement source, IElement target) {
  target
    ..tdId = source.tdId
    ..trId = source.trId
    ..tableId = source.tableId
    ..level = source.level
    ..titleId = source.titleId
    ..title = source.title
    ..listId = source.listId
    ..listType = source.listType
    ..listStyle = source.listStyle
    ..areaId = source.areaId
    ..area = source.area
    ..rowFlex = source.rowFlex
    ..rowMargin = source.rowMargin;
}

void _applyControlStyle(IControl? control, IElement target) {
  if (control == null) {
    return;
  }
  target
    ..font = control.font ?? target.font
    ..size = control.size ?? target.size
    ..bold = control.bold ?? target.bold
    ..highlight = control.highlight ?? target.highlight
    ..italic = control.italic ?? target.italic
    ..strikeout = control.strikeout ?? target.strikeout;
}

List<IElement> _cloneElementList(List<IElement>? source) {
  if (source == null) {
    return <IElement>[];
  }
  return source.map((element) => _cloneElement(element)).toList();
}

ITextDecoration? _cloneTextDecoration(ITextDecoration? source) {
  if (source == null) {
    return null;
  }
  return ITextDecoration(style: source.style);
}

IColgroup _cloneColgroup(IColgroup source) {
  return IColgroup(
    id: source.id,
    width: source.width,
  );
}

List<IColgroup>? _cloneColgroupList(List<IColgroup>? source) {
  if (source == null) {
    return null;
  }
  return source.map(_cloneColgroup).toList();
}

ITd _cloneTd(ITd source) {
  return ITd(
    conceptId: source.conceptId,
    id: source.id,
    extension: deepClone(source.extension),
    externalId: source.externalId,
    x: source.x,
    y: source.y,
    width: source.width,
    height: source.height,
    colspan: source.colspan,
    rowspan: source.rowspan,
    value: _cloneElementList(source.value),
    trIndex: source.trIndex,
    tdIndex: source.tdIndex,
    isLastRowTd: source.isLastRowTd,
    isLastColTd: source.isLastColTd,
    isLastTd: source.isLastTd,
    rowIndex: source.rowIndex,
    colIndex: source.colIndex,
    rowList: source.rowList == null ? null : List<IRow>.from(source.rowList!),
    positionList: source.positionList == null
        ? null
        : List<IElementPosition>.from(source.positionList!),
    verticalAlign: source.verticalAlign,
    backgroundColor: source.backgroundColor,
    borderTypes: source.borderTypes == null
        ? null
        : List<TdBorder>.from(source.borderTypes!),
    slashTypes: source.slashTypes == null
        ? null
        : List<TdSlash>.from(source.slashTypes!),
    mainHeight: source.mainHeight,
    realHeight: source.realHeight,
    realMinHeight: source.realMinHeight,
    disabled: source.disabled,
    deletable: source.deletable,
  );
}

ITr _cloneTr(ITr source) {
  return ITr(
    id: source.id,
    extension: deepClone(source.extension),
    externalId: source.externalId,
    height: source.height,
    tdList: source.tdList.map(_cloneTd).toList(),
    minHeight: source.minHeight,
    pagingRepeat: source.pagingRepeat,
  );
}

List<ITr>? _cloneTrList(List<ITr>? source) {
  if (source == null) {
    return null;
  }
  return source.map(_cloneTr).toList();
}

ICheckbox? _cloneCheckbox(ICheckbox? source) {
  if (source == null) {
    return null;
  }
  return ICheckbox(
    value: source.value,
    code: source.code,
    disabled: source.disabled,
  );
}

IRadio? _cloneRadio(IRadio? source) {
  if (source == null) {
    return null;
  }
  return IRadio(
    value: source.value,
    code: source.code,
    disabled: source.disabled,
  );
}

IIFrameBlock? _cloneIFrameBlock(IIFrameBlock? source) {
  if (source == null) {
    return null;
  }
  return IIFrameBlock(
    src: source.src,
    srcdoc: source.srcdoc,
  );
}

IVideoBlock? _cloneIVideoBlock(IVideoBlock? source) {
  if (source == null) {
    return null;
  }
  return IVideoBlock(src: source.src);
}

IBlock? _cloneBlock(IBlock? source) {
  if (source == null) {
    return null;
  }
  return IBlock(
    type: source.type,
    iframeBlock: _cloneIFrameBlock(source.iframeBlock),
    videoBlock: _cloneIVideoBlock(source.videoBlock),
  );
}

ITitle? _cloneTitle(ITitle? source) {
  if (source == null) {
    return null;
  }
  return ITitle(
    deletable: source.deletable,
    disabled: source.disabled,
    conceptId: source.conceptId,
  );
}

IPlaceholder? _clonePlaceholder(IPlaceholder? source) {
  if (source == null) {
    return null;
  }
  return IPlaceholder(
    data: source.data,
    color: source.color,
    opacity: source.opacity,
    size: source.size,
    font: source.font,
  );
}

IArea? _cloneArea(IArea? source) {
  if (source == null) {
    return null;
  }
  return IArea(
    extension: deepClone(source.extension),
    placeholder: _clonePlaceholder(source.placeholder),
    top: source.top,
    borderColor: source.borderColor,
    backgroundColor: source.backgroundColor,
    mode: source.mode,
    hide: source.hide,
    deletable: source.deletable,
  );
}

IValueSet _cloneValueSet(IValueSet source) {
  return IValueSet(
    value: source.value,
    code: source.code,
  );
}

IControl? _cloneControl(IControl? source) {
  if (source == null) {
    return null;
  }
  final clonedValueSets = source.valueSets.map(_cloneValueSet).toList();
  return IControl(
    type: source.type,
    value: source.value?.map(_cloneElement).toList(),
    placeholder: source.placeholder,
    conceptId: source.conceptId,
    groupId: source.groupId,
    prefix: source.prefix,
    postfix: source.postfix,
    minWidth: source.minWidth,
    underline: source.underline,
    border: source.border,
    extension: deepClone(source.extension),
    indentation: source.indentation,
    rowFlex: source.rowFlex,
    preText: source.preText,
    postText: source.postText,
    deletable: source.deletable,
    disabled: source.disabled,
    pasteDisabled: source.pasteDisabled,
    hide: source.hide,
    font: source.font,
    size: source.size,
    bold: source.bold,
    highlight: source.highlight,
    italic: source.italic,
    strikeout: source.strikeout,
    code: source.code,
    valueSets: clonedValueSets,
    isMultiSelect: source.isMultiSelect,
    multiSelectDelimiter: source.multiSelectDelimiter,
    selectExclusiveOptions: source.selectExclusiveOptions == null
        ? null
        : Map<String, bool>.from(source.selectExclusiveOptions!),
    min: source.min,
    max: source.max,
    flexDirection: source.flexDirection,
    dateFormat: source.dateFormat,
  );
}

dynamic _cloneAttributeValue(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num || value is bool || value is String) {
    return value;
  }
  if (value is IElement) {
    return _cloneElement(value);
  }
  if (value is List<IElement>) {
    return value.map(_cloneElement).toList();
  }
  if (value is ITd) {
    return _cloneTd(value);
  }
  if (value is List<ITd>) {
    return value.map(_cloneTd).toList();
  }
  if (value is ITr) {
    return _cloneTr(value);
  }
  if (value is List<ITr>) {
    return value.map(_cloneTr).toList();
  }
  if (value is IColgroup) {
    return _cloneColgroup(value);
  }
  if (value is List<IColgroup>) {
    return value.map(_cloneColgroup).toList();
  }
  if (value is IControl) {
    return _cloneControl(value);
  }
  if (value is ICheckbox) {
    return _cloneCheckbox(value);
  }
  if (value is IRadio) {
    return _cloneRadio(value);
  }
  if (value is IBlock) {
    return _cloneBlock(value);
  }
  if (value is ITitle) {
    return _cloneTitle(value);
  }
  if (value is IArea) {
    return _cloneArea(value);
  }
  if (value is ITextDecoration) {
    return _cloneTextDecoration(value);
  }
  if (value is Map<String, num>) {
    return Map<String, num>.from(value);
  }
  if (value is Map<String, bool>) {
    return Map<String, bool>.from(value);
  }
  if (value is Map) {
    return Map<dynamic, dynamic>.from(value);
  }
  if (value is List) {
    return value.map(_cloneAttributeValue).toList();
  }
  return value;
}

void _assignElementAttributes(
  IElement source,
  IElement target,
  List<String> attributes,
) {
  for (final attribute in attributes) {
    final attrValue = _getElementAttr(source, attribute);
    if (attrValue == null) {
      continue;
    }
    _setElementAttr(target, attribute, _cloneAttributeValue(attrValue));
  }
}

void assignElementAttributes(
  IElement source,
  IElement target,
  List<String> attributes,
) {
  _assignElementAttributes(source, target, attributes);
}

void _overwriteElementAttributes(
  IElement source,
  IElement target,
  List<String> attributes,
) {
  for (final attribute in attributes) {
    final attrValue = _getElementAttr(source, attribute);
    if (attrValue == null) {
      _setElementAttr(target, attribute, null);
    } else {
      _setElementAttr(target, attribute, _cloneAttributeValue(attrValue));
    }
  }
}

void _applyControlStyleFromElement(IElement source, IControl? control) {
  if (control == null) {
    return;
  }
  for (final attr in element_constants.controlStyleAttr) {
    final value = _getElementAttr(source, attr);
    if (value == null) {
      continue;
    }
    switch (attr) {
      case 'font':
        control.font = value as String?;
        break;
      case 'size':
        control.size = value as int?;
        break;
      case 'bold':
        control.bold = value as bool?;
        break;
      case 'highlight':
        control.highlight = value as String?;
        break;
      case 'italic':
        control.italic = value as bool?;
        break;
      case 'strikeout':
        control.strikeout = value as bool?;
        break;
    }
  }
}

void _copyTdZipAttributes(ITd source, ITd target) {
  for (final attr in element_constants.tableTdZipAttr) {
    switch (attr) {
      case 'conceptId':
        target.conceptId = source.conceptId;
        break;
      case 'extension':
        target.extension = deepClone(source.extension);
        break;
      case 'externalId':
        target.externalId = source.externalId;
        break;
      case 'verticalAlign':
        target.verticalAlign = source.verticalAlign;
        break;
      case 'backgroundColor':
        target.backgroundColor = source.backgroundColor;
        break;
      case 'borderTypes':
        target.borderTypes = source.borderTypes == null
            ? null
            : List<TdBorder>.from(source.borderTypes!);
        break;
      case 'slashTypes':
        target.slashTypes = source.slashTypes == null
            ? null
            : List<TdSlash>.from(source.slashTypes!);
        break;
      case 'disabled':
        target.disabled = source.disabled;
        break;
      case 'deletable':
        target.deletable = source.deletable;
        break;
    }
  }
}

dynamic _getElementAttr(IElement element, String attr) {
  switch (attr) {
    case 'id':
      return element.id;
    case 'type':
      return element.type;
    case 'value':
      return element.value;
    case 'extension':
      return element.extension;
    case 'externalId':
      return element.externalId;
    case 'font':
      return element.font;
    case 'size':
      return element.size;
    case 'width':
      return element.width;
    case 'height':
      return element.height;
    case 'bold':
      return element.bold;
    case 'color':
      return element.color;
    case 'highlight':
      return element.highlight;
    case 'italic':
      return element.italic;
    case 'underline':
      return element.underline;
    case 'strikeout':
      return element.strikeout;
    case 'rowFlex':
      return element.rowFlex;
    case 'rowMargin':
      return element.rowMargin;
    case 'letterSpacing':
      return element.letterSpacing;
    case 'textDecoration':
      return element.textDecoration;
    case 'hide':
      return element.hide;
    case 'groupIds':
      return element.groupIds;
    case 'colgroup':
      return element.colgroup;
    case 'trList':
      return element.trList;
    case 'borderType':
      return element.borderType;
    case 'borderColor':
      return element.borderColor;
    case 'borderWidth':
      return element.borderWidth;
    case 'borderExternalWidth':
      return element.borderExternalWidth;
    case 'translateX':
      return element.translateX;
    case 'tableToolDisabled':
      return element.tableToolDisabled;
    case 'tdId':
      return element.tdId;
    case 'trId':
      return element.trId;
    case 'tableId':
      return element.tableId;
    case 'conceptId':
      return element.conceptId;
    case 'pagingId':
      return element.pagingId;
    case 'pagingIndex':
      return element.pagingIndex;
    case 'valueList':
      return element.valueList;
    case 'url':
      return element.url;
    case 'hyperlinkId':
      return element.hyperlinkId;
    case 'actualSize':
      return element.actualSize;
    case 'dashArray':
      return element.dashArray;
    case 'control':
      return element.control;
    case 'controlId':
      return element.controlId;
    case 'controlComponent':
      return element.controlComponent;
    case 'checkbox':
      return element.checkbox;
    case 'radio':
      return element.radio;
    case 'laTexSVG':
      return element.laTexSVG;
    case 'dateFormat':
      return element.dateFormat;
    case 'dateId':
      return element.dateId;
    case 'imgDisplay':
      return element.imgDisplay;
    case 'imgFloatPosition':
      return element.imgFloatPosition;
    case 'imgToolDisabled':
      return element.imgToolDisabled;
    case 'block':
      return element.block;
    case 'level':
      return element.level;
    case 'titleId':
      return element.titleId;
    case 'title':
      return element.title;
    case 'listType':
      return element.listType;
    case 'listStyle':
      return element.listStyle;
    case 'listId':
      return element.listId;
    case 'listWrap':
      return element.listWrap;
    case 'areaId':
      return element.areaId;
    case 'areaIndex':
      return element.areaIndex;
    case 'area':
      return element.area;
    default:
      return null;
  }
}

void _setElementAttr(IElement element, String attr, dynamic value) {
  switch (attr) {
    case 'id':
      element.id = value as String?;
      break;
    case 'type':
      element.type = value as ElementType?;
      break;
    case 'value':
      element.value = value as String;
      break;
    case 'extension':
      element.extension = value;
      break;
    case 'externalId':
      element.externalId = value as String?;
      break;
    case 'font':
      element.font = value as String?;
      break;
    case 'size':
      element.size = value as int?;
      break;
    case 'width':
      element.width = value as double?;
      break;
    case 'height':
      element.height = value as double?;
      break;
    case 'bold':
      element.bold = value as bool?;
      break;
    case 'color':
      element.color = value as String?;
      break;
    case 'highlight':
      element.highlight = value as String?;
      break;
    case 'italic':
      element.italic = value as bool?;
      break;
    case 'underline':
      element.underline = value as bool?;
      break;
    case 'strikeout':
      element.strikeout = value as bool?;
      break;
    case 'rowFlex':
      element.rowFlex = value as RowFlex?;
      break;
    case 'rowMargin':
      element.rowMargin = value as double?;
      break;
    case 'letterSpacing':
      element.letterSpacing = value as double?;
      break;
    case 'textDecoration':
      element.textDecoration = value as ITextDecoration?;
      break;
    case 'hide':
      element.hide = value as bool?;
      break;
    case 'groupIds':
      element.groupIds =
          value == null ? null : List<String>.from(value as Iterable<dynamic>);
      break;
    case 'colgroup':
      element.colgroup = value == null
          ? null
          : List<IColgroup>.from(value as Iterable<IColgroup>);
      break;
    case 'trList':
      element.trList =
          value == null ? null : List<ITr>.from(value as Iterable<ITr>);
      break;
    case 'borderType':
      element.borderType = value as TableBorder?;
      break;
    case 'borderColor':
      element.borderColor = value as String?;
      break;
    case 'borderWidth':
      element.borderWidth = value as double?;
      break;
    case 'borderExternalWidth':
      element.borderExternalWidth = value as double?;
      break;
    case 'translateX':
      element.translateX = value as double?;
      break;
    case 'tableToolDisabled':
      element.tableToolDisabled = value as bool?;
      break;
    case 'tdId':
      element.tdId = value as String?;
      break;
    case 'trId':
      element.trId = value as String?;
      break;
    case 'tableId':
      element.tableId = value as String?;
      break;
    case 'conceptId':
      element.conceptId = value as String?;
      break;
    case 'pagingId':
      element.pagingId = value as String?;
      break;
    case 'pagingIndex':
      element.pagingIndex = value as int?;
      break;
    case 'valueList':
      element.valueList = value == null
          ? null
          : List<IElement>.from(value as Iterable<IElement>);
      break;
    case 'url':
      element.url = value as String?;
      break;
    case 'hyperlinkId':
      element.hyperlinkId = value as String?;
      break;
    case 'actualSize':
      element.actualSize = value as int?;
      break;
    case 'dashArray':
      element.dashArray =
          value == null ? null : List<double>.from(value as Iterable<double>);
      break;
    case 'control':
      element.control = value as IControl?;
      break;
    case 'controlId':
      element.controlId = value as String?;
      break;
    case 'controlComponent':
      element.controlComponent = value as ControlComponent?;
      break;
    case 'checkbox':
      element.checkbox = value as ICheckbox?;
      break;
    case 'radio':
      element.radio = value as IRadio?;
      break;
    case 'laTexSVG':
      element.laTexSVG = value as String?;
      break;
    case 'dateFormat':
      element.dateFormat = value as String?;
      break;
    case 'dateId':
      element.dateId = value as String?;
      break;
    case 'imgDisplay':
      element.imgDisplay = value as ImageDisplay?;
      break;
    case 'imgFloatPosition':
      element.imgFloatPosition = value == null
          ? null
          : Map<String, num>.from(value as Map<String, num>);
      break;
    case 'imgToolDisabled':
      element.imgToolDisabled = value as bool?;
      break;
    case 'block':
      element.block = value as IBlock?;
      break;
    case 'level':
      element.level = value as TitleLevel?;
      break;
    case 'titleId':
      element.titleId = value as String?;
      break;
    case 'title':
      element.title = value as ITitle?;
      break;
    case 'listType':
      element.listType = value as ListType?;
      break;
    case 'listStyle':
      element.listStyle = value as ListStyle?;
      break;
    case 'listId':
      element.listId = value as String?;
      break;
    case 'listWrap':
      element.listWrap = value as bool?;
      break;
    case 'areaId':
      element.areaId = value as String?;
      break;
    case 'areaIndex':
      element.areaIndex = value as int?;
      break;
    case 'area':
      element.area = value as IArea?;
      break;
  }
}

void formatElementList(
  List<IElement> elementList,
  FormatElementListOption options,
) {
  final isHandleFirstElement = options.isHandleFirstElement;
  final isForceCompensation = options.isForceCompensation;
  final editorOptions = options.editorOptions;
  final startElement = elementList.isNotEmpty ? elementList.first : null;

  final startValue = startElement?.value ?? '';
  if (isForceCompensation ||
      (isHandleFirstElement &&
          startElement?.type != ElementType.list &&
          ((startElement?.type != null &&
                  startElement?.type != ElementType.text) ||
              !startLineBreakReg.hasMatch(startValue)))) {
    elementList.insert(0, IElement(value: ZERO));
  }

  var i = 0;
  while (i < elementList.length) {
    var el = elementList[i];

    if (el.type == ElementType.title) {
      elementList.removeAt(i);
      final valueList = el.valueList ?? <IElement>[];
      el.valueList = valueList;
      formatElementList(
        valueList,
        options.copyWith(
          isHandleFirstElement: false,
          isForceCompensation: false,
        ),
      );
      if (valueList.isNotEmpty) {
        final titleId = el.titleId ?? getUUID();
        final titleOptions = editorOptions.title;
        for (var v = 0; v < valueList.length; v++) {
          final value = valueList[v];
          value.title = el.title;
          if (el.level != null) {
            value.titleId = titleId;
            value.level = el.level;
          }
          if (isTextLikeElement(value) && titleOptions != null) {
            if (value.size == null && value.level != null) {
              final resolvedSize =
                  _resolveTitleSize(titleOptions, value.level!);
              if (resolvedSize != null) {
                value.size = resolvedSize.round();
              }
            }
            value.bold ??= true;
          }
          elementList.insert(i, value);
          i++;
        }
      }
      i--;
    } else if (el.type == ElementType.list) {
      elementList.removeAt(i);
      final valueList = el.valueList ?? <IElement>[];
      el.valueList = valueList;
      formatElementList(
        valueList,
        options.copyWith(
          isHandleFirstElement: true,
          isForceCompensation: false,
        ),
      );
      if (valueList.isNotEmpty) {
        final listId = getUUID();
        for (var v = 0; v < valueList.length; v++) {
          final value = valueList[v];
          value.listId = listId;
          value.listType = el.listType;
          value.listStyle = el.listStyle;
          elementList.insert(i, value);
          i++;
        }
      }
      i--;
    } else if (el.type == ElementType.area) {
      elementList.removeAt(i);
      final valueList = el.valueList ?? <IElement>[];
      el.valueList = valueList;
      formatElementList(
        valueList,
        options.copyWith(
          isHandleFirstElement: true,
          isForceCompensation: true,
        ),
      );
      if (valueList.isNotEmpty) {
        final areaId = el.areaId ?? getUUID();
        for (var v = 0; v < valueList.length; v++) {
          final value = valueList[v];
          value.areaId = el.areaId ?? areaId;
          value.area = el.area;
          value.areaIndex = v;
          if (value.type == ElementType.table && value.trList != null) {
            for (final tr in value.trList!) {
              for (final td in tr.tdList) {
                for (final tdValue in td.value) {
                  tdValue.areaId = el.areaId ?? areaId;
                  tdValue.area = el.area;
                }
              }
            }
          }
          elementList.insert(i, value);
          i++;
        }
      }
      i--;
    } else if (el.type == ElementType.table) {
      final tableId = el.id ?? getUUID();
      el.id = tableId;
      final tableOptions = editorOptions.table;
      if (el.trList != null && tableOptions != null) {
        final defaultTrMinHeight = tableOptions.defaultTrMinHeight;
        for (final tr in el.trList!) {
          final trId = tr.id ?? getUUID();
          tr.id = trId;
          if (tr.minHeight == null ||
              (defaultTrMinHeight != null &&
                  tr.minHeight! < defaultTrMinHeight)) {
            tr.minHeight = defaultTrMinHeight;
          }
          if (tr.minHeight != null && tr.height < tr.minHeight!) {
            tr.height = tr.minHeight!;
          }
          for (final td in tr.tdList) {
            final tdId = td.id ?? getUUID();
            td.id = tdId;
            formatElementList(
              td.value,
              options.copyWith(
                isHandleFirstElement: true,
                isForceCompensation: true,
              ),
            );
            if (td.value.isNotEmpty) {
              final first = td.value.first;
              final second = td.value.length > 1 ? td.value[1] : null;
              if (first.size == null &&
                  second != null &&
                  second.size != null &&
                  isTextLikeElement(second)) {
                first.size = second.size;
              }
              for (final value in td.value) {
                value.tdId = tdId;
                value.trId = trId;
                value.tableId = tableId;
              }
            }
          }
        }
      }
    } else if (el.type == ElementType.hyperlink) {
      elementList.removeAt(i);
      final valueList = unzipElementList(el.valueList ?? <IElement>[]);
      if (valueList.isNotEmpty) {
        final hyperlinkId = getUUID();
        for (final value in valueList) {
          value.type = el.type;
          value.url = el.url;
          value.hyperlinkId = hyperlinkId;
          elementList.insert(i, value);
          i++;
        }
      }
      i--;
    } else if (el.type == ElementType.date) {
      elementList.removeAt(i);
      final valueList = unzipElementList(el.valueList ?? <IElement>[]);
      if (valueList.isNotEmpty) {
        final dateId = getUUID();
        for (final value in valueList) {
          value.type = el.type;
          value.dateFormat = el.dateFormat;
          value.dateId = dateId;
          elementList.insert(i, value);
          i++;
        }
      }
      i--;
    } else if (el.type == ElementType.control) {
      final control = el.control;
      if (control == null) {
        i++;
        continue;
      }

      final prefix = control.prefix;
      final postfix = control.postfix;
      final preText = control.preText;
      final postText = control.postText;
      final placeholder = control.placeholder;
      final code = control.code;
      final type = control.type;
      final valueSets = control.valueSets;
      var valueList = _cloneElementList(control.value);

      final controlOption = editorOptions.control ?? IControlOption();
      final checkboxOption = editorOptions.checkbox ?? ICheckboxOption();
      final radioOption = editorOptions.radio ?? IRadioOption();
      final controlId = el.controlId ?? getUUID();

      elementList.removeAt(i);

      void addElementToList(IElement element) {
        _copyContextFromElement(el, element);
        _applyControlStyle(control, element);
        element.control = control;
        element.controlId = controlId;
        elementList.insert(i, element);
        i++;
      }

      String resolveText(String? primary, String? fallback) {
        if (primary != null && primary.isNotEmpty) {
          return primary;
        }
        return fallback ?? '';
      }

      // Prefix characters
      final prefixChars = splitText(resolveText(prefix, controlOption.prefix));
      for (final char in prefixChars) {
        final prefixElement = IElement(
          value: char,
          type: el.type,
          controlComponent: ControlComponent.prefix,
        );
        addElementToList(prefixElement);
        prefixElement.color = controlOption.bracketColor ?? prefixElement.color;
      }

      // Pre text characters
      if (preText != null && preText.isNotEmpty) {
        final preTextChars = splitText(preText);
        for (final char in preTextChars) {
          final preTextElement = IElement(
            value: char,
            type: el.type,
            controlComponent: ControlComponent.preText,
          );
          addElementToList(preTextElement);
        }
      }

      final bool hasValue = valueList.isNotEmpty;
      final bool isCheckbox = type == ControlType.checkbox;
      final bool isRadio = type == ControlType.radio;
      final bool isSelect =
          type == ControlType.select && code != null && code.isNotEmpty;

      if (hasValue || isCheckbox || isRadio || (isSelect && !hasValue)) {
        if (isCheckbox) {
          final codeList = <String>[];
          if (code != null && code.isNotEmpty) {
            codeList.addAll(code.split(','));
          }
          if (valueSets.isNotEmpty) {
            final valueStyleList = <IElement>[];
            for (final current in valueList) {
              final characters = splitText(current.value);
              for (final character in characters) {
                valueStyleList.add(_cloneElement(current, value: character));
              }
            }
            var valueStyleIndex = 0;
            for (final valueSet in valueSets) {
              final checkboxElement = IElement(
                value: '',
                type: el.type,
                controlComponent: ControlComponent.checkbox,
                checkbox: ICheckbox(
                  code: valueSet.code,
                  value: codeList.contains(valueSet.code),
                ),
              );
              addElementToList(checkboxElement);

              final valueChars = splitText(valueSet.value);
              for (var e = 0; e < valueChars.length; e++) {
                final char = valueChars[e];
                final isLastLetter = e == valueChars.length - 1;
                IElement valueElement;
                if (valueStyleIndex < valueStyleList.length) {
                  valueElement = _cloneElement(
                    valueStyleList[valueStyleIndex],
                    value: char,
                  );
                } else {
                  valueElement = IElement(value: char);
                }
                valueElement
                  ..controlComponent = ControlComponent.value
                  ..type = valueElement.type ?? ElementType.text
                  ..letterSpacing =
                      isLastLetter ? (checkboxOption.gap ?? 0) : 0;
                addElementToList(valueElement);
                valueStyleIndex++;
              }
            }
          }
        } else if (isRadio) {
          if (valueSets.isNotEmpty) {
            final valueStyleList = <IElement>[];
            for (final current in valueList) {
              final characters = splitText(current.value);
              for (final character in characters) {
                valueStyleList.add(_cloneElement(current, value: character));
              }
            }
            var valueStyleIndex = 0;
            for (final valueSet in valueSets) {
              final radioElement = IElement(
                value: '',
                type: el.type,
                controlComponent: ControlComponent.radio,
                radio: IRadio(
                  code: valueSet.code,
                  value: code == valueSet.code,
                ),
              );
              addElementToList(radioElement);

              final valueChars = splitText(valueSet.value);
              for (var e = 0; e < valueChars.length; e++) {
                final char = valueChars[e];
                final isLastLetter = e == valueChars.length - 1;
                IElement valueElement;
                if (valueStyleIndex < valueStyleList.length) {
                  valueElement = _cloneElement(
                    valueStyleList[valueStyleIndex],
                    value: char,
                  );
                } else {
                  valueElement = IElement(value: char);
                }
                valueElement
                  ..controlComponent = ControlComponent.value
                  ..type = valueElement.type ?? ElementType.text
                  ..letterSpacing = isLastLetter ? (radioOption.gap ?? 0) : 0;
                addElementToList(valueElement);
                valueStyleIndex++;
              }
            }
          }
        } else {
          if (!hasValue && valueSets.isNotEmpty) {
            IValueSet? matched;
            for (final set in valueSets) {
              if (set.code == code) {
                matched = set;
                break;
              }
            }
            if (matched != null) {
              valueList = <IElement>[
                IElement(value: matched.value),
              ];
            }
          }
          formatElementList(
            valueList,
            options.copyWith(
              isHandleFirstElement: false,
              isForceCompensation: false,
            ),
          );
          for (final element in valueList) {
            final sanitizedValue =
                (element.value == '\n' || element.value == '\r\n')
                    ? ZERO
                    : element.value;
            final valueElement = _cloneElement(element, value: sanitizedValue)
              ..controlComponent = ControlComponent.value
              ..control = control
              ..controlId = controlId
              ..type = element.type ?? ElementType.text;
            _copyContextFromElement(el, valueElement);
            _applyControlStyle(control, valueElement);
            elementList.insert(i, valueElement);
            i++;
          }
        }
      } else if (placeholder != null && placeholder.isNotEmpty) {
        final placeholderChars = splitText(placeholder);
        for (final char in placeholderChars) {
          final placeholderElement = IElement(
            value: char,
            type: el.type,
            controlComponent: ControlComponent.placeholder,
          );
          addElementToList(placeholderElement);
          placeholderElement.color =
              controlOption.placeholderColor ?? placeholderElement.color;
        }
      }

      if (postText != null && postText.isNotEmpty) {
        final postTextChars = splitText(postText);
        for (final char in postTextChars) {
          final postTextElement = IElement(
            value: char,
            type: el.type,
            controlComponent: ControlComponent.postText,
          );
          addElementToList(postTextElement);
        }
      }

      final postfixChars =
          splitText(resolveText(postfix, controlOption.postfix));
      for (final char in postfixChars) {
        final postfixElement = IElement(
          value: char,
          type: el.type,
          controlComponent: ControlComponent.postfix,
        );
        addElementToList(postfixElement);
        postfixElement.color =
            controlOption.bracketColor ?? postfixElement.color;
      }

      i--;
    } else if ((el.type == null ||
            element_constants.textlikeElementType.contains(el.type)) &&
        el.value.length > 1) {
      elementList.removeAt(i);
      final valueChars = splitText(el.value);
      for (var v = 0; v < valueChars.length; v++) {
        elementList.insert(i + v, _cloneElement(el, value: valueChars[v]));
      }
      el = elementList[i];
    }

    if (el.value == '\n' || el.value == '\r\n') {
      el.value = ZERO;
    }

    if (el.type == ElementType.image || el.type == ElementType.block) {
      el.id = el.id ?? getUUID();
    }

    if (el.type == ElementType.latex) {
      el.id = el.id ?? getUUID();
      // TODO: Convert LaTeX content to SVG when the particle module is ported.
    }

    i++;
    if (i < 0) {
      i = 0;
    }
  }
}

class ZipElementListOption {
  const ZipElementListOption({
    this.extraPickAttrs,
    this.isClassifyArea = false,
    this.isClone = true,
  });

  final List<String>? extraPickAttrs;
  final bool isClassifyArea;
  final bool isClone;

  ZipElementListOption copyWith({
    List<String>? extraPickAttrs,
    bool? isClassifyArea,
    bool? isClone,
  }) {
    return ZipElementListOption(
      extraPickAttrs: extraPickAttrs ?? this.extraPickAttrs,
      isClassifyArea: isClassifyArea ?? this.isClassifyArea,
      isClone: isClone ?? this.isClone,
    );
  }
}

List<IElement> zipElementList(
  List<IElement> payload, {
  ZipElementListOption options = const ZipElementListOption(),
}) {
  final elementList = options.isClone ? _cloneElementList(payload) : payload;
  final extraPickAttrs = options.extraPickAttrs;
  final result = <IElement>[];
  var index = 0;

  while (index < elementList.length) {
    var element = elementList[index];

    if (index == 0 &&
        element.value == ZERO &&
        element.listId == null &&
        (element.type == null || element.type == ElementType.text)) {
      index++;
      continue;
    }

    if (element.areaId != null) {
      final areaId = element.areaId;
      final area = element.area;
      final valueList = <IElement>[];
      while (index < elementList.length) {
        final areaElement = elementList[index];
        if (areaElement.areaId != areaId) {
          index--;
          break;
        }
        areaElement.area = null;
        areaElement.areaId = null;
        valueList.add(areaElement);
        index++;
      }
      final zippedAreaElements = zipElementList(valueList, options: options);
      if (options.isClassifyArea) {
        final areaElement = IElement(
          value: '',
          type: ElementType.area,
        )
          ..areaId = areaId
          ..area = area
          ..valueList = zippedAreaElements;
        element = areaElement;
      } else {
        result.addAll(zippedAreaElements);
        index++;
        continue;
      }
    } else if (element.titleId != null && element.level != null) {
      final titleId = element.titleId;
      final level = element.level!;
      final title = element.title;
      final valueList = <IElement>[];
      while (index < elementList.length) {
        final titleElement = elementList[index];
        if (titleElement.titleId != titleId) {
          index--;
          break;
        }
        titleElement.level = null;
        titleElement.title = null;
        valueList.add(titleElement);
        index++;
      }
      final titleElement = IElement(
        value: '',
        type: ElementType.title,
      )
        ..titleId = titleId
        ..level = level
        ..title = title
        ..valueList = zipElementList(valueList, options: options);
      element = titleElement;
    } else if (element.listId != null && element.listType != null) {
      final listId = element.listId;
      final listType = element.listType!;
      final listStyle = element.listStyle;
      final valueList = <IElement>[];
      while (index < elementList.length) {
        final listElement = elementList[index];
        if (listElement.listId != listId) {
          index--;
          break;
        }
        listElement.listType = null;
        listElement.listStyle = null;
        valueList.add(listElement);
        index++;
      }
      final listElement = IElement(
        value: '',
        type: ElementType.list,
      )
        ..listId = listId
        ..listType = listType
        ..listStyle = listStyle
        ..valueList = zipElementList(valueList, options: options);
      element = listElement;
    } else if (element.type == ElementType.table) {
      if (element.pagingId != null) {
        var tableIndex = index + 1;
        var combineCount = 0;
        while (tableIndex < elementList.length) {
          final nextElement = elementList[tableIndex];
          if (nextElement.pagingId == element.pagingId) {
            element.height = (element.height ?? 0) + (nextElement.height ?? 0);
            if (nextElement.trList != null) {
              element.trList ??= <ITr>[];
              element.trList!.addAll(nextElement.trList!);
            }
            tableIndex++;
            combineCount++;
          } else {
            break;
          }
        }
        index += combineCount;
      }
      if (element.trList != null) {
        for (final tr in element.trList!) {
          tr.id = null;
          for (var tdIndex = 0; tdIndex < tr.tdList.length; tdIndex++) {
            final td = tr.tdList[tdIndex];
            final zipTd = ITd(
              colspan: td.colspan,
              rowspan: td.rowspan,
              value: zipElementList(
                td.value,
                options: options.copyWith(isClassifyArea: false),
              ),
            );
            _copyTdZipAttributes(td, zipTd);
            tr.tdList[tdIndex] = zipTd;
          }
        }
      }
    } else if (element.type == ElementType.hyperlink) {
      final hyperlinkId = element.hyperlinkId;
      if (hyperlinkId != null) {
        final url = element.url;
        final valueList = <IElement>[];
        while (index < elementList.length) {
          final hyperlinkElement = elementList[index];
          if (hyperlinkElement.hyperlinkId != hyperlinkId) {
            index--;
            break;
          }
          hyperlinkElement.type = null;
          hyperlinkElement.url = null;
          valueList.add(hyperlinkElement);
          index++;
        }
        final hyperlinkElement = IElement(
          value: '',
          type: ElementType.hyperlink,
        )
          ..url = url
          ..valueList = zipElementList(valueList, options: options);
        element = hyperlinkElement;
      }
    } else if (element.type == ElementType.date) {
      final dateId = element.dateId;
      if (dateId != null) {
        final dateFormat = element.dateFormat;
        final valueList = <IElement>[];
        while (index < elementList.length) {
          final dateElement = elementList[index];
          if (dateElement.dateId != dateId) {
            index--;
            break;
          }
          dateElement.type = null;
          dateElement.dateFormat = null;
          valueList.add(dateElement);
          index++;
        }
        final dateElement = IElement(
          value: '',
          type: ElementType.date,
        )
          ..dateFormat = dateFormat
          ..valueList = zipElementList(valueList, options: options);
        element = dateElement;
      }
    } else if (element.controlId != null) {
      final controlId = element.controlId!;
      if (element.controlComponent == ControlComponent.prefix) {
        final valueList = <IElement>[];
        var isComplete = false;
        var start = index;
        while (start < elementList.length) {
          final controlElement = elementList[start];
          if (controlElement.controlId != controlId) {
            break;
          }
          if (controlElement.controlComponent == ControlComponent.value) {
            controlElement.control = null;
            controlElement.controlId = null;
            valueList.add(controlElement);
          }
          if (controlElement.controlComponent == ControlComponent.postfix) {
            isComplete = true;
          }
          start++;
        }
        if (isComplete) {
          final controlElementResult = IElement(
            value: '',
            type: ElementType.control,
          )..controlId = controlId;
          _assignElementAttributes(
            element,
            controlElementResult,
            <String>[
              ...element_constants.editorElementContextAttr,
              ...element_constants.editorRowAttr,
            ],
          );
          controlElementResult.control = _cloneControl(element.control);
          _applyControlStyleFromElement(element, controlElementResult.control);
          controlElementResult.control?.value =
              zipElementList(valueList, options: options);
          element = pickElementAttr(
            controlElementResult,
            extraPickAttrs: extraPickAttrs,
          );
          index += start - index - 1;
        }
      }
      if (element.controlComponent != null) {
        element.control = null;
        element.controlId = null;
        if (element.controlComponent != ControlComponent.value &&
            element.controlComponent != ControlComponent.preText &&
            element.controlComponent != ControlComponent.postText) {
          index++;
          continue;
        }
      }
    }

    final pickElement = pickElementAttr(
      element,
      extraPickAttrs: extraPickAttrs,
    );
    if (element.type == null ||
        element.type == ElementType.text ||
        element.type == ElementType.subscript ||
        element.type == ElementType.superscript) {
      while (true) {
        final nextIndex = index + 1;
        if (nextIndex >= elementList.length) {
          index++;
          break;
        }
        final nextElement = elementList[nextIndex];
        index++;
        final nextPick = pickElementAttr(
          nextElement,
          extraPickAttrs: extraPickAttrs,
        );
        if (isSameElementExceptValue(pickElement, nextPick)) {
          final nextValue =
              nextElement.value == ZERO ? '\n' : nextElement.value;
          pickElement.value += nextValue;
        } else {
          break;
        }
      }
    } else {
      index++;
    }

    result.add(pickElement);
  }

  return result;
}

Map<int, List<IElement>> splitListElement(List<IElement> elementList) {
  var currentListIndex = 0;
  final listElementMap = <int, List<IElement>>{};

  for (var e = 0; e < elementList.length; e++) {
    final element = elementList[e];
    if (e == 0) {
      if (element.checkbox != null) {
        continue;
      }
      element.value = element.value.replaceFirst(startLineBreakReg, '');
    }

    if (element.listWrap == true) {
      final existing = listElementMap[currentListIndex] ?? <IElement>[];
      existing.add(element);
      listElementMap[currentListIndex] = existing;
      continue;
    }

    final valueSegments = element.value.split('\n');
    for (var c = 0; c < valueSegments.length; c++) {
      if (c > 0) {
        currentListIndex += 1;
      }
      final segment = valueSegments[c];
      final entry = listElementMap[currentListIndex] ?? <IElement>[];
      entry.add(_cloneElement(element, value: segment));
      listElementMap[currentListIndex] = entry;
    }
  }

  return listElementMap;
}

class ElementListGroupRowFlex {
  ElementListGroupRowFlex({
    required this.rowFlex,
    required this.data,
  });

  RowFlex? rowFlex;
  List<IElement> data;
}

List<ElementListGroupRowFlex> groupElementListByRowFlex(
  List<IElement> elementList,
) {
  if (elementList.isEmpty) {
    return <ElementListGroupRowFlex>[];
  }

  final groupList = <ElementListGroupRowFlex>[];
  var currentRowFlex = elementList.first.rowFlex;
  groupList.add(ElementListGroupRowFlex(
    rowFlex: currentRowFlex,
    data: <IElement>[elementList.first],
  ));

  for (var index = 1; index < elementList.length; index++) {
    final element = elementList[index];
    final rowFlex = element.rowFlex;
    final previousElement = elementList[index - 1];
    final isSameRowFlex = currentRowFlex == rowFlex;
    final isPreviousBlock = getIsBlockElement(previousElement);
    final isCurrentBlock = getIsBlockElement(element);

    if (isSameRowFlex && !isCurrentBlock && !isPreviousBlock) {
      groupList.last.data.add(element);
    } else {
      groupList.add(ElementListGroupRowFlex(
        rowFlex: rowFlex,
        data: <IElement>[element],
      ));
      currentRowFlex = rowFlex;
    }
  }

  for (final group in groupList) {
    group.data = zipElementList(group.data);
  }

  return groupList;
}

Element convertElementToDom(IElement element, IEditorOption options) {
  var tagName = 'span';
  if (element.type == ElementType.superscript) {
    tagName = 'sup';
  } else if (element.type == ElementType.subscript) {
    tagName = 'sub';
  }

  final dom = Element.tag(tagName);

  final fontFamily = element.font ?? options.defaultFont;
  if (fontFamily != null && fontFamily.isNotEmpty) {
    dom.style.fontFamily = fontFamily;
  }

  if (element.rowFlex != null) {
    dom.style.textAlign = convertRowFlexToTextAlign(element.rowFlex!);
  }

  if (element.color != null) {
    dom.style.color = element.color!;
  }

  if (element.bold == true) {
    dom.style.fontWeight = '600';
  }

  if (element.italic == true) {
    dom.style.fontStyle = 'italic';
  }

  final fontSize = element.size ?? options.defaultSize;
  if (fontSize != null) {
    dom.style.fontSize = '${fontSize}px';
  }

  if (element.highlight != null) {
    dom.style.backgroundColor = element.highlight!;
  }

  var textDecoration = '';
  if (element.underline == true) {
    textDecoration = 'underline';
  }
  if (element.strikeout == true) {
    textDecoration = textDecoration.isEmpty
        ? 'line-through'
        : '$textDecoration line-through';
  }
  if (textDecoration.isNotEmpty) {
    dom.style.textDecoration = textDecoration;
  }

  dom.innerText = element.value.replaceAll(ZERO, '\n');
  return dom;
}

DivElement createDomFromElementList(
  List<IElement> elementList, {
  IEditorOption? options,
}) {
  final editorOptions = mergeOption(options);

  DivElement buildDom(List<IElement> payload) {
    final container = DivElement();

    for (var index = 0; index < payload.length; index++) {
      final element = payload[index];

      if (element.type == ElementType.table) {
        final tableDom = TableElement()
          ..setAttribute('cellspacing', '0')
          ..setAttribute('cellpadding', '0')
          ..setAttribute('border', '0');

        final borderStyle = '1px solid #000000';
        if (element.borderType == null ||
            element.borderType == TableBorder.all) {
          tableDom.style
            ..borderTop = borderStyle
            ..borderLeft = borderStyle;
        } else if (element.borderType == TableBorder.external) {
          tableDom.style.border = borderStyle;
        }

        if (element.width != null) {
          tableDom.style.width = '${element.width}px';
        }

        if (element.colgroup != null && element.colgroup!.isNotEmpty) {
          final colgroupDom = Element.tag('colgroup');
          for (final colgroup in element.colgroup!) {
            final colDom = Element.tag('col')
              ..setAttribute('width', '${colgroup.width}');
            colgroupDom.append(colDom);
          }
          tableDom.append(colgroupDom);
        }

        if (element.trList != null) {
          for (final tr in element.trList!) {
            final trDom = TableRowElement()..style.height = '${tr.height}px';

            for (final td in tr.tdList) {
              final tdDom = TableCellElement()
                ..colSpan = td.colspan
                ..rowSpan = td.rowspan;

              if (element.borderType == null ||
                  element.borderType == TableBorder.all) {
                tdDom.style
                  ..borderBottom = '1px solid'
                  ..borderRight = '1px solid';
              }

              if (td.borderTypes?.contains(TdBorder.top) == true) {
                tdDom.style.borderTop = borderStyle;
              }
              if (td.borderTypes?.contains(TdBorder.right) == true) {
                tdDom.style.borderRight = borderStyle;
              }
              if (td.borderTypes?.contains(TdBorder.bottom) == true) {
                tdDom.style.borderBottom = borderStyle;
              }
              if (td.borderTypes?.contains(TdBorder.left) == true) {
                tdDom.style.borderLeft = borderStyle;
              }

              final verticalAlignValue =
                  td.verticalAlign?.value ?? VerticalAlign.top.value;
              tdDom.style.verticalAlign = verticalAlignValue;

              final childDom =
                  createDomFromElementList(td.value, options: options);
              tdDom.innerHtml = childDom.innerHtml;

              if (td.backgroundColor != null) {
                tdDom.style.backgroundColor = td.backgroundColor;
              }

              trDom.append(tdDom);
            }

            tableDom.append(trDom);
          }
        }

        container.append(tableDom);
      } else if (element.type == ElementType.hyperlink) {
        final anchor = AnchorElement()
          ..text = (element.valueList ?? <IElement>[]) // safe fallback
              .map((item) => item.value)
              .join('');
        if (element.url != null) {
          anchor.href = element.url!;
        }
        container.append(anchor);
      } else if (element.type == ElementType.title) {
        final level = element.level ?? TitleLevel.first;
        final heading = Element.tag('h${titleOrderNumberMapping[level]}');
        final childDom = buildDom(element.valueList ?? <IElement>[]);
        heading.innerHtml = childDom.innerHtml;
        container.append(heading);
      } else if (element.type == ElementType.list) {
        final listTag =
            list_constants.listTypeElementMapping[element.listType] ?? 'ul';
        final listElement = Element.tag(listTag);

        if (element.listStyle != null) {
          final cssStyle =
              list_constants.listStyleCssMapping[element.listStyle];
          if (cssStyle != null) {
            listElement.style.listStyleType = cssStyle;
          }
        }

        final zipList = zipElementList(element.valueList ?? <IElement>[]);
        final listElementMap = splitListElement(zipList);
        listElementMap.forEach((_, listValue) {
          final li = LIElement();
          final childDom = buildDom(listValue);
          li.innerHtml = childDom.innerHtml;
          listElement.append(li);
        });

        container.append(listElement);
      } else if (element.type == ElementType.image) {
        final image = ImageElement();
        if (element.value.isNotEmpty) {
          image.src = element.value;
        }
        if (element.width != null) {
          image.width = element.width!.toInt();
        }
        if (element.height != null) {
          image.height = element.height!.toInt();
        }
        container.append(image);
      } else if (element.type == ElementType.block) {
        if (element.block?.type == BlockType.video) {
          final src = element.block?.videoBlock?.src;
          if (src != null) {
            final num resolvedWidth;
            if (element.width != null) {
              resolvedWidth = element.width!;
            } else if (options?.width != null) {
              resolvedWidth = options!.width!;
            } else {
              resolvedWidth = window.innerWidth ?? 0;
            }
            final int videoWidth = resolvedWidth.round();
            final video = VideoElement()
              ..style.display = 'block'
              ..controls = true
              ..src = src
              ..width = videoWidth;
            final videoHeight = element.height?.round();
            if (videoHeight != null) {
              video.height = videoHeight;
            }
            container.append(video);
          }
        } else if (element.block?.type == BlockType.iframe) {
          final iframeBlock = element.block?.iframeBlock;
          if (iframeBlock?.src != null || iframeBlock?.srcdoc != null) {
            final iframe = IFrameElement()
              ..style.display = 'block'
              ..style.border = 'none';
            final sandbox = iframe.sandbox;
            if (sandbox != null) {
              for (final token in _iframeSandboxAllowList) {
                sandbox.add(token);
              }
            }
            if (iframeBlock?.src != null) {
              iframe.src = iframeBlock!.src!;
            } else if (iframeBlock?.srcdoc != null) {
              iframe.srcdoc = iframeBlock!.srcdoc!;
            }
            final iframeWidth =
                element.width ?? options?.width ?? window.innerWidth;
            iframe.width = '$iframeWidth';
            if (element.height != null) {
              iframe.height = '${element.height}';
            }
            container.append(iframe);
          }
        }
      } else if (element.type == ElementType.separator) {
        container.append(HRElement());
      } else if (element.type == ElementType.checkbox) {
        final checkbox = InputElement(type: 'checkbox')
          ..checked = element.checkbox?.value ?? false;
        container.append(checkbox);
      } else if (element.type == ElementType.radio) {
        final radio = InputElement(type: 'radio')
          ..checked = element.radio?.value ?? false;
        container.append(radio);
      } else if (element.type == ElementType.tab) {
        final span = SpanElement()
          ..setInnerHtml(
            '$NON_BREAKING_SPACE$NON_BREAKING_SPACE',
            validator: NodeValidatorBuilder.common()..allowHtml5(),
          );
        container.append(span);
      } else if (element.type == ElementType.control) {
        final controlSpan = SpanElement();
        final childDom = buildDom(element.control?.value ?? <IElement>[]);
        controlSpan.innerHtml = childDom.innerHtml;
        container.append(controlSpan);
      } else if (element.type == ElementType.date) {
        final text =
            element.valueList?.map((value) => value.value).join('') ?? '';
        if (text.isEmpty) {
          continue;
        }
        final dom = convertElementToDom(element, editorOptions)
          ..innerText = text.replaceAll(ZERO, '\n');
        if (index > 0 && payload[index - 1].type == ElementType.title) {
          dom.innerText = dom.innerText.replaceFirst(RegExp('^\n'), '');
        }
        container.append(dom);
      } else if (element.type == ElementType.latex ||
          element.type == ElementType.superscript ||
          element.type == ElementType.subscript ||
          element.type == ElementType.text ||
          element.type == null ||
          element_constants.textlikeElementType.contains(element.type)) {
        var textContent = element.value;
        if (element.type == ElementType.date) {
          textContent =
              element.valueList?.map((value) => value.value).join('') ?? '';
        }
        if (textContent.isEmpty) {
          continue;
        }
        final dom = convertElementToDom(element, editorOptions);
        if (index > 0 && payload[index - 1].type == ElementType.title) {
          textContent = textContent.replaceFirst(RegExp('^\n'), '');
        }
        dom.innerText = textContent.replaceAll(ZERO, '\n');
        container.append(dom);
      }
    }

    return container;
  }

  final clipboardDom = DivElement();
  final groupedElementList = groupElementListByRowFlex(elementList);
  for (final group in groupedElementList) {
    final isDefaultRowFlex =
        group.rowFlex == null || group.rowFlex == RowFlex.left;
    final rowContainer = DivElement();

    if (!isDefaultRowFlex && group.data.isNotEmpty) {
      final firstElement = group.data.first;
      if (getIsBlockElement(firstElement)) {
        rowContainer.style
          ..display = 'flex'
          ..justifyContent =
              convertRowFlexToJustifyContent(firstElement.rowFlex!);
      } else {
        rowContainer.style.textAlign =
            convertRowFlexToTextAlign(group.rowFlex!);
      }
    }

    rowContainer.innerHtml = buildDom(group.data).innerHtml;

    if (isDefaultRowFlex) {
      final childNodes = rowContainer.childNodes.toList();
      for (final child in childNodes) {
        clipboardDom.append(child.clone(true));
      }
    } else {
      clipboardDom.append(rowContainer);
    }
  }

  return clipboardDom;
}

bool isSameElementExceptValue(IElement source, IElement target) {
  final comparableKeys = <String>{
    ...element_constants.editorElementZipAttr,
    'controlComponent',
    'controlId',
    'hyperlinkId',
    'dateId',
    'tdId',
    'trId',
    'tableId',
    'pagingId',
    'pagingIndex',
    'listId',
    'areaId',
    'areaIndex',
  };

  for (final key in comparableKeys) {
    final sourceValue = _getElementAttr(source, key);
    final targetValue = _getElementAttr(target, key);
    if (key == 'groupIds') {
      final sourceGroupIds = sourceValue as List<String>?;
      final targetGroupIds = targetValue as List<String>?;
      if (sourceGroupIds == null && targetGroupIds == null) {
        continue;
      }
      if (sourceGroupIds == null || targetGroupIds == null) {
        return false;
      }
      if (!isArrayEqual(sourceGroupIds, targetGroupIds)) {
        return false;
      }
      continue;
    }

    if (sourceValue != targetValue) {
      if (sourceValue == null && targetValue == null) {
        continue;
      }
      return false;
    }
  }

  return true;
}

IElement pickElementAttr(
  IElement payload, {
  List<String>? extraPickAttrs,
}) {
  final pickKeys = <String>[
    ...element_constants.editorElementZipAttr,
    if (extraPickAttrs != null) ...extraPickAttrs,
  ];

  final element = IElement(
    value: payload.value == ZERO ? '\n' : payload.value,
  );

  for (final key in pickKeys) {
    final value = _getElementAttr(payload, key);
    if (value == null) {
      continue;
    }
    _setElementAttr(element, key, _cloneAttributeValue(value));
  }

  return element;
}

RowFlex convertTextAlignToRowFlex(Element node) {
  final textAlign = node.getComputedStyle().textAlign;
  switch (textAlign) {
    case 'left':
    case 'start':
      return RowFlex.left;
    case 'center':
      return RowFlex.center;
    case 'right':
    case 'end':
      return RowFlex.right;
    case 'justify':
      return RowFlex.alignment;
    case 'justify-all':
      return RowFlex.justify;
    default:
      return RowFlex.left;
  }
}

String convertRowFlexToTextAlign(RowFlex rowFlex) {
  return rowFlex == RowFlex.alignment ? 'justify' : rowFlex.name;
}

String convertRowFlexToJustifyContent(RowFlex rowFlex) {
  switch (rowFlex) {
    case RowFlex.left:
      return 'flex-start';
    case RowFlex.center:
      return 'center';
    case RowFlex.right:
      return 'flex-end';
    case RowFlex.alignment:
    case RowFlex.justify:
      return 'space-between';
  }
}

bool isTextLikeElement(IElement element) {
  return element.type == null ||
      element_constants.textlikeElementType.contains(element.type);
}

String getElementListText(List<IElement> elementList) {
  final buffer = StringBuffer();
  for (final element in elementList) {
    if (isTextLikeElement(element)) {
      buffer.write(element.value);
    }
  }
  return buffer.toString().replaceAll(ZERO, '');
}

IElement? getAnchorElement(List<IElement> elementList, int anchorIndex) {
  if (anchorIndex < 0 || anchorIndex >= elementList.length) {
    return null;
  }
  final anchorElement = elementList[anchorIndex];
  final anchorNextElement = anchorIndex + 1 < elementList.length
      ? elementList[anchorIndex + 1]
      : null;
  final shouldUseNext = anchorElement.listId == null &&
      anchorElement.value == ZERO &&
      anchorNextElement != null &&
      anchorNextElement.value != ZERO &&
      anchorElement.areaId == anchorNextElement.areaId;
  return shouldUseNext ? anchorNextElement : anchorElement;
}

void formatElementContext(
  List<IElement> sourceElementList,
  List<IElement> formatElementList,
  int anchorIndex, {
  FormatElementContextOption options = const FormatElementContextOption(),
}) {
  final copyElement = getAnchorElement(sourceElementList, anchorIndex);
  if (copyElement == null) {
    return;
  }

  final isBreakWhenWrap = options.isBreakWhenWrap;
  final editorOptions = options.editorOptions;
  final mode = editorOptions?.mode;
  final shouldSkipTitleContext =
      mode != EditorMode.design && (copyElement.title?.disabled ?? false);
  final skipAttributes = shouldSkipTitleContext
      ? element_constants.titleContextAttr.toSet()
      : const <String>{};

  var isBreakWrapped = false;

  for (final targetElement in formatElementList) {
    if (isBreakWhenWrap &&
        copyElement.listId == null &&
        startLineBreakReg.hasMatch(targetElement.value)) {
      isBreakWrapped = true;
    }

    if (isBreakWrapped ||
        (copyElement.listId == null &&
            targetElement.type == ElementType.list)) {
      final cloneAttr = <String>[
        ...element_constants.tableContextAttr,
        ...element_constants.editorRowAttr,
        ...element_constants.areaContextAttr,
      ];
      if (skipAttributes.isNotEmpty) {
        cloneAttr.removeWhere((attr) => skipAttributes.contains(attr));
      }
      _overwriteElementAttributes(copyElement, targetElement, cloneAttr);
      for (final valueItem in targetElement.valueList ?? <IElement>[]) {
        _overwriteElementAttributes(copyElement, valueItem, cloneAttr);
      }
      continue;
    }

    final valueList = targetElement.valueList;
    if (valueList != null && valueList.isNotEmpty) {
      formatElementContext(
        sourceElementList,
        valueList,
        anchorIndex,
        options: options,
      );
    }

    final cloneAttr = <String>[
      ...element_constants.editorElementContextAttr,
      if (!getIsBlockElement(targetElement)) ...element_constants.editorRowAttr,
    ];
    if (skipAttributes.isNotEmpty) {
      cloneAttr.removeWhere((attr) => skipAttributes.contains(attr));
    }
    _overwriteElementAttributes(copyElement, targetElement, cloneAttr);
  }
}

bool getIsBlockElement(IElement? element) {
  if (element == null || element.type == null) {
    return false;
  }
  return element_constants.blockElementType.contains(element.type) ||
      element.imgDisplay == ImageDisplay.inline;
}

Element replaceHTMLElementTag(Element oldDom, String tagName) {
  final newDom = document.createElement(tagName);
  oldDom.attributes.forEach(newDom.setAttribute);
  newDom.innerHtml = oldDom.innerHtml;
  return newDom;
}

List<IElement> pickSurroundElementList(List<IElement> elementList) {
  return elementList
      .where((element) => element.imgDisplay == ImageDisplay.surround)
      .toList();
}

void deleteSurroundElementList(List<IElement> elementList, int pageNo) {
  for (var index = elementList.length - 1; index >= 0; index--) {
    final surroundElement = elementList[index];
    final surroundPageNo = surroundElement.imgFloatPosition != null
        ? surroundElement.imgFloatPosition!['pageNo']?.toInt()
        : null;
    if (surroundPageNo == pageNo) {
      elementList.removeAt(index);
    }
  }
}

int getNonHideElementIndex(
  List<IElement> elementList,
  int index, [
  LocationPosition position = LocationPosition.before,
]) {
  bool isVisible(int idx) {
    if (idx < 0 || idx >= elementList.length) {
      return false;
    }
    final element = elementList[idx];
    return !(element.hide == true ||
        element.control?.hide == true ||
        element.area?.hide == true);
  }

  if (isVisible(index)) {
    return index;
  }

  if (position == LocationPosition.before) {
    for (var i = index - 1; i >= 0; i--) {
      if (isVisible(i)) {
        return i;
      }
    }
    return 0;
  }

  for (var i = index + 1; i < elementList.length; i++) {
    if (isVisible(i)) {
      return i;
    }
  }
  return elementList.isEmpty ? 0 : elementList.length - 1;
}

IElement? convertTextNodeToElement(Node? textNode) {
  if (textNode == null || textNode.nodeType != Node.TEXT_NODE) {
    return null;
  }

  final parentNode = textNode.parentNode;
  if (parentNode is! Element) {
    return null;
  }

  Element anchorNode;
  if (parentNode.nodeName == 'FONT' && parentNode.parent is Element) {
    anchorNode = parentNode.parent as Element;
  } else {
    anchorNode = parentNode;
  }

  if (anchorNode.nodeName == 'STYLE') {
    return null;
  }

  final value = textNode.text;
  if (value == null || value.isEmpty) {
    return null;
  }

  final rowFlex = convertTextAlignToRowFlex(anchorNode);
  final style = anchorNode.getComputedStyle();

  final fontWeight = style.fontWeight.toLowerCase();
  final parsedFontWeight = int.tryParse(fontWeight);
  final isBold = (parsedFontWeight != null && parsedFontWeight > 500) ||
      fontWeight == 'bold' ||
      fontWeight == 'bolder';

  final fontSizeValue = style.fontSize;
  final parsedFontSize = double.tryParse(
      fontSizeValue.replaceAll(RegExp('px', caseSensitive: false), ''));

  final textDecorationLine = style.textDecorationLine.toLowerCase();

  final element = IElement(
    value: value,
    color: style.color,
    bold: isBold ? true : null,
    italic: style.fontStyle.toLowerCase().contains('italic') ? true : null,
    size: parsedFontSize?.floor(),
  );

  if (rowFlex != RowFlex.left) {
    element.rowFlex = rowFlex;
  }

  final background = style.backgroundColor.toLowerCase();
  if (background.isNotEmpty &&
      background != 'rgba(0, 0, 0, 0)' &&
      background != 'transparent') {
    element.highlight = style.backgroundColor;
  }

  if (textDecorationLine.contains('underline')) {
    element.underline = true;
  }
  if (textDecorationLine.contains('line-through')) {
    element.strikeout = true;
  }

  final verticalAlign = style.verticalAlign.toLowerCase();
  if (anchorNode.nodeName == 'SUB' || verticalAlign == 'sub') {
    element.type = ElementType.subscript;
  } else if (anchorNode.nodeName == 'SUP' || verticalAlign == 'super') {
    element.type = ElementType.superscript;
  }

  return element;
}

List<IElement> getElementListByHTML(
  String htmlText,
  GetElementListByHtmlOption options,
) {
  final elementList = <IElement>[];

  VerticalAlign? resolveVerticalAlign(String? cssValue) {
    if (cssValue == null || cssValue.isEmpty) {
      return null;
    }
    for (final align in VerticalAlign.values) {
      if (align.value == cssValue) {
        return align;
      }
    }
    return null;
  }

  ListStyle? resolveListStyle(String? cssValue) {
    if (cssValue == null || cssValue.isEmpty) {
      return null;
    }
    for (final style in ListStyle.values) {
      if (style.value == cssValue) {
        return style;
      }
    }
    return null;
  }

  int? parseIntAttribute(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return int.tryParse(value);
  }

  void findTextNode(Node dom) {
    if (dom.nodeType == Node.TEXT_NODE) {
      final element = convertTextNodeToElement(dom);
      if (element != null) {
        elementList.add(element);
      }
      return;
    }

    if (dom.nodeType != Node.ELEMENT_NODE) {
      return;
    }

    final elementNode = dom as Element;
    final childNodes = elementNode.childNodes;
    for (var n = 0; n < childNodes.length; n++) {
      final node = childNodes[n];
      switch (node.nodeName) {
        case 'BR':
          elementList.add(IElement(value: '\n'));
          continue;
        case 'A':
          final anchor = node as AnchorElement;
          final text = anchor.innerText;
          if (text.isNotEmpty) {
            elementList.add(
              IElement(
                value: '',
                type: ElementType.hyperlink,
                valueList: <IElement>[IElement(value: text)],
                url: anchor.href,
              ),
            );
          }
          continue;
      }

      final nodeName = node.nodeName ?? '';

      if (RegExp(r'^H[1-6]$').hasMatch(nodeName)) {
        final heading = node as Element;
        final titleLevel = titleNodeNameMapping[nodeName];
        if (titleLevel != null) {
          final replaced =
              replaceHTMLElementTag(heading, 'div').outerHtml ?? '';
          final valueList = getElementListByHTML(
            replaced,
            options,
          );
          elementList.add(
            IElement(
              value: '',
              type: ElementType.title,
              level: titleLevel,
              valueList: valueList,
            ),
          );
          final nextSibling = node.nextNode;
          if (nextSibling != null) {
            final nextNodeName = nextSibling.nodeName ?? '';
            if (nextNodeName.isNotEmpty &&
                !element_constants.inlineNodeName.contains(nextNodeName)) {
              elementList.add(IElement(value: '\n'));
            }
          }
          continue;
        }
      }

      if (nodeName == 'UL' || nodeName == 'OL') {
        final listNode = node as Element;
        final listElement = IElement(
          value: '',
          type: ElementType.list,
          valueList: <IElement>[],
        );
        if (nodeName == 'OL') {
          listElement.listType = ListType.ordered;
          listElement.listStyle = ListStyle.decimal;
        } else {
          listElement.listType = ListType.unordered;
          final listStyle = resolveListStyle(listNode.style.listStyleType);
          listElement.listStyle = listStyle;
        }

        listNode.querySelectorAll('li').forEach((li) {
          final liValueList = getElementListByHTML(li.innerHtml ?? '', options);
          for (final listItem in liValueList) {
            if (listItem.value == '\n') {
              listItem.listWrap = true;
            }
          }
          liValueList.insert(0, IElement(value: '\n'));
          listElement.valueList!.addAll(liValueList);
        });

        elementList.add(listElement);
        continue;
      }

      if (node.nodeName == 'HR') {
        elementList.add(
          IElement(
            value: '\n',
            type: ElementType.separator,
          ),
        );
        continue;
      }

      if (node.nodeName == 'IMG') {
        final image = node as ImageElement;
        final src = image.src ?? '';
        final width = image.width;
        final height = image.height;
        if (src.isEmpty) {
          continue;
        }
        if (width == null || height == null) {
          continue;
        }
        if (width <= 0 || height <= 0) {
          continue;
        }
        elementList.add(
          IElement(
            value: src,
            type: ElementType.image,
            width: width.toDouble(),
            height: height.toDouble(),
          ),
        );
        continue;
      }

      if (node.nodeName == 'VIDEO') {
        final video = node as VideoElement;
        final String src = video.src;
        final int width = video.width;
        final int height = video.height;
        if (src.isEmpty) {
          continue;
        }
        if (width <= 0 || height <= 0) {
          continue;
        }
        elementList.add(
          IElement(
            value: '',
            type: ElementType.block,
            block: IBlock(
              type: BlockType.video,
              videoBlock: IVideoBlock(src: src),
            ),
            width: width.toDouble(),
            height: height.toDouble(),
          ),
        );
        continue;
      }

      if (node.nodeName == 'IFRAME') {
        final iframe = node as IFrameElement;
        final src = iframe.src;
        final srcdoc = iframe.srcdoc;
        final width = parseIntAttribute(iframe.getAttribute('width'));
        final height = parseIntAttribute(iframe.getAttribute('height'));
        final hasSrc = src != null && src.isNotEmpty;
        if ((hasSrc || (srcdoc != null && srcdoc.isNotEmpty)) &&
            width != null &&
            width > 0 &&
            height != null &&
            height > 0) {
          elementList.add(
            IElement(
              value: '',
              type: ElementType.block,
              block: IBlock(
                type: BlockType.iframe,
                iframeBlock: IIFrameBlock(
                  src: hasSrc ? src : null,
                  srcdoc: srcdoc?.isNotEmpty == true ? srcdoc : null,
                ),
              ),
              width: width.toDouble(),
              height: height.toDouble(),
            ),
          );
        }
        continue;
      }

      if (node.nodeName == 'TABLE') {
        final table = node as TableElement;
        final tableElement = IElement(
          value: '\n',
          type: ElementType.table,
          colgroup: <IColgroup>[],
          trList: <ITr>[],
        );

        final colElements = table.querySelectorAll('colgroup col');
        table.querySelectorAll('tr').forEach((trNode) {
          final trStyle = trNode.getComputedStyle();
          final trHeight = double.tryParse(
                trStyle.height.replaceAll('px', ''),
              ) ??
              0;
          final tr = ITr(
            height: trHeight,
            minHeight: trHeight,
            tdList: <ITd>[],
          );

          trNode.querySelectorAll('th,td').forEach((tdNode) {
            final tableCell = tdNode as TableCellElement;
            final valueList =
                getElementListByHTML(tableCell.innerHtml ?? '', options);
            final td = ITd(
              colspan: tableCell.colSpan,
              rowspan: tableCell.rowSpan,
              value: valueList,
            );
            final tdStyle = tdNode.getComputedStyle();
            td.verticalAlign = resolveVerticalAlign(tdStyle.verticalAlign);
            final tdWidth = double.tryParse(tdStyle.width.replaceAll('px', ''));
            if (tdWidth != null) {
              td.width = tdWidth;
            }
            final backgroundColor = tableCell.style.backgroundColor;
            if (backgroundColor.isNotEmpty) {
              td.backgroundColor = backgroundColor;
            }
            tr.tdList.add(td);
          });

          tableElement.trList!.add(tr);
        });

        if ((tableElement.trList?.isNotEmpty ?? false) &&
            tableElement.trList!.first.tdList.isNotEmpty) {
          final tdCount = tableElement.trList!.first.tdList
              .fold<int>(0, (acc, td) => acc + td.colspan);
          if (tdCount > 0) {
            final defaultWidth = (options.innerWidth / tdCount).ceilToDouble();
            for (var i = 0; i < tdCount; i++) {
              final col = colElements.length > i ? colElements[i] : null;
              final colWidthAttr = col?.getAttribute('width');
              final colWidth =
                  colWidthAttr != null ? double.tryParse(colWidthAttr) : null;
              tableElement.colgroup!.add(
                IColgroup(
                  width: colWidth ?? defaultWidth,
                ),
              );
            }
          }
          elementList.add(tableElement);
        }
        continue;
      }

      if (node.nodeName == 'INPUT') {
        final input = node as InputElement;
        final type = input.type?.toLowerCase();
        if (type == ControlComponent.checkbox.name) {
          elementList.add(
            IElement(
              value: '',
              type: ElementType.checkbox,
              checkbox: ICheckbox(value: input.checked ?? false),
            ),
          );
          continue;
        }
        if (type == ControlComponent.radio.name) {
          elementList.add(
            IElement(
              value: '',
              type: ElementType.radio,
              radio: IRadio(value: input.checked ?? false),
            ),
          );
          continue;
        }
      }

      if (node.nodeType == Node.ELEMENT_NODE && n != childNodes.length - 1) {
        final nodeElement = node as Element;
        final display = nodeElement.getComputedStyle().display;
        final textContent = nodeElement.text ?? '';
        if (display == 'block' &&
            !RegExp(r'(\n|\r\n)$').hasMatch(textContent)) {
          elementList.add(IElement(value: '\n'));
        }
      }
    }
  }

  final clipboardDom = DivElement()
    ..setInnerHtml(
      htmlText,
      validator: NodeValidatorBuilder.common()..allowHtml5(),
    );
  final body = document.body;
  if (body != null) {
    body.append(clipboardDom);
  } else {
    document.append(clipboardDom);
  }

  final deleteNodes = <Node>[];
  for (final child in clipboardDom.childNodes) {
    final text = child.text?.trim();
    if (child.nodeType != Node.ELEMENT_NODE && (text == null || text.isEmpty)) {
      deleteNodes.add(child);
    }
  }
  for (final node in deleteNodes) {
    node.remove();
  }

  findTextNode(clipboardDom);
  clipboardDom.remove();

  return elementList;
}

String getTextFromElementList(List<IElement> elementList) {
  String buildText(List<IElement> payload) {
    final buffer = StringBuffer();
    for (var index = 0; index < payload.length; index++) {
      final element = payload[index];
      if (element.type == ElementType.table) {
        buffer.write('\n');
        final trList = element.trList ?? <ITr>[];
        for (final tr in trList) {
          for (var tdIndex = 0; tdIndex < tr.tdList.length; tdIndex++) {
            final td = tr.tdList[tdIndex];
            final tdText = buildText(zipElementList(td.value));
            final isFirst = tdIndex == 0;
            final isLast = tdIndex == tr.tdList.length - 1;
            buffer
              ..write(isFirst ? '' : '  ')
              ..write(tdText)
              ..write(isLast ? '\n' : '');
          }
        }
      } else if (element.type == ElementType.tab) {
        buffer.write('\t');
      } else if (element.type == ElementType.hyperlink) {
        final text = (element.valueList ?? <IElement>[])
            .map((value) => value.value)
            .join('');
        buffer.write(text);
      } else if (element.type == ElementType.title) {
        buffer.write(
            buildText(zipElementList(element.valueList ?? <IElement>[])));
      } else if (element.type == ElementType.list) {
        final zipList = zipElementList(element.valueList ?? <IElement>[]);
        final listMap = splitListElement(zipList);
        final entries = listMap.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        final prefix = element.listType == ListType.unordered
            ? (() {
                for (final entry in list_constants.ulStyleMapping.entries) {
                  if (entry.key.value == element.listStyle?.value) {
                    return entry.value;
                  }
                }
                return null;
              })()
            : null;
        for (var listIndex = 0; listIndex < entries.length; listIndex++) {
          final isLast = listIndex == entries.length - 1;
          final listValue = entries[listIndex].value;
          final marker = prefix ?? '${listIndex + 1}.';
          buffer
            ..write('\n')
            ..write(marker)
            ..write(buildText(listValue));
          if (isLast) {
            buffer.write('\n');
          }
        }
      } else if (element.type == ElementType.checkbox) {
        buffer.write(element.checkbox?.value == true ? '☑' : '□');
      } else if (element.type == ElementType.radio) {
        buffer.write(element.radio?.value == true ? '☉' : '○');
      } else if (element.type == ElementType.latex ||
          element.type == ElementType.superscript ||
          element.type == ElementType.subscript ||
          element.type == ElementType.text ||
          element.type == null ||
          element_constants.textlikeElementType.contains(element.type)) {
        var textLike = '';
        if (element.type == ElementType.control) {
          final controlValue = element.control?.value?.isNotEmpty == true
              ? element.control!.value!.first.value
              : '';
          if (controlValue.isNotEmpty) {
            textLike =
                '${element.control?.preText ?? ''}$controlValue${element.control?.postText ?? ''}';
          }
        } else if (element.type == ElementType.date) {
          textLike =
              element.valueList?.map((value) => value.value).join('') ?? '';
        } else {
          textLike = element.value;
        }
        buffer.write(textLike.replaceAll(ZERO, '\n'));
      }
    }
    return buffer.toString();
  }

  return buildText(zipElementList(elementList));
}

List<IElement> getSlimCloneElementList(List<IElement> elementList) {
  final cloned =
      deepCloneOmitKeys(elementList, const <String>['metrics', 'style']);
  return (cloned as List<dynamic>).cast<IElement>();
}
