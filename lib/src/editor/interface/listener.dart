import 'dart:html' show Event, MouseEvent;

import '../dataset/enum/editor.dart';
import '../dataset/enum/element.dart';
import '../dataset/enum/list.dart';
import '../dataset/enum/row.dart';
import '../dataset/enum/title.dart';
import './editor.dart';
import './element.dart';
import './position.dart';

class IRangeStyle {
  ElementType? type;
  bool undo;
  bool redo;
  bool painter;
  String font;
  double size;
  bool bold;
  bool italic;
  bool underline;
  bool strikeout;
  String? color;
  String? highlight;
  RowFlex? rowFlex;
  double rowMargin;
  List<double> dashArray;
  TitleLevel? level;
  ListType? listType;
  ListStyle? listStyle;
  List<String>? groupIds;
  ITextDecoration? textDecoration;
  dynamic extension;

  IRangeStyle({
    this.type,
    required this.undo,
    required this.redo,
    required this.painter,
    required this.font,
    required this.size,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strikeout,
    this.color,
    this.highlight,
    this.rowFlex,
    required this.rowMargin,
    required this.dashArray,
    this.level,
    this.listType,
    this.listStyle,
    this.groupIds,
    this.textDecoration,
    this.extension,
  });
}

typedef IRangeStyleChange = void Function(IRangeStyle payload);

typedef IVisiblePageNoListChange = void Function(List<int> payload);

typedef IIntersectionPageNoChange = void Function(int payload);

typedef IPageSizeChange = void Function(double payload);

typedef IPageScaleChange = void Function(double payload);

typedef ISaved = void Function(IEditorResult payload);

typedef IContentChange = void Function();

typedef IControlChange = void Function(IControlChangeResult payload);

typedef IControlContentChange = void Function(IControlContentChangeResult payload);

typedef IPageModeChange = void Function(PageMode payload);

typedef IZoneChange = void Function(EditorZone payload);

typedef IMouseEventChange = void Function(MouseEvent evt);

typedef IInputEventChange = void Function(Event evt);

class IPositionContextChangePayload {
  IPositionContext value;
  IPositionContext oldValue;

  IPositionContextChangePayload({
    required this.value,
    required this.oldValue,
  });
}

typedef IPositionContextChange = void Function(
  IPositionContextChangePayload payload,
);

class IImageSizeChangePayload {
  IElement element;

  IImageSizeChangePayload({required this.element});
}

typedef IImageSizeChange = void Function(IImageSizeChangePayload payload);

class IImageMousedownPayload {
  MouseEvent evt;
  IElement element;

  IImageMousedownPayload({
    required this.evt,
    required this.element,
  });
}

typedef IImageMousedown = void Function(IImageMousedownPayload payload);
