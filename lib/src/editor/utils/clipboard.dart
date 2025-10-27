import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:js_util' as js_util;

import '../dataset/constant/editor.dart';
import '../dataset/enum/area.dart';
import '../dataset/enum/block.dart';
import '../dataset/enum/common.dart';
import '../dataset/enum/control.dart';
import '../dataset/enum/element.dart';
import '../dataset/enum/list.dart';
import '../dataset/enum/row.dart';
import '../dataset/enum/table/table.dart';
import '../dataset/enum/text.dart';
import '../dataset/enum/title.dart';
import '../dataset/enum/vertical_align.dart';
import '../interface/editor.dart';
import '../interface/element.dart';
import '../interface/placeholder.dart';
import '../interface/row.dart';
import '../interface/table/td.dart';
import './element.dart';

class ClipboardDataPayload {
  ClipboardDataPayload({
    required this.text,
    required this.elementList,
  });

  final String text;
  final List<IElement> elementList;
}

void setClipboardData(ClipboardDataPayload data) {
  final payload = <String, dynamic>{
    'text': data.text,
    'elementList': _serializeElementList(data.elementList),
  };

  try {
    window.localStorage[editorClipboard] = jsonEncode(payload);
  } catch (_) {
    // Ignore storage write failures (quota, private mode, etc.).
  }
}

ClipboardDataPayload? getClipboardData() {
  String? raw;
  try {
    raw = window.localStorage[editorClipboard];
  } catch (_) {
    return null;
  }

  final stored = raw;
  if (stored == null || stored.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(stored);
    if (decoded is! Map) {
      return null;
    }
    final map = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded);

    final text = map['text'] as String? ?? '';
    final elementListRaw = map['elementList'];
    final elements = elementListRaw is List
        ? _deserializeElementList(elementListRaw)
        : <IElement>[];

    return ClipboardDataPayload(text: text, elementList: elements);
  } catch (_) {
    removeClipboardData();
    return null;
  }
}

void removeClipboardData() {
  try {
    window.localStorage.remove(editorClipboard);
  } catch (_) {
    // Ignore storage removal failures.
  }
}

Future<void> writeClipboardItem(
  String text,
  String html,
  List<IElement> elementList,
) async {
  if (text.isEmpty && html.isEmpty && elementList.isEmpty) {
    return;
  }

  final plainText = Blob(<dynamic>[text], 'text/plain');
  final htmlText = Blob(<dynamic>[html], 'text/html');

  if (js_util.hasProperty(js_util.globalThis, 'ClipboardItem')) {
    final clipboardItemCtor = js_util.getProperty(
      js_util.globalThis,
      'ClipboardItem',
    );

    final item = js_util.callConstructor(
      clipboardItemCtor,
      <dynamic>[
        js_util.jsify(<String, dynamic>{
          plainText.type: plainText,
          htmlText.type: htmlText,
        })
      ],
    );

    final clipboard = js_util.getProperty(window.navigator, 'clipboard');
    if (clipboard != null) {
      await js_util.promiseToFuture<void>(
        js_util.callMethod(clipboard, 'write', <dynamic>[
          js_util.jsify(<dynamic>[item]),
        ]),
      );
    }
  } else {
    final fakeElement = DivElement()
      ..setAttribute('contenteditable', 'true')
      ..innerHtml = html;
    document.body?.append(fakeElement);

    final selection = window.getSelection();
    final range = document.createRange();
    final br = SpanElement()..innerText = '\\n';
    fakeElement.append(br);

    range.selectNodeContents(fakeElement);
    selection?.removeAllRanges();
    selection?.addRange(range);
    document.execCommand('copy');
    fakeElement.remove();
  }

  setClipboardData(ClipboardDataPayload(text: text, elementList: elementList));
}

Future<void> writeElementList(
  List<IElement> elementList,
  IEditorOption options,
) async {
  final clipboardDom = createDomFromElementList(
    elementList,
    options: options,
  );

  document.body?.append(clipboardDom);
  final text = clipboardDom.innerText;
  clipboardDom.remove();
  final html = clipboardDom.innerHtml ?? '';

  if (text.isEmpty && html.isEmpty && elementList.isEmpty) {
    return;
  }

  await writeClipboardItem(text, html, zipElementList(elementList));
}

bool getIsClipboardContainFile(DataTransfer clipboardData) {
  final itemList = clipboardData.items;
  if (itemList == null) {
    return false;
  }
  final length = itemList.length ?? 0;
  for (var i = 0; i < length; i++) {
    final item = itemList[i];
    if (item.kind == 'file') {
      return true;
    }
  }
  return false;
}

List<Map<String, dynamic>> _serializeElementList(List<IElement> elements) {
  return elements.map(_serializeElement).toList();
}

List<IElement> _deserializeElementList(List<dynamic> data) {
  final result = <IElement>[];
  for (final entry in data) {
    if (entry is Map<String, dynamic>) {
      result.add(_deserializeElement(entry));
    } else if (entry is Map) {
      result.add(_deserializeElement(entry.cast<String, dynamic>()));
    }
  }
  return result;
}

