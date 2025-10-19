import '../dataset/enum/Common.dart';
import '../dataset/enum/Control.dart';
import '../dataset/enum/Element.dart';
import '../dataset/enum/List.dart';
import '../dataset/enum/Row.dart';
import '../dataset/enum/Title.dart';
import '../dataset/enum/table/Table.dart';
import './Area.dart';
import './Block.dart';
import './Checkbox.dart';
import './Control.dart';
import './Radio.dart';
import './Text.dart';
import './Title.dart';
import './table/Colgroup.dart';
import './table/Tr.dart';

// Placeholder for IArea
class IArea {}
// Placeholder for IBlock
class IBlock {}
// Placeholder for ICheckbox
class ICheckbox {}
// Placeholder for IControl
class IControl {}
// Placeholder for IRadio
class IRadio {}
// Placeholder for ITextDecoration
class ITextDecoration {}
// Placeholder for ITitle
class ITitle {}
// Placeholder for IColgroup
class IColgroup {}
// Placeholder for ITr
class ITr {}

class IElementBasic {
  String? id;
  ElementType? type;
  String value;
  dynamic extension;
  String? externalId;

  IElementBasic({
    this.id,
    this.type,
    required this.value,
    this.extension,
    this.externalId,
  });
}

class IElementStyle {
  String? font;
  int? size;
  double? width;
  double? height;
  bool? bold;
  String? color;
  String? highlight;
  bool? italic;
  bool? underline;
  bool? strikeout;
  RowFlex? rowFlex;
  double? rowMargin;
  double? letterSpacing;
  ITextDecoration? textDecoration;

  IElementStyle({
    this.font,
    this.size,
    this.width,
    this.height,
    this.bold,
    this.color,
    this.highlight,
    this.italic,
    this.underline,
    this.strikeout,
    this.rowFlex,
    this.rowMargin,
    this.letterSpacing,
    this.textDecoration,
  });
}

class IElementRule {
  bool? hide;

  IElementRule({
    this.hide,
  });
}

class IElementGroup {
  List<String>? groupIds;

  IElementGroup({
    this.groupIds,
  });
}

class ITitleElement {
  List<IElement>? valueList;
  TitleLevel? level;
  String? titleId;
  ITitle? title;

  ITitleElement({
    this.valueList,
    this.level,
    this.titleId,
    this.title,
  });
}

class IListElement {
  List<IElement>? valueList;
  ListType? listType;
  ListStyle? listStyle;
  String? listId;
  bool? listWrap;

  IListElement({
    this.valueList,
    this.listType,
    this.listStyle,
    this.listId,
    this.listWrap,
  });
}

class ITableAttr {
  List<IColgroup>? colgroup;
  List<ITr>? trList;
  TableBorder? borderType;
  String? borderColor;
  double? borderWidth;
  double? borderExternalWidth;
  double? translateX;

  ITableAttr({
    this.colgroup,
    this.trList,
    this.borderType,
    this.borderColor,
    this.borderWidth,
    this.borderExternalWidth,
    this.translateX,
  });
}

class ITableRule {
  bool? tableToolDisabled;

  ITableRule({
    this.tableToolDisabled,
  });
}

class ITableElement {
  String? tdId;
  String? trId;
  String? tableId;
  String? conceptId;
  String? pagingId;
  int? pagingIndex;

  ITableElement({
    this.tdId,
    this.trId,
    this.tableId,
    this.conceptId,
    this.pagingId,
    this.pagingIndex,
  });
}

class ITable implements ITableAttr, ITableRule, ITableElement {
  // ITableAttr
  @override
  List<IColgroup>? colgroup;
  @override
  List<ITr>? trList;
  @override
  TableBorder? borderType;
  @override
  String? borderColor;
  @override
  double? borderWidth;
  @override
  double? borderExternalWidth;
  @override
  double? translateX;

  // ITableRule
  @override
  bool? tableToolDisabled;

  // ITableElement
  @override
  String? tdId;
  @override
  String? trId;
  @override
  String? tableId;
  @override
  String? conceptId;
  @override
  String? pagingId;
  @override
  int? pagingIndex;

  ITable({
    this.colgroup,
    this.trList,
    this.borderType,
    this.borderColor,
    this.borderWidth,
    this.borderExternalWidth,
    this.translateX,
    this.tableToolDisabled,
    this.tdId,
    this.trId,
    this.tableId,
    this.conceptId,
    this.pagingId,
    this.pagingIndex,
  });
}

