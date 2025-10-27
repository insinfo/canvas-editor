import './element.dart';
import './range.dart';

class IPasteOption {
  bool isPlainText;

  IPasteOption({required this.isPlainText});
}

class ITableInfoByEvent {
  IElement element;
  int trIndex;
  int tdIndex;

  ITableInfoByEvent({
    required this.element,
    required this.trIndex,
    required this.tdIndex,
  });
}

class IPositionContextByEventResult {
  int pageNo;
  IElement? element;
  RangeRect? rangeRect;
  ITableInfoByEvent? tableInfo;

  IPositionContextByEventResult({
    required this.pageNo,
    this.element,
    this.rangeRect,
    this.tableInfo,
  });
}

class IPositionContextByEventOption {
  bool? isMustDirectHit;

  IPositionContextByEventOption({this.isMustDirectHit});
}

class ICopyOption {
  bool isPlainText;

  ICopyOption({required this.isPlainText});
}