Map<String, dynamic> _serializeElement(IElement element) {
  final map = <String, dynamic>{'value': element.value};

  void write(String key, dynamic value) {
    if (value == null) {
      return;
    }
    map[key] = _serializeDynamic(value);
  }

  write('id', element.id);
  write('type', element.type?.name);
  write('extension', element.extension);
  write('externalId', element.externalId);
  write('font', element.font);
  write('size', element.size);
  write('width', element.width);
  write('height', element.height);
  write('bold', element.bold);
  write('color', element.color);
  write('highlight', element.highlight);
  write('italic', element.italic);
  write('underline', element.underline);
  write('strikeout', element.strikeout);
  write('rowFlex', element.rowFlex?.name);
  write('rowMargin', element.rowMargin);
  write('letterSpacing', element.letterSpacing);
  if (element.textDecoration != null) {
    map['textDecoration'] = _serializeTextDecoration(element.textDecoration!);
  }
  write('hide', element.hide);
  if (element.groupIds != null && element.groupIds!.isNotEmpty) {
    map['groupIds'] = List<String>.from(element.groupIds!);
  }
  if (element.colgroup != null && element.colgroup!.isNotEmpty) {
    map['colgroup'] =
        element.colgroup!.map(_serializeColgroup).toList(growable: false);
  }
  if (element.trList != null && element.trList!.isNotEmpty) {
    map['trList'] = element.trList!.map(_serializeTr).toList(growable: false);
  }
  write('borderType', element.borderType?.name);
  write('borderColor', element.borderColor);
  write('borderWidth', element.borderWidth);
  write('borderExternalWidth', element.borderExternalWidth);
  write('translateX', element.translateX);
  write('tableToolDisabled', element.tableToolDisabled);
  write('tdId', element.tdId);
  write('trId', element.trId);
  write('tableId', element.tableId);
  write('conceptId', element.conceptId);
  write('pagingId', element.pagingId);
  write('pagingIndex', element.pagingIndex);
  if (element.valueList != null && element.valueList!.isNotEmpty) {
    map['valueList'] =
        element.valueList!.map(_serializeElement).toList(growable: false);
  }
  write('url', element.url);
  write('hyperlinkId', element.hyperlinkId);
  write('actualSize', element.actualSize);
  if (element.dashArray != null && element.dashArray!.isNotEmpty) {
    map['dashArray'] = List<double>.from(element.dashArray!);
  }
  if (element.control != null) {
    map['control'] = _serializeControl(element.control!);
  }
  write('controlId', element.controlId);
  write('controlComponent', element.controlComponent?.name);
  if (element.checkbox != null) {
    map['checkbox'] = _serializeCheckbox(element.checkbox!);
  }
  if (element.radio != null) {
    map['radio'] = _serializeRadio(element.radio!);
  }
  write('laTexSVG', element.laTexSVG);
  write('dateFormat', element.dateFormat);
  write('dateId', element.dateId);
  write('imgDisplay', element.imgDisplay?.name);
  if (element.imgFloatPosition != null) {
    map['imgFloatPosition'] =
        element.imgFloatPosition!.map((key, value) => MapEntry(key, value));
  }
  write('imgToolDisabled', element.imgToolDisabled);
  if (element.block != null) {
    map['block'] = _serializeBlock(element.block!);
  }
  write('level', element.level?.name);
  write('titleId', element.titleId);
  if (element.title != null) {
    map['title'] = _serializeTitle(element.title!);
  }
  write('listType', element.listType?.name);
  write('listStyle', element.listStyle?.name);
  write('listId', element.listId);
  write('listWrap', element.listWrap);
  write('areaId', element.areaId);
  write('areaIndex', element.areaIndex);
  if (element.area != null) {
    map['area'] = _serializeArea(element.area!);
  }

  return map;
}