class IHyperlinkElement {
  List<IElement>? valueList;
  String? url;
  String? hyperlinkId;

  IHyperlinkElement({
    this.valueList,
    this.url,
    this.hyperlinkId,
  });
}

class ISuperscriptSubscript {
  int? actualSize;

  ISuperscriptSubscript({
    this.actualSize,
  });
}

class ISeparator {
  List<double>? dashArray;

  ISeparator({
    this.dashArray,
  });
}

class IControlElement {
  IControl? control;
  String? controlId;
  ControlComponent? controlComponent;

  IControlElement({
    this.control,
    this.controlId,
    this.controlComponent,
  });
}

class ICheckboxElement {
  ICheckbox? checkbox;

  ICheckboxElement({
    this.checkbox,
  });
}

class IRadioElement {
  IRadio? radio;

  IRadioElement({
    this.radio,
  });
}

class ILaTexElement {
  String? laTexSVG;

  ILaTexElement({
    this.laTexSVG,
  });
}

class IDateElement {
  String? dateFormat;
  String? dateId;

  IDateElement({
    this.dateFormat,
    this.dateId,
  });
}

class IImageRule {
  bool? imgToolDisabled;

  IImageRule({
    this.imgToolDisabled,
  });
}

class IImageBasic {
  ImageDisplay? imgDisplay;
  Map<String, num>? imgFloatPosition;

  IImageBasic({
    this.imgDisplay,
    this.imgFloatPosition,
  });
}

class IImageElement implements IImageBasic, IImageRule {
  // IImageBasic
  @override
  ImageDisplay? imgDisplay;
  @override
  Map<String, num>? imgFloatPosition;

  // IImageRule
  @override
  bool? imgToolDisabled;

  IImageElement({
    this.imgDisplay,
    this.imgFloatPosition,
    this.imgToolDisabled,
  });
}

class IBlockElement {
  IBlock? block;

  IBlockElement({
    this.block,
  });
}

class IAreaElement {
  List<IElement>? valueList;
  String? areaId;
  int? areaIndex;
  IArea? area;

  IAreaElement({
    this.valueList,
    this.areaId,
    this.areaIndex,
    this.area,
  });
}

