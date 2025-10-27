import 'dart:html';

import '../dataset/constant/common.dart';
import '../dataset/constant/element.dart' as element_constants;
import '../dataset/constant/regular.dart';
import '../dataset/enum/common.dart';
import '../dataset/enum/control.dart';
import '../dataset/enum/element.dart';
import '../dataset/enum/row.dart';
import '../dataset/enum/title.dart';
import '../interface/checkbox.dart';
import '../interface/control.dart';
import '../interface/element.dart';
import '../interface/editor.dart';
import '../interface/radio.dart';
import './index.dart';

IElement _cloneElement(
  IElement source, {
  String? value,
}) {
  return IElement(
    id: source.id,
    type: source.type,
    value: value ?? source.value,
    extension: source.extension,
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
    textDecoration: source.textDecoration,
    hide: source.hide,
    groupIds:
        source.groupIds != null ? List<String>.from(source.groupIds!) : null,
    colgroup:
        source.colgroup != null ? List<IColgroup>.from(source.colgroup!) : null,
    trList: source.trList != null ? List<ITr>.from(source.trList!) : null,
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
    valueList: source.valueList != null
        ? List<IElement>.from(source.valueList!)
        : null,
    url: source.url,
    hyperlinkId: source.hyperlinkId,
    actualSize: source.actualSize,
    dashArray:
        source.dashArray != null ? List<double>.from(source.dashArray!) : null,
    control: source.control,
    controlId: source.controlId,
    controlComponent: source.controlComponent,
    checkbox: source.checkbox,
    radio: source.radio,
    laTexSVG: source.laTexSVG,
    dateFormat: source.dateFormat,
    dateId: source.dateId,
    imgDisplay: source.imgDisplay,
    imgFloatPosition: source.imgFloatPosition != null
        ? Map<String, num>.from(source.imgFloatPosition!)
        : null,
    imgToolDisabled: source.imgToolDisabled,
    block: source.block,
    level: source.level,
    titleId: source.titleId,
    title: source.title,
    listType: source.listType,
    listStyle: source.listStyle,
    listId: source.listId,
    listWrap: source.listWrap,
    areaId: source.areaId,
    areaIndex: source.areaIndex,
    area: source.area,
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
    }

    i++;
    if (i < 0) {
      i = 0;
    }
  }
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

// TODO: Remaining utilities from TypeScript module pending translation.