IElement _deserializeElement(Map<String, dynamic> json) {
  final element = IElement(value: json['value'] as String? ?? '');

  element.id = json['id'] as String?;
  element.type = _enumFromName(ElementType.values, json['type'] as String?);
  element.extension = json['extension'];
  element.externalId = json['externalId'] as String?;
  element.font = json['font'] as String?;
  element.size = _asInt(json['size']);
  element.width = _asDouble(json['width']);
  element.height = _asDouble(json['height']);
  element.bold = json['bold'] as bool?;
  element.color = json['color'] as String?;
  element.highlight = json['highlight'] as String?;
  element.italic = json['italic'] as bool?;
  element.underline = json['underline'] as bool?;
  element.strikeout = json['strikeout'] as bool?;
  element.rowFlex = _enumFromName(RowFlex.values, json['rowFlex'] as String?);
  element.rowMargin = _asDouble(json['rowMargin']);
  element.letterSpacing = _asDouble(json['letterSpacing']);
  if (json['textDecoration'] != null) {
    element.textDecoration = _deserializeTextDecoration(
      _asMap(json['textDecoration']),
    );
  }
  element.hide = json['hide'] as bool?;
  if (json['groupIds'] is List) {
    element.groupIds =
        (json['groupIds'] as List).map((e) => e.toString()).toList();
  }
  if (json['colgroup'] is List) {
    element.colgroup =
        _deserializeColgroupList(json['colgroup'] as List<dynamic>);
  }
  if (json['trList'] is List) {
    element.trList = _deserializeTrList(json['trList'] as List<dynamic>);
  }
  element.borderType =
      _enumFromName(TableBorder.values, json['borderType'] as String?);
  element.borderColor = json['borderColor'] as String?;
  element.borderWidth = _asDouble(json['borderWidth']);
  element.borderExternalWidth = _asDouble(json['borderExternalWidth']);
  element.translateX = _asDouble(json['translateX']);
  element.tableToolDisabled = json['tableToolDisabled'] as bool?;
  element.tdId = json['tdId'] as String?;
  element.trId = json['trId'] as String?;
  element.tableId = json['tableId'] as String?;
  element.conceptId = json['conceptId'] as String?;
  element.pagingId = json['pagingId'] as String?;
  element.pagingIndex = _asInt(json['pagingIndex']);
  if (json['valueList'] is List) {
    element.valueList =
        _deserializeElementList(json['valueList'] as List<dynamic>);
  }
  element.url = json['url'] as String?;
  element.hyperlinkId = json['hyperlinkId'] as String?;
  element.actualSize = _asInt(json['actualSize']);
  if (json['dashArray'] is List) {
    element.dashArray = (json['dashArray'] as List)
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList();
  }
  if (json['control'] is Map) {
    element.control = _deserializeControl(_asMap(json['control']));
  }
  element.controlId = json['controlId'] as String?;
  element.controlComponent = _enumFromName(
    ControlComponent.values,
    json['controlComponent'] as String?,
  );
  if (json['checkbox'] is Map) {
    element.checkbox = _deserializeCheckbox(_asMap(json['checkbox']));
  }
  if (json['radio'] is Map) {
    element.radio = _deserializeRadio(_asMap(json['radio']));
  }
  element.laTexSVG = json['laTexSVG'] as String?;
  element.dateFormat = json['dateFormat'] as String?;
  element.dateId = json['dateId'] as String?;
  element.imgDisplay =
      _enumFromName(ImageDisplay.values, json['imgDisplay'] as String?);
  if (json['imgFloatPosition'] is Map) {
    final position = <String, num>{};
    json['imgFloatPosition'].cast<String, dynamic>().forEach((key, value) {
      if (value is num) {
        position[key] = value;
      }
    });
    element.imgFloatPosition = position.isEmpty ? null : position;
  }
  element.imgToolDisabled = json['imgToolDisabled'] as bool?;
  if (json['block'] is Map) {
    element.block = _deserializeBlock(_asMap(json['block']));
  }
  element.level = _enumFromName(TitleLevel.values, json['level'] as String?);
  element.titleId = json['titleId'] as String?;
  if (json['title'] is Map) {
    element.title = _deserializeTitle(_asMap(json['title']));
  }
  element.listType =
      _enumFromName(ListType.values, json['listType'] as String?);
  element.listStyle =
      _enumFromName(ListStyle.values, json['listStyle'] as String?);
  element.listId = json['listId'] as String?;
  element.listWrap = json['listWrap'] as bool?;
  element.areaId = json['areaId'] as String?;
  element.areaIndex = _asInt(json['areaIndex']);
  if (json['area'] is Map) {
    element.area = _deserializeArea(_asMap(json['area']));
  }

  return element;
}

dynamic _serializeDynamic(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Enum) {
    return value.name;
  }
  if (value is List) {
    return value.map(_serializeDynamic).toList();
  }
  if (value is Map) {
    return value.map(
      (key, dynamic entry) =>
          MapEntry(key.toString(), _serializeDynamic(entry)),
    );
  }
  if (value is IElement) {
    return _serializeElement(value);
  }
  if (value is IControl) {
    return _serializeControl(value);
  }
  if (value is ICheckbox) {
    return _serializeCheckbox(value);
  }
  if (value is IRadio) {
    return _serializeRadio(value);
  }
  if (value is IBlock) {
    return _serializeBlock(value);
  }
  if (value is ITitle) {
    return _serializeTitle(value);
  }
  if (value is IArea) {
    return _serializeArea(value);
  }
  if (value is IPlaceholder) {
    return _serializePlaceholder(value);
  }
  if (value is ITextDecoration) {
    return _serializeTextDecoration(value);
  }
  if (value is IColgroup) {
    return _serializeColgroup(value);
  }
  if (value is ITr) {
    return _serializeTr(value);
  }
  if (value is ITd) {
    return _serializeTd(value);
  }
  if (value is IRow) {
    return _serializeRow(value);
  }
  if (value is IRowElement) {
    return _serializeRowElement(value);
  }
  if (value is IElementPosition) {
    return _serializeElementPosition(value);
  }
  if (value is IElementMetrics) {
    return _serializeElementMetrics(value);
  }
  if (value is IValueSet) {
    return _serializeValueSet(value);
  }
  if (value is IIFrameBlock) {
    return _serializeIFrameBlock(value);
  }
  if (value is IVideoBlock) {
    return _serializeVideoBlock(value);
  }
  return value;
}