class IElement
    implements
        IElementBasic,
        IElementStyle,
        IElementRule,
        IElementGroup,
        ITable,
        IHyperlinkElement,
        ISuperscriptSubscript,
        ISeparator,
        IControlElement,
        ICheckboxElement,
        IRadioElement,
        ILaTexElement,
        IDateElement,
        IImageElement,
        IBlockElement,
        ITitleElement,
        IListElement,
        IAreaElement {
  // IElementBasic
  @override
  String? id;
  @override
  ElementType? type;
  @override
  String value;
  @override
  dynamic extension;
  @override
  String? externalId;

  // IElementStyle
  @override
  String? font;
  @override
  int? size;
  @override
  double? width;
  @override
  double? height;
  @override
  bool? bold;
  @override
  String? color;
  @override
  String? highlight;
  @override
  bool? italic;
  @override
  bool? underline;
  @override
  bool? strikeout;
  @override
  RowFlex? rowFlex;
  @override
  double? rowMargin;
  @override
  double? letterSpacing;
  @override
  ITextDecoration? textDecoration;

  // IElementRule
  @override
  bool? hide;

  // IElementGroup
  @override
  List<String>? groupIds;

  // ITable
  @override
  List<IColgroup>? colgroup;
  @override
  List<ITr>? trList;
  @override
  TableBorder? borderType;
  @override
  String? borderColor;
  @override
  double? borderWidth;
  @override
  double? borderExternalWidth;
  @override
  double? translateX;
  @override
  bool? tableToolDisabled;
  @override
  String? tdId;
  @override
  String? trId;
  @override
  String? tableId;
  @override
  String? conceptId;
  @override
  String? pagingId;
  @override
  int? pagingIndex;

  // IHyperlinkElement
  @override
  List<IElement>? valueList;
  @override
  String? url;
  @override
  String? hyperlinkId;

  // ISuperscriptSubscript
  @override
  int? actualSize;

  // ISeparator
  @override
  List<double>? dashArray;

  // IControlElement
  @override
  IControl? control;
  @override
  String? controlId;
  @override
  ControlComponent? controlComponent;

  // ICheckboxElement
  @override
  ICheckbox? checkbox;

  // IRadioElement
  @override
  IRadio? radio;

  // ILaTexElement
  @override
  String? laTexSVG;

  // IDateElement
  @override
  String? dateFormat;
  @override
  String? dateId;

  // IImageElement
  @override
  ImageDisplay? imgDisplay;
  @override
  Map<String, num>? imgFloatPosition;
  @override
  bool? imgToolDisabled;

  // IBlockElement
  @override
  IBlock? block;

  // ITitleElement
  @override
  TitleLevel? level;
  @override
  String? titleId;
  @override
  ITitle? title;

  // IListElement
  @override
  ListType? listType;
  @override
  ListStyle? listStyle;
  @override
  String? listId;
  @override
  bool? listWrap;

  // IAreaElement
  @override
  String? areaId;
  @override
  int? areaIndex;
  @override
  IArea? area;

  IElement({
    // IElementBasic
    this.id,
    this.type,
    required this.value,
    this.extension,
    this.externalId,
    // IElementStyle
    this.font,
    this.size,
    this.width,
    this.height,
    this.bold,
    this.color,
    this.highlight,
    this.italic,
    this.underline,
    this.strikeout,
    this.rowFlex,
    this.rowMargin,
    this.letterSpacing,
    this.textDecoration,
    // IElementRule
    this.hide,
    // IElementGroup
    this.groupIds,
    // ITable
    this.colgroup,
    this.trList,
    this.borderType,
    this.borderColor,
    this.borderWidth,
    this.borderExternalWidth,
    this.translateX,
    this.tableToolDisabled,
    this.tdId,
    this.trId,
    this.tableId,
    this.conceptId,
    this.pagingId,
    this.pagingIndex,
    // IHyperlinkElement
    this.valueList,
    this.url,
    this.hyperlinkId,
    // ISuperscriptSubscript
    this.actualSize,
    // ISeparator
    this.dashArray,
    // IControlElement
    this.control,
    this.controlId,
    this.controlComponent,
    // ICheckboxElement
    this.checkbox,
    // IRadioElement
    this.radio,
    // ILaTexElement
    this.laTexSVG,
    // IDateElement
    this.dateFormat,
    this.dateId,
    // IImageElement
    this.imgDisplay,
    this.imgFloatPosition,
    this.imgToolDisabled,
    // IBlockElement
    this.block,
    // ITitleElement
    this.level,
    this.titleId,
    this.title,
    // IListElement
    this.listType,
    this.listStyle,
    this.listId,
    this.listWrap,
    // IAreaElement
    this.areaId,
    this.areaIndex,
    this.area,
  });
}

class IElementMetrics {
  double width;
  double height;
  double boundingBoxAscent;
  double boundingBoxDescent;

  IElementMetrics({
    required this.width,
    required this.height,
    required this.boundingBoxAscent,
    required this.boundingBoxDescent,
  });
}

class IElementPosition {
  int pageNo;
  int index;
  String value;
  int rowIndex;
  int rowNo;
  double ascent;
  double lineHeight;
  double left;
  IElementMetrics metrics;
  bool isFirstLetter;
  bool isLastLetter;
  Map<String, List<double>> coordinate;

  IElementPosition({
    required this.pageNo,
    required this.index,
    required this.value,
    required this.rowIndex,
    required this.rowNo,
    required this.ascent,
    required this.lineHeight,
    required this.left,
    required this.metrics,
    required this.isFirstLetter,
    required this.isLastLetter,
    required this.coordinate,
  });
}

class IElementFillRect {
  double x;
  double y;
  double width;
  double height;

  IElementFillRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class IUpdateElementByIdOption {
  String? id;
  String? conceptId;
  IElement properties;

  IUpdateElementByIdOption({
    this.id,
    this.conceptId,
    required this.properties,
  });
}

class IDeleteElementByIdOption {
  String? id;
  String? conceptId;

  IDeleteElementByIdOption({
    this.id,
    this.conceptId,
  });
}

class IGetElementByIdOption {
  String? id;
  String? conceptId;

  IGetElementByIdOption({
    this.id,
    this.conceptId,
  });
}

class IInsertElementListOption {
  bool? isReplace;
  bool? isSubmitHistory;

  IInsertElementListOption({
    this.isReplace,
    this.isSubmitHistory,
  });
}

class ISpliceElementListOption {
  bool? isIgnoreDeletedRule;

  ISpliceElementListOption({
    this.isIgnoreDeletedRule,
  });
}