Map<String, dynamic> _serializeControl(IControl control) {
  final map = <String, dynamic>{
    'type': control.type.name,
    'valueSets': control.valueSets.map(_serializeValueSet).toList(),
    'flexDirection': control.flexDirection.name,
  };

  void write(String key, dynamic value) {
    if (value == null) {
      return;
    }
    map[key] = _serializeDynamic(value);
  }

  if (control.value != null && control.value!.isNotEmpty) {
    map['value'] = control.value!.map(_serializeElement).toList();
  }
  write('placeholder', control.placeholder);
  write('conceptId', control.conceptId);
  write('groupId', control.groupId);
  write('prefix', control.prefix);
  write('postfix', control.postfix);
  write('minWidth', control.minWidth);
  write('underline', control.underline);
  write('border', control.border);
  write('extension', control.extension);
  write('indentation', control.indentation?.name);
  write('rowFlex', control.rowFlex?.name);
  write('preText', control.preText);
  write('postText', control.postText);
  write('deletable', control.deletable);
  write('disabled', control.disabled);
  write('pasteDisabled', control.pasteDisabled);
  write('hide', control.hide);
  write('font', control.font);
  write('size', control.size);
  write('bold', control.bold);
  write('highlight', control.highlight);
  write('italic', control.italic);
  write('strikeout', control.strikeout);
  write('code', control.code);
  write('isMultiSelect', control.isMultiSelect);
  write('multiSelectDelimiter', control.multiSelectDelimiter);
  if (control.selectExclusiveOptions != null) {
    map['selectExclusiveOptions'] =
        Map<String, bool>.from(control.selectExclusiveOptions!);
  }
  write('min', control.min);
  write('max', control.max);
  write('dateFormat', control.dateFormat);
  return map;
}

IControl _deserializeControl(Map<String, dynamic> json) {
  final type = _enumFromName(ControlType.values, json['type'] as String?) ??
      ControlType.text;
  final valueSets = _deserializeValueSetList(json['valueSets']);
  final flexDirection = _enumFromName(
        FlexDirection.values,
        json['flexDirection'] as String?,
      ) ??
      FlexDirection.row;

  final control = IControl(
    type: type,
    valueSets: valueSets,
    flexDirection: flexDirection,
  );

  if (json['value'] is List) {
    control.value = _deserializeElementList(json['value'] as List<dynamic>);
  }
  control.placeholder = json['placeholder'] as String?;
  control.conceptId = json['conceptId'] as String?;
  control.groupId = json['groupId'] as String?;
  control.prefix = json['prefix'] as String?;
  control.postfix = json['postfix'] as String?;
  control.minWidth = _asDouble(json['minWidth']);
  control.underline = json['underline'] as bool?;
  control.border = json['border'] as bool?;
  control.extension = json['extension'];
  control.indentation = _enumFromName(
    ControlIndentation.values,
    json['indentation'] as String?,
  );
  control.rowFlex = _enumFromName(RowFlex.values, json['rowFlex'] as String?);
  control.preText = json['preText'] as String?;
  control.postText = json['postText'] as String?;
  control.deletable = json['deletable'] as bool?;
  control.disabled = json['disabled'] as bool?;
  control.pasteDisabled = json['pasteDisabled'] as bool?;
  control.hide = json['hide'] as bool?;
  control.font = json['font'] as String?;
  control.size = _asInt(json['size']);
  control.bold = json['bold'] as bool?;
  control.highlight = json['highlight'] as String?;
  control.italic = json['italic'] as bool?;
  control.strikeout = json['strikeout'] as bool?;
  control.code = json['code'] as String?;
  control.isMultiSelect = json['isMultiSelect'] as bool?;
  control.multiSelectDelimiter = json['multiSelectDelimiter'] as String?;
  if (json['selectExclusiveOptions'] is Map) {
    control.selectExclusiveOptions = Map<String, bool>.from(
      json['selectExclusiveOptions'].cast<String, dynamic>(),
    );
  }
  control.min = _asInt(json['min']);
  control.max = _asInt(json['max']);
  control.dateFormat = json['dateFormat'] as String?;
  return control;
}

Map<String, dynamic> _serializeValueSet(IValueSet valueSet) {
  return <String, dynamic>{
    'value': valueSet.value,
    'code': valueSet.code,
  };
}

List<IValueSet> _deserializeValueSetList(dynamic data) {
  if (data is! List) {
    return <IValueSet>[];
  }
  return data
      .map((entry) => entry is Map<String, dynamic>
          ? IValueSet(
              value: entry['value'] as String? ?? '',
              code: entry['code'] as String? ?? '',
            )
          : entry is Map
              ? IValueSet(
                  value: entry['value']?.toString() ?? '',
                  code: entry['code']?.toString() ?? '',
                )
              : null)
      .whereType<IValueSet>()
      .toList();
}

Map<String, dynamic> _serializeCheckbox(ICheckbox checkbox) {
  return <String, dynamic>{
    if (checkbox.value != null) 'value': checkbox.value,
    if (checkbox.code != null) 'code': checkbox.code,
    if (checkbox.disabled != null) 'disabled': checkbox.disabled,
  };
}

ICheckbox _deserializeCheckbox(Map<String, dynamic> json) {
  return ICheckbox(
    value: json['value'] as bool?,
    code: json['code'] as String?,
    disabled: json['disabled'] as bool?,
  );
}

Map<String, dynamic> _serializeRadio(IRadio radio) {
  return <String, dynamic>{
    if (radio.value != null) 'value': radio.value,
    if (radio.code != null) 'code': radio.code,
    if (radio.disabled != null) 'disabled': radio.disabled,
  };
}

IRadio _deserializeRadio(Map<String, dynamic> json) {
  return IRadio(
    value: json['value'] as bool?,
    code: json['code'] as String?,
    disabled: json['disabled'] as bool?,
  );
}

Map<String, dynamic> _serializeBlock(IBlock block) {
  final map = <String, dynamic>{
    'type': block.type.name,
  };
  if (block.iframeBlock != null) {
    map['iframeBlock'] = _serializeIFrameBlock(block.iframeBlock!);
  }
  if (block.videoBlock != null) {
    map['videoBlock'] = _serializeVideoBlock(block.videoBlock!);
  }
  return map;
}

IBlock _deserializeBlock(Map<String, dynamic> json) {
  final type = _enumFromName(BlockType.values, json['type'] as String?) ??
      BlockType.video;
  return IBlock(
    type: type,
    iframeBlock: json['iframeBlock'] is Map
        ? _deserializeIFrameBlock(_asMap(json['iframeBlock']))
        : null,
    videoBlock: json['videoBlock'] is Map
        ? _deserializeVideoBlock(_asMap(json['videoBlock']))
        : null,
  );
}

Map<String, dynamic> _serializeIFrameBlock(IIFrameBlock block) {
  return <String, dynamic>{
    if (block.src != null) 'src': block.src,
    if (block.srcdoc != null) 'srcdoc': block.srcdoc,
  };
}

IIFrameBlock _deserializeIFrameBlock(Map<String, dynamic> json) {
  return IIFrameBlock(
    src: json['src'] as String?,
    srcdoc: json['srcdoc'] as String?,
  );
}

Map<String, dynamic> _serializeVideoBlock(IVideoBlock block) {
  return <String, dynamic>{'src': block.src};
}

IVideoBlock _deserializeVideoBlock(Map<String, dynamic> json) {
  return IVideoBlock(src: json['src'] as String? ?? '');
}

Map<String, dynamic> _serializeTitle(ITitle title) {
  return <String, dynamic>{
    if (title.deletable != null) 'deletable': title.deletable,
    if (title.disabled != null) 'disabled': title.disabled,
    if (title.conceptId != null) 'conceptId': title.conceptId,
  };
}

ITitle _deserializeTitle(Map<String, dynamic> json) {
  return ITitle(
    deletable: json['deletable'] as bool?,
    disabled: json['disabled'] as bool?,
    conceptId: json['conceptId'] as String?,
  );
}

Map<String, dynamic> _serializeTextDecoration(ITextDecoration decoration) {
  return <String, dynamic>{
    if (decoration.style != null) 'style': decoration.style!.name,
  };
}

ITextDecoration _deserializeTextDecoration(Map<String, dynamic> json) {
  return ITextDecoration(
    style: _enumFromName(
      TextDecorationStyle.values,
      json['style'] as String?,
    ),
  );
}

Map<String, dynamic> _serializeArea(IArea area) {
  final map = <String, dynamic>{};
  if (area.extension != null) {
    map['extension'] = _serializeDynamic(area.extension);
  }
  if (area.placeholder != null) {
    map['placeholder'] = _serializePlaceholder(area.placeholder!);
  }
  if (area.top != null) {
    map['top'] = area.top;
  }
  if (area.borderColor != null) {
    map['borderColor'] = area.borderColor;
  }
  if (area.backgroundColor != null) {
    map['backgroundColor'] = area.backgroundColor;
  }
  if (area.mode != null) {
    map['mode'] = area.mode!.name;
  }
  if (area.hide != null) {
    map['hide'] = area.hide;
  }
  if (area.deletable != null) {
    map['deletable'] = area.deletable;
  }
  return map;
}

IArea _deserializeArea(Map<String, dynamic> json) {
  return IArea(
    extension: json['extension'],
    placeholder: json['placeholder'] is Map
        ? _deserializePlaceholder(_asMap(json['placeholder']))
        : null,
    top: _asDouble(json['top']),
    borderColor: json['borderColor'] as String?,
    backgroundColor: json['backgroundColor'] as String?,
    mode: _enumFromName(AreaMode.values, json['mode'] as String?),
    hide: json['hide'] as bool?,
    deletable: json['deletable'] as bool?,
  );
}

Map<String, dynamic> _serializePlaceholder(IPlaceholder placeholder) {
  return <String, dynamic>{
    'data': placeholder.data,
    if (placeholder.color != null) 'color': placeholder.color,
    if (placeholder.opacity != null) 'opacity': placeholder.opacity,
    if (placeholder.size != null) 'size': placeholder.size,
    if (placeholder.font != null) 'font': placeholder.font,
  };
}

IPlaceholder _deserializePlaceholder(Map<String, dynamic> json) {
  return IPlaceholder(
    data: json['data'] as String? ?? '',
    color: json['color'] as String?,
    opacity: _asDouble(json['opacity']),
    size: _asDouble(json['size']),
    font: json['font'] as String?,
  );
}

Map<String, dynamic> _serializeColgroup(IColgroup colgroup) {
  return <String, dynamic>{
    if (colgroup.id != null) 'id': colgroup.id,
    'width': colgroup.width,
  };
}

List<IColgroup> _deserializeColgroupList(List<dynamic> data) {
  return data
      .map((entry) => entry is Map<String, dynamic>
          ? _deserializeColgroup(entry)
          : entry is Map
              ? _deserializeColgroup(entry.cast<String, dynamic>())
              : null)
      .whereType<IColgroup>()
      .toList();
}

IColgroup _deserializeColgroup(Map<String, dynamic> json) {
  return IColgroup(
    id: json['id'] as String?,
    width: _asDouble(json['width']) ?? 0,
  );
}

Map<String, dynamic> _serializeTr(ITr tr) {
  return <String, dynamic>{
    if (tr.id != null) 'id': tr.id,
    if (tr.extension != null) 'extension': _serializeDynamic(tr.extension),
    if (tr.externalId != null) 'externalId': tr.externalId,
    'height': tr.height,
    'tdList': tr.tdList.map(_serializeTd).toList(growable: false),
    if (tr.minHeight != null) 'minHeight': tr.minHeight,
    if (tr.pagingRepeat != null) 'pagingRepeat': tr.pagingRepeat,
  };
}

List<ITr> _deserializeTrList(List<dynamic> data) {
  return data
      .map((entry) => entry is Map<String, dynamic>
          ? _deserializeTr(entry)
          : entry is Map
              ? _deserializeTr(entry.cast<String, dynamic>())
              : null)
      .whereType<ITr>()
      .toList();
}

ITr _deserializeTr(Map<String, dynamic> json) {
  return ITr(
    id: json['id'] as String?,
    extension: json['extension'],
    externalId: json['externalId'] as String?,
    height: _asDouble(json['height']) ?? 0,
    tdList: _deserializeTdList(_asList(json['tdList'])),
    minHeight: _asDouble(json['minHeight']),
    pagingRepeat: json['pagingRepeat'] as bool?,
  );
}

Map<String, dynamic> _serializeTd(ITd td) {
  final map = <String, dynamic>{
    if (td.conceptId != null) 'conceptId': td.conceptId,
    if (td.id != null) 'id': td.id,
    if (td.extension != null) 'extension': _serializeDynamic(td.extension),
    if (td.externalId != null) 'externalId': td.externalId,
    if (td.x != null) 'x': td.x,
    if (td.y != null) 'y': td.y,
    if (td.width != null) 'width': td.width,
    if (td.height != null) 'height': td.height,
    'colspan': td.colspan,
    'rowspan': td.rowspan,
    'value': td.value.map(_serializeElement).toList(growable: false),
    if (td.trIndex != null) 'trIndex': td.trIndex,
    if (td.tdIndex != null) 'tdIndex': td.tdIndex,
    if (td.isLastRowTd != null) 'isLastRowTd': td.isLastRowTd,
    if (td.isLastColTd != null) 'isLastColTd': td.isLastColTd,
    if (td.isLastTd != null) 'isLastTd': td.isLastTd,
    if (td.rowIndex != null) 'rowIndex': td.rowIndex,
    if (td.colIndex != null) 'colIndex': td.colIndex,
    if (td.rowList != null)
      'rowList': td.rowList!.map(_serializeRow).toList(growable: false),
    if (td.positionList != null)
      'positionList': td.positionList!
          .map(_serializeElementPosition)
          .toList(growable: false),
    if (td.verticalAlign != null) 'verticalAlign': td.verticalAlign!.name,
    if (td.backgroundColor != null) 'backgroundColor': td.backgroundColor,
    if (td.borderTypes != null)
      'borderTypes': td.borderTypes!.map((value) => value.name).toList(),
    if (td.slashTypes != null)
      'slashTypes': td.slashTypes!.map((value) => value.name).toList(),
    if (td.mainHeight != null) 'mainHeight': td.mainHeight,
    if (td.realHeight != null) 'realHeight': td.realHeight,
    if (td.realMinHeight != null) 'realMinHeight': td.realMinHeight,
    if (td.disabled != null) 'disabled': td.disabled,
    if (td.deletable != null) 'deletable': td.deletable,
  };
  return map;
}

List<ITd> _deserializeTdList(List<dynamic> data) {
  return data
      .map((entry) => entry is Map<String, dynamic>
          ? _deserializeTd(entry)
          : entry is Map
              ? _deserializeTd(entry.cast<String, dynamic>())
              : null)
      .whereType<ITd>()
      .toList();
}

ITd _deserializeTd(Map<String, dynamic> json) {
  final borderTypes = json['borderTypes'] is List
      ? (json['borderTypes'] as List)
          .map((value) => _enumFromName(TdBorder.values, value as String?))
          .whereType<TdBorder>()
          .toList()
      : null;
  final slashTypes = json['slashTypes'] is List
      ? (json['slashTypes'] as List)
          .map((value) => _enumFromName(TdSlash.values, value as String?))
          .whereType<TdSlash>()
          .toList()
      : null;
  return ITd(
    conceptId: json['conceptId'] as String?,
    id: json['id'] as String?,
    extension: json['extension'],
    externalId: json['externalId'] as String?,
    x: _asDouble(json['x']),
    y: _asDouble(json['y']),
    width: _asDouble(json['width']),
    height: _asDouble(json['height']),
    colspan: _asInt(json['colspan']) ?? 1,
    rowspan: _asInt(json['rowspan']) ?? 1,
    value: _deserializeElementList(_asList(json['value'])),
    trIndex: _asInt(json['trIndex']),
    tdIndex: _asInt(json['tdIndex']),
    isLastRowTd: json['isLastRowTd'] as bool?,
    isLastColTd: json['isLastColTd'] as bool?,
    isLastTd: json['isLastTd'] as bool?,
    rowIndex: _asInt(json['rowIndex']),
    colIndex: _asInt(json['colIndex']),
    rowList: json['rowList'] is List
        ? _deserializeRowList(json['rowList'] as List<dynamic>)
        : null,
    positionList: json['positionList'] is List
        ? _deserializeElementPositionList(
            json['positionList'] as List<dynamic>,
          )
        : null,
    verticalAlign: _enumFromName(
      VerticalAlign.values,
      json['verticalAlign'] as String?,
    ),
    backgroundColor: json['backgroundColor'] as String?,
    borderTypes: borderTypes,
    slashTypes: slashTypes,
    mainHeight: _asDouble(json['mainHeight']),
    realHeight: _asDouble(json['realHeight']),
    realMinHeight: _asDouble(json['realMinHeight']),
    disabled: json['disabled'] as bool?,
    deletable: json['deletable'] as bool?,
  );
}

Map<String, dynamic> _serializeRow(IRow row) {
  return <String, dynamic>{
    'width': row.width,
    'height': row.height,
    'ascent': row.ascent,
    if (row.rowFlex != null) 'rowFlex': row.rowFlex!.name,
    'startIndex': row.startIndex,
    if (row.isPageBreak != null) 'isPageBreak': row.isPageBreak,
    if (row.isList != null) 'isList': row.isList,
    if (row.listIndex != null) 'listIndex': row.listIndex,
    if (row.offsetX != null) 'offsetX': row.offsetX,
    if (row.offsetY != null) 'offsetY': row.offsetY,
    'elementList':
        row.elementList.map(_serializeRowElement).toList(growable: false),
    if (row.isWidthNotEnough != null) 'isWidthNotEnough': row.isWidthNotEnough,
    'rowIndex': row.rowIndex,
    if (row.isSurround != null) 'isSurround': row.isSurround,
  };
}

List<IRow> _deserializeRowList(List<dynamic>? data) {
  if (data == null) {
    return <IRow>[];
  }
  return data
      .map((entry) => entry is Map<String, dynamic>
          ? _deserializeRow(entry)
          : entry is Map
              ? _deserializeRow(entry.cast<String, dynamic>())
              : null)
      .whereType<IRow>()
      .toList();
}

IRow _deserializeRow(Map<String, dynamic> json) {
  return IRow(
    width: _asDouble(json['width']) ?? 0,
    height: _asDouble(json['height']) ?? 0,
    ascent: _asDouble(json['ascent']) ?? 0,
    rowFlex: _enumFromName(RowFlex.values, json['rowFlex'] as String?),
    startIndex: _asInt(json['startIndex']) ?? 0,
    isPageBreak: json['isPageBreak'] as bool?,
    isList: json['isList'] as bool?,
    listIndex: _asInt(json['listIndex']),
    offsetX: _asDouble(json['offsetX']),
    offsetY: _asDouble(json['offsetY']),
    elementList: _deserializeRowElementList(_asList(json['elementList'])),
    isWidthNotEnough: json['isWidthNotEnough'] as bool?,
    rowIndex: _asInt(json['rowIndex']) ?? 0,
    isSurround: json['isSurround'] as bool?,
  );
}

List<IRowElement> _deserializeRowElementList(List<dynamic> data) {
  return data
      .map((entry) => entry is Map<String, dynamic>
          ? _deserializeRowElement(entry)
          : entry is Map
              ? _deserializeRowElement(entry.cast<String, dynamic>())
              : null)
      .whereType<IRowElement>()
      .toList();
}

IRowElement _deserializeRowElement(Map<String, dynamic> json) {
  final metrics = _deserializeElementMetrics(_asMap(json['metrics']));
  final style = json['style'] as String? ?? '';
  final left = _asDouble(json['left']);

  final baseMap = Map<String, dynamic>.from(json)
    ..remove('metrics')
    ..remove('style')
    ..remove('left');

  final baseElement = _deserializeElement(baseMap);

  return IRowElement(
    metrics: metrics,
    style: style,
    left: left,
    id: baseElement.id,
    type: baseElement.type,
    value: baseElement.value,
    extension: baseElement.extension,
    externalId: baseElement.externalId,
    font: baseElement.font,
    size: baseElement.size,
    width: baseElement.width,
    height: baseElement.height,
    bold: baseElement.bold,
    color: baseElement.color,
    highlight: baseElement.highlight,
    italic: baseElement.italic,
    underline: baseElement.underline,
    strikeout: baseElement.strikeout,
    rowFlex: baseElement.rowFlex,
    rowMargin: baseElement.rowMargin,
    letterSpacing: baseElement.letterSpacing,
    textDecoration: baseElement.textDecoration,
    hide: baseElement.hide,
    groupIds: baseElement.groupIds,
    colgroup: baseElement.colgroup,
    trList: baseElement.trList,
    borderType: baseElement.borderType,
    borderColor: baseElement.borderColor,
    borderWidth: baseElement.borderWidth,
    borderExternalWidth: baseElement.borderExternalWidth,
    translateX: baseElement.translateX,
    tableToolDisabled: baseElement.tableToolDisabled,
    tdId: baseElement.tdId,
    trId: baseElement.trId,
    tableId: baseElement.tableId,
    conceptId: baseElement.conceptId,
    pagingId: baseElement.pagingId,
    pagingIndex: baseElement.pagingIndex,
    valueList: baseElement.valueList,
    url: baseElement.url,
    hyperlinkId: baseElement.hyperlinkId,
    actualSize: baseElement.actualSize,
    dashArray: baseElement.dashArray,
    control: baseElement.control,
    controlId: baseElement.controlId,
    controlComponent: baseElement.controlComponent,
    checkbox: baseElement.checkbox,
    radio: baseElement.radio,
    laTexSVG: baseElement.laTexSVG,
    dateFormat: baseElement.dateFormat,
    dateId: baseElement.dateId,
    imgDisplay: baseElement.imgDisplay,
    imgFloatPosition: baseElement.imgFloatPosition,
    imgToolDisabled: baseElement.imgToolDisabled,
    block: baseElement.block,
    level: baseElement.level,
    titleId: baseElement.titleId,
    title: baseElement.title,
    listType: baseElement.listType,
    listStyle: baseElement.listStyle,
    listId: baseElement.listId,
    listWrap: baseElement.listWrap,
    areaId: baseElement.areaId,
    areaIndex: baseElement.areaIndex,
    area: baseElement.area,
  );
}

Map<String, dynamic> _serializeRowElement(IRowElement element) {
  final map = _serializeElement(element);
  map['metrics'] = _serializeElementMetrics(element.metrics);
  map['style'] = element.style;
  if (element.left != null) {
    map['left'] = element.left;
  }
  return map;
}

Map<String, dynamic> _serializeElementMetrics(IElementMetrics metrics) {
  return <String, dynamic>{
    'width': metrics.width,
    'height': metrics.height,
    'boundingBoxAscent': metrics.boundingBoxAscent,
    'boundingBoxDescent': metrics.boundingBoxDescent,
  };
}

IElementMetrics _deserializeElementMetrics(Map<String, dynamic> json) {
  return IElementMetrics(
    width: _asDouble(json['width']) ?? 0,
    height: _asDouble(json['height']) ?? 0,
    boundingBoxAscent: _asDouble(json['boundingBoxAscent']) ?? 0,
    boundingBoxDescent: _asDouble(json['boundingBoxDescent']) ?? 0,
  );
}

Map<String, dynamic> _serializeElementPosition(IElementPosition position) {
  return <String, dynamic>{
    'pageNo': position.pageNo,
    'index': position.index,
    'value': position.value,
    'rowIndex': position.rowIndex,
    'rowNo': position.rowNo,
    'ascent': position.ascent,
    'lineHeight': position.lineHeight,
    'left': position.left,
    'metrics': _serializeElementMetrics(position.metrics),
    'isFirstLetter': position.isFirstLetter,
    'isLastLetter': position.isLastLetter,
    'coordinate': position.coordinate.map(
      (key, value) => MapEntry(
        key,
        value.map((offset) => offset.toDouble()).toList(),
      ),
    ),
  };
}

List<IElementPosition> _deserializeElementPositionList(List<dynamic> data) {
  return data
      .map((entry) => entry is Map<String, dynamic>
          ? _deserializeElementPosition(entry)
          : entry is Map
              ? _deserializeElementPosition(entry.cast<String, dynamic>())
              : null)
      .whereType<IElementPosition>()
      .toList();
}

IElementPosition _deserializeElementPosition(Map<String, dynamic> json) {
  final coordinate = <String, List<double>>{};
  if (json['coordinate'] is Map) {
    json['coordinate'].cast<String, dynamic>().forEach((key, value) {
      if (value is List) {
        coordinate[key] =
            value.whereType<num>().map((entry) => entry.toDouble()).toList();
      }
    });
  }

  return IElementPosition(
    pageNo: _asInt(json['pageNo']) ?? 0,
    index: _asInt(json['index']) ?? 0,
    value: json['value'] as String? ?? '',
    rowIndex: _asInt(json['rowIndex']) ?? 0,
    rowNo: _asInt(json['rowNo']) ?? 0,
    ascent: _asDouble(json['ascent']) ?? 0,
    lineHeight: _asDouble(json['lineHeight']) ?? 0,
    left: _asDouble(json['left']) ?? 0,
    metrics: _deserializeElementMetrics(_asMap(json['metrics'])),
    isFirstLetter: json['isFirstLetter'] as bool? ?? false,
    isLastLetter: json['isLastLetter'] as bool? ?? false,
    coordinate: coordinate,
  );
}

double? _asDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

int? _asInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  if (value is List) {
    return value;
  }
  return const <dynamic>[];
}

T? _enumFromName<T extends Enum>(List<T> values, String? name) {
  if (name == null) {
    return null;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}
